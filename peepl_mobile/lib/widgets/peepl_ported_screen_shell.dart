import 'package:flutter/material.dart';

/// Blue header + white body, matching Peepl RN / Flutter main apps.
const Color kPeeplPortedBlue = Color(0xFF1565C0);

/// Shared layout for ported React Native screens.
class PeeplPortedScreenShell extends StatelessWidget {
  const PeeplPortedScreenShell({
    super.key,
    required this.title,
    this.description,
    this.children = const [],
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPeeplPortedBlue,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Coming soon',
                          style: TextStyle(
                            color: kPeeplPortedBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (description != null) ...[
                        Text(
                          description!,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      ...children,
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
