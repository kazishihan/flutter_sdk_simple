import 'package:flutter/services.dart';
import 'package:flutter_module/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.example.flutter_module/bridge');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows config, host data, and navigates across screens',
      (tester) async {
    String nextPaymentStatus = 'success';

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'getConfig') {
        return <String, dynamic>{'userId': '12345', 'language': 'en'};
      }
      if (call.method == 'openPayment') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        return <String, dynamic>{
          'status': nextPaymentStatus,
          'phoneNumber': args['phoneNumber'],
        };
      }
      return null;
    });

    app.main();
    await tester.pumpAndSettle();
    expect(find.textContaining('User: 12345'), findsOneWidget);

    final data = _channel.codec
        .encodeMethodCall(const MethodCall('receiveData', 'hello'));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_channel.name, data, (_) {});
    await tester.pump();
    expect(find.text('From host: hello'), findsOneWidget);

    // Navigate to SecondScreen and test Pay -> Success -> ThirdScreen.
    await tester.tap(find.text('Go to second screen'));
    await tester.pumpAndSettle();
    expect(find.text('Second screen'), findsOneWidget);

    nextPaymentStatus = 'success';
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Third screen'), findsOneWidget);
    expect(find.text('Payment Success'), findsOneWidget);

    // Go back to SecondScreen, verify Paid status, and test Pay -> Failed -> ThirdScreen.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Second screen'), findsOneWidget);
    expect(find.text('Payment status: Paid'), findsOneWidget);

    nextPaymentStatus = 'failed';
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Payment Failed'), findsOneWidget);
  });
}
