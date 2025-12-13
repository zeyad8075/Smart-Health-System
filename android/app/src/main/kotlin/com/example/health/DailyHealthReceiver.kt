package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DailyHealthReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DailyHealthReceiver", "Starting daily health task")
        val serviceIntent = Intent(context, DailyHealthService::class.java)
        context.startService(serviceIntent)
    }
}