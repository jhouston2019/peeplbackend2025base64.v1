import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MerchantAccountNumberScreen extends StatelessWidget {
  const MerchantAccountNumberScreen({super.key});

  String get _accountNumber {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'XXXXX';
    final suffix = uid.length >= 5
        ? uid.substring(uid.length - 5).toUpperCase()
        : uid.toUpperCase().padLeft(5, 'X');
    return 'MRC-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.28)),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '🏢',
                          style: TextStyle(fontSize: 72),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Account Created!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your account number is:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _accountNumber,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                              letterSpacing: 5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Save this number for support enquiries.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () =>
                                Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/merchant_portal',
                              (_) => false,
                            ),
                            child: const Text(
                              'Go to Dashboard →',
                              style: TextStyle(
                                fontSize: 17,
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
      ),
    );
  }
}
