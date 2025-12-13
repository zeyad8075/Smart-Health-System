package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DailyAnalysisReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DailyAnalysisReceiver", "Starting daily analysis")
        val serviceIntent = Intent(context, DailyAnalysisService::class.java)
        context.startService(serviceIntent)
    }
}