import 'package:flutter/material.dart';

import 'peepl_merchant_tokens.dart';

class MerchantGlassTextField extends StatelessWidget {
  const MerchantGlassTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.prefixIcon,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      style: const TextStyle(color: PeeplMerchantTokens.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelStyle: const TextStyle(color: PeeplMerchantTokens.textSecondary),
        hintStyle: const TextStyle(color: PeeplMerchantTokens.textMuted),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: PeeplMerchantTokens.textMuted, size: 20)
            : null,
        filled: true,
        fillColor: PeeplMerchantTokens.glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.danger),
        ),
        errorStyle: const TextStyle(color: PeeplMerchantTokens.danger),
      ),
    );
  }
}

class MerchantGlassDropdown extends StatelessWidget {
  const MerchantGlassDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      enabled: enabled,
      width: MediaQuery.sizeOf(context).width - 40,
      initialSelection: value,
      label: Text(label),
      hintText: 'Select $label',
      dropdownMenuEntries: items
          .map((e) => DropdownMenuEntry<String>(value: e, label: e))
          .toList(),
      onSelected: onChanged,
      textStyle: const TextStyle(color: PeeplMerchantTokens.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PeeplMerchantTokens.glassFill,
        labelStyle: const TextStyle(color: PeeplMerchantTokens.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: PeeplMerchantTokens.glassBorder),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(PeeplMerchantTokens.cardElevated),
      ),
    );
  }
}

class MerchantSectionCard extends StatelessWidget {
  const MerchantSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: PeeplMerchantTokens.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PeeplMerchantTokens.sectionTitle(context)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
