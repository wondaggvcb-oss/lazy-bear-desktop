package com.example.bear

import android.content.Context
import android.graphics.*
import androidx.core.content.ContextCompat

object GifHelper {

    /**
     * 生成占位气泡图片。
     * 后续版本可替换为资源文件或更精美的绘制。
     */
    fun createPlaceholderBitmap(context: Context, text: String, width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 背景圆角矩形
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(200, 139, 105, 20) // #8B6914
            style = Paint.Style.FILL
        }
        val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(rect, 20f, 20f, paint)

        // 文字
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 14f * context.resources.displayMetrics.density
            textAlign = Paint.Align.CENTER
        }
        val x = width / 2f
        val y = height / 2f - (textPaint.descent() + textPaint.ascent()) / 2f
        canvas.drawText(text, x, y, textPaint)

        return bitmap
    }

    /**
     * 验证 GIF 文件是否有效且大小在限制内。
     * @return true 表示可以接受
     */
    fun isValidGif(path: String, maxSizeBytes: Long = 5 * 1024 * 1024): Boolean {
        val file = java.io.File(path)
        if (!file.exists() || !file.isFile) return false
        if (file.length() > maxSizeBytes) return false

        val name = file.name.lowercase()
        return name.endsWith(".gif")
    }
}
