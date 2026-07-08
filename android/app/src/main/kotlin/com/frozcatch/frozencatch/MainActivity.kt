package com.frozcatch.frozencatch

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — Frozen Catch (WebView file-upload bridge)
// ============================================================
// Bridges <input type="file"> from the WebView (see
// lib/overlay/content_stage.dart) into the native document picker
// without pulling in file_picker (which would collide with the
// Kotlin Gradle Plugin in v10+ — see gray_part_pitfalls.md §1).
//
// The channel name declared here MUST match the value used by
// `_uploadPipe` in content_stage.dart. If you rename this string,
// rename it on the Dart side in the same commit.
// ============================================================
class MainActivity : FlutterActivity() {
    // Matches ContentStage._uploadPipe on the Dart side.
    private val bridgeChannel = "frozencatch/media_bridge"

    // Any unused short int works; kept unique per project as a small
    // extra fingerprint knob.
    private val chooserRequestCode = 0x5F17

    private var pendingReply: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bridgeChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "choose") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimeTypes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    launchPicker(multiple, mimeTypes, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun launchPicker(
        multiple: Boolean,
        mimeTypes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Any prior pending reply gets an empty list so we don't leak it.
        pendingReply?.success(emptyList<String>())
        pendingReply = result

        val validMimes = mimeTypes.filter { it.contains("/") }
        val chooserIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                validMimes.isEmpty() -> type = "*/*"
                validMimes.size == 1 -> type = validMimes[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, validMimes.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(
                Intent.createChooser(chooserIntent, null),
                chooserRequestCode,
            )
        } catch (_: Exception) {
            pendingReply = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != chooserRequestCode) return

        val reply = pendingReply
        pendingReply = null
        if (reply == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            reply.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        reply.success(uris)
    }
}
