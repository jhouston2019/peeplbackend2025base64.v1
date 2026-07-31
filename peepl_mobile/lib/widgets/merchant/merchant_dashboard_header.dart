import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantDashboardHeader extends StatelessWidget {
  const MerchantDashboardHeader({
    super.key,
    required this.businessName,
    this.logoUrl,
    this.merchantId,
    this.isVerified = false,
    this.subscriptionLabel,
    this.onBack,
    this.onSettings,
  });

  final String businessName;
  final String? logoUrl;
  final String? merchantId;
  final bool isVerified;
  final String? subscriptionLabel;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: PeeplMerchantTokens.heroGradient(),
      child: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: PeeplMerchantTokens.glassHeroOverlay())),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null)
                      _GlassCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: onBack!,
                      ),
                    if (onBack != null) const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Merchant Center',
                        style: TextStyle(
                          color: PeeplMerchantTokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    if (onSettings != null)
                      _GlassCircleButton(
                        icon: Icons.settings_rounded,
                        onTap: onSettings!,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BusinessLogo(logoUrl: logoUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: PeeplMerchantTokens.heroTitle(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (merchantId != null && merchantId!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'ID · ${merchantId!.length > 8 ? '${merchantId!.substring(0, 8)}…' : merchantId}',
                              style: PeeplMerchantTokens.caption(context),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (isVerified) const _VerifiedBadge(),
                              if (subscriptionLabel != null)
                                _PremiumPill(
                                  label: subscriptionLabel!,
                                  color: PeeplMerchantTokens.accentBlue,
                                  icon: Icons.workspace_premium_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessLogo extends StatelessWidget {
  const _BusinessLogo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PeeplMerchantTokens.glassBorder, width: 1.5),
        boxShadow: PeeplMerchantTokens.premiumShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        color: PeeplMerchantTokens.cardElevated,
        child: const Icon(
          Icons.storefront_rounded,
          color: PeeplMerchantTokens.textSecondary,
          size: PeeplMerchantTokens.iconXl,
        ),
      );
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return _PremiumPill(
      label: 'Verified Merchant',
      color: PeeplMerchantTokens.success,
      icon: Icons.verified_rounded,
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: PeeplMerchantTokens.iconSm),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplMerchantTokens.glassFill,
      shape: const CircleBorder(
        side: BorderSide(color: PeeplMerchantTokens.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: PeeplMerchantTokens.textPrimary, size: PeeplMerchantTokens.iconMd),
        ),
      ),
    );
  }
}

String merchantTimeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}
