from pathlib import Path

# Fix step3
p = Path("lib/screens/merchant/merchant_setup_step3_screen.dart")
t = p.read_text(encoding="utf-8-sig")
t = t.replace("color: PeeplMerchantTokens.textPrimary,\n        borderRadius: BorderRadius.circular(16),\n        boxShadow:", "decoration: PeeplMerchantTokens.cardDecoration(),\n        // was boxShadow:")
# simpler fix for _whiteCard
old_card = """  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PeeplMerchantTokens.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }"""
new_card = """  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: PeeplMerchantTokens.cardDecoration(),
      child: child,
    );
  }"""
if old_card not in t:
    old_card = old_card.replace("PeeplMerchantTokens.textPrimary", "Colors.white")
t = t.replace(old_card, new_card)
for wrong in [
    "const Icon(Icons.campaign_outlined, color: PeeplMerchantTokens.shellNavy, size: 20)",
    "color: PeeplMerchantTokens.shellNavy,\n                ),\n              ),\n            ],\n          ),\n          const Divider(height: 24),",
]:
    pass
t = t.replace("const Icon(Icons.campaign_outlined, color: PeeplMerchantTokens.shellNavy, size: 20)",
              "const Icon(Icons.campaign_outlined, color: PeeplMerchantTokens.accentBlue, size: 20)")
# Order summary title and total - replace shellNavy with accentBlue in summary section only
t = t.replace("""                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PeeplMerchantTokens.shellNavy,
                ),""",
            """                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PeeplMerchantTokens.accentBlue,
                ),""")
t = t.replace("""                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: PeeplMerchantTokens.shellNavy,
                ),""",
            """                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: PeeplMerchantTokens.accentBlue,
                ),""")
t = t.replace("""          const Icon(
            Icons.info_outline,
            color: PeeplMerchantTokens.shellNavy,""",
            """          const Icon(
            Icons.info_outline,
            color: PeeplMerchantTokens.accentBlue,""")
p.write_text(t, encoding="utf-8")

# Fix how_to_advertise from clean git content
p2 = Path("lib/screens/merchant/how_to_advertise_screen.dart")
h = p2.read_text(encoding="utf-8-sig")
if not h.strip().startswith("import"):
    h = p2.read_text(encoding="utf-8")
h = h.replace("import 'package:flutter/material.dart';",
              "import 'package:flutter/material.dart';\n\nimport '../../widgets/merchant/peepl_merchant_tokens.dart';")
h = h.replace("  static const Color _blue = Color(0xFF1565C0);\n  static const Color _blueDark = Color(0xFF0D47A1);\n\n", "")
replacements = [
    ("_blueDark", "PeeplMerchantTokens.accentGradientEnd"),
    ("_blue", "PeeplMerchantTokens.accentBlue"),
    ("backgroundColor: Colors.grey[50],", "backgroundColor: PeeplMerchantTokens.background,"),
    ("color: Colors.black87,", "color: PeeplMerchantTokens.textPrimary,"),
    ("Colors.grey.shade200", "PeeplMerchantTokens.border"),
    ("Colors.grey.shade600", "PeeplMerchantTokens.textSecondary"),
    ("Colors.grey.shade700", "PeeplMerchantTokens.textSecondary"),
]
for a,b in replacements:
    h = h.replace(a,b)
# pricing cards white -> card (two occurrences in tier and how it works)
h = h.replace(
    """      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tier.isPopular ? PeeplMerchantTokens.accentBlue : PeeplMerchantTokens.border,""",
    """      decoration: BoxDecoration(
        color: PeeplMerchantTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tier.isPopular ? PeeplMerchantTokens.accentBlue : PeeplMerchantTokens.border,""",
)
h = h.replace(
    """      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PeeplMerchantTokens.border),""",
    """      decoration: BoxDecoration(
        color: PeeplMerchantTokens.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PeeplMerchantTokens.border),""",
)
h = h.replace(
    """          const Text(
            'Advertise on Peepl',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),""",
    """          const Text(
            'Advertise on Peepl',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PeeplMerchantTokens.textPrimary,
            ),
          ),""",
)
h = h.replace(
    """          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),""",
    """          IconButton(
            icon: const Icon(Icons.arrow_back, color: PeeplMerchantTokens.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),""",
)
h = h.replace(
    "builder: (ctx) => AlertDialog(\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),",
    "builder: (ctx) => AlertDialog(\n        backgroundColor: PeeplMerchantTokens.card,\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),",
)
p2.write_text(h, encoding="utf-8")
print("fixed step3 and how_to_advertise")
