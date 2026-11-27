package com.mechi.mechi

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mechi/job_actions")
            .setMethodCallHandler { call, result ->
                val argument = call.arguments as? String
                if (argument == null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "directions" -> {
                        val uri = Uri.parse(argument)
                        if (uri.scheme != "https" || uri.host != "www.google.com") {
                            result.success(false)
                        } else {
                            val maps = Intent(Intent.ACTION_VIEW, uri)
                                .setPackage("com.google.android.apps.maps")
                            result.success(open(maps) || open(Intent(Intent.ACTION_VIEW, uri)))
                        }
                    }
                    "dial" -> result.success(open(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", argument, null))))
                    else -> result.notImplemented()
                }
            }
    }

    private fun open(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
