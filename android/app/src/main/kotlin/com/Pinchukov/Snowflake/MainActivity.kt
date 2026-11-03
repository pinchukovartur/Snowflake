package com.Pinchukov.Snowflake

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VideoWriter.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "snowflake/video"))
    }
}
