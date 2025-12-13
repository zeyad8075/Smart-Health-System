package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DailyMentalHealthReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DailyMentalHealthReceiver", "Starting mental health analysis")
        val serviceIntent = Intent(context, DailyMentalHealthService::class.java)
        context.startService(serviceIntent)
    }
}