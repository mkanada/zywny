package com.example.zywny

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // cpal (AAudio) precisa da JavaVM + Context; ver ffi.rs.
        System.loadLibrary("zywny_audio")
        nativeInit(applicationContext)
    }

    private external fun nativeInit(context: Context)
}
