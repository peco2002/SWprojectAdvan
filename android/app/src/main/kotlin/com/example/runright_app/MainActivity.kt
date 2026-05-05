package com.example.runright_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.runright_app/tcx_share"
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getPendingSharedFile") {
                    val bytes = pendingBytes
                    pendingBytes = null
                    result.success(bytes)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
                readUri(uri)
            }
            Intent.ACTION_VIEW -> {
                val uri = intent.data ?: return
                readUri(uri)
            }
        }
    }

    private fun readUri(uri: Uri) {
        try {
            contentResolver.openInputStream(uri)?.use { stream ->
                pendingBytes = stream.readBytes()
            }
        } catch (e: Exception) {
            pendingBytes = null
        }
    }
}
