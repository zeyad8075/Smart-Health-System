// TaskWorker.kt
package com.example.health

import kotlin.Result

interface TaskWorker {
    suspend fun doTask(): Result<Unit>
}