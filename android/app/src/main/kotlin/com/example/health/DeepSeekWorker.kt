package com.example.health

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class DeepSeekWorker(private val context: Context) : TaskWorker {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override suspend fun doTask(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            // 1. التحقق من آخر تنفيذ باستخدام Firestore
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("DeepSeekWorker", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }


            // 3. تنفيذ المهمة الأصلية
            val healthMetrics = fetchLatestHealthData(user.uid)

            if (healthMetrics.isEmpty()) {
                Log.e("DeepSeekWorker", "No health data available")
                return@withContext Result.failure(Exception("No health data available"))
            }

            val previousAnalysis = fetchYesterdayHealthAnalysis(user.uid)
            val analysis = analyzeHealthData(healthMetrics, previousAnalysis)
            saveAnalysisResult(user.uid, analysis)
            sendNotification(analysis)

            // 4. تسجيل التنفيذ الناجح
            val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val documentId = "execution_$currentDate"

            FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .collection("execution_logs")
                .document(documentId)
                .set(mapOf(
                    "timestamp" to FieldValue.serverTimestamp(),
                    "user_id" to user.uid,
                    "execution_date" to currentDate
                ))
                .await()

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("DeepSeekWorker", "Error in worker", e)
            Result.failure(e)
        }
    }

    private suspend fun fetchLatestHealthData(userId: String): Map<String, Any> {
        val db = FirebaseFirestore.getInstance()
        val userRef = db.collection("users").document(userId)

        // جلب أحدث سجل من كل مجموعة بشكل متوازي
        val bodyCompQuery = userRef.collection("BodyComposition")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        val activityQuery = userRef.collection("DailyActivity")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        val sleepQuery = userRef.collection("SleepData")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        val vitalsQuery = userRef.collection("VitalSigns")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        // دمج البيانات في خريطة واحدة
        val combinedData = mutableMapOf<String, Any>()

        bodyCompQuery.documents.firstOrNull()?.data?.let { combinedData.putAll(it) }
        activityQuery.documents.firstOrNull()?.data?.let { combinedData.putAll(it) }
        sleepQuery.documents.firstOrNull()?.data?.let { combinedData.putAll(it) }
        vitalsQuery.documents.firstOrNull()?.data?.let { combinedData.putAll(it) }

        return if (combinedData.isEmpty()) emptyMap() else combinedData
    }
    private suspend fun fetchYesterdayHealthAnalysis(userId: String): String? {
        val snapshot = FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("HealthAnalysis")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        return snapshot.documents.firstOrNull()?.getString("analysis")
    }


    private suspend fun analyzeHealthData(
        healthData: Map<String, Any>,
        previousAnalysis: String? = null
    ): String {
        val prompt = buildHealthAnalysisPrompt(healthData, previousAnalysis)
        return callDeepSeekAPI(prompt)
    }

    private fun buildHealthAnalysisPrompt(
        healthData: Map<String, Any>,
        previousAnalysis: String? = null
    ): String {
        val previousNote = previousAnalysis?.let {
            "\nمقارنة بتحليل الأمس:\n$it\n\nيرجى توضيح التقدم أو التراجع."
        } ?: "\nلا يوجد تحليل سابق للمقارنة.\n"

        return """
    أنا مساعد صحي ذكي. أطلب منك تحليل البيانات الصحية التالية بناءً على أحدث القراءات:
     $previousNote

    [البيانات الأساسية]
    - الطول: ${healthData["height"] ?: "غير معروف"} متر
    - الوزن: ${healthData["weight"] ?: "غير معروف"} كجم
    - مؤشر كتلة الجسم: ${healthData["bmi"] ?: "غير معروف"}
    - نسبة الدهون: ${healthData["bodyFat"] ?: "غير معروف"}%
    - كتلة الدهون: ${healthData["fatMassKg"] ?: "غير معروف"} كجم
    - الكتلة العضلية: ${healthData["muscleMassKg"] ?: "غير معروف"} كجم

    [النشاط اليومي]
    - السعرات الحرارية المحروقة: ${healthData["calories"] ?: "غير معروف"} سعر حراري
    - الخطوات: ${healthData["steps"] ?: "غير معروف"} خطوة
    - المسافة: ${healthData["distanceMeters"] ?: "غير معروف"} متر
    ${getExerciseDurations(healthData)}

    [نوعية النوم]
    - إجمالي وقت النوم: ${formatMinutes(healthData["sleepTotalMinutes"])} 
    - نوم عميق: ${formatMinutes(healthData["sleepDeepMinutes"])}
    - نوم خفيف: ${formatMinutes(healthData["sleepLightMinutes"])}
    - نوم حركة العين السريعة: ${formatMinutes(healthData["sleepREMMinutes"])}

    [المؤشرات الحيوية]
    - معدل ضربات القلب (متوسط): ${healthData["heartRateAvg"] ?: "غير معروف"} نبضة/دقيقة
    - تشبع الأكسجين: ${healthData["spo2"] ?: "غير معروف"}%
    - معدل ضربات القلب أثناء الراحة: ${healthData["heartRateMin"] ?: "غير معروف"} نبضة/دقيقة
    - HRV (SDNN): ${healthData["hrvSDNN"] ?: "غير معروف"} مللي ثانية
    ${getBloodPressureText(healthData)}
    ${getBloodGlucoseText(healthData)}

    [المطلوب]
    1. تقييم شامل للحالة الصحية بناءً على جميع المقاييس
    2. تحليل العلاقات بين المؤشرات المختلفة (مثل النوم والأداء الرياضي)
    3. تحديد 3 نقاط قوة و3 نقاط تحتاج تحسين
    4. خطة تحسين شهرية تشمل:
       - التغذية (كميات، أنواع أطعمة)
       - التمارين (نوع، شدة، تكرار)
       - تحسين النوم
    5. أهداف ذكية (SMART) قابلة للقياس
    """.trimIndent()
    }

    // دوال مساعدة
    private fun getExerciseDurations(data: Map<String, Any>): String {
        return data.entries
            .filter { it.key.startsWith("exerciseDuration_") }
            .joinToString("\n") { entry ->
                "- ${entry.key.removePrefix("exerciseDuration_")}: ${entry.value} دقيقة"
            }.ifEmpty { "- لا توجد بيانات للتمارين" }
    }

    private fun formatMinutes(minutes: Any?): String {
        return when (val mins = minutes?.toString()?.toIntOrNull()) {
            null -> "غير معروف"
            else -> "${mins} دقيقة (${mins / 60} ساعة ${mins % 60} دقيقة)"
        }
    }

    private fun getBloodPressureText(data: Map<String, Any>): String {
        val systolic = data["systolicBloodPressure"]
        val diastolic = data["diastolicBloodPressure"]
        return if (systolic != null && diastolic != null) {
            "- ضغط الدم: $systolic/$diastolic مم زئبق"
        } else {
            ""
        }
    }

    private fun getBloodGlucoseText(data: Map<String, Any>): String {
        val before = data["bloodGlucoseBeforeMeal"]
        val after = data["bloodGlucoseAfterMeal"]
        return when {
            before != null && after != null -> "- سكر الدم: قبل الوجبة $before مغ/دل، بعد الوجبة $after مغ/دل"
            before != null -> "- سكر الدم: قبل الوجبة $before مغ/دل"
            after != null -> "- سكر الدم: بعد الوجبة $after مغ/دل"
            else -> ""
        }
    }

    private suspend fun callDeepSeekAPI(prompt: String): String {
        val mediaType = "application/json".toMediaType()
        val requestBody = """
        {
            "model": "deepseek/deepseek-r1:free",
            "messages": [
                {
                    "role": "user",
                    "content": "$prompt"
                }
            ],
            "parameters": {
                "max_new_tokens": 1000,
                "temperature": 0.7,
                "top_p": 0.9
            }
        }
        """.trimIndent()

        val request = Request.Builder()
            .url("https://openrouter.ai/api/v1/chat/completions")
            .post(requestBody.toRequestBody(mediaType))
            .addHeader("Authorization", "")
            .addHeader("HTTP-Referer", "health")
            .addHeader("X-Title", "HealthAnalysisApp")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw Exception("API request failed: ${response.code}")
            }

            return response.body?.use { responseBody ->
                val jsonResponse = responseBody.string()
                val jsonObject = JSONObject(jsonResponse)
                val choicesArray = jsonObject.getJSONArray("choices")
                val firstChoice = choicesArray.getJSONObject(0)
                val message = firstChoice.getJSONObject("message")
                var rawText = message.getString("content")

                rawText
                    .replace("**", "")
                    .replace("- ", "\n• ")
                    .replace("المتوسط", "\n| المتوسط")
                    .replace("الأعلى", "| الأعلى")
                    .replace("الأدنى", "| الأدنى")
                    .replace("(", " (")
            } ?: throw Exception("Empty response")
        }
    }

    private suspend fun saveAnalysisResult(userId: String, analysis: String) {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
        val documentId = dateFormat.format(Date())

        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("HealthAnalysis")
            .document(documentId)
            .set(mapOf(
                "analysis" to analysis,
                "timestamp" to FieldValue.serverTimestamp()
            ))
            .await()
    }

    private fun sendNotification(analysis: String) {
        try {
            val channelId = "health_analysis_channel"
            val channelName = "Health Analysis Notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    importance
                ).apply {
                    description = "Notifications for health analysis results"
                    enableLights(true)
                    lightColor = Color.BLUE
                    enableVibration(true)
                }

                val notificationManager = context
                    .getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }

            val notificationId = Random().nextInt(1000)
            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_health_notification)
                .setColor(ContextCompat.getColor(context, R.color.blue))
                .setColorized(true)
                .setContentTitle("تم تحليل بياناتك الصحية لهذا اليوم .")
                .setContentText("انقر لعرض التحليل الكامل")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(
                    PendingIntent.getActivity(
                        context,
                        0,
                        Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                            putExtra("analysis", analysis)
                            putExtra("target_tab", 1)
                        },
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                    )
                )
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: Exception) {
            Log.e("DeepSeekWorker", "Error sending notification", e)
        }
    }
}