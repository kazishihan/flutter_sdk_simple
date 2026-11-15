package com.example.native_android_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Everything the app needs from Flutter, in one place: a cached engine, the
 * channel to the Flutter screen, and a way to open it.
 */
object FlutterHost {

    private const val ENGINE_ID = "main_engine"
    private const val CHANNEL = "com.example.flutter_module/bridge"

    /** Called when the Flutter screen sends an event. Set by the UI. */
    var onEvent: ((name: String, payload: Map<String, Any?>) -> Unit)? = null

    private var channel: MethodChannel? = null

    /** Starts the Flutter engine once. Call it early (app start or after login). */
    fun start(context: Context, userId: String, language: String) {
        if (channel != null) return
        val engine = FlutterEngine(context.applicationContext)

        // Register the channel BEFORE Dart starts, so no message is missed.
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConfig" -> result.success(
                        mapOf("userId" to userId, "language" to language),
                    )
                    "sendEvent" -> {
                        val name = call.argument<String>("name")
                        if (name == null) {
                            result.error("INVALID_ARGUMENT", "name is missing", null)
                        } else {
                            val payload = call.argument<Map<String, Any?>>("payload").orEmpty()
                            onEvent?.invoke(name, payload)
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    val isStarted: Boolean get() = channel != null

    /** Shows the Flutter screen. Needs [start] first. */
    fun open(context: Context) {
        check(isStarted) { "Call FlutterHost.start() first" }
        context.startActivity(FlutterActivity.withCachedEngine(ENGINE_ID).build(context))
    }

    /** Sends text to the Flutter screen. */
    fun sendData(text: String) {
        channel?.invokeMethod("receiveData", text)
    }

    /** Frees the engine (for example on logout). */
    fun stop() {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.destroy()
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        channel = null
    }
}
