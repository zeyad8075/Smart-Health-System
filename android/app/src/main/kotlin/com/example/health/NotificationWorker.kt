package com.example.health

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.Query
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import com.example.health.R
import androidx.core.app.NotificationCompat.PRIORITY_HIGH
import android.graphics.Color

class NotificationWorker(private val context: Context) : TaskWorker {

    override suspend fun doTask(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val user = FirebaseAuth.getInstance().currentUser
            if (user == null) {
                Log.e("NotificationWorker", "User not authenticated")
                return@withContext Result.failure(Exception("User not authenticated"))
            }



            // 2. Send notifications
            val notifications = listOf(
                NotificationData(
                    title = "تذكير أسبوعي بالصحة",
                    message = "من أجل متابعة صحتك، نذكرك بإدخال بيانات ضغط الدم"
                ),
                NotificationData(
                    title = "تذكير أسبوعي بالصحة",
                    message = "لا تنسَ تسجيل مستوى السكر في الدم لمتابعة صحتك"
                ),
                NotificationData(
                    title = "تذكير أسبوعي بالصحة",
                    message = "لحصول على تقييم دقيق، نذكرك بقياس بيانات بنية الجسم (Body Composition)"
                )
            )

            notifications.forEach { notification ->
                sendHealthNotification(notification.title, notification.message)
            }

            // 3. Log notifications in Firestore
            val currentDate = getCurrentDateString()
            val documentId = "notification_$currentDate"

            val logData = mapOf(
                "user_id" to user.uid,
                "timestamp" to FieldValue.serverTimestamp(),
                "notifications_sent" to notifications.size,
                "last_notification_date" to currentDate
            )

            FirebaseFirestore.getInstance()
                .collection("users")
                .document(user.uid)
                .collection("notification_logs")
                .document(documentId)
                .set(logData)
                .await()

            Result.success(Unit)
        } catch (e: Exception) {
            Log.e("NotificationWorker", "Error in notification worker", e)
            Result.failure(e)
        }
    }

    private fun getCurrentDateString(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    data class NotificationData(
        val title: String,
        val message: String
    )

    private fun sendHealthNotification(title: String, message: String) {
        try {
            // Create notification channel
            val channelId = "health_reminders_channel"
            val channelName = "Health Reminders"
            val importance = NotificationManager.IMPORTANCE_HIGH

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    importance
                ).apply {
                    description = "Notifications for health reminders"
                    enableLights(true)
                    lightColor = Color.BLUE
                    enableVibration(true)
                }

                val notificationManager = context
                    .getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }

            // Build intent to open app when notification is clicked
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            // Build notification
            val notificationId = Random().nextInt(1000)
            val notification = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_health_notification)
                .setColor(ContextCompat.getColor(context, R.color.blue))
                .setColorized(true)
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .build()

            // Show notification
            NotificationManagerCompat.from(context).notify(notificationId, notification)

        } catch (e: Exception) {
            Log.e("NotificationWorker", "Error sending notification", e)
        }
    }
}