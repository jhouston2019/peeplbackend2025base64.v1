import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantBillingCard extends StatelessWidget {
  const MerchantBillingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.amount,
    this.trailing,
    this.icon,
    this.badge,
    this.onTap,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String? amount;
  final Widget? trailing;
  final IconData? icon;
  final String? badge;
  final VoidCallback? onTap;
  final List<MerchantBillingAction> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PeeplMerchantTokens.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: PeeplMerchantTokens.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PeeplMerchantTokens.accentBlue.withValues(alpha: 0.3),
                            PeeplMerchantTokens.cardElevated,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: PeeplMerchantTokens.accentBlue),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: PeeplMerchantTokens.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: PeeplMerchantTokens.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badge!,
                                  style: const TextStyle(
                                    color: PeeplMerchantTokens.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: PeeplMerchantTokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (amount != null)
                    Text(
                      amount!,
                      style: const TextStyle(
                        color: PeeplMerchantTokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions
                      .map(
                        (a) => TextButton.icon(
                          onPressed: a.onTap,
                          icon: Icon(a.icon, size: 16),
                          label: Text(a.label),
                          style: TextButton.styleFrom(
                            foregroundColor: PeeplMerchantTokens.accentBlue,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MerchantBillingAction {
  const MerchantBillingAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
