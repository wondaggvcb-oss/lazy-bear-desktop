package com.example.bear

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class ReminderReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "bear_reminder_channel"
        const val NOTIFICATION_ID = 2001
    }

    override fun onReceive(context: Context, intent: Intent) {
        createNotificationChannel(context)

        val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = PendingIntent.getActivity(
            context, 0, appIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val titles = listOf(
            "熊：到点啦，该休息一下哦～",
            "熊：熊提醒你喝水了",
            "熊：别太累了，站起来走走～",
            "熊：抬头看看窗外，熊在你好旁边",
        )
        val title = titles.random()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("熊")
            .setContentText(title)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "熊提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "每日提醒"
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
