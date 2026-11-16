import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ThirdScreen extends StatefulWidget {
  const ThirdScreen({
    super.key,
    required this.config,
    required this.hostMessage,
    required this.onSendEvent,
    this.paymentStatus,
    this.phoneNumber,
  });

  final ValueListenable<Map<String, dynamic>?> config;
  final ValueListenable<String> hostMessage;
  final Future<bool> Function(String name, Map<String, dynamic> payload)
      onSendEvent;
  final String? paymentStatus;
  final String? phoneNumber;

  @override
  State<ThirdScreen> createState() => _ThirdScreenState();
}

class _ThirdScreenState extends State<ThirdScreen> {
  String _status = '';

  Future<void> _sendThirdScreenEvent() async {
    final ok = await widget.onSendEvent(
      'third_screen_tapped',
      {
        'screen': 'third',
        if (widget.paymentStatus != null) 'paymentStatus': widget.paymentStatus,
      },
    );
    if (!mounted) return;
    setState(
      () => _status = ok ? 'Event sent from third screen' : 'No host attached',
    );
  }

  Widget _buildHeader() {
    switch (widget.paymentStatus) {
      case 'success':
        return Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 8),
            const Text(
              'Payment Success',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Phone: ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      case 'failed':
        return Column(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 56),
            const SizedBox(height: 8),
            const Text(
              'Payment Failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Phone: ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      default:
        return const Text(
          'Welcome to the third Flutter screen',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Third screen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: widget.config,
              builder: (_, config, _) => Text(
                config == null
                    ? 'Config: not received'
                    : 'User: ${config['userId']} · Lang: ${config['language']}',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: widget.hostMessage,
              builder: (_, message, _) => Text(
                'From host: $message',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sendThirdScreenEvent,
              child: const Text('Send event from third screen'),
            ),
            const SizedBox(height: 8),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
