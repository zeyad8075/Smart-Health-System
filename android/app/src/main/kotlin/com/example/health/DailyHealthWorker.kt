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

class DailyHealthWorker(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    suspend fun doDailyTask(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("DailyHealthWorker", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }

            val healthData = fetchHealthData(user.uid)
            if (healthData.isEmpty()) {
                Log.e("DailyHealthWorker", "No health data available")
                return@withContext Result.failure(Exception("No health data available"))
            }

            val recommendations = generateDailyRecommendations(healthData)
            saveAnalysisResult(user.uid, recommendations)
            sendDailyNotification(recommendations)

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("DailyHealthWorker", "Error in worker", e)
            Result.failure(e)
        }
    }

    private suspend fun fetchHealthData(userId: String): Map<String, Any> {
        val db = FirebaseFirestore.getInstance()
        val userRef = db.collection("users").document(userId)

        val bodyCompQuery = userRef.collection("BodyComposition")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        val vitalsQuery = userRef.collection("VitalSigns")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        val combinedData = mutableMapOf<String, Any>()
        bodyCompQuery.documents.firstOrNull()?.data?.let { combinedData.putAll(it) }
        vitalsQuery.documents.firstOrNull()?.data?.let { combinedData.putAll(it) }

        return combinedData
    }

    private suspend fun generateDailyRecommendations(healthData: Map<String, Any>): Map<String, String> {
        val previousRecommendations = getPreviousRecommendations()
        val prompt = buildDailyPrompt(healthData, previousRecommendations)
        val response = callHealthAPI(prompt)
        return parseRecommendations(response)
    }

    private fun buildDailyPrompt(healthData: Map<String, Any>, previousRecommendations: List<String> = emptyList()): String {
        val dayOfWeek = SimpleDateFormat("EEEE", Locale.getDefault()).format(Date())
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        return """
        أنا مساعد صحي ذكي. أطلب منك إنشاء توصيات يومية بناءً على البيانات التالية:
        
        [تاريخ اليوم]
        - اليوم: $dayOfWeek
        - التاريخ: $date
        
        [البيانات الصحية]
        - الوزن: ${healthData["weight"] ?: "غير معروف"} كجم
        - مؤشر كتلة الجسم: ${healthData["bmi"] ?: "غير معروف"}
        - نسبة الدهون: ${healthData["bodyFat"] ?: "غير معروف"}%
        - ضغط الدم: ${healthData["systolicBloodPressure"] ?: "غير معروف"}/${healthData["diastolicBloodPressure"] ?: "غير معروف"} مم زئبق
        - سكر الدم: ${healthData["bloodGlucose"] ?: "غير معروف"} مغ/دل
        
        [التوصيات السابقة]
        ${if (previousRecommendations.isEmpty()) "لا توجد توصيات سابقة" else previousRecommendations.joinToString("\n")}
        
        [المطلوب]
        1. اقتراح وجبات صحية مختلفة عن الأيام السابقة:
           - وجبة الفطور (مختلفة عن السابق، تحتوي على عناصر غذائية متوازنة)
           - وجبة الغداء (مختلفة عن السابق، غنية بالبروتين والألياف)
           - وجبة العشاء (مختلفة عن السابق، خفيفة وسهلة الهضم)
        
        2. اقتراح تمارين اليوم (مختلفة عن الأيام السابقة):
           - نوع التمرين (قوة، كارديو، مرونة)
           - المدة المقترحة
           - الشدة المقترحة
        
        3. نصائح صحية عامة لليوم (مختلفة عن السابق)
        
        يرجى تنظيم الإجابة بالشكل التالي:
        [الفطور] [تفاصيل الوجبة]
        [الغداء] [تفاصيل الوجبة]
        [العشاء] [تفاصيل الوجبة]
        [التمارين] [تفاصيل التمارين]
        [النصائح] [النصيحة اليومية]
        """.trimIndent()
    }
    private suspend fun getPreviousRecommendations(): List<String> {
        return try {
            val db = FirebaseFirestore.getInstance()
            val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return emptyList()

            val docs = db.collection("users")
                .document(userId)
                .collection("Daily_Recommendations")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(1)
                .get()
                .await()

            docs.documents.firstOrNull()?.getString("analysis")
                ?.split("\n")?.filter { it.isNotBlank() } ?: emptyList()
        } catch (e: Exception) {
            Log.e("DailyHealthWorker", "Error getting previous recommendations", e)
            emptyList()
        }
    }
    private suspend fun callHealthAPI(prompt: String): String {
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
                "max_new_tokens": 800,
                "temperature": 0.7
            }
        }
        """.trimIndent()

        val request = Request.Builder()
            .url("https://openrouter.ai/api/v1/chat/completions")
            .post(requestBody.toRequestBody(mediaType))
            .addHeader("Authorization", "Bearer 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")
            .addHeader("HTTP-Referer", "health")
            .addHeader("X-Title", "DailyHealthApp")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw Exception("API request failed: ${response.code}")
            }

            return response.body?.use { responseBody ->
                val jsonResponse = responseBody.string()
                val jsonObject = JSONObject(jsonResponse)
                jsonObject.getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .getString("content")
            } ?: throw Exception("Empty response")
        }
    }

    private fun parseRecommendations(response: String): Map<String, String> {
        val recommendations = mutableMapOf<String, String>()
        val sections = listOf("الفطور", "الغداء", "العشاء", "التمارين", "النصائح")

        var currentSection = ""
        val content = StringBuilder()

        response.split("\n").forEach { line ->
            val trimmedLine = line.trim()

            when {
                // اكتشاف بدء قسم جديد
                sections.any { trimmedLine.startsWith(it) } -> {
                    if (currentSection.isNotEmpty()) {
                        recommendations[currentSection] = content.toString().trim()
                        content.clear()
                    }
                    currentSection = sections.first { trimmedLine.startsWith(it) }
                    content.append(trimmedLine.substringAfter("]").trim())
                }

                // إضافة محتوى للقسم الحالي
                currentSection.isNotEmpty() -> {
                    if (content.isNotEmpty()) content.append("\n")
                    content.append(trimmedLine)
                }
            }
        }

        // إضافة آخر قسم تم معالجته
        if (currentSection.isNotEmpty()) {
            recommendations[currentSection] = content.toString().trim()
        }

        // تحسين التنسيق النهائي
        return recommendations.mapValues { (_, value) ->
            value.split("=-").last().trim()
                .replace(".,", ".\n")
                .replace("., ", ".\n")
                .replace(" - ", "\n- ")
                .replace(": ", ":\n  ")
                .replace("**", "")
                .replace("***", "")
                .replace("##", "")
                .replace("###", "")
                .replace("####", "")
                .replace("#", "")
                .replace("*", "")
        }
    }

    private suspend fun saveAnalysisResult(userId: String, recommendations: Map<String, String>) {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
        val documentId = dateFormat.format(Date())

        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("Daily_Recommendations")
            .document(documentId)
            .set(mapOf(
                "analysis" to recommendations.toString(),
                "timestamp" to FieldValue.serverTimestamp()
            ))
            .await()
    }

    private fun sendDailyNotification(recommendations: Map<String, String>) {
        try {
            val channelId = "daily_health_channel"
            createNotificationChannel(channelId, "Daily Health Recommendations")

            val notificationId = Random().nextInt(1000)
            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_health_notification)
                .setColor(ContextCompat.getColor(context, R.color.blue))
                .setContentTitle("توصياتك الصحية لليوم")
                .setContentText("اضغط لعرض اقتراحات الوجبات والتمارين")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(
                    PendingIntent.getActivity(
                        context,
                        0,
                        Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                            putExtra("recommendations", recommendations.toString())
                            putExtra("target_tab", 1) // تبويب التوصيات
                        },
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: Exception) {
            Log.e("DailyHealthWorker", "Error sending notification", e)
        }
    }

    private fun createNotificationChannel(channelId: String, channelName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily health recommendations"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}