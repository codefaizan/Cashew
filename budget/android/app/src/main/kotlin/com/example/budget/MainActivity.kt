package com.budget.tracker_app

import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutionException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

class MainActivity: FlutterFragmentActivity() {
    companion object {
        private const val GEMINI_NANO_CHANNEL = "cashew/ai_gemini_nano"
        private const val STATUS_TIMEOUT_SECONDS = 8L
        private const val WARMUP_TIMEOUT_SECONDS = 20L
        private const val GENERATE_TIMEOUT_SECONDS = 90L
    }

    private val geminiExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var geminiModelFutures: GenerativeModelFutures? = null

    private fun getGeminiClient(): GenerativeModelFutures {
        val existing = geminiModelFutures
        if (existing != null) return existing
        val created = GenerativeModelFutures.from(Generation.getClient())
        geminiModelFutures = created
        return created
    }

    private fun composePrompt(
        systemPrompt: String,
        history: List<Map<String, Any?>>,
        userMessage: String
    ): String {
        val prompt = StringBuilder()
        if (systemPrompt.isNotBlank()) {
            prompt.append("System:\n")
            prompt.append(systemPrompt.trim())
            prompt.append("\n\n")
        }
        if (history.isNotEmpty()) {
            prompt.append("Conversation so far:\n")
            for (message in history) {
                val role = (message["role"] as? String)?.trim().orEmpty().ifEmpty { "assistant" }
                val content = (message["content"] as? String)?.trim().orEmpty()
                if (content.isBlank()) continue
                prompt.append(role)
                prompt.append(": ")
                prompt.append(content)
                prompt.append('\n')
            }
            prompt.append('\n')
        }
        prompt.append("User: ")
        prompt.append(userMessage.trim())
        return prompt.toString()
    }

    private fun unwrapException(error: Throwable): Throwable {
        return if (error is ExecutionException && error.cause != null) {
            error.cause!!
        } else {
            error
        }
    }

    private fun respondSuccess(result: MethodChannel.Result, value: Any?) {
        runOnUiThread { result.success(value) }
    }

    private fun respondError(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Any? = null
    ) {
        runOnUiThread { result.error(code, message, details) }
    }

    private fun runGeminiTask(
        result: MethodChannel.Result,
        task: () -> Unit
    ) {
        geminiExecutor.execute {
            try {
                task()
            } catch (error: Throwable) {
                val cause = unwrapException(error)
                when (cause) {
                    is TimeoutException -> {
                        respondError(
                            result,
                            "timeout",
                            "Gemini Nano request timed out."
                        )
                    }
                    else -> {
                        respondError(
                            result,
                            "native-error",
                            "Gemini Nano native failure: ${cause.message ?: cause.javaClass.simpleName}"
                        )
                    }
                }
            }
        }
    }

    private fun checkAvailabilityInternal(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val status = getGeminiClient()
            .checkStatus()
            .get(STATUS_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        return status == FeatureStatus.AVAILABLE
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEMINI_NANO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> {
                        runGeminiTask(result) {
                            respondSuccess(result, checkAvailabilityInternal())
                        }
                    }
                    "initialize" -> {
                        runGeminiTask(result) {
                            val available = checkAvailabilityInternal()
                            if (!available) {
                                respondSuccess(result, false)
                                return@runGeminiTask
                            }

                            getGeminiClient()
                                .warmup()
                                .get(WARMUP_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                            respondSuccess(result, true)
                        }
                    }
                    "generate" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val systemPrompt = (arguments?.get("systemPrompt") as? String)?.trim().orEmpty()
                        val userMessage = (arguments?.get("userMessage") as? String)?.trim().orEmpty()
                        @Suppress("UNCHECKED_CAST")
                        val history = (arguments?.get("history") as? List<Map<String, Any?>>).orEmpty()

                        if (userMessage.isBlank()) {
                            result.error("invalid-args", "userMessage is required.", null)
                            return@setMethodCallHandler
                        }

                        runGeminiTask(result) {
                            if (!checkAvailabilityInternal()) {
                                respondError(
                                    result,
                                    "unavailable",
                                    "Gemini Nano is not available on this device."
                                )
                                return@runGeminiTask
                            }

                            val prompt = composePrompt(
                                systemPrompt = systemPrompt,
                                history = history,
                                userMessage = userMessage
                            )
                            val response = getGeminiClient()
                                .generateContent(prompt)
                                .get(GENERATE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                            val text = response.candidates
                                .firstOrNull()
                                ?.text
                                ?.trim()
                                .orEmpty()

                            if (text.isBlank()) {
                                respondError(result, "empty-response", "Gemini Nano returned empty text.")
                            } else {
                                respondSuccess(result, text)
                            }
                        }
                    }
                    "dispose" -> {
                        geminiModelFutures = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        geminiExecutor.shutdownNow()
    }
}
