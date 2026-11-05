package com.waypoint.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

open class WaypointMonthWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val dateFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
        val currentMonthYear = dateFormat.format(Calendar.getInstance().time)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
            views.setTextViewText(R.id.widget_title, currentMonthYear)

            // Bind calendar grid collection service
            val serviceIntent = Intent(context, MonthWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            views.setRemoteAdapter(R.id.calendar_grid, serviceIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.calendar_grid)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
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
        super.onUpdate(context, appWidgetManager, appWidgetIds)
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
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }
}

class WaypointWidgetProvider : WaypointMonthWidgetProvider()

class MonthWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthViewsFactory(applicationContext)
    }
}

class MonthViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val days = mutableListOf<CalendarDayItem>()

    data class CalendarDayItem(
        val dayNumber: String,
        val isCurrentMonth: Boolean,
        val isToday: Boolean,
        val hasTasks: Boolean
    )

    override fun onCreate() {
        populateCalendar()
    }

    override fun onDataSetChanged() {
        populateCalendar()
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int = days.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_cell)
        if (position in days.indices) {
            val item = days[position]
            views.setTextViewText(R.id.cell_day_text, item.dayNumber)

            if (!item.isCurrentMonth) {
                views.setTextColor(R.id.cell_day_text, 0xFF555555.toInt())
            } else if (item.isToday) {
                views.setTextColor(R.id.cell_day_text, 0xFF88C0A4.toInt())
            } else {
                views.setTextColor(R.id.cell_day_text, 0xFFE0E0E0.toInt())
            }

            views.setViewVisibility(
                R.id.cell_indicator,
                if (item.hasTasks || item.isToday) View.VISIBLE else View.GONE
            )
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun populateCalendar() {
        days.clear()
        val calendar = Calendar.getInstance()
        val todayDay = calendar.get(Calendar.DAY_OF_MONTH)
        val todayMonth = calendar.get(Calendar.MONTH)
        val todayYear = calendar.get(Calendar.YEAR)

        calendar.set(Calendar.DAY_OF_MONTH, 1)
        val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) // 1 = Sunday
        val maxDaysCurrentMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

        // Previous month padding
        val prevMonthCalendar = calendar.clone() as Calendar
        prevMonthCalendar.add(Calendar.MONTH, -1)
        val maxDaysPrevMonth = prevMonthCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

        val leadingDays = firstDayOfWeek - 1
        for (i in (leadingDays - 1) downTo 0) {
            val dayNum = maxDaysPrevMonth - i
            days.add(CalendarDayItem(dayNum.toString(), isCurrentMonth = false, isToday = false, hasTasks = false))
        }

        // Current month days
        for (day in 1..maxDaysCurrentMonth) {
            val isToday = (day == todayDay && calendar.get(Calendar.MONTH) == todayMonth && calendar.get(Calendar.YEAR) == todayYear)
            days.add(CalendarDayItem(day.toString(), isCurrentMonth = true, isToday = isToday, hasTasks = isToday))
        }

        // Trailing days to complete 35 or 42 grid cells
        val totalCells = if (days.size <= 35) 35 else 42
        var nextMonthDay = 1
        while (days.size < totalCells) {
            days.add(CalendarDayItem(nextMonthDay.toString(), isCurrentMonth = false, isToday = false, hasTasks = false))
            nextMonthDay++
        }
    }
}
