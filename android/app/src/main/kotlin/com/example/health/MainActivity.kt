package com.example.health

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import androidx.work.WorkManager
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import java.util.concurrent.TimeUnit
import androidx.work.*
import android.os.Handler
import android.os.Looper


class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.channel.notification"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        setupAlarms()
        setupWorkers()
        Log.d("MainActivity", "Activity created")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d("MainActivity", "Configuring Flutter engine")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MainActivity", "Received method call: ${call.method}")

            when (call.method) {
                "saveBloodPressure" -> {
                    val systolic = call.argument<String>("systolic")
                    val diastolic = call.argument<String>("diastolic")
                    Log.d("MainActivity", "Received BP: $systolic/$diastolic")

                    if (systolic != null && diastolic != null) {
                        saveBloodPressureToSharedPrefs(systolic, diastolic)
                        result.success(true)
                    } else {
                        result.error("INVALID_DATA", "Systolic or diastolic is null", null)
                    }
                }
                "saveBloodSugar" -> {
                    val glucoseBefore = call.argument<String>("glucoseBefore")
                    val glucoseAfter = call.argument<String>("glucoseAfter")
                    Log.d("MainActivity", "Received Sugar: $glucoseBefore/$glucoseAfter")

                    if (glucoseBefore != null && glucoseAfter != null) {
                        saveBloodSugarToSharedPrefs(glucoseBefore, glucoseAfter)
                        result.success(true)
                    } else {
                        result.error("INVALID_DATA", "Glucose values are null", null)
                    }
                }
                "initialData" -> {
                    val tabIndex = intent.getIntExtra("target_tab", 0)
                    val analysis = intent.getStringExtra("analysis") ?: ""
                    result.success(mapOf(
                        "tabIndex" to tabIndex,
                        "analysis" to analysis
                    ))
                }
                else -> {
                    Log.w("MainActivity", "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveBloodPressureToSharedPrefs(systolic: String, diastolic: String) {
        val sharedPref = getSharedPreferences("health_prefs", Context.MODE_PRIVATE)
        with(sharedPref.edit()) {
            putString("systolic", systolic)
            putString("diastolic", diastolic)
            apply()
        }
        Log.d("MainActivity", "Saved BP to SharedPreferences: $systolic/$diastolic")
    }

    private fun saveBloodSugarToSharedPrefs(glucoseBefore: String, glucoseAfter: String) {
        val sharedPref = getSharedPreferences("health_prefs", Context.MODE_PRIVATE)
        with(sharedPref.edit()) {
            putString("glucoseBefore", glucoseBefore)
            putString("glucoseAfter", glucoseAfter)
            apply()
        }
        Log.d("MainActivity", "Saved Sugar to SharedPreferences: $glucoseBefore/$glucoseAfter")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }


    private fun handleIntent(intent: Intent?) {
        intent?.let {
            // معالجة الانتقال إلى التبويب المطلوب
            if (it.hasExtra("target_tab")) {
                val tabIndex = it.getIntExtra("target_tab", 0)
                val analysis = it.getStringExtra("analysis") ?: ""

                flutterEngine?.let { engine ->
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                        "navigateToTab",
                        mapOf("tabIndex" to tabIndex, "analysis" to analysis)
                    )
                }
            }

            // معالجة طلب عرض تقييم الحالة المزاجية من الإشعار
            if (it.getBooleanExtra("show_questions", false) ||
                "OPEN_MENTAL_HEALTH_QUESTIONS" == it.action) {

                val sdnn = it.getFloatExtra("hrv_sdnn", 0f)
                val rmssd = it.getFloatExtra("hrv_rmssd", 0f)

                // تأخير العرض حتى تكتمل تهيئة واجهة المستخدم
                Handler(Looper.getMainLooper()).postDelayed({
                    flutterEngine?.let { engine ->
                        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                            "showMoodAssessment", // تغيير الاسم هنا
                            mapOf(
                                "sdnn" to sdnn,
                                "rmssd" to rmssd,
                                "from_notification" to true  // إشارة أن الطلب من الإشعار
                            )
                        )
                    }
                }, 1000)
            }
        }
    }

    private fun setupWorkers() {
        val workManager = WorkManager.getInstance(this)
        workManager.cancelAllWork()
        val healthWorkRequest = PeriodicWorkRequestBuilder<HealthWorker>(
            15, TimeUnit.MINUTES
        ).setConstraints(
            Constraints.Builder()
                .setRequiresBatteryNotLow(true)
                .build()
        ).build()

        workManager.enqueueUniquePeriodicWork(
            "health_data_worker",
            ExistingPeriodicWorkPolicy.REPLACE,
            healthWorkRequest
        )


    }

    private fun setupAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // إلغاء جميع الإنذارات السابقة
        cancelAllAlarms(alarmManager)

        // إنشاء إنذارات جديدة
        setupDailyAnalysisAlarm(alarmManager)
        setupDailyHealthAlarm(alarmManager)
        setupWeeklyNotificationAlarm(alarmManager)
        setupMonthlyAnalysisAlarm(alarmManager)
        setupSleepAnalysisAlarm(alarmManager)
        setupDailyMentalHealthAlarm(alarmManager)
        setupHRVAlertAlarm(alarmManager)

    }

    private fun cancelAllAlarms(alarmManager: AlarmManager) {
        val intents = listOf(
            Intent(this, DailyAnalysisReceiver::class.java),
            Intent(this, DailyHealthReceiver::class.java),
            Intent(this, WeeklyNotificationReceiver::class.java),
            Intent(this, MonthlyAnalysisReceiver::class.java),
            Intent(this, SleepAnalysisReceiver::class.java),
            Intent(this, DailyMentalHealthReceiver::class.java),
            Intent(this, HRVAlertReceiver::class.java)

        )

        intents.forEach { intent ->
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
    }

    private fun setupHRVAlertAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, HRVAlertReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليعمل كل ساعة
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis(),
            AlarmManager.INTERVAL_HOUR,
            pendingIntent
        )
    }
    private fun setupDailyMentalHealthAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, DailyMentalHealthReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليتم كل يوم في الساعة 9 مساء
        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, 20)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
        }

        // إذا كان الوقت المحدد قد مضى، أضف يومًا
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }


    private fun setupDailyHealthAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, DailyHealthReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليتم كل يوم في الساعة 9 مساء
        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, 8)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
        }

        // إذا كان الوقت المحدد قد مضى، أضف يومًا
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }



    private fun setupDailyAnalysisAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, DailyAnalysisReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليتم كل يوم في الساعة 9 مساء
        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, 21)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
        }

        // إذا كان الوقت المحدد قد مضى، أضف يومًا
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }

    private fun setupWeeklyNotificationAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, WeeklyNotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليتم كل أسبوع في يوم محدد (مثل كل يوم سبت الساعة 10 صباحًا)
        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.DAY_OF_WEEK, Calendar.SATURDAY)
            set(Calendar.HOUR_OF_DAY, 10)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
        }

        // إذا كان الوقت المحدد قد مضى، أضف أسبوعًا
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.WEEK_OF_YEAR, 1)
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY * 7,
            pendingIntent
        )
    }

    private fun setupMonthlyAnalysisAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, MonthlyAnalysisReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليتم كل شهر في اليوم الأول الساعة 9 صباحًا
        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
        }

        // إذا كان الوقت المحدد قد مضى، أضف شهرًا
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.MONTH, 1)
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY * 30, // تقريبًا شهر
            pendingIntent
        )
    }

    private fun setupSleepAnalysisAlarm(alarmManager: AlarmManager) {
        val intent = Intent(this, SleepAnalysisReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ضبط الإنذار ليتم كل يوم في الساعة 10 صباحًا
        val calendar = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            set(Calendar.HOUR_OF_DAY, 14)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
        }

        // إذا كان الوقت المحدد قد مضى، أضف يومًا
        if (calendar.timeInMillis <= System.currentTimeMillis()) {
            calendar.add(Calendar.DAY_OF_YEAR, 1)
        }

        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
    }
}