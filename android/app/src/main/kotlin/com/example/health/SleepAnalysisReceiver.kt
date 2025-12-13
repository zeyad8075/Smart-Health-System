package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class SleepAnalysisReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SleepAnalysisReceiver", "Starting sleep analysis")
        val serviceIntent = Intent(context, SleepAnalysisService::class.java)
        context.startService(serviceIntent)
    }
}