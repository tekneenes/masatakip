package com.example.masa_takip  // Projenizin package adıyla aynı olmalı

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.flutter_app/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // Örnek native fonksiyon (istersen değiştirebilir veya silebilirsin)
                "helloNative" -> {
                    val message = "Native Android tarafından selamlar"
                    result.success(message)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
