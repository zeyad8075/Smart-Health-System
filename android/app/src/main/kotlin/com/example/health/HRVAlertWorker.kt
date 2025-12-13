package com.example.health

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*
import android.graphics.Color
import com.google.firebase.firestore.FieldValue
import androidx.core.content.ContextCompat


class HRVAlertWorker(private val context: Context) {

    private val db = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    // تعريف نطاقات الخطر لـ SDNN و RMSSD
    private val DANGER_SDNN_THRESHOLD = 20 // مللي ثانية (أقل من هذه القيمة تعتبر خطيرة)
    private val DANGER_RMSSD_THRESHOLD = 15 // مللي ثانية (أقل من هذه القيمة تعتبر خطيرة)

    suspend fun checkHRVAndNotify(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val user = auth.currentUser
            if (user == null) {
                Log.e("HRVAlertWorker", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }

            // جلب أحدث سجل للمؤشرات الحيوية
            val latestVitals = db.collection("users")
                .document(user.uid)
                .collection("VitalSigns")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(1)
                .get()
                .await()

            if (latestVitals.isEmpty) {
                Log.d("HRVAlertWorker", "No vital signs data available")
                return@withContext Result.success(Unit)
            }

            val vitalsData = latestVitals.documents[0].data ?: return@withContext Result.success(Unit)

            // استخراج قيم SDNN و RMSSD
            val sdnn = (vitalsData["hrvSDNN"] as? Number)?.toFloat()
            val rmssd = (vitalsData["hrvRMSSD"] as? Number)?.toFloat()

            if (sdnn == null || rmssd == null) {
                Log.d("HRVAlertWorker", "No HRV data in latest vital signs")
                return@withContext Result.success(Unit)
            }

            // التحقق من وجود مؤشرات خطر مع استثناء حالة الصفر
            if ((sdnn < DANGER_SDNN_THRESHOLD || rmssd < DANGER_RMSSD_THRESHOLD) &&
                (sdnn != 0f && rmssd != 0f)) {
                Log.d("HRVAlertWorker", "Dangerous HRV levels detected: SDNN=$sdnn, RMSSD=$rmssd")
                sendHRVAlertNotification(sdnn, rmssd)
                saveHRVAlertEvent(user.uid, sdnn, rmssd)
            }

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("HRVAlertWorker", "Error in worker", e)
            Result.failure(e)
        }
    }

    private fun sendHRVAlertNotification(sdnn: Float, rmssd: Float) {
        try {
            val channelId = "hrv_alert_channel"
            val channelName = "HRV Alert Notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    importance
                ).apply {
                    description = "Notifications for HRV alerts"
                    enableLights(true)
                    lightColor = Color.RED
                    enableVibration(true)
                    setShowBadge(true)
                }

                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("showMentalHealthQuestions", true)
                putExtra("target_tab", 2)
                putExtra("hrv_sdnn", sdnn)
                putExtra("hrv_rmssd", rmssd)
                action = "OPEN_MENTAL_HEALTH_QUESTIONS"
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                System.currentTimeMillis().toInt(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // بناء الإشعار
            val notificationId = Random().nextInt(10000)
            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_health_notification)
                .setColor(ContextCompat.getColor(context, R.color.red))
                .setContentTitle("تنبيه: مؤشرات التوتر مرتفعة")
                .setContentText("انقر لتقييم حالتك النفسية")
                .setStyle(NotificationCompat.BigTextStyle()
                    .bigText("تظهر مؤشرات HRV لديك مستويات توتر عالية:\nSDNN: ${"%.1f".format(sdnn)} ms\nRMSSD: ${"%.1f".format(rmssd)} ms"))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .addAction(
                    R.drawable.ic_health_notification,
                    "الإجابة على الأسئلة",
                    pendingIntent
                )
                .build()

            NotificationManagerCompat.from(context).notify(notificationId, notification)

        } catch (e: Exception) {
            Log.e("HRVAlertWorker", "Error sending HRV alert notification", e)
        }
    }

    private suspend fun saveHRVAlertEvent(userId: String, sdnn: Float, rmssd: Float) {
        try {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault())
            val documentId = dateFormat.format(Date())

            db.collection("users")
                .document(userId)
                .collection("HRVAlerts")
                .document(documentId)
                .set(mapOf(
                    "sdnn" to sdnn,
                    "rmssd" to rmssd,
                    "timestamp" to FieldValue.serverTimestamp(),
                    "status" to "pending" // pending, completed
                ))
                .await()
        } catch (e: Exception) {
            Log.e("HRVAlertWorker", "Error saving HRV alert event", e)
        }
    }
}