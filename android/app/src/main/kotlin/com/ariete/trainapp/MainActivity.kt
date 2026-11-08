package com.ariete.trainapp

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Borde a borde también en Android < 15 (en 15+ ya es obligatorio
        // al apuntar al SDK 35), para que la app se vea igual en todos.
        WindowCompat.enableEdgeToEdge(window)
        super.onCreate(savedInstanceState)
    }
}
