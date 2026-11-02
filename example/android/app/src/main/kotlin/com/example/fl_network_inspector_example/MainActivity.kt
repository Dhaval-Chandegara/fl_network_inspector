package com.example.fl_network_inspector_example

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable edge-to-edge window layout for Android 15 & 16
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
