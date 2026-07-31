import 'dart:io';
import '../../theme/peepl_app_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/peepl_home_tokens.dart';
import 'peepl_merchant_tokens.dart';

class MerchantOfferEditor extends StatelessWidget {
  const MerchantOfferEditor({
    super.key,
    required this.controller,
    required this.maxLength,
    this.headlineController,
    this.advertiserName,
    this.imageFile,
    this.ctaText = 'Get Deal',
    this.onPickImage,
    this.onAiImprove,
    this.suggestedCopies = const [],
    this.expirationLabel,
    this.couponCode,
    this.onCouponChanged,
    this.onSuggestionTap,
  });

  final TextEditingController controller;
  final TextEditingController? headlineController;
  final int maxLength;
  final String? advertiserName;
  final File? imageFile;
  final String ctaText;
  final VoidCallback? onPickImage;
  final VoidCallback? onAiImprove;
  final List<String> suggestedCopies;
  final String? expirationLabel;
  final String? couponCode;
  final ValueChanged<String>? onCouponChanged;
  final ValueChanged<String>? onSuggestionTap;

  static const _defaultSuggestions = [
    '2-for-1 Drinks',
    '\$5 Margaritas',
    'Free Appetizer',
    'Half Price Wings',
    'Kids Eat Free',
    'Late Night Special',
  ];

  @override
  Widget build(BuildContext context) {
    final count = controller.text.characters.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Offer Builder', style: PeeplMerchantTokens.sectionTitle(context)),
        const SizedBox(height: 16),
        Container(
          decoration: PeeplMerchantTokens.cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Live Preview',
                style: TextStyle(
                  color: PeeplMerchantTokens.textMuted.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              _FeedPreview(
                headline: headlineController?.text.trim().isNotEmpty == true
                    ? headlineController!.text.trim()
                    : 'Your headline',
                body: controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : 'Your offer copy appears here as you type…',
                advertiserName: advertiserName,
                imageFile: imageFile,
                ctaText: ctaText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (headlineController != null) ...[
          _FieldLabel('Headline'),
          const SizedBox(height: 8),
          _StyledField(
            controller: headlineController!,
            hint: 'Catchy headline',
            maxLength: 50,
          ),
          const SizedBox(height: 16),
        ],
        _FieldLabel('Promotion copy'),
        const SizedBox(height: 8),
        _StyledField(
          controller: controller,
          hint: 'Describe your offer…',
          maxLength: maxLength,
          maxLines: 6,
          minLines: 5,
        ),
        const SizedBox(height: 12),
        Text(
          'Suggested offers',
          style: TextStyle(
            color: PeeplMerchantTokens.textSecondary.withValues(alpha: 0.95),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (suggestedCopies.isEmpty ? _defaultSuggestions : suggestedCopies)
              .map((copy) {
            return ActionChip(
              label: Text(copy, style: const TextStyle(fontSize: 12)),
              backgroundColor: PeeplMerchantTokens.glassFill,
              side: const BorderSide(color: PeeplMerchantTokens.glassBorder),
              onPressed: () {
                HapticFeedback.selectionClick();
                if (onSuggestionTap != null) {
                  onSuggestionTap!(copy);
                } else {
                  controller.text = copy;
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '$count / $maxLength',
              style: const TextStyle(
                color: PeeplMerchantTokens.textMuted,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (onAiImprove != null)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAiImprove!();
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('AI Improve'),
                style: TextButton.styleFrom(
                  foregroundColor: PeeplMerchantTokens.accentBlue,
                ),
              ),
          ],
        ),
        if (expirationLabel != null) ...[
          const SizedBox(height: 16),
          _MetaRow(icon: Icons.timer_outlined, label: expirationLabel!),
        ],
        if (onPickImage != null) ...[
          const SizedBox(height: 16),
          _ImagePickerTile(imageFile: imageFile, onTap: onPickImage!),
        ],
        if (onCouponChanged != null && couponCode != null) ...[
          const SizedBox(height: 16),
          _FieldLabel('Coupon code (optional)'),
          const SizedBox(height: 8),
          _StyledField(
            controller: TextEditingController(text: couponCode),
            hint: 'SAVE20',
            onChanged: onCouponChanged,
          ),
        ],
      ],
    );
  }
}

class _FeedPreview extends StatelessWidget {
  const _FeedPreview({
    required this.headline,
    required this.body,
    this.advertiserName,
    this.imageFile,
    required this.ctaText,
  });

  final String headline;
  final String body;
  final String? advertiserName;
  final File? imageFile;
  final String ctaText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PeeplMerchantTokens.shellNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PeeplHomeTokens.sponsoredBorder),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageFile != null
                  ? Image.file(imageFile!, fit: BoxFit.cover)
                  : ColoredBox(
                      color: PeeplMerchantTokens.cardElevated,
                      child: const Icon(
                        Icons.image_outlined,
                        color: PeeplMerchantTokens.textMuted,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (advertiserName != null && advertiserName!.isNotEmpty)
                  Text(
                    advertiserName!,
                    style: const TextStyle(
                      color: PeeplMerchantTokens.textMuted,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  headline,
                  style: const TextStyle(
                    color: PeeplMerchantTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: PeeplMerchantTokens.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  PeeplMerchantTokens.accentGradientStart,
                  PeeplMerchantTokens.accentGradientEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              ctaText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: PeeplMerchantTokens.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.minLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final int minLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      style: const TextStyle(color: PeeplMerchantTokens.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: PeeplMerchantTokens.textMuted),
        filled: true,
        fillColor: PeeplMerchantTokens.glassFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.accentBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
        counterStyle: const TextStyle(color: PeeplMerchantTokens.textMuted),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PeeplMerchantTokens.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: PeeplMerchantTokens.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({this.imageFile, required this.onTap});

  final File? imageFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PeeplMerchantTokens.glassFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PeeplMerchantTokens.glassBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(imageFile!, fit: BoxFit.cover),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PeeplAppTokens.textPrimary.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Change',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: PeeplMerchantTokens.textMuted, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Add promotion image',
                      style: TextStyle(color: PeeplMerchantTokens.textSecondary),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
