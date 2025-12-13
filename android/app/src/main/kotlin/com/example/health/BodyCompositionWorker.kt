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
import okhttp3.*
import java.io.IOException
import com.google.firebase.Timestamp


class BodyCompositionWorker(private val context: Context) : TaskWorker {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override suspend fun doTask(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            // 1. التحقق من آخر تنفيذ شهري
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("BodyCompositionWorker", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }

            // 2. التحقق من آخر تنفيذ ومرور 30 يوم
            val lastExecutionQuery = FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .collection("monthly_execution_logs")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(1)
                .get()
                .await()

            if (!lastExecutionQuery.isEmpty) {
                val lastExecution = lastExecutionQuery.documents[0]
                val lastExecutionTime = lastExecution.getDate("timestamp")

                if (lastExecutionTime != null) {
                    val currentTime = Calendar.getInstance().time
                    val diffInMillis = currentTime.time - lastExecutionTime.time
                    val daysPassed = TimeUnit.MILLISECONDS.toDays(diffInMillis)

                    if (daysPassed < 30) {
                        Log.i("BodyCompositionWorker", "لم يمر 30 يوم بعد. أيام مرت: $daysPassed")
                        return@withContext Result.success(Unit)
                    }
                }
            }
            val previousAnalysis = fetchPreviousAnalysis(user.uid)

            val (currentData, previousData) = fetchMonthlyBodyCompositionData(user.uid)

            if (currentData.isEmpty()) {
                Log.e("BodyCompositionWorker", "No body composition data available")
                return@withContext Result.failure(Exception("No body composition data available"))
            }

            val analysis = analyzeBodyCompositionData(currentData to previousData, previousAnalysis)



            // 5. حفظ النتيجة في Firestore
            saveMonthlyAnalysisResult(user.uid, analysis)

            // 6. إرسال إشعار للمستخدم
            sendMonthlyNotification(analysis)

            // 7. تسجيل التنفيذ الناجح
            val currentMonth = SimpleDateFormat("yyyy-MM", Locale.getDefault()).format(Date())
            val documentId = "monthly_execution_$currentMonth"

            FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .collection("monthly_execution_logs")
                .document(documentId)
                .set(mapOf(
                    "timestamp" to FieldValue.serverTimestamp(),
                    "user_id" to user.uid,
                    "execution_month" to currentMonth
                ))
                .await()

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("BodyCompositionWorker", "Error in monthly worker", e)
            Result.failure(e)
        }
    }

    private suspend fun fetchMonthlyBodyCompositionData(userId: String): Pair<Map<String, Any>, Map<String, Any>?> {
        val db = FirebaseFirestore.getInstance()
        val bodyCompositionRef = db.collection("users")
            .document(userId)
            .collection("BodyComposition")

        // جلب أحدث مستند
        val latestDoc = bodyCompositionRef
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()
            .documents
            .firstOrNull()
            ?: throw Exception("لا توجد بيانات لبنية الجسم مخزنة")

        val latestBodyData = latestDoc.data ?:
        throw Exception("بيانات بنية الجسم غير صالحة")

        // حساب تاريخ الشهر الماضي
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.MONTH, -1)
        val previousMonth = calendar.time

        // جلب أحدث مستند قبل شهر
        val previousDoc = bodyCompositionRef
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .whereLessThan("timestamp", latestDoc.getTimestamp("timestamp")!!.toDate())
            .whereGreaterThan("timestamp", previousMonth)
            .limit(1)
            .get()
            .await()
            .documents
            .firstOrNull()

        val previousBodyData = previousDoc?.data

        return Pair(latestBodyData, previousBodyData)
    }

    private suspend fun analyzeBodyCompositionData(
        data: Pair<Map<String, Any>, Map<String, Any>?>,
        previousAnalysis: String? = null
    ): String {
        val (currentData, previousData) = data
        val prompt = buildMonthlyAnalysisPrompt(
            currentData,
            previousData,
            "AIzaSyDsaUgFuvIZ8vjOzuPuCLJWiibVKoeBR7U",
            previousAnalysis
        )
        return callDeepSeekAPI(prompt)
    }
    private suspend fun fetchPreviousAnalysis(userId: String): String? {
        val snapshot = FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("Monthly_Analysis")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        return snapshot.documents.firstOrNull()?.getString("analysis")
    }




    private fun buildMonthlyAnalysisPrompt(
        currentData: Map<String, Any>,
        previousData: Map<String, Any>?,
        youtubeApiKey: String,
        previousAnalysis: String? = null
    ): String {
        val getValue = { map: Map<String, Any>?, key: String -> map?.get(key)?.toString() ?: "غير معروف" }

        val fields = listOf(
            "age", "gender", "height", "weight", "bmi", "bodyFat",
            "fatMassKg", "muscleMassKg", "totalBodyWaterKg", "leanBodyMassKg", "bmr"
        )

        val current = fields.associateWith { getValue(currentData, it) }
        val previous = fields.associateWith { getValue(previousData, it) }

        val nutritionQuery = if (current["bmi"]?.toDouble() ?: 0.0 > 30) "تغذية لفقدان الوزن" else "تغذية لزيادة العضلات"
        val exerciseQuery = if (current["muscleMassKg"]?.toDouble() ?: 0.0 < 10) "تمارين مبتدئ" else "تمارين متقدم"
        val relaxationQuery = if (current["bmr"]?.toDouble() ?: 0.0 > 2000) "استرخاء لتقليل التوتر" else "استرخاء عميق"

        val nutritionVideos = fetchYouTubeVideos(nutritionQuery, youtubeApiKey)
        val exerciseVideos = fetchYouTubeVideos(exerciseQuery, youtubeApiKey)
        val relaxationVideos = fetchYouTubeVideos(relaxationQuery, youtubeApiKey)

        val previousNote = previousAnalysis?.let {
            "ملاحظة: التقرير التالي هو من اليوم السابق. يرجى تجنّب تكرار نفس الوجبات والتمارين:\n\n$it\n\n"
        } ?: ""

        return """
$previousNote

أنا مساعد صحي متخصص. أرجو منك تحليل بيانات بنية الجسم التالية وتقديم تقرير طبي شامل دون استخدام رموز أو زخارف.

القسم الأول: البيانات الحالية
- العمر: ${current["age"]} عام
- الجنس: ${current["gender"]}
- الطول: ${current["height"]} متر
- الوزن: ${current["weight"]} كجم
- مؤشر كتلة الجسم: ${current["bmi"]}
- نسبة الدهون: ${current["bodyFat"]}%
- كتلة الدهون: ${current["fatMassKg"]} كجم
- الكتلة العضلية: ${current["muscleMassKg"]} كجم
- كتلة المياه: ${current["totalBodyWaterKg"]} كجم
- الكتلة الخالية من الدهون (LBM): ${current["leanBodyMassKg"]} كجم
- معدل الأيض الأساسي (BMR): ${current["bmr"]}

القسم الثاني: البيانات قبل شهر
- العمر: ${previous["age"]} عام
- الجنس: ${previous["gender"]}
- الطول: ${previous["height"]} متر
- الوزن: ${previous["weight"]} كجم
- مؤشر كتلة الجسم: ${previous["bmi"]}
- نسبة الدهون: ${previous["bodyFat"]}%
- كتلة الدهون: ${previous["fatMassKg"]} كجم
- الكتلة العضلية: ${previous["muscleMassKg"]} كجم
- كتلة المياه: ${previous["totalBodyWaterKg"]} كجم
- الكتلة الخالية من الدهون (LBM): ${previous["leanBodyMassKg"]} كجم
- معدل الأيض الأساسي (BMR): ${previous["bmr"]}

المطلوب منك:
1. تحليل التغيرات الجسدية.
2. تقييم الحالة الصحية الحالية (الإيجابيات والنقاط التي تحتاج تحسين).
3. تقديم خطة غذائية، رياضية، ونمط نوم جديدة ومختلفة عن اليوم السابق.
4. اقتراح أهداف صحية لهذا الشهر.

روابط مقترحة:
- تغذية: $nutritionVideos
- تمارين: $exerciseVideos
- استرخاء: $relaxationVideos
""".trimIndent()
    }


    private fun fetchYouTubeVideos(query: String, apiKey: String): String {
        val url = "https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&key=$apiKey"
        val client = OkHttpClient()
        val request = Request.Builder()
            .url(url)
            .build()

        return try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw IOException("Unexpected code $response")
                val jsonResponse = response.body?.string()
                val jsonObject = JSONObject(jsonResponse)
                val items = jsonObject.getJSONArray("items")
                val videoLinks = StringBuilder()

                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val videoId = item.getJSONObject("id").getString("videoId")
                    val videoLink = "https://www.youtube.com/watch?v=$videoId"
                    videoLinks.append("\n- $videoLink")
                }
                videoLinks.toString()
            }
        } catch (e: IOException) {
            "لم يتم العثور على فيديوهات."
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
                "max_new_tokens": 1500,
                "temperature": 0.7,
                "top_p": 0.9
            }
        }
        """.trimIndent()

        val request = Request.Builder()
            .url("https://openrouter.ai/api/v1/chat/completions")
            .post(requestBody.toRequestBody(mediaType))
            .addHeader("Authorization", "Bearer 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")
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
                message.getString("content")
            } ?: throw Exception("Empty response")
        }
    }

    private suspend fun saveMonthlyAnalysisResult(userId: String, analysis: String) {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
        val documentId = dateFormat.format(Date())

        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("Monthly_Analysis")
            .document(documentId)
            .set(mapOf(
                "analysis" to analysis,
                "timestamp" to FieldValue.serverTimestamp()
            ))
            .await()
    }

    private fun sendMonthlyNotification(analysis: String) {
        try {
            val channelId = "monthly_analysis_channel"
            val channelName = "Monthly Body Analysis"
            val importance = NotificationManager.IMPORTANCE_HIGH

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    importance
                ).apply {
                    description = "Monthly body composition analysis"
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
                .setContentTitle("تقرير شهري لبنية جسمك")
                .setContentText("انقر لعرض التحليل الكامل والخطة الشهرية")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(
                    PendingIntent.getActivity(
                        context,
                        0,
                        Intent(context, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                            putExtra("monthly_analysis", analysis)
                            putExtra("target_tab", 1)
                        },
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                )
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: Exception) {
            Log.e("BodyCompositionWorker", "Error sending monthly notification", e)
        }
    }
}