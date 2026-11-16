package com.example.native_android_app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.example.native_android_app.databinding.ActivityMainBinding
import java.util.Locale

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    /** Initializes edge-to-edge host UI, Flutter event listener, and button click handlers. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        FlutterHost.onEvent = { name, payload -> log("Event: $name $payload") }

        binding.btnStart.setOnClickListener {
            FlutterHost.start(this, userId = "12345", language = Locale.getDefault().language)
            log("Flutter engine started")
        }
        binding.btnOpen.setOnClickListener {
            if (FlutterHost.isStarted) FlutterHost.open(this) else log("Start the engine first")
        }
        binding.btnSend.setOnClickListener {
            val text = binding.etMessage.text.toString()
            FlutterHost.sendData(text)
            log("Sent: $text")
        }
        binding.btnStop.setOnClickListener {
            FlutterHost.stop()
            log("Flutter engine stopped")
        }
    }

    /** Detaches the UI event listener to avoid leaking the Activity. */
    override fun onDestroy() {
        FlutterHost.onEvent = null
        super.onDestroy()
    }

    /** Appends a line to the on-screen Activity Log. */
    private fun log(line: String) {
        binding.tvLog.append(line + "\n")
    }
}
