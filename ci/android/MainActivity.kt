package PACKAGE_NAME

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the SMS inbox for the Dart side over the `masareef/sms` channel.
 * Copied over the generated MainActivity by ci/apply_android_overlay.py.
 */
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensurePermission" -> ensurePermission(result)
                    "readInbox" -> {
                        val since = call.argument<Number>("since")?.toLong() ?: 0L
                        readInboxAsync(since, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun ensurePermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.error("BUSY", "A permission request is already open", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingPermission = result
            requestPermissions(arrayOf(Manifest.permission.READ_SMS), REQUEST_CODE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
    }

    private fun readInboxAsync(since: Long, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("NO_PERMISSION", "SMS permission is not granted", null)
            return
        }
        Thread {
            try {
                val rows = readInbox(since)
                runOnUiThread { result.success(rows) }
            } catch (error: Exception) {
                runOnUiThread { result.error("READ_FAILED", error.message, null) }
            }
        }.start()
    }

    private fun readInbox(since: Long): List<Map<String, Any?>> {
        val rows = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date >= ?",
            arrayOf(since.toString()),
            "date ASC",
        )?.use { cursor ->
            val address = cursor.getColumnIndexOrThrow("address")
            val body = cursor.getColumnIndexOrThrow("body")
            val date = cursor.getColumnIndexOrThrow("date")
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "address" to cursor.getString(address),
                        "body" to cursor.getString(body),
                        "date" to cursor.getLong(date),
                    ),
                )
            }
        }
        return rows
    }

    private companion object {
        const val CHANNEL = "masareef/sms"
        const val REQUEST_CODE = 4242
    }
}
