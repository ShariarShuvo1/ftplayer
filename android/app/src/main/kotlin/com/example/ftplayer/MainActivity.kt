package com.example.ftplayer

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Socket
import java.net.SocketException

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ftplayer/config"
    private val NETWORK_CHANNEL = "com.example.ftplayer/network"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApiUrl") {
                try {
                    val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val apiUrl = appInfo.metaData?.getString("API_URL") ?: ""
                    result.success(apiUrl)
                } catch (e: Exception) {
                    result.success("")
                }
            } else {
                result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "optimizeNetworkBuffers" -> {
                    try {
                        optimizeSystemNetworkBuffers()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NETWORK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun optimizeSystemNetworkBuffers() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val runtime = Runtime.getRuntime()
                val process = runtime.exec(arrayOf("sh", "-c", "sysctl -w net.ipv4.tcp_rmem='4096 131072 6291456'"))
                process.waitFor()
            }
        } catch (e: Exception) {
            // Silently ignore - optimization not critical
        }
    }
}

