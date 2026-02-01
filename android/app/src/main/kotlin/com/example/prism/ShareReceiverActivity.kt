package com.example.prism

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Toast

/**
 * Transparent activity that receives share intents from other apps.
 * This activity is invisible to the user - it processes the share and finishes immediately,
 * allowing the user to stay in their gallery/source app.
 * 
 * Flow:
 * 1. User shares media from gallery -> This activity catches the intent
 * 2. Files are copied to app cache
 * 3. BackgroundShareService is started for upload
 * 4. Activity finishes immediately (user stays in gallery)
 * 5. User sees notifications for upload progress and completion
 */
class ShareReceiverActivity : Activity() {

    companion object {
        private const val TAG = "ShareReceiverActivity"
        
        // SharedPreferences keys (must match Flutter's AuthProvider)
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_AUTH_TOKEN = "flutter.prism_auth_token"
        private const val KEY_USER_ID = "flutter.prism_user_id"
        private const val KEY_BASE_URL = "flutter.prism_base_url"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // No setContentView - activity is completely invisible
        Log.d(TAG, "ShareReceiverActivity created with action: ${intent?.action}")
        
        processShareIntent()
    }

    private fun processShareIntent() {
        val action = intent?.action
        
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            Log.w(TAG, "Unknown action: $action, finishing")
            finish()
            return
        }

        // Check if user is logged in
        val credentials = getStoredCredentials()
        if (credentials == null) {
            Log.w(TAG, "User not logged in, opening main app")
            showToast("Please login to Prism first")
            openMainApp()
            finish()
            return
        }

        Log.d(TAG, "User authenticated: ${credentials.userId}")

        // Process shared files
        val shareIntentHandler = ShareIntentHandler(this)
        val filePaths = shareIntentHandler.handleIntent(intent)

        if (filePaths.isEmpty()) {
            Log.w(TAG, "No files found in share intent")
            showToast("Could not process shared files")
            finish()
            return
        }

        Log.d(TAG, "Received ${filePaths.size} files to share")

        // Start background service for upload
        startBackgroundUpload(filePaths, credentials)

        // Show confirmation toast
        val fileCount = filePaths.size
        val message = if (fileCount == 1) "Uploading 1 photo..." else "Uploading $fileCount photos..."
        showToast(message)

        // Finish immediately - user stays in their gallery app
        finish()
    }

    private fun startBackgroundUpload(filePaths: List<String>, credentials: UserCredentials) {
        Log.d(TAG, "Starting BackgroundShareService with ${filePaths.size} files")

        val serviceIntent = Intent(this, BackgroundShareService::class.java).apply {
            action = BackgroundShareService.ACTION_START_SHARE
            putStringArrayListExtra(BackgroundShareService.EXTRA_FILE_PATHS, ArrayList(filePaths))
            putExtra(BackgroundShareService.EXTRA_AUTH_TOKEN, credentials.authToken)
            putExtra(BackgroundShareService.EXTRA_USER_ID, credentials.userId)
            putExtra(BackgroundShareService.EXTRA_BASE_URL, credentials.baseUrl)
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun getStoredCredentials(): UserCredentials? {
        try {
            // Flutter's shared_preferences uses "FlutterSharedPreferences" as the file name
            // and prepends "flutter." to all keys
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            Log.d(TAG, "Checking SharedPreferences for credentials...")
            Log.d(TAG, "SharedPreferences file: $PREFS_NAME")
            Log.d(TAG, "All keys in SharedPreferences: ${prefs.all.keys}")
            
            val authToken = prefs.getString(KEY_AUTH_TOKEN, null)
            val userId = prefs.getString(KEY_USER_ID, null)
            val baseUrl = prefs.getString(KEY_BASE_URL, null) ?: "http://43.204.227.62"

            Log.d(TAG, "authToken found: ${authToken != null} (length: ${authToken?.length ?: 0})")
            Log.d(TAG, "userId found: ${userId != null} (value: $userId)")
            Log.d(TAG, "baseUrl: $baseUrl")

            if (authToken == null || userId == null) {
                Log.w(TAG, "Missing credentials - authToken: ${authToken != null}, userId: ${userId != null}")
                Log.w(TAG, "User needs to logout and login again to save credentials")
                return null
            }

            Log.d(TAG, "✅ Credentials found successfully!")
            return UserCredentials(authToken, userId, baseUrl)
        } catch (e: Exception) {
            Log.e(TAG, "Error reading credentials: ${e.message}", e)
            return null
        }
    }

    private fun openMainApp() {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(mainIntent)
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    /**
     * Data class to hold user credentials
     */
    data class UserCredentials(
        val authToken: String,
        val userId: String,
        val baseUrl: String
    )
}
