/// A lightweight and easy to integrate SDK, providing first-class integration with Kochava’s installation attribution and analytics platform.
///
/// Getting Started: https://support.kochava.com/sdk-integration/flutter-sdk-integration
library kochava_tracker;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Attribution callback handler used to retrieve the attribution results from Kochava servers.
typedef KochavaTrackerAttributionCallback = void Function(String? attribution);

/// Deeplink callback handler used to retrieve a deeplink destination when using enhanced deeplinking.
typedef KochavaTrackerDeeplinkCallback = void Function(
    KochavaTrackerDeeplink deeplink);

/// Deeplink object returned when using enhanced deeplinking.
class KochavaTrackerDeeplink {
  final String? destination;
  final Map<String, dynamic>? raw;

  KochavaTrackerDeeplink(this.destination, this.raw);
}

/// Kochava Tracker SDK.
class KochavaTracker {
  // Singleton
  static final KochavaTracker _instance = KochavaTracker._internal();

  /// Returns the singleton instance of the [KochavaTracker].
  static KochavaTracker get instance => _instance;

  // Configuration Parameter Keys.
  static const PARAM_ANDROID_APP_GUID_STRING_KEY = "androidAppGUIDString";
  static const PARAM_IOS_APP_GUID_STRING_KEY = "iOSAppGUIDString";
  static const PARAM_PARTNER_NAME_STRING_KEY = "partnerName";
  static const PARAM_APP_LIMIT_AD_TRACKING_BOOL_KEY = "limitAdTracking";
  static const PARAM_IDENTITY_LINK_MAP_OBJECT_KEY = "identityLink";
  static const PARAM_LOG_LEVEL_ENUM_KEY = "logLevel";
  static const PARAM_RETRIEVE_ATTRIBUTION_BOOL_KEY = "retrieveAttribution";
  static const PARAM_SLEEP_BOOL_KEY = "sleepBool";
  static const PARAM_CUSTOM_MAP_OBJECT_KEY = "custom";
  static const PARAM_INSTANT_APP_GUID_STRING_KEY = "instant_app_id";
  static const PARAM_CONTAINER_APP_GROUP_IDENTIFIER_STRING_KEY =
      "container_app_group_identifier";
  static const PARAM_APP_TRACKING_TRANSPARENCY_ENABLED_BOOL_KEY = "att_enabled";
  static const PARAM_APP_TRACKING_TRANSPARENCY_WAIT_TIME_DOUBLE_KEY =
      "att_wait_time";
  static const PARAM_APP_TRACKING_TRANSPARENCY_AUTO_REQUEST_BOOL_KEY =
      "att_auto_request";

  // Log Level Values.
  static const LOG_LEVEL_ENUM_NONE_VALUE = "never";
  static const LOG_LEVEL_ENUM_ERROR_VALUE = "error";
  static const LOG_LEVEL_ENUM_WARN_VALUE = "warn";
  static const LOG_LEVEL_ENUM_INFO_VALUE = "info";
  static const LOG_LEVEL_ENUM_DEBUG_VALUE = "debug";
  static const LOG_LEVEL_ENUM_TRACE_VALUE = "trace";

  // Standard Event Types.
  static const EVENT_TYPE_ACHIEVEMENT_STRING_KEY = "Achievement";
  static const EVENT_TYPE_ADD_TO_CART_STRING_KEY = "Add to Cart";
  static const EVENT_TYPE_ADD_TO_WISH_LIST_STRING_KEY = "Add to Wish List";
  static const EVENT_TYPE_CHECKOUT_START_STRING_KEY = "Checkout Start";
  static const EVENT_TYPE_LEVEL_COMPLETE_STRING_KEY = "Level Complete";
  static const EVENT_TYPE_PURCHASE_STRING_KEY = "Purchase";
  static const EVENT_TYPE_RATING_STRING_KEY = "Rating";
  static const EVENT_TYPE_REGISTRATION_COMPLETE_STRING_KEY =
      "Registration Complete";
  static const EVENT_TYPE_SEARCH_STRING_KEY = "Search";
  static const EVENT_TYPE_TUTORIAL_COMPLETE_STRING_KEY = "Tutorial Complete";
  static const EVENT_TYPE_VIEW_STRING_KEY = "View";
  static const EVENT_TYPE_AD_VIEW_STRING_KEY = "Ad View";
  static const EVENT_TYPE_PUSH_RECEIVED_STRING_KEY = "Push Received";
  static const EVENT_TYPE_PUSH_OPENED_STRING_KEY = "Push Opened";
  static const EVENT_TYPE_CONSENT_GRANTED_STRING_KEY = "Consent Granted";
  static const EVENT_TYPE_DEEP_LINK_STRING_KEY = "_Deeplink";
  static const EVENT_TYPE_AD_CLICK_STRING_KEY = "Ad Click";
  static const EVENT_TYPE_START_TRIAL_STRING_KEY = "Start Trial";
  static const EVENT_TYPE_SUBSCRIBE_STRING_KEY = "Subscribe";

  // State
  final MethodChannel _channel = const MethodChannel('kochava_tracker');
  KochavaTrackerAttributionCallback? _attributionCallback;
  Map<String, KochavaTrackerDeeplinkCallback> _deeplinkCallbacks = Map();
  int _deeplinkCallbackCount = 0;

  // Private Constructor
  KochavaTracker._internal() {
    _channel.setMethodCallHandler(this._methodCallHandler);
  }

  // Internal handler for method calls (callbacks) from the native layer.
  Future<void> _methodCallHandler(MethodCall call) async {
    try {
      switch (call.method) {
        case "attributionCallback":
          if (_attributionCallback != null) {
            _attributionCallback!.call(call.arguments);
          }
          break;
        case "deeplinkCallback":
          Map<String, dynamic> response = json.decode(call.arguments);
          // Build the deeplink from the returned arguments.
          String? id = response["id"];
          Map<String, dynamic> deeplink = response["deeplink"];
          String? destination = deeplink["destination"];
          Map<String, dynamic>? raw = deeplink["raw"];

          // Lookup the callback handler and call it.
          if (_deeplinkCallbacks.containsKey(id)) {
            KochavaTrackerDeeplinkCallback callback = _deeplinkCallbacks[id!]!;
            callback.call(KochavaTrackerDeeplink(destination, raw));
            _deeplinkCallbacks.remove(id);
          }
          break;
      }
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: _methodCallHandler: $e");
    }
  }

  /// Configures and starts the SDK.
  void configure(Map<String, dynamic>? input) {
    try {
      if (input == null) {
        throw FormatException("Null parameter");
      }
      // Inject wrapper info
      Map<String, String> wrapper = Map();
      wrapper['name'] = "Flutter";
      wrapper['version'] = "1.1.2";
      wrapper['build_date'] = "2021-01-25T19:22:56Z";
      _channel.invokeMethod("executeAdvancedInstruction",
          {"key": "wrapper", "value": json.encode(wrapper)});

      // Start the SDK
      _channel.invokeMethod('configure', input);
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: configure: $e");
    }
  }

  /// Sets a listener for the Attribution callback event. Setting to null will remove an existing listener.
  void setAttributionListener(
      KochavaTrackerAttributionCallback attributionCallback) {
    _attributionCallback = attributionCallback;
  }

  /// Returns the attribution results as stringified json or an empty string if not available.
  Future<String?> get getAttribution async {
    try {
      return await _channel.invokeMethod('getAttribution');
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: getAttribution: $e");
      return Future.value("");
    }
  }

  /// Returns the unique device id string set by Kochava or an empty string if the SDK is not started.
  Future<String?> get getDeviceId async {
    try {
      return await _channel.invokeMethod('getDeviceId');
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: getDeviceId: $e");
      return Future.value("");
    }
  }

  /// Retrieves the SDK version in the following format "AndroidTracker x.y.z (Flutter a.b.c)" or "iOSTracker x.y.z (Flutter a.b.c)".
  Future<String?> get getVersion async {
    try {
      return await _channel.invokeMethod('getVersion');
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: getVersion: $e");
      return Future.value("");
    }
  }

  /// Sets whether advertising identifier tracking should be limited.
  void setAppLimitAdTracking(bool? appLimitAdTracking) {
    try {
      if (appLimitAdTracking == null) {
        throw FormatException("Null parameter");
      }
      _channel.invokeMethod("setAppLimitAdTracking", appLimitAdTracking);
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: setAppLimitAdTracking: $e");
    }
  }

  /// Sets an Identity Link object containing string key value pairs.
  void setIdentityLink(Map<String, String>? identityLink) {
    try {
      if (identityLink == null) {
        throw FormatException("Null parameter");
      }
      _channel.invokeMethod("setIdentityLink", identityLink);
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: setIdentityLink: $e");
    }
  }

  /// Sets the sleep state of the SDK.
  void setSleep(bool? sleep) {
    try {
      if (sleep == null) {
        throw FormatException("Null parameter");
      }
      _channel.invokeMethod("setSleep", sleep);
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: setSleep: $e");
    }
  }

  /// Returns the sleep state of the SDK.
  Future<bool?> get getSleep async {
    try {
      return await _channel.invokeMethod('getSleep');
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: getSleep: $e");
      return Future.value(false);
    }
  }

  /// Adds a new push token.
  void addPushToken(String? token) {
    try {
      if (token == null) {
        throw FormatException("Null parameter");
      }
      _channel.invokeMethod("addPushToken", token);
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: addPushToken: $e");
    }
  }

  /// Removes an existing Push Token.
  void removePushToken(String? token) {
    try {
      if (token == null) {
        throw FormatException("Null parameter");
      }
      _channel.invokeMethod("removePushToken", token);
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: removePushToken: $e");
    }
  }

  /// Sends an event using an event name and optional event data.
  void sendEventString(String? name, [String? info]) {
    try {
      if (name == null) {
        throw FormatException("Null name parameter");
      }
      _channel.invokeMethod("sendEventString", {"name": name, "info": info});
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: sendEventString: $e");
    }
  }

  /// Sends an event using an event name and event data.
  void sendEventMapObject(String? name, [Map<String, dynamic>? info]) {
    try {
      if (name == null) {
        throw FormatException("Null name parameter");
      }
      _channel.invokeMethod("sendEventMapObject", {"name": name, "info": info});
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: sendEventMapObject: $e");
    }
  }

  /// (iOS Only) Send an event using an event name, event data, and Apple Store receipt.
  void sendEventAppleAppStoreReceipt(String? name, Map<String, dynamic> info,
      String appStoreReceiptBase64EncodedString) {
    try {
      if (name == null) {
        throw FormatException("Null name parameter");
      }
      _channel.invokeMethod("sendEventAppleAppStoreReceipt", {
        "name": name,
        "info": info,
        "appStoreReceiptBase64EncodedString": appStoreReceiptBase64EncodedString
      });
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: sendEventAppleAppStoreReceipt: $e");
    }
  }

  /// (Android Only) Send an event using an event name, event data, and Google Play Store receipt.
  void sendEventGooglePlayReceipt(String? name, Map<String, dynamic> info,
      String receiptData, String receiptDataSignature) {
    try {
      if (name == null) {
        throw FormatException("Null name parameter");
      }
      _channel.invokeMethod("sendEventGooglePlayReceipt", {
        "name": name,
        "info": info,
        "receiptData": receiptData,
        "receiptDataSignature": receiptDataSignature
      });
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: sendEventGooglePlayReceipt: $e");
    }
  }

  /// Sends an event containing a deeplink uri and optional source application.
  void sendDeepLink(String openURLString, [String? sourceApplicationString]) {
    try {
      _channel.invokeMethod("sendDeepLink", {
        "openURLString": openURLString,
        "sourceApplicationString": sourceApplicationString
      });
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: sendDeepLink: $e");
    }
  }

  /// Process an enhanced deeplink using the default 10 second timeout.
  void processDeeplink(
      String path, KochavaTrackerDeeplinkCallback deeplinkCallback) {
    processDeeplinkWithOverrideTimeout(path, 10.0, deeplinkCallback);
  }

  /// Process an enhanced deeplink using the specified override timeout in seconds.
  void processDeeplinkWithOverrideTimeout(String? path, double? timeout,
      KochavaTrackerDeeplinkCallback? deeplinkCallback) {
    try {
      if (deeplinkCallback == null) {
        throw FormatException("Null deeplinkCallback parameter");
      }
      _deeplinkCallbackCount += 1;
      String id = _deeplinkCallbackCount.toString();
      _deeplinkCallbacks[id] = deeplinkCallback;
      _channel.invokeMethod("processDeeplink",
          {"id": id, "path": path ?? "", "timeout": timeout ?? 10.0});
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: processDeeplink: $e");
    }
  }

  /// (iOS) Request App Tracking Transparency Authorization.
  void enableAppTrackingTransparencyAutoRequest() {
    try {
      _channel.invokeMethod("enableAppTrackingTransparencyAutoRequest");
    } catch (e) {
      print(
          "Kochava/Tracker/Flutter Error: enableAppTrackingTransparencyAutoRequest: $e");
    }
  }

  /// Use only if directed to by your Client Success Manager.
  void executeAdvancedInstruction(String? key, String? value) {
    try {
      if (key == null || value == null) {
        throw FormatException("Invalid parameters");
      }
      if (key == "INTERNAL_UNCONFIGURE") {
        _deeplinkCallbacks.clear();
        _deeplinkCallbackCount = 0;
        _attributionCallback = null;
      }
      _channel.invokeMethod(
          "executeAdvancedInstruction", {"key": key, "value": value});
    } catch (e) {
      print("Kochava/Tracker/Flutter Error: executeAdvancedInstruction: $e");
    }
  }
}
