package com.example.prism

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.prism/share_handler"
    private val STORAGE_PERMISSION_CODE = 1001
    private val TAG = "MainActivity"
    
    // SharedPreferences keys for processing state (must match BackgroundShareService)
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val KEY_PROCESSING_BATCH_ID = "flutter.processing_batch_id"
    private val KEY_IS_PROCESSING = "flutter.is_processing"
    
    private lateinit var shareIntentHandler: ShareIntentHandler
    private var pendingResult: MethodChannel.Result? = null
    private var sharedFiles: List<String> = emptyList()
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "configureFlutterEngine called")
        
        shareIntentHandler = ShareIntentHandler(this)
        
        // Store method channel reference for proactive communication
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Handle initial intent
        handleIntent(intent)
        
        methodChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "MethodChannel call: ${call.method}")
            
            when (call.method) {
                "getSharedFiles" -> {
                    Log.d(TAG, "getSharedFiles called, returning: $sharedFiles")
                    result.success(sharedFiles)
                    // Clear after reading
                    sharedFiles = emptyList()
                }
                "saveImageToGallery" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val albumName = call.argument<String>("albumName") ?: "Prism"
                    
                    if (imagePath != null) {
                        if (checkStoragePermission()) {
                            val success = shareIntentHandler.saveImageToGallery(imagePath, albumName)
                            result.success(success)
                        } else {
                            pendingResult = result
                            requestStoragePermission()
                        }
                    } else {
                        result.error("INVALID_ARGS", "Image path is required", null)
                    }
                }
                "checkStoragePermission" -> {
                    result.success(checkStoragePermission())
                }
                "requestStoragePermission" -> {
                    if (checkStoragePermission()) {
                        result.success(true)
                    } else {
                        pendingResult = result
                        requestStoragePermission()
                    }
                }
                "clearSharedFiles" -> {
                    shareIntentHandler.clearSharedCache()
                    result.success(true)
                }
                "getAlbumImages" -> {
                    val albumName = call.argument<String>("albumName") ?: "Prism"
                    val images = shareIntentHandler.getImagesFromPrismAlbum(albumName)
                    result.success(images)
                }
                "deleteGalleryImage" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = shareIntentHandler.deleteImageFromGallery(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "File path is required", null)
                    }
                }
                "deleteGalleryImageById" -> {
                    val imageId = call.argument<Long>("imageId")
                    if (imageId != null) {
                        val success = shareIntentHandler.deleteImageById(imageId)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "Image ID is required", null)
                    }
                }
                "getPendingDeepLink" -> {
                    // Return pending deep link from notification and clear it
                    val deepLink = pendingDeepLink
                    pendingDeepLink = null
                    result.success(deepLink)
                }
                "getProcessingState" -> {
                    // Return current processing state from SharedPreferences
                    val state = getProcessingState()
                    result.success(state)
                }
                "getLocalImageIds" -> {
                    val albumName = call.argument<String>("albumName") ?: "Prism"
                    val imageIds = shareIntentHandler.getLocalImageIds(albumName)
                    result.success(imageIds)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called with action: ${intent.action}")
        setIntent(intent) // Update the activity's intent
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        Log.d(TAG, "handleIntent called with action: ${intent?.action}")
        
        // Check for deep link from notification (route to confirm_share or processing)
        val route = intent?.getStringExtra("route")
        val batchId = intent?.getStringExtra("batchId")
        val isProcessing = intent?.getBooleanExtra("isProcessing", false) ?: false
        
        if (route != null && batchId != null) {
            Log.d(TAG, "Deep link received: route=$route, batchId=$batchId, isProcessing=$isProcessing")
            // Store for Flutter to retrieve via method channel
            pendingDeepLink = mapOf(
                "route" to route, 
                "batchId" to batchId,
                "isProcessing" to isProcessing.toString()
            )
            // Immediately notify Flutter if engine is ready
            notifyFlutterOfDeepLink(route, batchId, isProcessing)
        }
        
        // Legacy: Handle share intents that may still come to MainActivity
        // (This is now primarily handled by ShareReceiverActivity)
        if (intent?.action == Intent.ACTION_SEND || intent?.action == Intent.ACTION_SEND_MULTIPLE) {
            Log.d(TAG, "Processing share intent for background handling")
            val files = shareIntentHandler.handleIntent(intent)
            Log.d(TAG, "Processed files: $files")
            
            if (files.isNotEmpty()) {
                // Start background service instead of just storing files
                startBackgroundShareService(files)
            }
        }
    }
    
    // Pending deep link from notification
    private var pendingDeepLink: Map<String, String>? = null
    
    private fun startBackgroundShareService(filePaths: List<String>) {
        Log.d(TAG, "Starting BackgroundShareService with ${filePaths.size} files")
        
        // Set up callback for when service signals Flutter
        BackgroundShareService.onFilesReady = { paths ->
            Log.d(TAG, "BackgroundShareService signaled with ${paths.size} files")
            // Store files for Flutter to retrieve
            sharedFiles = paths
            // Notify Flutter via a method call if engine is ready
            notifyFlutterOfSharedFiles(paths)
        }
        
        val serviceIntent = Intent(this, BackgroundShareService::class.java).apply {
            action = BackgroundShareService.ACTION_START_SHARE
            putStringArrayListExtra(BackgroundShareService.EXTRA_FILE_PATHS, ArrayList(filePaths))
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
    
    private fun notifyFlutterOfSharedFiles(filePaths: List<String>) {
        // This will be called when Flutter is ready to receive files
        // Store them for retrieval via getSharedFiles method channel call
        sharedFiles = filePaths
        Log.d(TAG, "Files stored for Flutter retrieval: $filePaths")
    }
    
    /**
     * Immediately notify Flutter when a deep link is received from notification tap.
     * This allows navigation to happen without delay.
     */
    private fun notifyFlutterOfDeepLink(route: String, batchId: String, isProcessing: Boolean) {
        try {
            methodChannel?.invokeMethod(
                "onDeepLinkReceived",
                mapOf(
                    "route" to route,
                    "batchId" to batchId,
                    "isProcessing" to isProcessing
                )
            )
            Log.d(TAG, "Flutter notified of deep link: route=$route, batchId=$batchId")
        } catch (e: Exception) {
            Log.w(TAG, "Could not notify Flutter of deep link: ${e.message}")
            // Flutter will retrieve via getPendingDeepLink as fallback
        }
    }
    
    /**
     * Get current processing state from SharedPreferences.
     * Returns null if not processing, or map with batchId if processing is ongoing.
     */
    private fun getProcessingState(): Map<String, Any>? {
        return try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val isProcessing = prefs.getBoolean(KEY_IS_PROCESSING, false)
            val batchId = prefs.getString(KEY_PROCESSING_BATCH_ID, null)
            
            if (isProcessing && batchId != null) {
                mapOf(
                    "isProcessing" to true,
                    "batchId" to batchId
                )
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting processing state: ${e.message}")
            null
        }
    }

    private fun checkStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10 and above - scoped storage, no permission needed
            true
        } else {
            // Android 9 and below
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStoragePermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == STORAGE_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && 
                         grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
        }
    }
}
