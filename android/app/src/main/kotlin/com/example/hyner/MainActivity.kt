package com.example.hyner

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var profilePhotoResult: MethodChannel.Result? = null
    private var profilePhotoUid: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/whatsapp")
            .setMethodCallHandler { call, result ->
                if (call.method != "openChat") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val enteredPhone = call.argument<String>("phone")?.filter { it.isDigit() }.orEmpty()
                val phone = if (enteredPhone.length == 10) "91$enteredPhone" else enteredPhone
                val message = call.argument<String>("message").orEmpty()
                if (phone.length !in 8..15 || message.isBlank()) {
                    result.error("invalid-input", "Enter an international phone number and a message.", null)
                    return@setMethodCallHandler
                }
                val uri = Uri.parse("https://wa.me/$phone")
                    .buildUpon()
                    .appendQueryParameter("text", message)
                    .build()
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, uri))
                    result.success(null)
                } catch (_: ActivityNotFoundException) {
                    result.error("unavailable", "No app can open this WhatsApp link.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isEnabled" -> result.success(notificationsEnabled())
                    "requestPermission" -> requestNotificationPermission(result)
                    "openSettings" -> openNotificationSettings(result)
                    "show" -> showNotification(call, result)
                    "cancel" -> {
                        val id = call.argument<Int>("id")
                        if (id == null) {
                            result.error("invalid-input", "A notification ID is required.", null)
                        } else {
                            getSystemService(NotificationManager::class.java).cancel(id)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hyner/media")
            .setMethodCallHandler { call, result ->
                if (call.method != "pickProfilePhoto") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uid = call.argument<String>("uid")?.trim().orEmpty()
                if (uid.isEmpty()) {
                    result.error("invalid-input", "Sign in before choosing a profile photo.", null)
                    return@setMethodCallHandler
                }
                if (profilePhotoResult != null) {
                    result.error("picker-open", "The photo picker is already open.", null)
                    return@setMethodCallHandler
                }
                profilePhotoUid = uid
                profilePhotoResult = result
                try {
                    val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "image/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    startActivityForResult(
                        Intent.createChooser(intent, "Choose a profile photo"),
                        PROFILE_PHOTO_REQUEST,
                    )
                } catch (_: ActivityNotFoundException) {
                    profilePhotoResult = null
                    profilePhotoUid = null
                    result.error("unavailable", "No photo picker is available on this device.", null)
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PROFILE_PHOTO_REQUEST) return
        val result = profilePhotoResult
        val uid = profilePhotoUid
        profilePhotoResult = null
        profilePhotoUid = null
        if (result == null) return
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null || uid == null) {
            result.success(null)
            return
        }
        try {
            result.success(saveProfilePhoto(uri, uid))
        } catch (error: Exception) {
            result.error("photo-save", "The selected photo could not be saved on this device.", error.message)
        }
    }

    private fun saveProfilePhoto(uri: Uri, uid: String): String {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("The selected image could not be opened.")
            BitmapFactory.decodeStream(input, null, bounds)
        }
        if (bounds.outWidth < 1 || bounds.outHeight < 1) {
            throw IllegalArgumentException("The selected file is not a readable image.")
        }
        val maxDimension = 1024
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > maxDimension ||
            bounds.outHeight / sampleSize > maxDimension
        ) sampleSize *= 2
        val bitmap = contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalStateException("The selected image could not be opened.")
            BitmapFactory.decodeStream(
                input,
                null,
                BitmapFactory.Options().apply { inSampleSize = sampleSize },
            ) ?: throw IllegalArgumentException("The selected image could not be decoded.")
        }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(uid.toByteArray())
            .joinToString("") { byte -> "%02x".format(byte) }
        val directory = File(filesDir, "profile-images")
        if (!directory.exists() && !directory.mkdirs()) {
            bitmap.recycle()
            throw IllegalStateException("The profile image folder could not be created.")
        }
        val file = File(directory, "$digest.jpg")
        try {
            FileOutputStream(file).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 86, output)) {
                    throw IllegalStateException("The selected image could not be compressed.")
                }
            }
        } finally {
            bitmap.recycle()
        }
        return file.absolutePath
    }

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(notificationsEnabled())
            return
        }
        if (notificationPermissionResult != null) {
            result.error("permission-pending", "A notification permission request is already open.", null)
            return
        }
        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }

    @Deprecated("Deprecated in Android API")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            notificationPermissionResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && notificationsEnabled(),
            )
            notificationPermissionResult = null
        }
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            }
            startActivity(intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("unavailable", "Notification settings could not be opened.", null)
        }
    }

    private fun showNotification(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        if (!notificationsEnabled()) {
            result.success(false)
            return
        }
        val id = call.argument<Int>("id")
        val title = call.argument<String>("title")?.trim().orEmpty()
        val body = call.argument<String>("body")?.trim().orEmpty()
        if (id == null || title.isEmpty() || body.isEmpty()) {
            result.error("invalid-input", "A notification title and message are required.", null)
            return
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                id,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(this)
        }
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setPriority(Notification.PRIORITY_HIGH)
        if (contentIntent != null) builder.setContentIntent(contentIntent)
        try {
            getSystemService(NotificationManager::class.java).notify(id, builder.build())
            result.success(true)
        } catch (_: SecurityException) {
            result.success(false)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL,
            "Hyner business alerts",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Low stock and saved business activity alerts"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private const val NOTIFICATION_CHANNEL = "hyner_business_alerts"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4127
        private const val PROFILE_PHOTO_REQUEST = 4128
    }
}
