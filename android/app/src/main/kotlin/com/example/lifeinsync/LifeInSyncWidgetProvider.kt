package com.example.lifeinsync

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class LifeInSyncWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_lifeinsync)
      val hours = widgetData.getString("daily_hours", "0.0") ?: "0.0"
      val wellbeing = widgetData.getString("wellbeing_score", "--") ?: "--"

      views.setTextViewText(R.id.widget_daily_hours, "${hours}h")
      views.setTextViewText(R.id.widget_wellbeing, wellbeing)
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
