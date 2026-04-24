package com.sofian.quran

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class PrayerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("HomeWidgetPlugin", Context.MODE_PRIVATE)

            val prayerName    = prefs.getString("next_prayer_name",     "—") ?: "—"
            val prayerTime    = prefs.getString("next_prayer_time",     "—") ?: "—"
            val prayerArabic  = prefs.getString("next_prayer_arabic",   "")  ?: ""
            val countdown     = prefs.getString("next_prayer_countdown","")  ?: ""

            val views = RemoteViews(context.packageName, R.layout.widget_prayer_times)
            views.setTextViewText(R.id.tv_prayer_name,   prayerName)
            views.setTextViewText(R.id.tv_prayer_time,   prayerTime)
            views.setTextViewText(R.id.tv_prayer_arabic, prayerArabic)
            views.setTextViewText(R.id.tv_countdown,     countdown)

            // Tap → ouvre l'app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
