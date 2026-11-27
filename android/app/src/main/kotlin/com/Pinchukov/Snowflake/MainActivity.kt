package com.Pinchukov.Snowflake

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val billing by lazy { HuaweiBilling(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        VideoWriter.attach(MethodChannel(messenger, "snowflake/video"))
        MethodChannel(messenger, "snowflake/iap").setMethodCallHandler(billing)
    }

    @Deprecated("The Huawei payment sheet answers here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (billing.onActivityResult(requestCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
