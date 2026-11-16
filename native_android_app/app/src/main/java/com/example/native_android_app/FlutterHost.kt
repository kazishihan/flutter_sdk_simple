package com.example.native_android_app

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.security.MessageDigest
import java.util.UUID

/**
 * Everything the app needs from Flutter, in one place: a cached engine, the
 * channel to the Flutter screen, and a way to open it.
 */
object FlutterHost {

    private const val ENGINE_ID = "main_engine"
    private const val CHANNEL = "com.example.flutter_module/bridge"

    private val ALLOWED_PAYMENT_STATUSES = setOf(
        PaymentActivity.STATUS_SUCCESS,
        PaymentActivity.STATUS_FAILED,
        PaymentActivity.STATUS_CANCELLED,
    )

    /** Called when the Flutter screen sends an event. Set by the UI. */
    var onEvent: ((name: String, payload: Map<String, Any?>) -> Unit)? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var appContext: Application? = null
    private var channel: MethodChannel? = null
    private var activeFlutterActivity: WeakReference<Activity>? = null
    private var pendingPaymentResult: MethodChannel.Result? = null
    private var pendingPaymentToken: String? = null

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        // Tracks the active FlutterActivity so native payment screens can launch on top of it.
        override fun onActivityResumed(activity: Activity) {
            if (activity is FlutterActivity) {
                activeFlutterActivity = WeakReference(activity)
            }
        }

        // Clears the reference when FlutterActivity is destroyed and cancels if it is finishing.
        override fun onActivityDestroyed(activity: Activity) {
            if (activeFlutterActivity?.get() === activity) {
                activeFlutterActivity = null
                if (activity.isFinishing) {
                    cancelPendingPayment()
                }
            }
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityStarted(activity: Activity) = Unit
        override fun onActivityPaused(activity: Activity) = Unit
        override fun onActivityStopped(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    }

    /** Starts the cached Flutter engine and registers the bridge channel. */
    fun start(context: Context, userId: String, language: String) {
        if (channel != null) return
        val application = context.applicationContext as Application
        appContext = application
        application.registerActivityLifecycleCallbacks(lifecycleCallbacks)

        val engine = FlutterEngine(application)

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
                    "openPayment" -> handleOpenPayment(call.argument<String>("phoneNumber"), result)
                    else -> result.notImplemented()
                }
            }
        }

        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    /** Validates input and launches PaymentActivity on top of the active FlutterActivity. */
    private fun handleOpenPayment(rawPhone: String?, result: MethodChannel.Result) {
        val phone = rawPhone?.trim().orEmpty()
        if (!PaymentActivity.isValidPhoneNumber(phone)) {
            result.error("INVALID_ARGUMENT", "Valid phone number is required", null)
            return
        }
        if (pendingPaymentResult != null) {
            result.error("PAYMENT_IN_PROGRESS", "A payment is already in progress", null)
            return
        }
        val activity = activeFlutterActivity?.get()
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            result.error("NO_ACTIVE_HOST", "Flutter screen is not active", null)
            return
        }

        val token = UUID.randomUUID().toString()
        pendingPaymentToken = token
        pendingPaymentResult = result
        activity.startActivity(PaymentActivity.createIntent(activity, phone, paymentToken = token))
    }

    /** Verifies the one-time token and resolves the pending Flutter payment call on main thread. */
    internal fun completePayment(token: String?, status: String, phoneNumber: String) {
        val finishBlock = {
            val expected = pendingPaymentToken
            if (expected != null && token != null &&
                MessageDigest.isEqual(expected.toByteArray(), token.toByteArray())
            ) {
                pendingPaymentToken = null
                val pending = pendingPaymentResult
                pendingPaymentResult = null

                val safeStatus = if (status in ALLOWED_PAYMENT_STATUSES) {
                    status
                } else {
                    PaymentActivity.STATUS_CANCELLED
                }
                val safePhone = if (PaymentActivity.isValidPhoneNumber(phoneNumber)) {
                    phoneNumber
                } else {
                    ""
                }

                pending?.success(
                    mapOf(
                        "status" to safeStatus,
                        "phoneNumber" to safePhone,
                    ),
                )
            }
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            finishBlock()
        } else {
            mainHandler.post(finishBlock)
        }
    }

    /** Cancels any in-flight payment request when the host or engine closes. */
    private fun cancelPendingPayment() {
        completePayment(
            token = pendingPaymentToken,
            status = PaymentActivity.STATUS_CANCELLED,
            phoneNumber = "",
        )
    }

    val isStarted: Boolean get() = channel != null

    /** Opens the stock FlutterActivity backed by the cached engine. */
    fun open(context: Context) {
        check(isStarted) { "Call FlutterHost.start() first" }
        context.startActivity(FlutterActivity.withCachedEngine(ENGINE_ID).build(context))
    }

    /** Sends a string message from the native host to Flutter. */
    fun sendData(text: String) {
        channel?.invokeMethod("receiveData", text)
    }

    /** Unregisters callbacks, cancels pending payment, and destroys the cached engine. */
    fun stop() {
        cancelPendingPayment()
        appContext?.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        appContext = null
        activeFlutterActivity = null
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.destroy()
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
        channel = null
    }
}
