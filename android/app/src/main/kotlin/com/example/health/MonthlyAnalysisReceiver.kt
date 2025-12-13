package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class MonthlyAnalysisReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MonthlyAnalysisReceiver", "Starting monthly analysis")
        val serviceIntent = Intent(context, MonthlyAnalysisService::class.java)
        context.startService(serviceIntent)
    }
}