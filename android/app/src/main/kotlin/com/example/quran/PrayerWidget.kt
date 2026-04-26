package com.sofian.quran

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import java.util.Calendar

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

        private data class PrayerCol(
            val name: String,
            val colId: Int,
            val nameId: Int,
            val timeId: Int,
        )

        private val PRAYERS = listOf(
            PrayerCol("Fajr",    R.id.col_fajr,    R.id.tv_fajr_name,    R.id.tv_fajr_time),
            PrayerCol("Sunrise", R.id.col_sunrise, R.id.tv_sunrise_name, R.id.tv_sunrise_time),
            PrayerCol("Dhuhr",   R.id.col_dhuhr,   R.id.tv_dhuhr_name,   R.id.tv_dhuhr_time),
            PrayerCol("Asr",     R.id.col_asr,     R.id.tv_asr_name,     R.id.tv_asr_time),
            PrayerCol("Maghrib", R.id.col_maghrib, R.id.tv_maghrib_name, R.id.tv_maghrib_time),
            PrayerCol("Isha",    R.id.col_isha,    R.id.tv_isha_name,    R.id.tv_isha_time),
        )

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs      = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val activeName = prefs.getString("pw_active", "") ?: ""
            val hijri      = prefs.getString("pw_hijri",  "") ?: ""

            val cal    = Calendar.getInstance()
            val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

            val views = RemoteViews(context.packageName, R.layout.widget_prayer_times)

            views.setTextViewText(R.id.tv_hijri, hijri)

            for (prayer in PRAYERS) {
                val key     = "pw_${prayer.name.lowercase()}"
                val timeStr = prefs.getString(key, "—") ?: "—"

                views.setTextViewText(prayer.nameId, prayer.name)
                views.setTextViewText(prayer.timeId, timeStr)

                // Fond actif (gradient or) ou transparent
                if (prayer.name == activeName) {
                    views.setInt(prayer.colId, "setBackgroundResource", R.drawable.widget_prayer_active_bg)
                } else {
                    views.setInt(prayer.colId, "setBackgroundColor", Color.TRANSPARENT)
                }

                // Prières passées à 55% alpha (jamais pour la prière active)
                val past = prayer.name != activeName && isPast(timeStr, nowMin)
                views.setFloat(prayer.colId, "setAlpha", if (past) 0.55f else 1.0f)

                // Sunrise : couleur ambre fixe
                if (prayer.name == "Sunrise") {
                    views.setTextColor(prayer.nameId, 0xFFFFA726.toInt())
                }
            }

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

        /** Retourne true si "HH:MM" représente une heure déjà passée aujourd'hui. */
        private fun isPast(timeStr: String, nowMin: Int): Boolean {
            val parts = timeStr.split(":")
            if (parts.size < 2) return false
            val h = parts[0].trim().toIntOrNull() ?: return false
            val m = parts[1].trim().take(2).toIntOrNull() ?: return false
            return (h * 60 + m) < nowMin
        }
    }
}
