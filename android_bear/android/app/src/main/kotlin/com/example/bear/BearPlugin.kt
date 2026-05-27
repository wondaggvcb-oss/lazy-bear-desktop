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

    private val skinPaths = mutableListOf<String>()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showBear" -> handleShowBear(result)
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
            else -> result.notImplemented()
        }
    }

    private fun handleShowBear(result: MethodChannel.Result) {
        if (!FloatService.hasOverlayPermission(context)) {
            result.success(false)
            return
        }
        val intent = Intent(context, FloatService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        result.success(true)
    }

    private fun handleHideBear(result: MethodChannel.Result) {
        context.stopService(Intent(context, FloatService::class.java))
        FloatService.isRunning = false
        result.success(null)
    }

    private fun handleUpdateSkin(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path") ?: ""
        // TODO: 通过 Messenger 或 binder 通知正在运行的 FloatService
        // Version 1: 重启 service 传递 path
        result.success(null)
    }

    private fun handleShowPlaceholder(result: MethodChannel.Result) {
        result.success(null)
    }

    private fun handleStartRotation(call: MethodCall, result: MethodChannel.Result) {
        val interval = call.argument<Int>("interval") ?: 10
        // TODO: 通知 FloatService
        result.success(null)
    }

    private fun handleStopRotation(result: MethodChannel.Result) {
        result.success(null)
    }

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
}
