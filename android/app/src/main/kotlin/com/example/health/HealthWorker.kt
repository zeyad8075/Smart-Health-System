package com.example.health

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.*
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Duration
import java.time.Instant
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Calendar
import kotlin.math.pow
import kotlin.math.sqrt
import kotlin.math.roundToInt
import kotlinx.coroutines.tasks.await
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.Date
import androidx.health.connect.client.records.SleepStageRecord
import androidx.health.connect.client.records.SleepSessionRecord


// Helper function to read records of a specific type within a time range
suspend inline fun <reified T : Record> HealthConnectClient.readRecordsInRange(
    timeRange: TimeRangeFilter
): List<T> {
    return this.readRecords(ReadRecordsRequest(T::class, timeRange)).records
}

private fun getBloodPressure(context: Context): Pair<String?, String?> {
    val sharedPref = context.getSharedPreferences("health_prefs", Context.MODE_PRIVATE)
    return Pair(
        sharedPref.getString("systolic", null),
        sharedPref.getString("diastolic", null)
    )
}

private fun getBloodSugar(context: Context): Pair<String?, String?> {
    val sharedPref = context.getSharedPreferences("health_prefs", Context.MODE_PRIVATE)
    return Pair(
        sharedPref.getString("glucoseBefore", null),
        sharedPref.getString("glucoseAfter", null)
    )
}

private suspend fun getUserProfileData(userId: String): Map<String, Any> {
    return try {
        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .get()
            .await() // إضافة await كمستورد صريح
            .data ?: emptyMap()
    } catch (e: Exception) {
        Log.e("HealthWorker", "Error fetching user profile", e)
        emptyMap()
    }
}

private fun calculateAge(birthDateStr: String): Int {
    return try {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val birthDate = dateFormat.parse(birthDateStr)
        val dob = Calendar.getInstance().apply { time = birthDate }
        val today = Calendar.getInstance()

        var age = today.get(Calendar.YEAR) - dob.get(Calendar.YEAR)
        if (today.get(Calendar.DAY_OF_YEAR) < dob.get(Calendar.DAY_OF_YEAR)) {
            age--
        }
        age
    } catch (e: Exception) {
        Log.e("HealthWorker", "Error calculating age", e)
        -1 // Default value in case of error
    }
}

class HealthWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    private val context = context
    private val client by lazy { HealthConnectClient.getOrCreate(context) }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("HealthWorker", "❌ User not authenticated")
                return@withContext Result.failure()
            }

            val userProfile = getUserProfileData(user.uid)
            val age = userProfile["birthDate"]?.toString()?.let { birthDateStr ->
                calculateAge(birthDateStr)
            }

            val timeRange = TimeRangeFilter.between(
                Instant.now().minus(Duration.ofHours(24)),
                Instant.now()
            )
            val hrvTimeRange = TimeRangeFilter.between(
                Instant.now().minus(Duration.ofHours(4)),
                Instant.now()
            )

            // احصل على تاريخ اليوم عند منتصف الليل (00:00)
            val startOfDay = LocalDate.now()
                .atStartOfDay(ZoneId.systemDefault())
                .toInstant()

// النطاق الزمني: من منتصف الليل حتى الآن
            val distanceTimeRange = TimeRangeFilter.between(
                startOfDay,  // بداية اليوم (12:00 ص)
                Instant.now() // اللحظة الحالية
            )

            // Fetch all health data
            val steps = getStepCount(timeRange)
            val exerciseDurations = getExerciseDurationsByType(distanceTimeRange)
            val distances = getTotalDistance(distanceTimeRange)
            val heartRateMetrics = getHeartRateMetrics(timeRange)
            val (sdnn, rmssd ,readingsCount) = getHRV(client, hrvTimeRange)
            val latestSpo2 = getLatestOxygenSaturation(distanceTimeRange)
            val sleepData = getSleepData(distanceTimeRange)
            val calories = getTotalCalories(timeRange)
            val height = getLatestHeight(timeRange)
            val bodyFat = getLatestBodyFat(timeRange)
            val bmr = getLatestBMR(timeRange)
            val weight = getLatestWeight(timeRange)
            val bodyComposition = if (weight != null && bodyFat != null && height != null) {
                calculateBodyComposition(weight, bodyFat, height)
            } else {
                null
            }

            // Prepare data for each category
            val bodyCompositionData = HashMap<String, Any>().apply {
                height?.let { put("height", it) }
                bodyFat?.let { put("bodyFat", it/100) }
                weight?.let { put("weight", it) }
                bmr?.let { put("bmr", it) }

                bodyComposition?.let {
                    it.leanBodyMassKg?.let { mass -> put("leanBodyMassKg", mass) }
                    it.muscleMassKg?.let { mass -> put("muscleMassKg", mass) }
                    it.totalBodyWaterKg?.let { water -> put("totalBodyWaterKg", water) }
                    it.bodyMassIndex?.let { mass -> put("bmi", mass) }
                    it.fatMassKg?.let { mass -> put("fatMassKg", mass) }
                }
            }

            val activityData = HashMap<String, Any>().apply {
                steps?.let { put("steps", it.toDouble()) }
                distances?.let { put("distanceMeters", it) }
                calories?.let { put("calories", it) }

                exerciseDurations.forEach { (type, duration) ->
                    put("exerciseDuration_${type}", duration)
                }
            }

            val sleepDataMap = HashMap<String, Any>().apply {
                sleepData?.let {
                    put("sleepTotalMinutes", it.totalSleepMinutes)
                    it.sleepStages.forEach { stage ->
                        when (stage.stageName) {
                            "Awake" -> put("sleepAwakeMinutes", stage.durationMinutes)
                            "Light" -> put("sleepLightMinutes", stage.durationMinutes)
                            "Deep" -> put("sleepDeepMinutes", stage.durationMinutes)
                            "REM" -> put("sleepREMMinutes", stage.durationMinutes)
                        }
                    }
                }
            }

            val vitalSignsData = HashMap<String, Any>().apply {
                heartRateMetrics.get("max")?.let { put("heartRateMax", it) }
                heartRateMetrics.get("min")?.let { put("heartRateMin", it) }
                heartRateMetrics.get("avg")?.let { put("heartRateAvg", it) }
                sdnn?.let { put("hrvSDNN", it) }
                rmssd?.let { put("hrvRMSSD", it) }
                readingsCount?.let { put("readingsCount", it) }
                latestSpo2?.let { put("spo2", it) }

                getBloodPressure(context).let { (systolic, diastolic) ->
                    systolic?.toDoubleOrNull()?.let { put("systolicBloodPressure", it) }
                    diastolic?.toDoubleOrNull()?.let { put("diastolicBloodPressure", it) }
                }

                getBloodSugar(context).let { (glucoseBefore, glucoseAfter) ->
                    glucoseBefore?.toDoubleOrNull()?.let { put("bloodGlucoseBeforeMeal", it) }
                    glucoseAfter?.toDoubleOrNull()?.let { put("bloodGlucoseAfterMeal", it) }
                }
            }

            // Save all data to Firestore if we have any valid data
            val hasData = listOf(
                bodyCompositionData.isNotEmpty(),
                activityData.isNotEmpty(),
                sleepDataMap.isNotEmpty(),
                vitalSignsData.isNotEmpty()
            ).any { it }

            if (hasData) {
                saveHealthDataToFirestore(
                    bodyCompositionData = bodyCompositionData,
                    activityData = activityData,
                    sleepData = sleepDataMap,
                    vitalSignsData = vitalSignsData
                )
                Result.success()
            } else {
                Log.e("HealthWorker", "No valid health data collected")
                Result.failure()
            }
        } catch (e: Exception) {
            Log.e("HealthWorker", "❌ Error in health worker", e)
            Result.failure()
        }
    }

    private suspend fun saveHealthDataToFirestore(
        bodyCompositionData: MutableMap<String, Any>,
        activityData: MutableMap<String, Any>,
        sleepData: MutableMap<String, Any>,
        vitalSignsData: MutableMap<String, Any>
    ) {
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user != null) {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
                val documentId = dateFormat.format(java.util.Date())
                val timestamp = Date() // java.util.Date

                val db = FirebaseFirestore.getInstance()
                val userRef = db.collection("users").document(user.uid)

                // القيم الافتراضية لبيانات النوم (باستخدام Any لتشمل جميع الأنواع)
                val defaultSleepData = mapOf<String, Any>(
                    "sleepTotalMinutes" to 0.0,
                    "sleepAwakeMinutes" to 0.0,
                    "sleepLightMinutes" to 0.0,
                    "sleepDeepMinutes" to 0.0,
                    "sleepREMMinutes" to 0.0
                )

                // القيم الافتراضية للمؤشرات الحيوية (باستخدام Any لتشمل جميع الأنواع)
                val defaultVitalSignsData = mapOf<String, Any>(
                    "heartRateMax" to 0.0,
                    "heartRateMin" to 0.0,
                    "heartRateAvg" to 0.0,
                    "hrvSDNN" to 0.0,
                    "hrvRMSSD" to 0.0,
                    "readingsCount" to 0,
                    "spo2" to 0.0,
                    "systolicBloodPressure" to 0.0,
                    "diastolicBloodPressure" to 0.0,
                    "bloodGlucoseBeforeMeal" to 0.0,
                    "bloodGlucoseAfterMeal" to 0.0
                )

                // Save Body Composition Data
                if (bodyCompositionData.isNotEmpty()) {
                    userRef.collection("BodyComposition")
                        .document(documentId)
                        .set(bodyCompositionData.apply { put("timestamp", timestamp) })
                        .addOnSuccessListener {
                            Log.d("HealthWorker", "✅ Body composition data saved to Firestore")
                        }
                        .addOnFailureListener { e ->
                            Log.e("HealthWorker", "❌ Failed to save body composition data", e)
                        }
                }

                // Save Activity Data
                if (activityData.isNotEmpty()) {
                    userRef.collection("DailyActivity")
                        .document(documentId)
                        .set(activityData.apply { put("timestamp", timestamp) })
                        .addOnSuccessListener {
                            Log.d("HealthWorker", "✅ Activity data saved to Firestore")
                        }
                        .addOnFailureListener { e ->
                            Log.e("HealthWorker", "❌ Failed to save activity data", e)
                        }
                }

                // Save Sleep Data
                val finalSleepData = defaultSleepData.toMutableMap().apply {
                    putAll(sleepData.filterValues { it != null })
                    put("timestamp", timestamp)
                }

                userRef.collection("SleepData")
                    .document(documentId)
                    .set(finalSleepData)
                    .addOnSuccessListener {
                        Log.d("HealthWorker", "✅ Sleep data saved to Firestore")
                    }
                    .addOnFailureListener { e ->
                        Log.e("HealthWorker", "❌ Failed to save sleep data", e)
                    }

                // Save Vital Signs Data
                val finalVitalSignsData = defaultVitalSignsData.toMutableMap().apply {
                    putAll(vitalSignsData.filterValues { it != null })
                    put("timestamp", timestamp)
                }

                userRef.collection("VitalSigns")
                    .document(documentId)
                    .set(finalVitalSignsData)
                    .addOnSuccessListener {
                        Log.d("HealthWorker", "✅ Vital signs data saved to Firestore")
                    }
                    .addOnFailureListener { e ->
                        Log.e("HealthWorker", "❌ Failed to save vital signs data", e)
                    }
            } else {
                Log.e("HealthWorker", "❌ User not authenticated")
            }
        } catch (e: Exception) {
            Log.e("HealthWorker", "❌ Firebase error: ${e.message}", e)
        }
    }

    private suspend fun getStepCount(timeRange: TimeRangeFilter): Long? =
        client.readRecordsInRange<StepsRecord>(timeRange)
            .sumOf { it.count }
            .takeIf { it > 0 }

    private suspend fun getTotalDistance(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<DistanceRecord>(timeRange)
            .sumOf { it.distance.inMeters }
            .takeIf { it > 0 }

    private suspend fun getHeartRateMetrics(timeRange: TimeRangeFilter): Map<String, Double?> {
        return try {
            val result = client.aggregate(
                AggregateRequest(
                    metrics = setOf(
                        HeartRateRecord.BPM_MAX,
                        HeartRateRecord.BPM_MIN,
                        HeartRateRecord.BPM_AVG
                    ),
                    timeRangeFilter = timeRange
                )
            )
            mapOf(
                "max" to result.get(HeartRateRecord.BPM_MAX)?.toDouble(),
                "min" to result.get(HeartRateRecord.BPM_MIN)?.toDouble(),
                "avg" to result.get(HeartRateRecord.BPM_AVG)?.toDouble()
            )
        } catch (e: Exception) {
            Log.e("HealthWorker", "Error getting heart rate metrics", e)
            emptyMap()
        }
    }

    private suspend fun getHRV(client: HealthConnectClient, timeRange: TimeRangeFilter): Triple<Double?, Double?, Int> {
        return try {
            val rrIntervals = mutableListOf<Double>()

            client.readRecordsInRange<HeartRateRecord>(timeRange).forEach { record ->
                record.samples.forEach { sample ->
                    val bpm = sample.beatsPerMinute
                    if (bpm in 31..219) {
                        rrIntervals.add(60000.0 / bpm) // تحويل bpm إلى RR (ms)
                    }
                }
            }

            val count = rrIntervals.size
            if (count <= 1) return Triple(null, null, count)

            val mean = rrIntervals.average()
            val sdnn = sqrt(rrIntervals.sumOf { (it - mean).pow(2) } / count)
            val rmssd = sqrt(
                rrIntervals.zipWithNext { a, b -> (b - a).pow(2) }.average()
            )

            Triple(sdnn, rmssd, count)
        } catch (e: Exception) {
            Log.e("HealthWorker", "Error calculating HRV", e)
            Triple(null, null, 0)
        }
    }

    private suspend fun getLatestOxygenSaturation(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<OxygenSaturationRecord>(timeRange)
            .maxByOrNull { it.time }
            ?.percentage?.value
            ?.takeIf { it > 0 }

    suspend fun getExerciseDurationsByType(timeRange: TimeRangeFilter): Map<String, Long> {
        val response = client.readRecords(
            ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = timeRange
            )
        )

        val sessions = response.records

        // Aggregate duration by exercise type
        val durationsByType = mutableMapOf<String, Long>()

        sessions.forEach { record ->
            val exerciseName = exerciseTypeName(record.exerciseType)
            val durationMinutes = Duration.between(record.startTime, record.endTime).toMinutes()

            durationsByType[exerciseName] = durationsByType.getOrDefault(exerciseName, 0L) + durationMinutes
        }

        return durationsByType
    }

    fun exerciseTypeName(type: Int): String {
        return when (type) {
            56 -> "Running"
            79 -> "Walking"
            8 -> "Biking"
            74 -> "Swimming"
            0 -> "Other Workout"
            64 -> "FootBall"
            37 -> "Hiking"
            83 -> "Yoga"
            else -> "Other"
        }
    }

    private suspend fun getTotalCalories(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<TotalCaloriesBurnedRecord>(timeRange)
            .sumOf { it.energy.inKilocalories }
            .takeIf { it > 0 }

    private suspend fun getLatestHeight(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<HeightRecord>(timeRange)
            .maxByOrNull { it.time }
            ?.height?.inMeters
            ?.takeIf { it > 0 }

    private suspend fun getLatestBodyFat(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<BodyFatRecord>(timeRange)
            .maxByOrNull { it.time }
            ?.percentage?.value
            ?.times(100)
            ?.takeIf { it > 0 }

    private suspend fun getLatestBMR(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<BasalMetabolicRateRecord>(timeRange)
            .maxByOrNull { it.time }
            ?.basalMetabolicRate?.inWatts
            ?.let { it * 0.86 * 24 }
            ?.takeIf { it > 0 }

    private suspend fun getLatestWeight(timeRange: TimeRangeFilter): Double? =
        client.readRecordsInRange<WeightRecord>(timeRange)
            .maxByOrNull { it.time }
            ?.weight?.inKilograms
            ?.takeIf { it > 0 }

    private fun getStageName(stage: Int): String {
        return when (stage) {
            1 -> "Awake"
            4 -> "Light"
            5 -> "Deep"
            6 -> "REM"
            else -> "Unknown"
        }
    }

    data class SleepStageData(
        val stageName: String,
        val durationMinutes: Double
    )

    data class SleepSummary(
        val totalSleepMinutes: Double,
        val sleepStages: List<SleepStageData>
    )

    data class BodyCompositionResult(
        val leanBodyMassKg: Double?,
        val muscleMassKg: Double?,
        val totalBodyWaterKg: Double?,
        val bodyMassIndex: Double?,
        val fatMassKg: Double?
    )

    private fun calculateBodyComposition(
        weightKg: Double,
        bodyFat: Double,
        heightM: Double
    ): BodyCompositionResult {
        val fatMass = weightKg * (bodyFat/10000)
        val leanBodyMass = weightKg-fatMass
        val muscleMass = leanBodyMass * 0.5
        val totalBodyWater = leanBodyMass * 0.6
        val bmi = weightKg / (heightM * heightM)

        return BodyCompositionResult(
            leanBodyMassKg = leanBodyMass.takeIf { it > 0 }?.let { String.format("%.2f", it).toDouble() },
            muscleMassKg = muscleMass.takeIf { it > 0 }?.let { String.format("%.2f", it).toDouble() },
            totalBodyWaterKg = totalBodyWater.takeIf { it > 0 }?.let { String.format("%.2f", it).toDouble() },
            bodyMassIndex = bmi.takeIf { it > 0 }?.let { String.format("%.2f", it).toDouble() },
            fatMassKg = fatMass.takeIf { it > 0 }?.let { String.format("%.2f", it).toDouble() }
        )
    }

    private suspend fun getSleepData(timeRange: TimeRangeFilter): SleepSummary? {
        return try {
            // الحصول على جلسات النوم
            val sleepSessions = client.readRecordsInRange<SleepSessionRecord>(timeRange)
            if (sleepSessions.isEmpty()) return null

            // الحصول على مراحل النوم بشكل منفصل
            val sleepStages = client.readRecordsInRange<SleepStageRecord>(timeRange)

            val stageDurations = mutableMapOf<String, Double>()
            var totalSleepTime = 0.0
            var wakeUpTime = 0.0

            // حساب وقت النوم الكلي من الجلسات
            sleepSessions.forEach { session ->
                val duration = Duration.between(session.startTime, session.endTime).toMinutes().toDouble()
                totalSleepTime += duration
            }

            // معالجة مراحل النوم
            sleepStages.forEach { stage ->
                val stageDuration = Duration.between(stage.startTime, stage.endTime).toMinutes().toDouble()
                val stageName = getStageName(stage.stage)
                stageDurations[stageName] = stageDurations.getOrDefault(stageName, 0.0) + stageDuration

                if (stageName == "Awake") {
                    wakeUpTime += stageDuration
                }
            }

            if (totalSleepTime <= 0) return null

            // إنشاء قائمة مراحل النوم
            val sleepStagesList = stageDurations.map { (stageName, duration) ->
                SleepStageData(stageName, duration)
            }

            SleepSummary(
                totalSleepMinutes = totalSleepTime,
                sleepStages = sleepStagesList
            )
        } catch (e: Exception) {
            Log.e("HealthWorker", "Error getting sleep data", e)
            null
        }
    }
}