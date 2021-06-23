package com.kochava.kochava_tracker

import android.content.Context
import com.kochava.base.Tracker
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import org.json.JSONObject

/** KochavaTrackerPlugin */
class KochavaTrackerPlugin : FlutterPlugin, MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    // Application Context
    lateinit var context: Context

    /**
     * Attached to the flutter engine.
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "kochava_tracker")
        channel.setMethodCallHandler(this)
    }

    /**
     * Detached from the flutter engine.
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // This static function is optional and equivalent to onAttachedToEngine. It supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both be defined
    // in the same class.
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "kochava_tracker")
            val plugin = KochavaTrackerPlugin()
            plugin.context = registrar.context()
            channel.setMethodCallHandler(plugin)
        }
    }

    /**
     * Handler for method calls from the Dart/Flutter layer to the native.
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        val isFailure = runCatching {
            return when (call.method) {
                "configure" -> {
                    configure(call.arguments<Map<String, Any>?>()?.toJSONObject())
                    result.success(null)
                }
                "getAttribution" -> result.success(Tracker.getAttribution())
                "getDeviceId" -> result.success(Tracker.getDeviceId())
                "getVersion" -> result.success(Tracker.getVersion())
                "setAppLimitAdTracking" -> {
                    Tracker.setAppLimitAdTracking(call.arguments())
                    result.success(null)
                }
                "setIdentityLink" -> {
                    val identityLink = call.arguments<Map<String, String>?>()
                    requireNotNull(identityLink)
                    Tracker.setIdentityLink(Tracker.IdentityLink()
                            .add(identityLink)
                    )
                    result.success(null)
                }
                "setSleep" -> {
                    Tracker.setSleep(call.arguments())
                    result.success(null)
                }
                "getSleep" -> result.success(Tracker.isSleep())
                "addPushToken" -> {
                    Tracker.addPushToken(call.arguments())
                    result.success(null)
                }
                "removePushToken" -> {
                    Tracker.removePushToken(call.arguments())
                    result.success(null)
                }
                "sendEventString" -> {
                    val name = call.argument("name") ?: ""
                    val info = call.argument("info") ?: ""
                    Tracker.sendEvent(name, info)
                    result.success(null)
                }
                "sendEventMapObject" -> {
                    val name = call.argument("name") ?: ""
                    val info = call.argument<Map<String, Any>?>("info")?.toJSONObject()
                    Tracker.sendEvent(Tracker.Event(name).apply {
                        if (info != null) {
                            addCustom(info)
                        }
                    })
                    result.success(null)
                }
                "sendEventAppleAppStoreReceipt" -> {
                    // Not supported on this platform.
                    result.success(null)
                }
                "sendEventGooglePlayReceipt" -> {
                    val name = call.argument("name") ?: ""
                    val info = call.argument<Map<String, Any>?>("info")?.toJSONObject()
                    val receiptData: String? = call.argument("receiptData")
                    val receiptDataSignature: String? = call.argument("receiptDataSignature")
                    Tracker.sendEvent(Tracker.Event(name).apply {
                        if (info != null) {
                            addCustom(info)
                        }
                        if (receiptData != null && receiptDataSignature != null) {
                            setGooglePlayReceipt(receiptData, receiptDataSignature)
                        }
                    })
                    result.success(null)
                }
                "sendDeepLink" -> {
                    val uri: String? = call.argument("openURLString")
                    val source: String? = call.argument("sourceApplicationString")
                    Tracker.sendEvent(Tracker.Event(Tracker.EVENT_TYPE_DEEP_LINK).apply {
                        if (uri != null) {
                            this.setUri(uri)
                        }
                        if (source != null) {
                            this.setSource(source)
                        }
                    })
                    result.success(null)
                }
                "processDeeplink" -> {
                    val id = call.argument("id") ?: ""
                    val path = call.argument("path") ?: ""
                    val timeout = call.argument("timeout") ?: 10.0
                    Tracker.processDeeplink(path, timeout) { deeplink ->
                        channel.invokeMethod("deeplinkCallback", JSONObject().apply {
                            put("id", id)
                            put("deeplink", deeplink.toJson())
                        }.toString())
                    }
                    result.success(null)
                }
                "enableAppTrackingTransparencyAutoRequest" -> {
                    // Not supported on this platform.
                    result.success(null)
                }
                "executeAdvancedInstruction" -> {
                    val key = call.argument("key") ?: ""
                    val value = call.argument("value") ?: ""

                    when(key) {
                        "INTERNAL_UNCONFIGURE" -> {
                            Tracker.unConfigure(false)
                        }
                        "INTERNAL_RESET" -> {
                            // Delete the database.
                            context.deleteDatabase("kodb")

                            // Clear shared preferences
                            val sp = context.getSharedPreferences("kosp", Context.MODE_PRIVATE)
                            sp.edit().clear().apply()
                        }
                        else -> Tracker.executeAdvancedInstruction(key, value)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }.isFailure
        if (isFailure) {
            result.error("1234", "Failed to process: ${call.method}", null)
        }
    }

    /**
     * Configure and Start the Tracker.
     */
    private fun configure(input: JSONObject?) {
        // Validate
        requireNotNull(input)

        // Create the configuration object and pass it our context.
        val configuration = Tracker.Configuration(context)

        // Check for the App Guid.
        input.optString("androidAppGUIDString", null)?.let {
            configuration.setAppGuid(it)
        }

        // Check for the Instant App Guid.
        input.optString("instant_app_id", null)?.let {
            configuration.setInstantAppGuid(it)
        }

        // Check for the partner name key.
        input.optString("partnerName", null)?.let {
            configuration.setPartnerName(it)
        }

        // Check for the log level. Do not set if invalid.
        input.optString("logLevel", null)?.optLogLevel()?.let {
            configuration.setLogLevel(it)
        }

        // Check for request attribution.
        input.getBooleanOrNull("retrieveAttribution")?.let {
            if (it) {
                configuration.setAttributionUpdateListener { attribution ->
                    channel.invokeMethod("attributionCallback", attribution)
                }
            }
        }

        // Check for app limit ad tracking.
        input.getBooleanOrNull("limitAdTracking")?.let {
            configuration.setAppLimitAdTracking(it)
        }

        // Check for sleep.
        input.getBooleanOrNull("sleepBool")?.let {
            configuration.setSleep(it)
        }

        // Check for Identity Link
        input.optJSONObject("identityLink")?.let {
            configuration.setIdentityLink(it.toIdentityLink())
        }

        // Check for Custom
        input.optJSONObject("custom")?.let {
            configuration.addCustom(it)
        }

        // Configure the tracker.
        Tracker.configure(configuration)
    }

    /**
     * Converts a Map into a JSONObject and returns null on failure.
     */
    private fun Map<*, *>.toJSONObject(): JSONObject? {
        return runCatching {
            JSONObject(this)
        }.getOrNull()
    }

    /**
     * Converts all the key values in a JSONObject into an IdentityLink object.
     */
    private fun JSONObject.toIdentityLink(): Tracker.IdentityLink {
        return Tracker.IdentityLink().apply {
            keys().forEach { key ->
                optString(key, null)?.let {
                    add(key, it)
                }
            }
        }
    }

    /**
     * Converts a String into the proper log level. Returning null if unable.
     */
    private fun String.optLogLevel(): Int? {
        return when {
            "NEVER".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_NONE
            "NONE".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_NONE
            "ERROR".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_ERROR
            "WARN".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_WARN
            "INFO".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_INFO
            "DEBUG".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_DEBUG
            "TRACE".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_TRACE
            "VERBOSE".equals(this, ignoreCase = true) -> Tracker.LOG_LEVEL_TRACE
            else -> null
        }
    }

    /**
     * Optionally and safely retrieve a boolean from json.
     */
    private fun JSONObject.getBooleanOrNull(key: String): Boolean? {
        if (!this.has(key)) {
            return null
        }
        val value = this.opt(key)
        if (value == null || value !is Boolean) {
            return null
        }
        return value
    }

}
