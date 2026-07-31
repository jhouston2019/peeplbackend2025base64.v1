import 'dart:io';
import '../theme/peepl_app_tokens.dart';

import 'package:flutter/material.dart';

class NoConnectionScreen extends StatefulWidget {
  const NoConnectionScreen({super.key});

  @override
  State<NoConnectionScreen> createState() => _NoConnectionScreenState();
}

class _NoConnectionScreenState extends State<NoConnectionScreen> {
  bool _checking = false;

  Future<void> _tryAgain() async {
    setState(() => _checking = true);

    bool connected = false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      connected = false;
    } catch (_) {
      connected = false;
    }

    if (!mounted) return;

    if (connected) {
      Navigator.pop(context);
    } else {
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still no connection. Check your signal and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            Container(
              color: PeeplAppTokens.background,
              width: double.infinity,
              padding: EdgeInsets.only(top: topPadding + 16, bottom: 20),
              child: const Center(
                child: Text(
                  'peepl',
                  style: TextStyle(
                    color: PeeplAppTokens.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📵', style: TextStyle(fontSize: 72)),
                      const SizedBox(height: 24),
                      const Text(
                        'No Connection',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Peepl needs internet to show live crowd data. Check your Wi-Fi or cellular signal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: PeeplAppTokens.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checking ? null : _tryAgain,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PeeplAppTokens.background,
                            foregroundColor: PeeplAppTokens.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _checking
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: PeeplAppTokens.textPrimary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Try Again',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
