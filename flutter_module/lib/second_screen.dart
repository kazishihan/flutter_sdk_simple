import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'third_screen.dart';

class PaymentResult {
  const PaymentResult({
    required this.status,
    required this.phoneNumber,
  });

  final String status;
  final String phoneNumber;
}

class SecondScreen extends StatefulWidget {
  const SecondScreen({
    super.key,
    required this.config,
    required this.hostMessage,
    required this.onSendEvent,
    required this.onOpenPayment,
  });

  final ValueListenable<Map<String, dynamic>?> config;
  final ValueListenable<String> hostMessage;
  final Future<bool> Function(String name, Map<String, dynamic> payload)
      onSendEvent;
  final Future<PaymentResult?> Function(String phoneNumber) onOpenPayment;

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9\s\-()]{6,20}$');

  final TextEditingController _phoneController =
      TextEditingController(text: '+8801700000000');

  String _status = '';
  String? _paymentStatus;
  bool _isPaying = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendSecondScreenEvent() async {
    final ok = await widget.onSendEvent(
      'second_screen_tapped',
      {'screen': 'second'},
    );
    if (!mounted) return;
    setState(
      () => _status = ok ? 'Event sent from second screen' : 'No host attached',
    );
  }

  Future<void> _tapPay() async {
    if (_isPaying) return;
    final phone = _phoneController.text.trim();
    if (!_phoneRegex.hasMatch(phone)) {
      setState(() => _status = 'Enter a valid phone number (6-20 digits)');
      return;
    }

    setState(() {
      _isPaying = true;
      _status = '';
    });

    final result = await widget.onOpenPayment(phone);
    if (!mounted) return;

    setState(() => _isPaying = false);

    if (result == null) {
      setState(() => _status = 'Unable to open native payment');
      return;
    }

    if (result.status == 'success' || result.status == 'failed') {
      setState(() {
        _paymentStatus = result.status == 'success' ? 'Paid' : null;
      });
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ThirdScreen(
            config: widget.config,
            hostMessage: widget.hostMessage,
            onSendEvent: widget.onSendEvent,
            paymentStatus: result.status,
            phoneNumber: result.phoneNumber,
          ),
        ),
      );
    } else {
      setState(() => _status = 'Payment cancelled');
    }
  }

  void _openThirdScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThirdScreen(
          config: widget.config,
          hostMessage: widget.hostMessage,
          onSendEvent: widget.onSendEvent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second screen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to the second Flutter screen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if (_paymentStatus != null) ...[
              const SizedBox(height: 12),
              Text(
                'Payment status: $_paymentStatus',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
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
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isPaying ? null : _tapPay,
              child: Text(_isPaying ? 'Processing...' : 'Pay'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendSecondScreenEvent,
              child: const Text('Send event from second screen'),
            ),
            const SizedBox(height: 8),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openThirdScreen,
              child: const Text('Go to third screen'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
