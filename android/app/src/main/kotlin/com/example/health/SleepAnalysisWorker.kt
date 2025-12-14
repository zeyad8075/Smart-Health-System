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
import kotlin.math.roundToInt

class SleepAnalysisWorker(private val context: Context) : TaskWorker {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override suspend fun doTask(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            // 1. Check last execution
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("SleepAnalysisWorker", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }



            // 3. Get current sleep data
            val currentData = fetchLatestSleepData(user.uid)

            if (currentData.isEmpty()) {
                Log.e("SleepAnalysisWorker", "No sleep data available")
                return@withContext Result.failure(Exception("No sleep data available"))
            }

            // 4. Analyze data and generate report
            val analysis = analyzeSleepData(currentData)

            // 5. Save result to HealthAnalysis
            saveSleepAnalysisResult(user.uid, analysis)

            // 6. Send notification to user
            sendSleepNotification(analysis)

            // 7. Log successful execution
            val currentDate = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
            val documentId = "sleep_execution_$currentDate"

            FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .collection("sleep_execution_logs")
                .document(documentId)
                .set(
                    mapOf(
                        "timestamp" to FieldValue.serverTimestamp(),
                        "user_id" to user.uid,
                        "execution_date" to currentDate
                    )
                )
                .await()

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("SleepAnalysisWorker", "Error in sleep analysis worker", e)
            Result.failure(e)
        }
    }

    private suspend fun fetchLatestSleepData(userId: String): Map<String, Any> {
        val querySnapshot = FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("SleepData")  // تم التعديل لاستخدام مجموعة SleepData بدلاً من HealthData
            .orderBy("timestamp", Query.Direction.DESCENDING)  // استخدام حقل timestamp للترتيب
            .limit(1)
            .get()
            .await()

        if (querySnapshot.isEmpty) {
            throw Exception("No sleep data available")
        }

        return querySnapshot.documents[0].data
            ?: throw Exception("Sleep document contains no data")
    }
    private suspend fun fetchYesterdaySleepAnalysis(userId: String): String? {
        val snapshot = FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("HealthAnalysis")
            .whereEqualTo("type", "sleep")
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()

        return snapshot.documents.firstOrNull()?.getString("analysis")
    }



    private suspend fun analyzeSleepData(data: Map<String, Any>, previousAnalysis: String? = null): String {
        val prompt = buildSleepAnalysisPrompt(data, previousAnalysis)
        val analysis = callDeepSeekAPI(prompt)

        val poorSleep = (data["sleepTotalMinutes"] as? Double ?: 0.0) < 360
        val youtubeVideos = if (poorSleep) searchYouTubeVideos("تمارين للاسترخاء وتحسين النوم") else emptyList()

        return if (youtubeVideos.isNotEmpty()) {
            val videosText = youtubeVideos.joinToString("\n\n") { video ->
                "📹 ${video["title"]}\n🔗 ${video["url"]}"
            }
            "$analysis\n\n📺 فيديوهات مقترحة:\n$videosText"
        } else {
            analysis
        }
    }

    private suspend fun searchYouTubeVideos(query: String): List<Map<String, String>> {
        val apiKey = ""

        // لتنوع النتائج: استخدم ترتيب مختلف عشوائيًا
        val orders = listOf("relevance", "date", "viewCount", "rating")
        val randomOrder = orders.random()

        val url = "https://www.googleapis.com/youtube/v3/search" +
                "?part=snippet" +
                "&maxResults=3" +
                "&q=$query" +
                "&type=video" +
                "&order=$randomOrder" +   // <--- ترتيب عشوائي
                "&key=$apiKey"

        val request = Request.Builder().url(url).build()

        return try {
            val response = client.newCall(request).execute()
            val jsonResponse = JSONObject(response.body?.string())
            val items = jsonResponse.getJSONArray("items")

            (0 until items.length()).map { i ->
                val item = items.getJSONObject(i)
                val id = item.getJSONObject("id").getString("videoId")
                val title = item.getJSONObject("snippet").getString("title")
                mapOf(
                    "videoId" to id,
                    "title" to title,
                    "url" to "https://www.youtube.com/watch?v=$id"
                )
            }
        } catch (e: Exception) {
            Log.e("YouTubeAPI", "Error fetching videos", e)
            emptyList()
        }
    }

    private fun buildSleepAnalysisPrompt(currentData: Map<String, Any>, previousAnalysis: String? = null): String {
        val age = currentData["age"]?.toString() ?: "غير معروف"
        val sex = currentData["gender"]?.toString() ?: "غير معروف"
        val totalMinutes = currentData["sleepTotalMinutes"] as? Double ?: 0.0
        val totalHours = totalMinutes / 60
        val deepMinutes = currentData["sleepDeepMinutes"] as? Double ?: 0.0
        val remMinutes = currentData["sleepREMMinutes"] as? Double ?: 0.0
        val lightMinutes = currentData["sleepLightMinutes"] as? Double ?: 0.0
        val awakeMinutes = currentData["sleepAwakeMinutes"] as? Double ?: 0.0
        val previousNote = previousAnalysis?.let {
            "\nمقارنة بتقرير الأمس:\n$it\n\nيرجى تقديم تقييم جديد يوضح التحسّن أو التراجع في جودة النوم.\n"
        } ?: "\nلا توجد بيانات سابقة للمقارنة.\n"

        return """
    أنا مساعد صحي ذكي متخصص في تحليل بيانات النوم وتقديم توصيات مخصصة.
        $previousNote

    أرجو منك تحليل البيانات التالية وتقديم تقرير مفصل يتضمن:
    1. تقييم شامل لجودة النوم بناءً على أحدث المعايير الطبية.
    2. تحديد نقاط القوة والضعف في نمط النوم.
    3. توصيات قابلة للتطبيق لتحسين جودة النوم.
    4. نصائح لزيادة وقت النوم العميق ونوم الـ REM.
    5. تنبيهات في حال وجود مؤشرات على مشكلات صحية.
    6. روابط تبدأ بـ http لمقالات أو فيديوهات موثوقة تساعد المستخدم في تحسين نومه.

    ◾ بيانات المستخدم:
    - العمر: $age عام
    - الجنس: $sex
    - إجمالي وقت النوم: ${"%.1f".format(totalHours)} ساعات (${totalMinutes.roundToInt()} دقيقة)
    - نوم عميق: ${deepMinutes.roundToInt()} دقيقة (${if (totalMinutes > 0) "%.1f".format((deepMinutes / totalMinutes) * 100) else "0"}%)
    - نوم خفيف: ${lightMinutes.roundToInt()} دقيقة (${if (totalMinutes > 0) "%.1f".format((lightMinutes / totalMinutes) * 100) else "0"}%)
    - نوم REM: ${remMinutes.roundToInt()} دقيقة (${if (totalMinutes > 0) "%.1f".format((remMinutes / totalMinutes) * 100) else "0"}%)
    - وقت الاستيقاظ أثناء النوم: ${awakeMinutes.roundToInt()} دقيقة

    لا توجد بيانات سابقة للمقارنة.

    ◾ إرشادات هامة للإجابة:
    - استخدم لغة واضحة وسهلة الفهم.
    - ركز على النقاط العملية المفيدة للمستخدم.
    - استخدم تنسيق منظم (قوائم نقطية أو مرقّمة).
    - تأكد من أن جميع الروابط تبدأ بـ http وتكون موثوقة (مثل روابط من مواقع علمية، Mayo Clinic، WebMD،  الرسمي لمراكز صحية).
""".trimIndent()
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
                val rawContent = message.getString("content")

                // Format and clean text
                formatText(rawContent)
            } ?: throw Exception("Empty response")
        }
    }

    private fun formatText(text: String): String {
        return text
            .replace(Regex("[*#•]"), "")                   // Remove unnecessary symbols
            .replace(Regex("\\s+"), " ")                   // Unify spaces
            .replace(Regex("(?<=[.?!])\\s+"), "\n")       // New line after each sentence ending with . or ! or ?
            .trim()
    }

    private suspend fun saveSleepAnalysisResult(userId: String, analysis: String) {
        val youtubeLinks = analysis.lines()
            .filter { it.startsWith("🔗") }
            .map { it.substringAfter("🔗 ") }

        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .collection("Sleep_Analysis")
            .document(SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date()))
            .set(mapOf(
                "analysis" to analysis,
                "youtube_links" to youtubeLinks,  // حفظ الروابط بشكل منفصل
                "timestamp" to FieldValue.serverTimestamp(),
                "type" to "sleep"
            ))
            .await()
    }

    private fun sendSleepNotification(analysis: String) {
        try {
            val channelId = "sleep_analysis_channel"
            val channelName = "Sleep Analysis"
            val importance = NotificationManager.IMPORTANCE_HIGH

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    importance
                ).apply {
                    description = "Sleep analysis notifications"
                    enableLights(true)
                    lightColor = Color.BLUE
                    enableVibration(true)
                }

                val notificationManager = context
                    .getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }

            val firstLine = analysis.lines().firstOrNull() ?: "تحليل نومك جاهز"
            val notificationId = Random().nextInt(1000)

            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_health_notification)
                .setContentTitle(firstLine)
                .setContentText("انقر لعرض التحليل الكامل")
                .setStyle(NotificationCompat.BigTextStyle().bigText(analysis))
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
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                    )
                )
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: Exception) {
            Log.e("SleepAnalysisWorker", "Error sending notification", e)
        }
    }
}