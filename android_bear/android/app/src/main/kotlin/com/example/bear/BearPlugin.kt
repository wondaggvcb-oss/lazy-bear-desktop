package com.example.bear

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

class BearPlugin(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    companion object {
        fun register(messenger: io.flutter.plugin.common.BinaryMessenger, activity: MainActivity) {
            val channel = MethodChannel(messenger, "com.example.bear/float_service")
            channel.setMethodCallHandler(BearPlugin(activity, channel))
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showBear" -> handleShowBear(call, result)
            "hideBear" -> handleHideBear(result)
            "updateSkin" -> handleUpdateSkin(call, result)
            "showPlaceholder" -> handleShowPlaceholder(result)
            "startRotation" -> handleStartRotation(call, result)
            "stopRotation" -> handleStopRotation(result)
            "setReminder" -> handleSetReminder(call, result)
            "cancelReminder" -> handleCancelReminder(result)
            "hasOverlayPermission" -> result.success(FloatService.hasOverlayPermission(context))
            "requestOverlayPermission" -> {
                FloatService.requestOverlayPermission(context)
                result.success(null)
            }
            "chatWithBear" -> handleChat(call, result)
            else -> result.notImplemented()
        }
    }

    // ──── 悬浮窗 ────

    private fun handleShowBear(call: MethodCall, result: MethodChannel.Result) {
        if (!FloatService.hasOverlayPermission(context)) {
            result.success(false)
            return
        }

        val skinPaths = call.argument<List<String>>("skinPaths") ?: emptyList()
        val placeholder = call.argument<Boolean>("placeholder") ?: true

        val intent = Intent(context, FloatService::class.java).apply {
            putStringArrayListExtra("skinPaths", ArrayList(skinPaths))
            putExtra("placeholder", placeholder)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }

        // 等 Service 启动后再发送皮肤路径
        mainHandler.postDelayed({
            val serviceIntent = Intent("com.example.bear.ACTION_SHOW_BEAR").apply {
                putStringArrayListExtra("skinPaths", ArrayList(skinPaths))
                putExtra("placeholder", placeholder)
            }
            context.sendBroadcast(serviceIntent)
        }, 200)

        result.success(true)
    }

    private fun handleHideBear(result: MethodChannel.Result) {
        context.stopService(Intent(context, FloatService::class.java))
        FloatService.isRunning = false
        result.success(null)
    }

    private fun handleUpdateSkin(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: ""
        val intent = Intent("com.example.bear.ACTION_UPDATE_SKIN").apply {
            putExtra("path", path)
        }
        context.sendBroadcast(intent)
        result.success(null)
    }

    private fun handleShowPlaceholder(result: MethodChannel.Result) {
        val intent = Intent("com.example.bear.ACTION_SHOW_PLACEHOLDER")
        context.sendBroadcast(intent)
        result.success(null)
    }

    private fun handleStartRotation(call: MethodCall, result: MethodChannel.Result) {
        val interval = call.argument<Int>("interval") ?: 10
        val paths = call.argument<List<String>>("skinPaths") ?: emptyList()
        val intent = Intent("com.example.bear.ACTION_START_ROTATION").apply {
            putExtra("interval", interval)
            putStringArrayListExtra("skinPaths", ArrayList(paths))
        }
        context.sendBroadcast(intent)
        result.success(null)
    }

    private fun handleStopRotation(result: MethodChannel.Result) {
        val intent = Intent("com.example.bear.ACTION_STOP_ROTATION")
        context.sendBroadcast(intent)
        result.success(null)
    }

    // ──── 提醒 ────

    private fun handleSetReminder(call: MethodCall, result: MethodChannel.Result) {
        val hour = call.argument<Int>("hour") ?: return result.error("INVALID", "hour required", null)
        val minute = call.argument<Int>("minute") ?: return result.error("INVALID", "minute required", null)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(Calendar.getInstance())) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val canSchedule = alarmManager.canScheduleExactAlarms()
                if (!canSchedule) {
                    result.error("PERMISSION", "需要精确闹钟权限", null)
                    return
                }
            }
            alarmManager.setRepeating(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                AlarmManager.INTERVAL_DAY,
                pending
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("ALARM_ERROR", e.localizedMessage, null)
        }
    }

    private fun handleCancelReminder(result: MethodChannel.Result) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        alarmManager.cancel(pending)
        result.success(null)
    }

    // ──── 聊天 (DeepSeek API) ────

    private fun handleChat(call: MethodCall, result: MethodChannel.Result) {
        val apiKey = call.argument<String>("apiKey") ?: return result.error("INVALID", "apiKey required", null)
        val question = call.argument<String>("question") ?: return result.error("INVALID", "question required", null)
        val personality = call.argument<String>("personality") ?: ""

        val systemPrompt = buildString {
            append("你的名字叫熊，是一只懒懒但很温暖、很可爱的桌面小熊。")
            append("你非常喜欢人类，你觉得用户是被你领养的人：你要负责把他照顾好。")
            append("回答要一针见血，少废话，但语气软一点、可爱一点。")
            append("不要热血，不要油腻，不要长篇安慰或说教；像刚睡醒但很聪明、很护短的小熊。")
            append("可以偶尔带一点颜文字。")

            val now = Calendar.getInstance()
            val timeStr = String.format(
                "%d年%d月%d日 %02d:%02d",
                now.get(Calendar.YEAR),
                now.get(Calendar.MONTH) + 1,
                now.get(Calendar.DAY_OF_MONTH),
                now.get(Calendar.HOUR_OF_DAY),
                now.get(Calendar.MINUTE)
            )
            append("\n当前本机时间：$timeStr。如果用户询问时间、日期、星期相关问题，必须以这个时间为准，不要猜测。")

            if (personality.isNotBlank()) {
                append("\n用户自定义熊性格：$personality。自定义性格优先，但名字叫熊、回答简短这两条不变。")
            }
        }

        Thread {
            try {
                val url = java.net.URL("https://api.deepseek.com/chat/completions")
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Authorization", "Bearer $apiKey")
                connection.setRequestProperty("Content-Type", "application/json")
                connection.connectTimeout = 30_000
                connection.readTimeout = 30_000
                connection.doOutput = true

                val body = """
                    {
                        "model": "deepseek-chat",
                        "messages": [
                            {"role": "system", "content": ${toJsonString(systemPrompt)}},
                            {"role": "user", "content": ${toJsonString(question)}}
                        ]
                    }
                """.trimIndent()

                connection.outputStream.use { it.write(body.toByteArray()) }

                val responseCode = connection.responseCode
                val responseText = if (responseCode in 200..299) {
                    connection.inputStream.bufferedReader().readText()
                } else {
                    connection.errorStream?.bufferedReader()?.readText() ?: "HTTP $responseCode"
                }

                val answer = try {
                    val json = org.json.JSONObject(responseText)
                    val choices = json.getJSONArray("choices")
                    choices.getJSONObject(0).getJSONObject("message").getString("content")
                } catch (e: Exception) {
                    null
                }

                mainHandler.post {
                    if (answer != null) {
                        result.success(answer)
                    } else {
                        result.error("API_ERROR", responseText, null)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("NETWORK_ERROR", e.localizedMessage, null)
                }
            }
        }.start()
    }

    private fun toJsonString(s: String): String {
        return "\"" + s
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t") + "\""
    }
}
