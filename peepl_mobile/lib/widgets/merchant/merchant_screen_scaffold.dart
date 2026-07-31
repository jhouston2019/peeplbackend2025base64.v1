import 'package:flutter/material.dart';

import 'merchant_dashboard_header.dart';
import 'merchant_skeleton.dart';
import 'peepl_merchant_tokens.dart';

/// Shared navy scaffold for standalone merchant routes (analytics, billing, etc.).
class MerchantScreenScaffold extends StatelessWidget {
  const MerchantScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions = const [],
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PeeplMerchantTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 16),
            decoration: PeeplMerchantTokens.heroGradient(),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: PeeplMerchantTokens.textPrimary),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: PeeplMerchantTokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          Expanded(
            child: Padding(padding: padding, child: body),
          ),
        ],
      ),
    );
  }
}

class MerchantLoadingView extends StatelessWidget {
  const MerchantLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MerchantDashboardSkeleton();
  }
}

class MerchantInputDecoration {
  MerchantInputDecoration._();

  static InputDecoration field({
    required String hint,
    String? label,
    IconData? prefixIcon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: PeeplMerchantTokens.textSecondary),
        hintStyle: const TextStyle(color: PeeplMerchantTokens.textMuted),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: PeeplMerchantTokens.textMuted)
            : null,
        filled: true,
        fillColor: PeeplMerchantTokens.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: PeeplMerchantTokens.accentBlue,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class MerchantPrimaryButton extends StatelessWidget {
  const MerchantPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? const LinearGradient(
                  colors: [
                    PeeplMerchantTokens.accentGradientStart,
                    PeeplMerchantTokens.accentGradientEnd,
                  ],
                )
              : null,
          color: onPressed == null ? PeeplMerchantTokens.glassFill : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onPressed != null ? PeeplMerchantTokens.premiumShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String merchantGreetingForHeader() => merchantTimeGreeting();
