package com.rohan.flashfeed2

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONArray

class WidgetRotateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val articlesJson = prefs.getString("widget_articles", null) ?: return

        val articles = try { JSONArray(articlesJson) } catch (e: Exception) { return }
        if (articles.length() == 0) return

        val current = prefs.getInt("widget_article_index", 0)
        val next = (current + 1) % articles.length()
        prefs.edit().putInt("widget_article_index", next).apply()

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, NewsWidget::class.java))
        for (id in ids) {
            updateWidget(context, manager, id)
        }
    }
}
