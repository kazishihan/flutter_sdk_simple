import 'package:flutter/services.dart';
import 'package:flutter_module/main.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.example.flutter_module/bridge');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows config from the host and host data', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'getConfig') {
        return <String, dynamic>{'userId': '12345', 'language': 'en'};
      }
      return null;
    });

    main(); // registers the handler and loads the config
    await tester.pumpAndSettle();
    expect(find.textContaining('User: 12345'), findsOneWidget);

    final data = _channel.codec
        .encodeMethodCall(const MethodCall('receiveData', 'hello'));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_channel.name, data, (_) {});
    await tester.pump();
    expect(find.text('From host: hello'), findsOneWidget);
  });
}
