package com.example.health

import android.app.Service
import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class DailyMentalHealthService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        CoroutineScope(Dispatchers.IO).launch {
            val worker = DailyMentalHealthWorker(applicationContext)
            worker.analyzeDailyMentalHealth()
            stopSelf()
        }
        return START_STICKY
    }
}