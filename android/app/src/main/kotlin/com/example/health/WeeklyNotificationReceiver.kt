package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class WeeklyNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("WeeklyNotificationReceiver", "Starting weekly notifications")
        val serviceIntent = Intent(context, WeeklyNotificationService::class.java)
        context.startService(serviceIntent)
    }
}