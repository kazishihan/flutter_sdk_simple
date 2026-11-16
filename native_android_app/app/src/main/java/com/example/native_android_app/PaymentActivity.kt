package com.example.native_android_app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.example.native_android_app.databinding.ActivityPaymentBinding

class PaymentActivity : AppCompatActivity() {

    private lateinit var binding: ActivityPaymentBinding
    private var paymentToken: String? = null
    private var hasCompleted = false

    /** Sets up secure payment UI, pre-fills validated phone number, and binds outcome buttons. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots, screen recording, and task-switcher previews on the payment screen.
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        enableEdgeToEdge()
        binding = ActivityPaymentBinding.inflate(layoutInflater)
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        val token = intent.getStringExtra(EXTRA_PAYMENT_TOKEN)?.trim().orEmpty()
        if (token.isEmpty()) {
            finish()
            return
        }
        paymentToken = token

        val incomingPhone = intent.getStringExtra(EXTRA_PHONE_NUMBER)?.trim().orEmpty()
        if (isValidPhoneNumber(incomingPhone)) {
            binding.etPhoneNumber.setText(incomingPhone)
            binding.etPhoneNumber.setSelection(incomingPhone.length)
        }

        binding.btnSuccess.setOnClickListener { finishWithOutcome(STATUS_SUCCESS) }
        binding.btnFailed.setOnClickListener { finishWithOutcome(STATUS_FAILED) }
    }

    /** Validates phone input, delivers the result to FlutterHost, and closes the screen. */
    private fun finishWithOutcome(status: String) {
        if (status !in ALLOWED_OUTCOMES || hasCompleted) return

        val phone = binding.etPhoneNumber.text.toString().trim()
        if (!isValidPhoneNumber(phone)) {
            binding.etPhoneNumber.error = "Enter a valid phone number (6-20 digits)"
            binding.etPhoneNumber.requestFocus()
            return
        }

        hasCompleted = true
        paymentToken?.let { token ->
            FlutterHost.completePayment(token = token, status = status, phoneNumber = phone)
        }
        finish()
    }

    /** Notifies FlutterHost of cancellation if the user backs out without completing payment. */
    override fun onDestroy() {
        if (isFinishing && !hasCompleted) {
            paymentToken?.let { token ->
                FlutterHost.completePayment(token = token, status = STATUS_CANCELLED, phoneNumber = "")
            }
        }
        super.onDestroy()
    }

    companion object {
        private const val EXTRA_PHONE_NUMBER = "extra_phone_number"
        private const val EXTRA_PAYMENT_TOKEN = "extra_payment_token"

        const val STATUS_SUCCESS = "success"
        const val STATUS_FAILED = "failed"
        const val STATUS_CANCELLED = "cancelled"

        private val ALLOWED_OUTCOMES = setOf(STATUS_SUCCESS, STATUS_FAILED)
        private val PHONE_REGEX = Regex("^\\+?[0-9\\s\\-()]{6,20}$")

        /** Checks that the phone string has 6-20 allowed phone characters. */
        fun isValidPhoneNumber(phone: String): Boolean {
            return phone.isNotEmpty() && phone.length <= 20 && PHONE_REGEX.matches(phone)
        }

        /** Builds an explicit Intent for PaymentActivity with a validated phone and one-time token. */
        fun createIntent(
            context: Context,
            phoneNumber: String,
            paymentToken: String,
        ): Intent {
            val sanitized = phoneNumber.trim()
            return Intent(context, PaymentActivity::class.java).apply {
                if (isValidPhoneNumber(sanitized)) {
                    putExtra(EXTRA_PHONE_NUMBER, sanitized)
                }
                putExtra(EXTRA_PAYMENT_TOKEN, paymentToken)
            }
        }
    }
}
