package com.rohan.flashfeed2

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONArray
import java.io.File
import java.util.concurrent.TimeUnit

class NewsWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        scheduleFetch(context)
        scheduleRotation(context)
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDisabled(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, WidgetRotateReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
    }
}

fun scheduleFetch(context: Context) {
    val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()

    val periodic = PeriodicWorkRequestBuilder<ArticleFetchWorker>(1, TimeUnit.HOURS)
        .setConstraints(constraints)
        .build()

    WorkManager.getInstance(context).enqueueUniquePeriodicWork(
        "widget_article_fetch",
        ExistingPeriodicWorkPolicy.KEEP,
        periodic
    )

    val immediate = OneTimeWorkRequestBuilder<ArticleFetchWorker>()
        .setConstraints(constraints)
        .build()
    WorkManager.getInstance(context).enqueue(immediate)
}

fun scheduleRotation(context: Context) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val intent = Intent(context, WidgetRotateReceiver::class.java)
    val pi = PendingIntent.getBroadcast(
        context, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    alarmManager.setInexactRepeating(
        AlarmManager.RTC,
        System.currentTimeMillis() + 5 * 60 * 1000L,
        5 * 60 * 1000L,
        pi
    )
}

fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val articlesJson = prefs.getString("widget_articles", null)
    val index = prefs.getInt("widget_article_index", 0)

    var title = "Loading latest news..."
    var source = "PolyArticle"
    var articleUrl = ""
    var imageIndex = index

    if (articlesJson != null) {
        try {
            val articles = JSONArray(articlesJson)
            if (articles.length() > 0) {
                val i = index % articles.length()
                val article = articles.getJSONObject(i)
                title = article.optString("title", title)
                source = article.optString("source", source)
                articleUrl = article.optString("url", "")
                imageIndex = i
            }
        } catch (_: Exception) {}
    }

    // Pick layout based on current widget size
    val options = appWidgetManager.getAppWidgetOptions(widgetId)
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
    val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)

    val layoutId = when {
        minWidth < 200 || minHeight < 200 -> R.layout.news_widget_small
        minHeight >= 250 -> R.layout.news_widget_large
        else -> R.layout.news_widget
    }

    val views = RemoteViews(context.packageName, layoutId)
    views.setTextViewText(R.id.widget_title, title)
    views.setTextViewText(R.id.widget_source, source)

    // Load cached image
    val imageFile = File(context.cacheDir, "widget_img_$imageIndex.jpg")
    if (imageFile.exists()) {
        try {
            val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_bg_image, bitmap)
                views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)
            }
        } catch (_: Exception) {
            views.setViewVisibility(R.id.widget_bg_image, View.GONE)
        }
    } else {
        views.setViewVisibility(R.id.widget_bg_image, View.GONE)
    }

    // Click intent — carries article URL so Flutter can open it directly
    val clickIntent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        if (articleUrl.isNotEmpty()) {
            data = Uri.parse(
                "homewidget://article?url=${Uri.encode(articleUrl)}" +
                "&title=${Uri.encode(title)}&source=${Uri.encode(source)}"
            )
        }
    }
    val pendingIntent = PendingIntent.getActivity(
        context, widgetId, clickIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setOnClickPendingIntent(R.id.news_widget_root, pendingIntent)

    appWidgetManager.updateAppWidget(widgetId, views)
}
