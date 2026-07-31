import 'package:flutter/material.dart';

import '../theme/peepl_app_tokens.dart';

/// Navy header + dark body shell for secondary Peepl screens.
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
      backgroundColor: PeeplAppTokens.shellNavy,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: PeeplAppTokens.textPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Image.asset(
                    'assets/icon/icon.png',
                    height: 32,
                    semanticLabel: 'Peepl',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: PeeplAppTokens.textPrimary,
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
                decoration: PeeplAppTokens.shellBodyDecoration(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: PeeplAppTokens.accentBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PeeplAppTokens.border),
                        ),
                        child: const Text(
                          'Coming soon',
                          style: TextStyle(
                            color: PeeplAppTokens.accentBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (description != null) ...[
                        Text(
                          description!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: PeeplAppTokens.textSecondary,
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
