import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One channel, shared with the Android and iOS host apps.
///
/// Dart -> host
///   getConfig  -> Map {userId, language}
///   sendEvent  {name, payload} -> bool
/// Host -> Dart
///   receiveData (String)
const MethodChannel _channel = MethodChannel('com.example.flutter_module/bridge');

/// Latest text sent by the host app.
final ValueNotifier<String> _hostMessage = ValueNotifier<String>('No data yet');

/// Config received from the host (null when running standalone).
final ValueNotifier<Map<String, dynamic>?> _config = ValueNotifier<Map<String, dynamic>?>(null);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register before anything else so data from the host is never missed.
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'receiveData') {
      _hostMessage.value = call.arguments?.toString() ?? '';
      return true;
    }
    throw MissingPluginException('Not implemented: ${call.method}');
  });

  _loadConfig();
  runApp(const MyApp());
}

Future<void> _loadConfig() async {
  try {
    final map = await _channel.invokeMapMethod<String, dynamic>('getConfig');
    _config.value = map;
  } on MissingPluginException {
    // Running standalone with `flutter run`: there is no host.
  } on PlatformException catch (e) {
    debugPrint('getConfig failed: ${e.message}');
  }
}

Future<bool> _sendEvent(String name, Map<String, dynamic> payload) async {
  try {
    return await _channel.invokeMethod<bool>(
            'sendEvent', {'name': name, 'payload': payload}) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException catch (e) {
    debugPrint('sendEvent failed: ${e.message}');
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _name = TextEditingController(text: 'Shihan');
  String _status = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _tapEvent() async {
    final ok = await _sendEvent('button_tapped', {'userName': _name.text});
    if (!mounted) return;
    setState(() => _status = ok ? 'Event sent to host' : 'No host attached');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter screen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: _config,
              builder: (_, config, __) => Text(
                config == null
                    ? 'Config: not received'
                    : 'User: ${config['userId']} · Lang: ${config['language']}',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<String>(
              valueListenable: _hostMessage,
              builder: (_, message, __) => Text(
                'From host: $message',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'User name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _tapEvent,
              child: const Text('Send event to host'),
            ),
            const SizedBox(height: 8),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: SystemNavigator.pop,
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
