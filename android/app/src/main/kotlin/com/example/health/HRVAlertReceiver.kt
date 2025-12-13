package com.example.health

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class HRVAlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("HRVAlertReceiver", "Starting HRV alert check")
        val serviceIntent = Intent(context, HRVAlertService::class.java)
        context.startService(serviceIntent)
    }
}