package com.example.bear

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import java.io.File

class FloatService : Service() {

    private lateinit var windowManager: WindowManager
    private var floatView: View? = null
    private var bearImage: ImageView? = null
    private var skinPaths: MutableList<String> = mutableListOf()
    private var currentSkinIndex = 0
    private var rotationInterval = 10
    private var rotationHandler: Handler? = null
    private var rotationRunnable: Runnable? = null
    private var broadcastReceiver: BroadcastReceiver? = null

    companion object {
        @Volatile
        var isRunning = false
        const val CHANNEL_ID = "bear_float_channel"
        const val NOTIFICATION_ID = 1001

        // Local broadcast actions
        const val ACTION_SHOW_BEAR = "com.example.bear.ACTION_SHOW_BEAR"
        const val ACTION_UPDATE_SKIN = "com.example.bear.ACTION_UPDATE_SKIN"
        const val ACTION_SHOW_PLACEHOLDER = "com.example.bear.ACTION_SHOW_PLACEHOLDER"
        const val ACTION_START_ROTATION = "com.example.bear.ACTION_START_ROTATION"
        const val ACTION_STOP_ROTATION = "com.example.bear.ACTION_STOP_ROTATION"
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        registerBroadcastReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        isRunning = true
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        stopRotation()
        removeFloatView()
        unregisterBroadcastReceiver()
        super.onDestroy()
    }

    private fun registerBroadcastReceiver() {
        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_SHOW_BEAR -> {
                        val paths = intent.getStringArrayListExtra("skinPaths") ?: arrayListOf()
                        val placeholder = intent.getBooleanExtra("placeholder", false)
                        showBear(paths, placeholder)
                    }
                    ACTION_UPDATE_SKIN -> {
                        val path = intent.getStringExtra("path") ?: return
                        updateSkin(path)
                    }
                    ACTION_SHOW_PLACEHOLDER -> {
                        showPlaceholderViewOnly()
                    }
                    ACTION_START_ROTATION -> {
                        val interval = intent.getIntExtra("interval", 10)
                        val paths = intent.getStringArrayListExtra("skinPaths") ?: arrayListOf()
                        startRotation(interval, paths)
                    }
                    ACTION_STOP_ROTATION -> {
                        stopRotation()
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_SHOW_BEAR)
            addAction(ACTION_UPDATE_SKIN)
            addAction(ACTION_SHOW_PLACEHOLDER)
            addAction(ACTION_START_ROTATION)
            addAction(ACTION_STOP_ROTATION)
        }
        registerReceiver(broadcastReceiver, filter)
    }

    private fun unregisterBroadcastReceiver() {
        broadcastReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
        }
    }

    // ──── 悬浮窗 ────

    fun showBear(newSkinPaths: List<String>, placeholder: Boolean) {
        this.skinPaths = newSkinPaths.toMutableList()
        removeFloatView()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 100
        params.y = 200

        bearImage = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = WindowManager.LayoutParams(170, 170)
        }

        // 加载 GIF 或占位
        if (newSkinPaths.isNotEmpty()) {
            loadGif(newSkinPaths[0])
        } else if (placeholder) {
            showPlaceholderView()
        }

        // 拖动逻辑
        val touchListener = View.OnTouchListener { view, event ->
            if (event.action == MotionEvent.ACTION_MOVE) {
                params.x = event.rawX.toInt() - view.width / 2
                params.y = event.rawY.toInt() - view.height / 2
                windowManager.updateViewLayout(floatView, params)
                true
            } else if (event.action == MotionEvent.ACTION_UP) {
                view.performClick()
                true
            } else {
                false
            }
        }

        val clickListener = View.OnClickListener {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (launchIntent != null) {
                startActivity(launchIntent)
            }
        }

        bearImage?.setOnTouchListener(touchListener)
        bearImage?.setOnClickListener(clickListener)
        bearImage?.isClickable = true

        floatView = bearImage
        windowManager.addView(floatView, params)
    }

    fun hideBear() {
        stopRotation()
        removeFloatView()
        stopSelf()
    }

    fun updateSkin(path: String) {
        bearImage?.let {
            Glide.with(this)
                .load(File(path))
                .into(it)
        }
    }

    fun showPlaceholderViewOnly() {
        removeFloatView()
        showBear(emptyList(), placeholder = true)
    }

    fun startRotation(intervalSeconds: Int, paths: List<String>) {
        skinPaths = paths.toMutableList()
        rotationInterval = intervalSeconds

        if (skinPaths.size <= 1 || rotationInterval <= 0) {
            stopRotation()
            return
        }

        rotationHandler = Handler(Looper.getMainLooper())
        rotationRunnable = object : Runnable {
            override fun run() {
                currentSkinIndex = (currentSkinIndex + 1) % skinPaths.size
                updateSkin(skinPaths[currentSkinIndex])
                rotationHandler?.postDelayed(this, rotationInterval * 1000L)
            }
        }
        rotationHandler?.postDelayed(rotationRunnable!!, rotationInterval * 1000L)
    }

    fun stopRotation() {
        rotationHandler?.removeCallbacks(rotationRunnable ?: return)
        rotationHandler = null
        rotationRunnable = null
    }

    // ──── 内部工具 ────

    private fun loadGif(path: String) {
        bearImage?.let {
            Glide.with(this)
                .asGif()
                .load(File(path))
                .into(it)
        }
    }

    private fun showPlaceholderView() {
        bearImage?.let {
            it.setBackgroundColor(0x44_8B6914.toInt())
            it.alpha = 0.3f
        }
    }

    private fun removeFloatView() {
        floatView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {}
            floatView = null
            bearImage = null
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("熊")
            .setContentText("熊在桌面上陪你～")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pending)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "悬浮熊服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "维持悬浮熊在桌面运行"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    // ──── 工具方法 ────

    companion object {
        fun hasOverlayPermission(context: Context): Boolean {
            return Settings.canDrawOverlays(context)
        }

        fun requestOverlayPermission(context: Context) {
            if (!hasOverlayPermission(context)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
            }
        }
    }
}
