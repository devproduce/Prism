package `in`.prismapp.prism

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.gson.Gson
import com.google.gson.JsonObject
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Background Foreground Service for handling share intents without opening app UI.
 * 
 * This service performs native HTTP uploads directly, without needing Flutter.
 * 
 * Flow:
 * 1. Receives file paths and credentials from ShareReceiverActivity
 * 2. Starts as foreground service with "Uploading..." notification
 * 3. Uploads files to backend via OkHttp multipart request
 * 4. Polls for batch processing status
 * 5. Shows "Ready to Review" notification when complete
 */
class BackgroundShareService : Service() {

    companion object {
        private const val TAG = "BackgroundShareService"
        const val CHANNEL_ID = "background_share_channel"
        const val CHANNEL_NAME = "Background Sharing"
        const val NOTIFICATION_ID = 100
        private const val COMPLETION_NOTIFICATION_ID = 102
        
        // High-priority channel for completion notifications (heads-up display)
        private const val COMPLETION_CHANNEL_ID = "share_completion_channel"
        private const val COMPLETION_CHANNEL_NAME = "Share Ready"
        
        // SharedPreferences for processing state
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PROCESSING_BATCH_ID = "flutter.processing_batch_id"
        private const val KEY_IS_PROCESSING = "flutter.is_processing"

        const val ACTION_START_SHARE = "in.prismapp.prism.ACTION_START_SHARE"
        const val EXTRA_FILE_PATHS = "file_paths"
        const val EXTRA_AUTH_TOKEN = "auth_token"
        const val EXTRA_USER_ID = "user_id"
        const val EXTRA_BASE_URL = "base_url"
        
        // Polling configuration
        private const val POLL_INTERVAL_MS = 2000L
        private const val MAX_POLL_ATTEMPTS = 60 // 2 minutes max
        
        // Upload endpoints - must match Flutter ApiClient
        private const val UPLOAD_ENDPOINT = "/images/upload" // Changed from /images/batch/upload
        private const val BATCH_STATUS_ENDPOINT = "/images/batch/" // + batchId
        
        // Legacy callback for Flutter communication (kept for backward compatibility)
        var onFilesReady: ((List<String>) -> Unit)? = null
    }
    
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val gson = Gson()
    
    private lateinit var okHttpClient: OkHttpClient
    private var currentBatchId: String? = null
    private var pollAttempts = 0

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "BackgroundShareService created")
        createNotificationChannel()
        
        okHttpClient = OkHttpClient.Builder()
            .connectTimeout(60, TimeUnit.SECONDS)
            .writeTimeout(120, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called with action: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_SHARE -> {
                val filePaths = intent.getStringArrayListExtra(EXTRA_FILE_PATHS)
                val authToken = intent.getStringExtra(EXTRA_AUTH_TOKEN)
                val userId = intent.getStringExtra(EXTRA_USER_ID)
                val baseUrl = intent.getStringExtra(EXTRA_BASE_URL) ?: "http://43.204.227.62"
                
                Log.d(TAG, "Received ${filePaths?.size ?: 0} files to share in background")
                Log.d(TAG, "UserId: $userId, BaseUrl: $baseUrl, AuthToken: ${authToken?.take(10)}...")
                
                if (filePaths != null && filePaths.isNotEmpty() && authToken != null && userId != null) {
                    // Start as foreground service with notification
                    startForeground(NOTIFICATION_ID, createUploadingNotification(0, filePaths.size))
                    
                    // Start native upload in background thread
                    executor.execute {
                        uploadFiles(filePaths, authToken, userId, baseUrl)
                    }
                } else {
                    Log.w(TAG, "Missing required data - files: ${filePaths?.size}, token: ${authToken != null}, userId: ${userId != null}")
                    stopSelf()
                }
            }
            else -> {
                Log.w(TAG, "Unknown action: ${intent?.action}")
                stopSelf()
            }
        }
        
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun uploadFiles(filePaths: List<String>, authToken: String, userId: String, baseUrl: String) {
        try {
            Log.d(TAG, "Starting native upload of ${filePaths.size} files")
            
            // Build multipart request
            val multipartBuilder = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart("user_id", userId)
            
            // Add each file
            filePaths.forEachIndexed { index, path ->
                val file = File(path)
                if (file.exists()) {
                    val mediaType = getMediaType(file)
                    val requestBody = file.asRequestBody(mediaType)
                    multipartBuilder.addFormDataPart("images", file.name, requestBody)
                    Log.d(TAG, "Added file ${index + 1}/${filePaths.size}: ${file.name}")
                    
                    // Update notification with progress
                    updateNotification(index + 1, filePaths.size)
                } else {
                    Log.w(TAG, "File not found: $path")
                }
            }
            
            val requestBody = multipartBuilder.build()
            
            val request = Request.Builder()
                .url("$baseUrl$UPLOAD_ENDPOINT")
                .header("Authorization", "Bearer $authToken")
                .post(requestBody)
                .build()
            
            Log.d(TAG, "Sending upload request to: $baseUrl$UPLOAD_ENDPOINT")
            
            okHttpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    Log.e(TAG, "Upload failed: ${response.code} - ${response.message}")
                    showErrorNotification("Upload failed: ${response.message}")
                    stopForegroundAndSelf()
                    return
                }
                
                val responseBody = response.body?.string()
                Log.d(TAG, "Upload response: $responseBody")
                
                // Parse batch ID from response
                val jsonResponse = gson.fromJson(responseBody, JsonObject::class.java)
                val batchId = jsonResponse.get("batch_id")?.asString ?: jsonResponse.get("id")?.asString
                
                if (batchId != null) {
                    currentBatchId = batchId
                    Log.d(TAG, "Upload successful! Batch ID: $batchId")
                    
                    // Update notification to show processing
                    updateNotificationProcessing()
                    
                    // Start polling for batch status
                    startPolling(authToken, baseUrl, batchId, userId)
                } else {
                    Log.e(TAG, "No batch_id in response")
                    showErrorNotification("Upload failed: Invalid response")
                    stopForegroundAndSelf()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Upload error: ${e.message}", e)
            showErrorNotification("Upload failed: ${e.message}")
            stopForegroundAndSelf()
        }
    }
    
    private fun startPolling(authToken: String, baseUrl: String, batchId: String, userId: String) {
        pollAttempts = 0
        pollBatchStatus(authToken, baseUrl, batchId, userId)
    }
    
    private fun pollBatchStatus(authToken: String, baseUrl: String, batchId: String, userId: String) {
        if (pollAttempts >= MAX_POLL_ATTEMPTS) {
            Log.w(TAG, "Max poll attempts reached")
            showErrorNotification("Processing timeout")
            stopForegroundAndSelf()
            return
        }
        
        pollAttempts++
        Log.d(TAG, "Polling batch status (attempt $pollAttempts/$MAX_POLL_ATTEMPTS)")
        
        executor.execute {
            try {
                // Pass user_id as query parameter
                val request = Request.Builder()
                    .url("$baseUrl$BATCH_STATUS_ENDPOINT$batchId?user_id=$userId")
                    .header("Authorization", "Bearer $authToken")
                    .get()
                    .build()
                
                okHttpClient.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) {
                        Log.e(TAG, "Status check failed: ${response.code}")
                        schedulePollRetry(authToken, baseUrl, batchId, userId)
                        return@use
                    }
                    
                    val responseBody = response.body?.string()
                    val jsonResponse = gson.fromJson(responseBody, JsonObject::class.java)
                    val status = jsonResponse.get("status")?.asString
                    
                    Log.d(TAG, "Batch status: $status")
                    
                    when (status) {
                        "completed" -> {
                            val recipientsArray = jsonResponse.getAsJsonArray("recipients")
                            val recipientCount = recipientsArray?.size() ?: 0
                            Log.d(TAG, "Processing complete! Found $recipientCount recipients")
                            showCompletionNotification(batchId, recipientCount)
                            stopForegroundAndSelf()
                        }
                        "failed" -> {
                            Log.e(TAG, "Batch processing failed")
                            showErrorNotification("Processing failed")
                            stopForegroundAndSelf()
                        }
                        else -> {
                            // Still processing, continue polling
                            schedulePollRetry(authToken, baseUrl, batchId, userId)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Poll error: ${e.message}", e)
                schedulePollRetry(authToken, baseUrl, batchId, userId)
            }
        }
    }
    
    private fun schedulePollRetry(authToken: String, baseUrl: String, batchId: String, userId: String) {
        mainHandler.postDelayed({
            pollBatchStatus(authToken, baseUrl, batchId, userId)
        }, POLL_INTERVAL_MS)
    }
    
    private fun getMediaType(file: File): MediaType {
        val extension = file.extension.lowercase()
        return when (extension) {
            "jpg", "jpeg" -> "image/jpeg".toMediaType()
            "png" -> "image/png".toMediaType()
            "gif" -> "image/gif".toMediaType()
            "webp" -> "image/webp".toMediaType()
            "mp4" -> "video/mp4".toMediaType()
            "mov" -> "video/quicktime".toMediaType()
            else -> "application/octet-stream".toMediaType()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Low-priority channel for progress updates (no sound/vibration)
            val progressChannel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress when sharing media in background"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(progressChannel)
            
            // High-priority channel for completion notifications (heads-up with sound)
            val completionChannel = NotificationChannel(
                COMPLETION_CHANNEL_ID,
                COMPLETION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when shared media is ready for review"
                setShowBadge(true)
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(completionChannel)
            
            Log.d(TAG, "Notification channels created")
        }
    }

    private fun createUploadingNotification(current: Int, total: Int): Notification {
        val pendingIntent = createMainAppPendingIntent()
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Uploading media...")
            .setContentText("Uploading $current of $total files")
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .setProgress(total, current, false)
            .setContentIntent(pendingIntent)
            .build()
    }
    
    private fun updateNotification(current: Int, total: Int) {
        val notification = createUploadingNotification(current, total)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun updateNotificationProcessing() {
        // Save processing state for cold start scenarios
        saveProcessingState(currentBatchId, true)
        
        // Create intent that opens processing screen when tapped
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/processing")
            putExtra("batchId", currentBatchId)
            putExtra("isProcessing", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            1, // Different request code from completion
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Processing media...")
            .setContentText("Analyzing your photos")
            .setSmallIcon(android.R.drawable.ic_menu_upload)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)
            .setProgress(0, 0, true) // Indeterminate progress
            .setContentIntent(pendingIntent)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun showCompletionNotification(batchId: String, recipientCount: Int) {
        // Clear processing state but store the finished batch ID for offline launch
        try {
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.pending_review_batch_id", batchId)
                .remove(KEY_PROCESSING_BATCH_ID)
                .remove(KEY_IS_PROCESSING)
                .apply()
            Log.d(TAG, "Saved pending_review_batch_id: $batchId")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving pending_review_batch_id: ${e.message}")
        }
        
        // Cancel the progress notification
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
        
        // Create intent that opens app to confirm screen
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/confirm_share")
            putExtra("batchId", batchId)
            putExtra("isProcessing", false)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Use high-priority completion channel for heads-up notification
        val notification = NotificationCompat.Builder(this, COMPLETION_CHANNEL_ID)
            .setContentTitle("Ready to Review!")
            .setContentText("We found $recipientCount friends in your photos.")
            .setSmallIcon(android.R.drawable.ic_menu_gallery)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE) // For heads-up display
            .setDefaults(NotificationCompat.DEFAULT_ALL) // Sound, vibration, lights
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        
        notificationManager.notify(COMPLETION_NOTIFICATION_ID, notification)
        Log.d(TAG, "Completion notification shown with heads-up")
    }
    
    private fun showErrorNotification(message: String) {
        // Clear processing state
        saveProcessingState(null, false)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
        
        // Use high-priority channel for error notifications too
        val notification = NotificationCompat.Builder(this, COMPLETION_CHANNEL_ID)
            .setContentTitle("Share Failed")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ERROR)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .build()
        
        notificationManager.notify(COMPLETION_NOTIFICATION_ID, notification)
    }
    
    /**
     * Save processing state to SharedPreferences for cold start scenarios.
     * This allows the app to know if processing is ongoing when launched from notification.
     */
    private fun saveProcessingState(batchId: String?, isProcessing: Boolean) {
        try {
            getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PROCESSING_BATCH_ID, batchId)
                .putBoolean(KEY_IS_PROCESSING, isProcessing)
                .apply()
            Log.d(TAG, "Processing state saved: batchId=$batchId, isProcessing=$isProcessing")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving processing state: ${e.message}")
        }
    }
    
    private fun createMainAppPendingIntent(): PendingIntent {
        return PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun stopForegroundAndSelf() {
        Log.d(TAG, "Stopping foreground service")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdown()
        Log.d(TAG, "BackgroundShareService destroyed")
    }
}
