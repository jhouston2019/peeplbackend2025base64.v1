import re
from pathlib import Path

# --- merchant_setup_step3_screen.dart ---
p = Path("lib/screens/merchant/merchant_setup_step3_screen.dart")
text = p.read_text(encoding="utf-8-sig")
if "peepl_merchant_tokens" not in text:
    text = text.replace(
        "import 'merchant_step_indicator.dart';",
        "import '../../widgets/merchant/peepl_merchant_tokens.dart';\nimport 'merchant_step_indicator.dart';",
    )
text = re.sub(
    r"  static const Color _blue = Color\(0xFF1565C0\);\n\n",
    "",
    text,
)
text = text.replace("backgroundColor: const Color(0xFFF5F7FA),", "backgroundColor: PeeplMerchantTokens.background,")
text = text.replace("backgroundColor: _blue,", "backgroundColor: PeeplMerchantTokens.shellNavy,")
text = text.replace("color: _blue,", "color: PeeplMerchantTokens.shellNavy,")
text = text.replace("foregroundColor: Colors.white,", "foregroundColor: PeeplMerchantTokens.textPrimary,")
text = text.replace("const Icon(Icons.campaign_outlined, color: _blue, size: 20)", "const Icon(Icons.campaign_outlined, color: PeeplMerchantTokens.accentBlue, size: 20)")
text = text.replace("color: _blue,", "color: PeeplMerchantTokens.accentBlue,")
text = text.replace("side: BorderSide(color: Colors.grey.shade300),", "side: const BorderSide(color: PeeplMerchantTokens.border),")
text = text.replace("color: const Color(0xFFE3F2FD),", "color: PeeplMerchantTokens.cardElevated,")
text = text.replace("color: _blue.withValues(alpha: 0.25),", "color: PeeplMerchantTokens.accentBlue.withValues(alpha: 0.25),")
text = text.replace("const Icon(\n            Icons.info_outline,\n            color: _blue,", "const Icon(\n            Icons.info_outline,\n            color: PeeplMerchantTokens.accentBlue,")
text = text.replace("color: Colors.blueGrey[700],", "color: PeeplMerchantTokens.textSecondary,")
text = text.replace("backgroundColor: const Color(0xFF2E7D32),", "backgroundColor: PeeplMerchantTokens.success,")
text = text.replace("color: Colors.white,", "color: PeeplMerchantTokens.textPrimary,")
text = text.replace(
    """      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),""",
    """      decoration: PeeplMerchantTokens.cardDecoration(),""",
)
text = text.replace("color: Colors.grey[600],", "color: PeeplMerchantTokens.textSecondary,")
text = text.replace(
    """            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),""",
    """            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PeeplMerchantTokens.textPrimary,
            ),""",
)
text = text.replace(
    """                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),""",
    """                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PeeplMerchantTokens.textPrimary,
                ),""",
)
text = text.replace("_blue", "PeeplMerchantTokens.accentBlue")
# fix double replacements
text = text.replace("PeeplMerchantTokens.accentBlue.withValues", "PeeplMerchantTokens.accentBlue.withValues")
text = text.replace("color: PeeplMerchantTokens.accentBlue,\n                  fontSize: 22", "color: PeeplMerchantTokens.accentBlue,\n                  fontSize: 22")
p.write_text(text, encoding="utf-8")

# --- how_to_advertise_screen.dart ---
p2 = Path("lib/screens/merchant/how_to_advertise_screen.dart")
h = p2.read_text(encoding="utf-8-sig")
h = h.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n\nimport '../../widgets/merchant/peepl_merchant_tokens.dart';")
h = re.sub(r"  static const Color _blue = Color\(0xFF1565C0\);\n  static const Color _blueDark = Color\(0xFF0D47A1\);\n\n", "", h)
h = h.replace("_blueDark", "PeeplMerchantTokens.accentGradientEnd")
h = h.replace("_blue", "PeeplMerchantTokens.accentBlue")
h = h.replace("backgroundColor: Colors.grey[50],", "backgroundColor: PeeplMerchantTokens.background,")
h = h.replace("color: Colors.white,", "color: PeeplMerchantTokens.textPrimary,")  # careful - hero should stay white - user said white text on gradient can stay
# Revert hero and badge white text - user wanted white on gradient to stay
h = h.replace(
    """            style: TextStyle(
              color: PeeplMerchantTokens.textPrimary,
              fontSize: 22,""",
    """            style: TextStyle(
              color: Colors.white,
              fontSize: 22,""",
)
h = h.replace(
    """            style: TextStyle(
              color: PeeplMerchantTokens.textPrimary.withValues(alpha: 0.88),""",
    """            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),""",
)
h = h.replace(
    """                  style: TextStyle(
                    color: PeeplMerchantTokens.textPrimary,
                    fontSize: 10,""",
    """                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,""",
)
h = h.replace("foregroundColor: PeeplMerchantTokens.textPrimary,", "foregroundColor: Colors.white,")
h = h.replace("color: Colors.white,\n        borderRadius: BorderRadius.circular(16),\n        border: Border.all(\n          color: tier.isPopular ? PeeplMerchantTokens.accentBlue : Colors.grey.shade200,", "color: PeeplMerchantTokens.card,\n        borderRadius: BorderRadius.circular(16),\n        border: Border.all(\n          color: tier.isPopular ? PeeplMerchantTokens.accentBlue : PeeplMerchantTokens.border,")
h = h.replace("color: Colors.black87,", "color: PeeplMerchantTokens.textPrimary,")
h = h.replace("Colors.grey.shade200", "PeeplMerchantTokens.border")
h = h.replace("Colors.grey.shade600", "PeeplMerchantTokens.textSecondary")
h = h.replace("Colors.grey.shade700", "PeeplMerchantTokens.textSecondary")
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
# top bar title readable on navy
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
# dialog navy styling
h = h.replace(
    "builder: (ctx) => AlertDialog(\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),",
    "builder: (ctx) => AlertDialog(\n        backgroundColor: PeeplMerchantTokens.card,\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),",
)
p2.write_text(h, encoding="utf-8")

# explore_screen
pe = Path("lib/screens/explore_screen.dart")
ex = pe.read_text(encoding="utf-8")
ex = ex.replace("Icon(Icons.search_off, size: 64, color: Colors.grey[400]),", "Icon(Icons.search_off, size: 64, color: PeeplAppTokens.textMuted),")
pe.write_text(ex, encoding="utf-8")

# test
pt = Path("test/home_feed_viewport_test.dart")
t = pt.read_text(encoding="utf-8")
t = t.replace("0xFF1565C0", "0xFF2E6CFF")
pt.write_text(t, encoding="utf-8")

print("applied all patches")
