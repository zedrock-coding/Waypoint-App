package com.waypoint.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

open class WaypointMonthWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

class WaypointWeekWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_agenda_layout)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

class WaypointDayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_priority_layout)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

class WaypointWidgetProvider : WaypointMonthWidgetProvider()
