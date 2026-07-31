import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'peepl_merchant_tokens.dart';

enum MerchantShellSection {
  dashboard,
  campaigns,
  calendar,
  account,
}

class MerchantDashboardShell extends StatelessWidget {
  const MerchantDashboardShell({
    super.key,
    required this.body,
    required this.currentSection,
    required this.onSectionChanged,
    required this.onCreatePressed,
    this.onAnalyticsPressed,
    this.header,
  });

  final Widget body;
  final MerchantShellSection currentSection;
  final ValueChanged<MerchantShellSection> onSectionChanged;
  final VoidCallback onCreatePressed;
  final VoidCallback? onAnalyticsPressed;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: PeeplMerchantTokens.background,
      body: Column(
        children: [
          if (header != null) header!,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: PeeplMerchantTokens.shellNavy,
          border: Border(top: BorderSide(color: PeeplMerchantTokens.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              offset: Offset(0, -4),
              blurRadius: 20,
            ),
          ],
        ),
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset - 6 : 0),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    selected: currentSection == MerchantShellSection.dashboard,
                    onTap: () => _select(onSectionChanged, MerchantShellSection.dashboard),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.campaign_rounded,
                    label: 'Campaigns',
                    selected: currentSection == MerchantShellSection.campaigns,
                    onTap: () => _select(onSectionChanged, MerchantShellSection.campaigns),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _CreateActionButton(onPressed: onCreatePressed),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.insights_rounded,
                    label: 'Analytics',
                    selected: false,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onAnalyticsPressed?.call();
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Account',
                    selected: currentSection == MerchantShellSection.account,
                    onTap: () => _select(onSectionChanged, MerchantShellSection.account),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _select(ValueChanged<MerchantShellSection> onChanged, MerchantShellSection s) {
    HapticFeedback.selectionClick();
    onChanged(s);
  }
}

class _CreateActionButton extends StatelessWidget {
  const _CreateActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create Campaign',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PeeplMerchantTokens.accentGradientStart,
                  PeeplMerchantTokens.accentGradientEnd,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.2),
                  blurRadius: 28,
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? PeeplMerchantTokens.accentBlue
        : PeeplMerchantTokens.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: selected
                    ? BoxDecoration(
                        color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MerchantQuickAction extends StatelessWidget {
  const MerchantQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient
                ? const LinearGradient(
                    colors: [
                      PeeplMerchantTokens.accentGradientStart,
                      PeeplMerchantTokens.accentGradientEnd,
                    ],
                  )
                : null,
            color: gradient ? null : PeeplMerchantTokens.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: gradient
                  ? PeeplMerchantTokens.accentBlue.withValues(alpha: 0.4)
                  : PeeplMerchantTokens.glassBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: PeeplMerchantTokens.textPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: PeeplMerchantTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MerchantSectionHeader extends StatelessWidget {
  const MerchantSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: PeeplMerchantTokens.sectionTitle(context)),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
