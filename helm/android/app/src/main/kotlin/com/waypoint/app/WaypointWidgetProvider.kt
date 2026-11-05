package com.waypoint.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

const val PREFERENCES_NAME = "HomeWidgetPreferences"

const val ACTION_SELECT_MONTH_DAY = "com.waypoint.app.ACTION_SELECT_MONTH_DAY"
const val ACTION_SELECT_WEEK_DAY = "com.waypoint.app.ACTION_SELECT_WEEK_DAY"

const val EXTRA_SELECTED_DATE = "EXTRA_SELECTED_DATE"
const val EXTRA_SELECTED_DATE_LABEL = "EXTRA_SELECTED_DATE_LABEL"
const val EXTRA_SELECTED_WEEK_DATE = "EXTRA_SELECTED_WEEK_DATE"

// ============================================================================
// Helper Data Models
// ============================================================================
data class TaskItem(
    val id: String,
    val title: String,
    val dueTime: String,
    val priority: String,
    val priorityWeight: Int,
    val subtaskProgress: String,
    val isCompleted: Boolean
) {
    companion object {
        fun fromJson(obj: JSONObject): TaskItem {
            return TaskItem(
                id = obj.optString("id", ""),
                title = obj.optString("title", ""),
                dueTime = obj.optString("due_time", ""),
                priority = obj.optString("priority", "medium").lowercase(Locale.getDefault()),
                priorityWeight = obj.optInt("priority_weight", 2),
                subtaskProgress = obj.optString("subtask_progress", ""),
                isCompleted = obj.optBoolean("is_completed", false)
            )
        }
    }
}

fun bindTaskRemoteView(context: Context, task: TaskItem): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_task_item)
    views.setTextViewText(R.id.task_title, task.title)

    // Due Time
    if (task.dueTime.isNotEmpty()) {
        views.setTextViewText(R.id.task_time, task.dueTime)
        views.setViewVisibility(R.id.task_time, View.VISIBLE)
    } else {
        views.setViewVisibility(R.id.task_time, View.GONE)
    }

    // Subtask Progress
    if (task.subtaskProgress.isNotEmpty()) {
        views.setTextViewText(R.id.task_subtask_progress, task.subtaskProgress)
        views.setViewVisibility(R.id.task_subtask_progress, View.VISIBLE)
    } else {
        views.setViewVisibility(R.id.task_subtask_progress, View.GONE)
    }

    // Priority Badge & Color
    val badgeText: String
    val badgeColor: Int
    when (task.priority) {
        "urgent", "critical" -> {
            badgeText = "URGENT"
            badgeColor = Color.parseColor("#FF5252") // High-contrast Red
        }
        "high" -> {
            badgeText = "HIGH"
            badgeColor = Color.parseColor("#FF5252")
        }
        "low" -> {
            badgeText = "LOW"
            badgeColor = Color.parseColor("#78909C") // Blue-grey
        }
        else -> {
            badgeText = "MED"
            badgeColor = Color.parseColor("#FFBF00") // Amber
        }
    }
    views.setTextViewText(R.id.task_priority_badge, badgeText)
    views.setTextColor(R.id.task_priority_badge, badgeColor)

    return views
}

// ============================================================================
// 1. Month Widget Provider (7x6 Calendar Grid + Inline Sidebar Partition)
// ============================================================================
open class WaypointMonthWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SELECT_MONTH_DAY) {
            val dateKey = intent.getStringExtra(EXTRA_SELECTED_DATE)
            val dateLabel = intent.getStringExtra(EXTRA_SELECTED_DATE_LABEL)
            if (dateKey != null) {
                val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("selected_month_day", dateKey)
                    .putString("selected_month_day_label", dateLabel ?: dateKey)
                    .apply()

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, WaypointMonthWidgetProvider::class.java)
                )
                for (id in ids) {
                    updateMonthSidebar(context, appWidgetManager, id, dateLabel ?: dateKey)
                }
            }
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val monthPayloadStr = prefs.getString("waypoint_month_payload", null)

        val dateFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
        var title = dateFormat.format(Calendar.getInstance().time)

        if (monthPayloadStr != null) {
            try {
                val json = JSONObject(monthPayloadStr)
                title = json.optString("month_title", title)
            } catch (_: Exception) {}
        }

        val todayLabel = SimpleDateFormat("MMM d", Locale.getDefault()).format(Calendar.getInstance().time)
        val selectedLabel = prefs.getString("selected_month_day_label", todayLabel) ?: todayLabel

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.sidebar_day_title, selectedLabel)

            // 1. Bind 7x6 Calendar Grid
            val gridIntent = Intent(context, MonthWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            views.setRemoteAdapter(R.id.calendar_grid, gridIntent)

            // Set fill-in pending intent template for calendar day clicks
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val selectDayIntent = Intent(context, WaypointMonthWidgetProvider::class.java).apply {
                action = ACTION_SELECT_MONTH_DAY
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, selectDayIntent, flags)
            views.setPendingIntentTemplate(R.id.calendar_grid, pendingIntent)

            // 2. Bind Sidebar Selected Day Tasks List
            val listIntent = Intent(context, MonthTasksWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            views.setRemoteAdapter(R.id.selected_day_tasks, listIntent)
            views.setEmptyView(R.id.selected_day_tasks, R.id.sidebar_empty)

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.calendar_grid)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.selected_day_tasks)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    private fun updateMonthSidebar(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        label: String
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
        views.setTextViewText(R.id.sidebar_day_title, label)
        appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.selected_day_tasks)
    }
}

class WaypointWidgetProvider : WaypointMonthWidgetProvider()

// ============================================================================
// 2. Week Widget Provider (7-Day Strip + Populated Day Tasks List)
// ============================================================================
class WaypointWeekWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SELECT_WEEK_DAY) {
            val dateKey = intent.getStringExtra(EXTRA_SELECTED_WEEK_DATE)
            if (dateKey != null) {
                val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                prefs.edit().putString("selected_week_day", dateKey).apply()

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, WaypointWeekWidgetProvider::class.java)
                )
                for (id in ids) {
                    val views = RemoteViews(context.packageName, R.layout.widget_agenda_layout)
                    views.setTextViewText(R.id.widget_agenda_selected_date, dateKey)
                    appWidgetManager.partiallyUpdateAppWidget(id, views)
                    appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.widget_agenda_list)
                }
            }
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val weekPayloadStr = prefs.getString("waypoint_week_payload", null)

        val cal = Calendar.getInstance()
        cal.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
        val isoFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val defaultToday = isoFormat.format(Calendar.getInstance().time)
        val selectedDate = prefs.getString("selected_week_day", defaultToday) ?: defaultToday

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_agenda_layout)
            views.setTextViewText(R.id.widget_agenda_selected_date, selectedDate)

            // Populate the 7-day strip
            val colIds = intArrayOf(
                R.id.day_col_0, R.id.day_col_1, R.id.day_col_2,
                R.id.day_col_3, R.id.day_col_4, R.id.day_col_5, R.id.day_col_6
            )
            val nameIds = intArrayOf(
                R.id.day_name_0, R.id.day_name_1, R.id.day_name_2,
                R.id.day_name_3, R.id.day_name_4, R.id.day_name_5, R.id.day_name_6
            )
            val numIds = intArrayOf(
                R.id.day_num_0, R.id.day_num_1, R.id.day_num_2,
                R.id.day_num_3, R.id.day_num_4, R.id.day_num_5, R.id.day_num_6
            )
            val indIds = intArrayOf(
                R.id.day_indicator_0, R.id.day_indicator_1, R.id.day_indicator_2,
                R.id.day_indicator_3, R.id.day_indicator_4, R.id.day_indicator_5, R.id.day_indicator_6
            )

            var weekDaysJson: JSONArray? = null
            if (weekPayloadStr != null) {
                try {
                    val json = JSONObject(weekPayloadStr)
                    weekDaysJson = json.optJSONArray("days")
                } catch (_: Exception) {}
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            for (i in 0 until 7) {
                var dayName = ""
                var dayNum = ""
                var dateKey = ""
                var hasPending = false

                if (weekDaysJson != null && i < weekDaysJson.length()) {
                    val dayObj = weekDaysJson.optJSONObject(i)
                    if (dayObj != null) {
                        dayName = dayObj.optString("day_name", "")
                        dayNum = dayObj.optString("day_number", "")
                        dateKey = dayObj.optString("date", "")
                        hasPending = dayObj.optInt("pending_count", 0) > 0
                    }
                }

                if (dayName.isEmpty()) {
                    val dayCal = cal.clone() as Calendar
                    dayCal.add(Calendar.DAY_OF_MONTH, i)
                    dayName = SimpleDateFormat("EEE", Locale.getDefault()).format(dayCal.time)
                    dayNum = dayCal.get(Calendar.DAY_OF_MONTH).toString()
                    dateKey = isoFormat.format(dayCal.time)
                }

                views.setTextViewText(nameIds[i], dayName)
                views.setTextViewText(numIds[i], dayNum)
                views.setViewVisibility(indIds[i], if (hasPending) View.VISIBLE else View.INVISIBLE)

                val clickIntent = Intent(context, WaypointWeekWidgetProvider::class.java).apply {
                    action = ACTION_SELECT_WEEK_DAY
                    putExtra(EXTRA_SELECTED_WEEK_DATE, dateKey)
                }
                val pi = PendingIntent.getBroadcast(context, i + 100, clickIntent, flags)
                views.setOnClickPendingIntent(colIds[i], pi)
            }

            // Bind list adapter for selected day tasks
            val listIntent = Intent(context, WeekWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            views.setRemoteAdapter(R.id.widget_agenda_list, listIntent)
            views.setEmptyView(R.id.widget_agenda_list, R.id.widget_agenda_empty)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_agenda_list)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }
}

// ============================================================================
// 3. Day Widget Provider (High-Density Today View Sorted Strictly by Priority)
// ============================================================================
class WaypointDayWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val dateFormat = SimpleDateFormat("EEEE, MMM d", Locale.getDefault())
        val todayTitle = dateFormat.format(Calendar.getInstance().time)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_priority_layout)
            views.setTextViewText(R.id.widget_priority_title, todayTitle)
            views.setTextViewText(R.id.widget_priority_badge, "DAY")

            val serviceIntent = Intent(context, DayWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            views.setRemoteAdapter(R.id.widget_priority_list, serviceIntent)
            views.setEmptyView(R.id.widget_priority_list, R.id.widget_priority_empty)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_priority_list)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }
}

// ============================================================================
// RemoteViews Services & Factories
// ============================================================================

// --- Month Calendar Grid View ---
class MonthWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthViewsFactory(applicationContext)
    }
}

class MonthViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val days = mutableListOf<CalendarDayItem>()

    data class CalendarDayItem(
        val dayNumber: String,
        val dateKey: String,
        val label: String,
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
                views.setTextColor(R.id.cell_day_text, Color.parseColor("#555555"))
            } else if (item.isToday) {
                views.setTextColor(R.id.cell_day_text, Color.parseColor("#88C0A4"))
            } else {
                views.setTextColor(R.id.cell_day_text, Color.parseColor("#E0E0E0"))
            }

            views.setViewVisibility(
                R.id.cell_indicator,
                if (item.hasTasks) View.VISIBLE else View.GONE
            )

            // Fill-in intent for day selection
            val fillInIntent = Intent().apply {
                putExtra(EXTRA_SELECTED_DATE, item.dateKey)
                putExtra(EXTRA_SELECTED_DATE_LABEL, item.label)
            }
            views.setOnClickFillInIntent(R.id.cell_root, fillInIntent)
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun populateCalendar() {
        days.clear()
        val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val monthPayloadStr = prefs.getString("waypoint_month_payload", null)

        val pendingDays = mutableSetOf<String>()
        if (monthPayloadStr != null) {
            try {
                val json = JSONObject(monthPayloadStr)
                val pDays = json.optJSONArray("pending_days")
                if (pDays != null) {
                    for (i in 0 until pDays.length()) {
                        pendingDays.add(pDays.getString(i))
                    }
                }
            } catch (_: Exception) {}
        }

        val calendar = Calendar.getInstance()
        val todayDay = calendar.get(Calendar.DAY_OF_MONTH)
        val todayMonth = calendar.get(Calendar.MONTH)
        val todayYear = calendar.get(Calendar.YEAR)

        calendar.set(Calendar.DAY_OF_MONTH, 1)
        val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) // 1 = Sunday
        val maxDaysCurrentMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

        val prevMonthCalendar = calendar.clone() as Calendar
        prevMonthCalendar.add(Calendar.MONTH, -1)
        val maxDaysPrevMonth = prevMonthCalendar.getActualMaximum(Calendar.DAY_OF_MONTH)

        val isoFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val labelFormat = SimpleDateFormat("MMM d", Locale.getDefault())

        val leadingDays = firstDayOfWeek - 1
        for (i in (leadingDays - 1) downTo 0) {
            val dayNum = maxDaysPrevMonth - i
            prevMonthCalendar.set(Calendar.DAY_OF_MONTH, dayNum)
            val dKey = isoFormat.format(prevMonthCalendar.time)
            val dLabel = labelFormat.format(prevMonthCalendar.time)
            days.add(CalendarDayItem(dayNum.toString(), dKey, dLabel, isCurrentMonth = false, isToday = false, hasTasks = pendingDays.contains(dKey)))
        }

        for (day in 1..maxDaysCurrentMonth) {
            calendar.set(Calendar.DAY_OF_MONTH, day)
            val isToday = (day == todayDay && calendar.get(Calendar.MONTH) == todayMonth && calendar.get(Calendar.YEAR) == todayYear)
            val dKey = isoFormat.format(calendar.time)
            val dLabel = labelFormat.format(calendar.time)
            val hasTasks = pendingDays.contains(dKey)
            days.add(CalendarDayItem(day.toString(), dKey, dLabel, isCurrentMonth = true, isToday = isToday, hasTasks = hasTasks))
        }

        val totalCells = 42
        var nextMonthDay = 1
        val nextMonthCalendar = calendar.clone() as Calendar
        nextMonthCalendar.add(Calendar.MONTH, 1)
        while (days.size < totalCells) {
            nextMonthCalendar.set(Calendar.DAY_OF_MONTH, nextMonthDay)
            val dKey = isoFormat.format(nextMonthCalendar.time)
            val dLabel = labelFormat.format(nextMonthCalendar.time)
            days.add(CalendarDayItem(nextMonthDay.toString(), dKey, dLabel, isCurrentMonth = false, isToday = false, hasTasks = pendingDays.contains(dKey)))
            nextMonthDay++
        }
    }
}

// --- Month Sidebar Selected Day Tasks View ---
class MonthTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthTasksViewsFactory(applicationContext)
    }
}

class MonthTasksViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val tasks = mutableListOf<TaskItem>()

    override fun onCreate() { loadTasks() }
    override fun onDataSetChanged() { loadTasks() }
    override fun onDestroy() { tasks.clear() }
    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position !in tasks.indices) {
            return RemoteViews(context.packageName, R.layout.widget_task_item)
        }
        return bindTaskRemoteView(context, tasks[position])
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun loadTasks() {
        tasks.clear()
        val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val isoToday = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Calendar.getInstance().time)
        val selectedDay = prefs.getString("selected_month_day", isoToday) ?: isoToday

        val monthPayloadStr = prefs.getString("waypoint_month_payload", null) ?: return
        try {
            val json = JSONObject(monthPayloadStr)
            val daysObj = json.optJSONObject("days") ?: return
            val dayTasksArray = daysObj.optJSONArray(selectedDay) ?: return
            for (i in 0 until dayTasksArray.length()) {
                val tObj = dayTasksArray.getJSONObject(i)
                tasks.add(TaskItem.fromJson(tObj))
            }
            tasks.sortBy { it.priorityWeight }
        } catch (_: Exception) {}
    }
}

// --- Week Selected Day Tasks View ---
class WeekWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WeekViewsFactory(applicationContext)
    }
}

class WeekViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val tasks = mutableListOf<TaskItem>()

    override fun onCreate() { loadTasks() }
    override fun onDataSetChanged() { loadTasks() }
    override fun onDestroy() { tasks.clear() }
    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position !in tasks.indices) {
            return RemoteViews(context.packageName, R.layout.widget_task_item)
        }
        return bindTaskRemoteView(context, tasks[position])
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun loadTasks() {
        tasks.clear()
        val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val isoToday = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Calendar.getInstance().time)
        val selectedDay = prefs.getString("selected_week_day", isoToday) ?: isoToday

        val weekPayloadStr = prefs.getString("waypoint_week_payload", null) ?: return
        try {
            val json = JSONObject(weekPayloadStr)
            val daysArray = json.optJSONArray("days") ?: return
            for (i in 0 until daysArray.length()) {
                val dayObj = daysArray.getJSONObject(i)
                if (dayObj.optString("date") == selectedDay) {
                    val taskArray = dayObj.optJSONArray("tasks") ?: break
                    for (j in 0 until taskArray.length()) {
                        tasks.add(TaskItem.fromJson(taskArray.getJSONObject(j)))
                    }
                    break
                }
            }
            tasks.sortBy { it.priorityWeight }
        } catch (_: Exception) {}
    }
}

// --- Day High-Density Priority View ---
class DayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return DayViewsFactory(applicationContext)
    }
}

class DayViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val tasks = mutableListOf<TaskItem>()

    override fun onCreate() { loadTasks() }
    override fun onDataSetChanged() { loadTasks() }
    override fun onDestroy() { tasks.clear() }
    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position !in tasks.indices) {
            return RemoteViews(context.packageName, R.layout.widget_task_item)
        }
        return bindTaskRemoteView(context, tasks[position])
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    private fun loadTasks() {
        tasks.clear()
        val prefs = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val dayPayloadStr = prefs.getString("waypoint_day_payload", null) ?: return
        try {
            val json = JSONObject(dayPayloadStr)
            val tasksArray = json.optJSONArray("tasks") ?: return
            for (i in 0 until tasksArray.length()) {
                tasks.add(TaskItem.fromJson(tasksArray.getJSONObject(i)))
            }
            // Strict priority sorting: Urgent (0) -> High (1) -> Medium (2) -> Low (3)
            tasks.sortBy { it.priorityWeight }
        } catch (_: Exception) {}
    }
}
