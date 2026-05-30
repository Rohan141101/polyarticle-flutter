package com.rohan.flashfeed2

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class ArticleFetchWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val url = URL("https://polyarticle-app.onrender.com/feed/widget")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 15000
            conn.readTimeout = 15000

            if (conn.responseCode != 200) {
                conn.disconnect()
                return@withContext Result.retry()
            }

            val body = conn.inputStream.bufferedReader().readText()
            conn.disconnect()

            val json = JSONObject(body)
            val articles: JSONArray = json.getJSONArray("articles")
            if (articles.length() == 0) return@withContext Result.retry()

            val prefs = applicationContext.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )
            prefs.edit()
                .putString("widget_articles", articles.toString())
                .putInt("widget_article_index", 0)
                .apply()

            // Download and cache images for all articles
            for (i in 0 until articles.length()) {
                val article = articles.getJSONObject(i)
                val imageUrl = article.optString("image_url", "")
                if (imageUrl.isNotEmpty()) {
                    downloadImage(applicationContext, imageUrl, i)
                }
            }

            // Trigger widget redraw
            val manager = AppWidgetManager.getInstance(applicationContext)
            val ids = manager.getAppWidgetIds(
                ComponentName(applicationContext, NewsWidget::class.java)
            )
            for (id in ids) {
                updateWidget(applicationContext, manager, id)
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private fun downloadImage(context: Context, imageUrl: String, index: Int) {
        try {
            val conn = URL(imageUrl).openConnection() as HttpURLConnection
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            conn.instanceFollowRedirects = true
            val raw = BitmapFactory.decodeStream(conn.inputStream) ?: return
            conn.disconnect()

            // Scale down to keep binder IPC within limits
            val maxW = 600
            val maxH = 400
            val scaleW = maxW.toFloat() / raw.width
            val scaleH = maxH.toFloat() / raw.height
            val scale = minOf(scaleW, scaleH, 1f)
            val bitmap = if (scale < 1f) {
                Bitmap.createScaledBitmap(
                    raw,
                    (raw.width * scale).toInt(),
                    (raw.height * scale).toInt(),
                    true
                )
            } else raw

            val file = File(context.cacheDir, "widget_img_$index.jpg")
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            }
        } catch (_: Exception) {}
    }
}
