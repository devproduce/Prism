package `in`.prismapp.prism

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.database.Cursor
import android.util.Log
import java.io.File
import java.io.FileOutputStream

class ShareIntentHandler(private val context: Context) {
    
    companion object {
        private const val TAG = "ShareIntentHandler"
    }

    /**
     * Handle incoming share intent and extract file paths
     * Supports both ACTION_SEND (single file) and ACTION_SEND_MULTIPLE (multiple files)
     */
    fun handleIntent(intent: Intent?): List<String> {
        if (intent == null) {
            Log.d(TAG, "Intent is null")
            return emptyList()
        }

        Log.d(TAG, "Handling intent action: ${intent.action}")
        
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                handleSingleShare(intent)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                handleMultipleShare(intent)
            }
            else -> {
                Log.d(TAG, "Unknown action: ${intent.action}")
                emptyList()
            }
        }
    }

    /**
     * Handle single file share (ACTION_SEND)
     */
    private fun handleSingleShare(intent: Intent): List<String> {
        val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        
        Log.d(TAG, "Single share URI: $uri")
        
        return if (uri != null) {
            val filePath = copyFileToAppStorage(uri)
            Log.d(TAG, "Copied file path: $filePath")
            if (filePath != null) listOf(filePath) else emptyList()
        } else {
            emptyList()
        }
    }

    /**
     * Handle multiple files share (ACTION_SEND_MULTIPLE)
     */
    private fun handleMultipleShare(intent: Intent): List<String> {
        val uris: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
        
        Log.d(TAG, "Multiple share URIs count: ${uris?.size}")
        
        return uris?.mapNotNull { uri ->
            Log.d(TAG, "Processing URI: $uri")
            copyFileToAppStorage(uri)
        } ?: emptyList()
    }

    /**
     * Copy file from content URI to app's cache directory
     * Returns the absolute path of the copied file
     */
    private fun copyFileToAppStorage(uri: Uri): String? {
        return try {
            Log.d(TAG, "Copying file from URI: $uri scheme: ${uri.scheme}")
            
            val inputStream = context.contentResolver.openInputStream(uri)
            if (inputStream == null) {
                Log.e(TAG, "Could not open input stream for URI: $uri")
                return null
            }
            
            // Get original filename or generate one
            val fileName = getFileName(uri) ?: "shared_${System.currentTimeMillis()}.jpg"
            Log.d(TAG, "File name: $fileName")
            
            // Create file in cache directory
            val cacheDir = File(context.cacheDir, "shared_media")
            if (!cacheDir.exists()) {
                val created = cacheDir.mkdirs()
                Log.d(TAG, "Cache dir created: $created at ${cacheDir.absolutePath}")
            }
            
            val file = File(cacheDir, fileName)
            Log.d(TAG, "Target file: ${file.absolutePath}")
            
            // Copy file
            FileOutputStream(file).use { outputStream ->
                val bytesCopied = inputStream.copyTo(outputStream)
                Log.d(TAG, "Bytes copied: $bytesCopied")
            }
            inputStream.close()
            
            // Verify file exists
            if (file.exists() && file.length() > 0) {
                Log.d(TAG, "File copied successfully: ${file.absolutePath} size: ${file.length()}")
                file.absolutePath
            } else {
                Log.e(TAG, "File copy failed or empty file")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error copying file: ${e.message}", e)
            null
        }
    }

    /**
     * Get filename from content URI
     */
    private fun getFileName(uri: Uri): String? {
        var fileName: String? = null
        
        try {
            val cursor: Cursor? = context.contentResolver.query(
                uri, null, null, null, null
            )
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index != -1) {
                        fileName = it.getString(index)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting file name: ${e.message}")
        }
        
        // If we couldn't get the name, generate one based on MIME type
        if (fileName == null) {
            val mimeType = context.contentResolver.getType(uri)
            val extension = when {
                mimeType?.contains("jpeg") == true || mimeType?.contains("jpg") == true -> ".jpg"
                mimeType?.contains("png") == true -> ".png"
                mimeType?.contains("gif") == true -> ".gif"
                mimeType?.contains("webp") == true -> ".webp"
                mimeType?.contains("video") == true -> ".mp4"
                else -> ".jpg"
            }
            fileName = "shared_${System.currentTimeMillis()}$extension"
        }
        
        return fileName
    }

    /**
     * Save image to device gallery
     * Creates album if it doesn't exist
     */
    fun saveImageToGallery(imagePath: String, albumName: String = "Prism"): Boolean {
        return try {
            val imageFile = File(imagePath)
            if (!imageFile.exists()) {
                Log.e(TAG, "Image file does not exist: $imagePath")
                return false
            }

            val values = android.content.ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, imageFile.name)
                put(MediaStore.Images.Media.MIME_TYPE, getMimeType(imagePath))
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$albumName")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)

            if (uri != null) {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    imageFile.inputStream().use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
                
                // Clear pending flag
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                
                Log.d(TAG, "Image saved to gallery: $imagePath")
                true
            } else {
                Log.e(TAG, "Failed to insert image into MediaStore")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving image to gallery: ${e.message}", e)
            false
        }
    }

    /**
     * Get MIME type from file path
     */
    private fun getMimeType(filePath: String): String {
        return when (filePath.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "mp4" -> "video/mp4"
            "mov" -> "video/quicktime"
            else -> "image/*"
        }
    }

    /**
     * Clear cached shared files
     */
    fun clearSharedCache() {
        try {
            val cacheDir = File(context.cacheDir, "shared_media")
            if (cacheDir.exists()) {
                cacheDir.listFiles()?.forEach { 
                    Log.d(TAG, "Deleting cached file: ${it.name}")
                    it.delete() 
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing cache: ${e.message}")
        }
    }

    /**
     * Get all images from the Prism album
     * Returns list of maps with image info: {path, fileName, dateAdded, mimeType, id}
     */
    fun getImagesFromPrismAlbum(albumName: String = "Prism"): List<Map<String, Any>> {
        val images = mutableListOf<Map<String, Any>>()
        
        try {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            
            val projection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.DATE_ADDED,
                MediaStore.Images.Media.MIME_TYPE,
                MediaStore.Images.Media.DATA,
                MediaStore.Images.Media.RELATIVE_PATH
            )
            
            // Query for images in Pictures/Prism folder
            val selection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                "${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?"
            } else {
                "${MediaStore.Images.Media.DATA} LIKE ?"
            }
            
            val selectionArgs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                arrayOf("Pictures/$albumName%")
            } else {
                arrayOf("%Pictures/$albumName%")
            }
            
            val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"
            
            context.contentResolver.query(
                collection,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
                val mimeColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
                val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idColumn)
                    val name = cursor.getString(nameColumn)
                    val dateAdded = cursor.getLong(dateColumn)
                    val mimeType = cursor.getString(mimeColumn) ?: "image/jpeg"
                    val filePath = cursor.getString(dataColumn) ?: ""
                    
                    val contentUri = android.content.ContentUris.withAppendedId(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        id
                    )
                    
                    images.add(mapOf(
                        "id" to id,
                        "fileName" to name,
                        "dateAdded" to dateAdded,
                        "mimeType" to mimeType,
                        "path" to filePath,
                        "contentUri" to contentUri.toString()
                    ))
                }
            }
            
            Log.d(TAG, "Found ${images.size} images in $albumName album")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error querying Prism album: ${e.message}", e)
        }
        
        return images
    }

    /**
     * Delete an image from the gallery by its file path or content URI
     * Returns true if deleted successfully
     */
    fun deleteImageFromGallery(filePath: String): Boolean {
        return try {
            Log.d(TAG, "Attempting to delete image: $filePath")
            
            // First try to find the image in MediaStore by path
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            
            val selection = "${MediaStore.Images.Media.DATA} = ?"
            val selectionArgs = arrayOf(filePath)
            
            // Try to delete from MediaStore
            val deletedRows = context.contentResolver.delete(
                collection,
                selection,
                selectionArgs
            )
            
            if (deletedRows > 0) {
                Log.d(TAG, "Deleted $deletedRows image(s) from MediaStore")
                return true
            }
            
            // If MediaStore delete didn't work, try deleting the file directly
            val file = File(filePath)
            if (file.exists()) {
                val deleted = file.delete()
                Log.d(TAG, "Direct file deletion result: $deleted")
                return deleted
            }
            
            Log.w(TAG, "Image not found for deletion: $filePath")
            false
            
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting image from gallery: ${e.message}", e)
            false
        }
    }

    /**
     * Get all image IDs (filenames without extensions) from the Prism album
     * This is optimized for checking which images already exist locally
     * Returns a set of image IDs for fast lookup
     */
    fun getLocalImageIds(albumName: String = "Prism"): List<String> {
        val imageIds = mutableListOf<String>()
        
        try {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            
            val projection = arrayOf(
                MediaStore.Images.Media.DISPLAY_NAME
            )
            
            // Query for images in Pictures/Prism folder
            val selection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                "${MediaStore.Images.Media.RELATIVE_PATH} LIKE ?"
            } else {
                "${MediaStore.Images.Media.DATA} LIKE ?"
            }
            
            val selectionArgs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                arrayOf("Pictures/$albumName%")
            } else {
                arrayOf("%Pictures/$albumName%")
            }
            
            context.contentResolver.query(
                collection,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                
                while (cursor.moveToNext()) {
                    val fileName = cursor.getString(nameColumn) ?: continue
                    // Remove extension to get the image ID
                    val imageId = fileName.substringBeforeLast('.', fileName)
                    if (imageId.isNotEmpty()) {
                        imageIds.add(imageId)
                    }
                }
            }
            
            Log.d(TAG, "Found ${imageIds.size} local image IDs in $albumName album")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting local image IDs: ${e.message}", e)
        }
        
        return imageIds
    }

    /**
     * Delete an image from the gallery by its MediaStore ID
     * Returns true if deleted successfully
     */
    fun deleteImageById(imageId: Long): Boolean {
        return try {
            Log.d(TAG, "Attempting to delete image by ID: $imageId")
            
            val contentUri = android.content.ContentUris.withAppendedId(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                imageId
            )
            
            Log.d(TAG, "Content URI for deletion: $contentUri")
            
            val deletedRows = context.contentResolver.delete(contentUri, null, null)
            
            Log.d(TAG, "Deleted $deletedRows image(s) by ID: $imageId")
            
            if (deletedRows > 0) {
                true
            } else {
                Log.w(TAG, "No rows deleted for ID: $imageId - file may not exist or permission denied")
                false
            }
            
        } catch (e: android.app.RecoverableSecurityException) {
            // On Android 10+, this may require user permission
            Log.e(TAG, "RecoverableSecurityException - user permission required: ${e.message}", e)
            false
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException deleting image by ID: ${e.message}", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting image by ID: ${e.message}", e)
            false
        }
    }
}
