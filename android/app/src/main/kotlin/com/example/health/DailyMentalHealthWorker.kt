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

class DailyMentalHealthWorker(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    suspend fun analyzeDailyMentalHealth(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("DailyMentalHealth", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }

            val (sleepData, activityData, hrvReadings) = fetchDailyMentalHealthData(user.uid)

            if (sleepData.isEmpty() && activityData.isEmpty() && hrvReadings.isEmpty()) {
                Log.e("DailyMentalHealth", "No mental health data available")
                return@withContext Result.failure(Exception("No mental health data available"))
            }

            val previousAnalysis = fetchYesterdayAnalysis(user.uid)
            val analysis = generateMentalHealthAnalysis(sleepData, activityData, hrvReadings, previousAnalysis)

            saveMentalHealthAnalysis(user.uid, analysis)
            sendMentalHealthNotification(analysis)

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("DailyMentalHealth", "Error in worker", e)
            Result.failure(e)
        }
    }

    private suspend fun fetchDailyMentalHealthData(userId: String): Triple<Map<String, Any>, Map<String, Any>, List<Map<String, Any>>> {
        val db = FirebaseFirestore.getInstance()
        val userRef = db.collection("users").document(userId)
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDay = calendar.time

        // أحدث بيانات النوم
        val sleepData = userRef.collection("SleepData")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()
            .documents.firstOrNull()?.data ?: emptyMap()

        // أحدث بيانات النشاط
        val activityData = userRef.collection("DailyActivity")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()
            .documents.firstOrNull()?.data ?: emptyMap()

        // جميع قراءات HRV لليوم الحالي
        val hrvReadings = userRef.collection("HRVData")
            .whereGreaterThanOrEqualTo("timestamp", startOfDay)
            .get()
            .await()
            .documents.map { it.data ?: emptyMap() }

        return Triple(sleepData, activityData, hrvReadings)
    }
    private suspend fun fetchYesterdayAnalysis(userId: String): String? {
        val snapshot = FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("Daily_Mental_Health_Reports")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        return snapshot.documents.firstOrNull()?.getString("analysis")
    }



    private suspend fun generateMentalHealthAnalysis(
        sleepData: Map<String, Any>,
        activityData: Map<String, Any>,
        hrvReadings: List<Map<String, Any>>,
        previousAnalysis: String? = null
    ): String {
        val prompt = buildMentalHealthPrompt(sleepData, activityData, hrvReadings, previousAnalysis)
        return callMentalHealthAPI(prompt)
    }



    private fun buildMentalHealthPrompt(
        sleepData: Map<String, Any>,
        activityData: Map<String, Any>,
        hrvReadings: List<Map<String, Any>>,
        previousAnalysis: String? = null
    ): String {
        val dateFormat = SimpleDateFormat("EEEE, yyyy-MM-dd", Locale.getDefault())
        val today = dateFormat.format(Date())

        val hrvAnalysis = analyzeHRVReadings(hrvReadings)

        val stressLevel = when (hrvAnalysis["avgSDNN"]?.toIntOrNull()) {
            null -> "غير معروف"
            in 0..29 -> "مرتفع"
            in 30..50 -> "متوسط"
            else -> "منخفض"
        }

        val relaxationVideo = if (stressLevel == "مرتفع") {
            "\nرابط تمرين مهدئ مقترح: https://www.youtube.com/watch?v=1ZYbU82GVz4"
        } else ""

        val previousNote = previousAnalysis?.let {
            "ملاحظة: فيما يلي تقرير الأمس للمقارنة. يرجى عدم تكرار التوصيات إذا لم يطرأ تحسّن:\n\n$it\n\n"
        } ?: ""

        return """
$previousNote

[تاريخ اليوم]
- $today

[مستوى التوتر العام]: $stressLevel$relaxationVideo

[بيانات النوم الأخيرة]
- إجمالي وقت النوم: ${formatMinutes(sleepData["sleepTotalMinutes"])}
- نوم عميق: ${formatMinutes(sleepData["sleepDeepMinutes"])}
- نوم خفيف: ${formatMinutes(sleepData["sleepLightMinutes"])}
- كفاءة النوم: ${sleepData["sleepEfficiency"] ?: "غير معروف"}%
- مرات الاستيقاظ: ${sleepData["awakeCount"] ?: "غير معروف"}

[النشاط اليومي]
- الخطوات: ${activityData["steps"] ?: "غير معروف"}
- السعرات الحرارية المحروقة: ${activityData["calories"] ?: "غير معروف"}
- وقت النشاط: ${formatMinutes(activityData["activeMinutes"])}
- وقت الجلوس: ${formatMinutes(activityData["sedentaryMinutes"])}

[تحليل HRV لليوم]
- عدد القراءات: ${hrvReadings.size}
- متوسط SDNN: ${hrvAnalysis["avgSDNN"]} مللي ثانية
- متوسط RMSSD: ${hrvAnalysis["avgRMSSD"]} مللي ثانية
- أعلى قراءة SDNN: ${hrvAnalysis["maxSDNN"]} مللي ثانية (${hrvAnalysis["maxSDNNTime"]})
- أدنى قراءة SDNN: ${hrvAnalysis["minSDNN"]} مللي ثانية (${hrvAnalysis["minSDNNTime"]})
- تقلبات HRV خلال اليوم: ${hrvAnalysis["variability"]}

[المطلوب]
1. تقييم شامل للصحة النفسية بناءً على:
   - جودة النوم
   - مستوى النشاط البدني
   - تقلبات HRV خلال اليوم
2. تحديد 3 مؤشرات رئيسية للتوتر/الاسترخاء
3. تقديم 4 توصيات مخصصة لتحسين الصحة النفسية
4. اقتراح 3 تمارين تنفس أو استرخاء مناسبة
5. تحليل أنماط HRV وتأثيرها على الحالة النفسية
6. نصائح لتحسين جودة النوم الليلة
""".trimIndent()
    }


    private fun analyzeHRVReadings(readings: List<Map<String, Any>>): Map<String, String> {
        if (readings.isEmpty()) return mapOf(
            "avgSDNN" to "غير متوفر",
            "avgRMSSD" to "غير متوفر",
            "maxSDNN" to "غير متوفر",
            "minSDNN" to "غير متوفر",
            "variability" to "غير معروف",
            "maxSDNNTime" to "",
            "minSDNNTime" to ""
        )

        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())

        val sdnnValues = readings.mapNotNull { it["hrvSDNN"]?.toString()?.toFloatOrNull() }
        val rmssdValues = readings.mapNotNull { it["hrvRMSSD"]?.toString()?.toFloatOrNull() }
        val timestamps = readings.mapNotNull { it["timestamp"] as? Date }

        val avgSDNN = sdnnValues.average().toInt()
        val avgRMSSD = rmssdValues.average().toInt()

        val maxIndex = sdnnValues.indices.maxByOrNull { sdnnValues[it] } ?: 0
        val minIndex = sdnnValues.indices.minByOrNull { sdnnValues[it] } ?: 0

        val variability = when {
            sdnnValues.isEmpty() -> "غير معروف"
            sdnnValues.max() - sdnnValues.min() > 20 -> "تقلبات عالية (إجهاد محتمل)"
            sdnnValues.max() - sdnnValues.min() > 10 -> "تقلبات متوسطة"
            else -> "تقلبات منخفضة (استقرار جيد)"
        }
        val stressLevel = when {
            avgSDNN == null -> "غير معروف"
            avgSDNN > 50 -> "منخفض"
            avgSDNN in 30..50 -> "متوسط"
            else -> "مرتفع"
        }


        return mapOf(
            "avgSDNN" to avgSDNN.toString(),
            "avgRMSSD" to avgRMSSD.toString(),
            "maxSDNN" to sdnnValues[maxIndex].toInt().toString(),
            "minSDNN" to sdnnValues[minIndex].toInt().toString(),
            "variability" to variability,
            "maxSDNNTime" to sdf.format(timestamps[maxIndex]),
            "minSDNNTime" to sdf.format(timestamps[minIndex]),
            "stressLevel" to stressLevel
        )
    }

    private fun formatMinutes(minutes: Any?): String {
        return when (val mins = minutes?.toString()?.toIntOrNull()) {
            null -> "غير معروف"
            else -> "${mins} دقيقة"
        }
    }

    private suspend fun callMentalHealthAPI(prompt: String): String {
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
                "max_new_tokens": 1200,
                "temperature": 0.7
            }
        }
        """.trimIndent()

        val request = Request.Builder()
            .url("https://openrouter.ai/api/v1/chat/completions")
            .post(requestBody.toRequestBody(mediaType))
            .addHeader("Authorization", "")
            .addHeader("HTTP-Referer", "health")
            .addHeader("X-Title", "DailyMentalHealth")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw Exception("API request failed: ${response.code}")
            }

            return response.body?.use { responseBody ->
                val jsonResponse = responseBody.string()
                JSONObject(jsonResponse)
                    .getJSONArray("choices")
                    .getJSONObject(0)
                    .getJSONObject("message")
                    .getString("content")
                    .replace("**", "")
                    .replace("• ", "◦ ")
                    .replace("[التقييم]", "\n=== التقييم العام ===\n")
                    .replace("[المؤشرات]", "\n=== المؤشرات الرئيسية للتوتر/الاسترخاء ===\n")
                    .replace("[التوصيات]", "\n=== التوصيات اليومية ===\n")
                    .replace("[التمارين]", "\n=== تمارين التنفس والاسترخاء ===\n")
                    .replace("[تحليل-HRV]", "\n=== تحليل HRV ===\n")
                    .replace("[النوم]", "\n=== نصائح لتحسين النوم ===\n")
                    .replace(" - ", "- ")
                    .replace("1.", "\n1.").replace("2.", "\n2.").replace("3.", "\n3.").replace("4.", "\n4.")

            } ?: throw Exception("Empty response")
        }
    }

    private suspend fun saveMentalHealthAnalysis(userId: String, analysis: String) {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
        val documentId = dateFormat.format(Date())

        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("Daily_Mental_Health_Reports")
            .document(documentId)
            .set(mapOf(
                "analysis" to analysis,
                "date" to dateFormat.format(Date()),
                "timestamp" to FieldValue.serverTimestamp()
            ))
            .await()
    }

    private fun sendMentalHealthNotification(analysis: String) {
        try {
            val channelId = "daily_mental_health"
            val channelName = "Daily Mental Health Reports"
            val importance = NotificationManager.IMPORTANCE_HIGH

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    importance
                ).apply {
                    description = "Daily mental health analysis reports"
                    enableLights(true)
                    lightColor = Color.parseColor("#6200EE")
                    enableVibration(true)
                }

                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }

            val notificationId = Random().nextInt(1000)
            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_health_notification)
                .setColor(ContextCompat.getColor(context, R.color.blue))
                .setContentTitle("تقرير صحتك النفسية اليومية")
                .setContentText("انقر لعرض التحليل الكامل")
                .setStyle(NotificationCompat.BigTextStyle().bigText("تحليل يومي شامل لحالتك النفسية بناءً على نشاطك ونومك ومؤشرات HRV"))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(
                    PendingIntent.getActivity(
                        context,
                        0,
                        Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                            putExtra("mental_health_report", analysis)
                            putExtra("target_tab", 2) // تبويب الصحة النفسية
                        },
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: Exception) {
            Log.e("DailyMentalHealth", "Error sending notification", e)
        }
    }
}