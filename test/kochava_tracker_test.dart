import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kochava_tracker/kochava_tracker.dart';

void main() {
  const MethodChannel channel = MethodChannel('kochava_tracker');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {});

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getSdkVersion', () async {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      expect(methodCall.method, "getVersion");
      return 'AndroidTracker 3.0.0 (Flutter 1.0.0)';
    });

    expect(await KochavaTracker.instance.getVersion,
        'AndroidTracker 3.0.0 (Flutter 1.0.0)');
  });
}
