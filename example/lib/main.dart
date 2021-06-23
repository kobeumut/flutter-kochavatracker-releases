import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kochava_tracker/kochava_tracker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

// See the full documentation on usage https://support.kochava.com/sdk-integration/flutter-sdk-integration/
class _MyAppState extends State<MyApp> {
  String _deviceId = 'N/A';
  String _version = 'N/A';

  @override
  void initState() {
    super.initState();
    startSdk();
  }

  // Start the Kochava SDK and retrieve the version and device ID.
  Future<void> startSdk() async {
    // Start the Kochava SDK.
    var config = {
      KochavaTracker.PARAM_ANDROID_APP_GUID_STRING_KEY: 'YOUR_ANDROID_APP_GUID',
      KochavaTracker.PARAM_IOS_APP_GUID_STRING_KEY: 'YOUR_IOS_APP_GUID',
      KochavaTracker.PARAM_LOG_LEVEL_ENUM_KEY:
          KochavaTracker.LOG_LEVEL_ENUM_TRACE_VALUE,
    };
    KochavaTracker.instance.configure(config);

    // Retrieve the Kochava Device ID.
    String deviceId = await KochavaTracker.instance.getDeviceId;

    // Retrieve the Kochava SDK Version.
    String version = await KochavaTracker.instance.getVersion;

    if (!mounted) return;

    setState(() {
      _deviceId = deviceId;
      _version = version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Kochava Plugin Sample'),
        ),
        body: Center(
            child: ListView(
          children: [
            Text('SDK Version: $_version\n'),
            Text('DeviceId: $_deviceId\n'),
          ],
        )),
      ),
    );
  }
}
