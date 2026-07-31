import re
from pathlib import Path

ROOT = Path("lib/screens")

TEXT_FIXES = [
    (r"color:\s*Color\(0xFF666666\)", "color: PeeplAppTokens.textSecondary"),
    (r"color:\s*Color\(0xFFCCCCCC\)", "color: PeeplAppTokens.textMuted"),
    (r"color:\s*Colors\.grey\.shade700", "color: PeeplAppTokens.textSecondary"),
    (r"color:\s*Colors\.grey\.shade800", "color: PeeplAppTokens.textSecondary"),
    (r"color:\s*Colors\.grey\.shade400", "color: PeeplAppTokens.textMuted"),
    (r"color:\s*Colors\.black87", "color: PeeplAppTokens.textPrimary"),
    (r"color:\s*Colors\.black\b", "color: PeeplAppTokens.textPrimary"),
    (r"fillColor:\s*Colors\.white\b", "fillColor: PeeplAppTokens.searchField"),
    (r"const Color\(0xFF1565C0\)", "PeeplAppTokens.accentBlue"),
    (r"Color\(0xFF1565C0\)", "PeeplAppTokens.accentBlue"),
    (r"Colors\.grey\[300\]", "PeeplAppTokens.cardElevated"),
    (r"Colors\.grey\.shade200", "PeeplAppTokens.cardElevated"),
    (r"Colors\.grey\.shade50", "PeeplAppTokens.card"),
    (r"color: isEven \? Colors\.white : Colors\.grey\.shade50", "color: isEven ? PeeplAppTokens.card : PeeplAppTokens.cardElevated"),
]

IMPORT = "import '../theme/peepl_app_tokens.dart';"
IMPORT2 = "import '../../theme/peepl_app_tokens.dart';"


def add_import(content: str, path: Path) -> str:
    if "peepl_app_tokens.dart" in content:
        return content
    depth = len(path.relative_to(Path("lib")).parts) - 1
    imp = IMPORT2 if depth >= 2 else IMPORT
    m = re.search(r"^(import .+;\n)+", content, re.M)
    if m:
        return content[: m.end()] + imp + "\n" + content[m.end() :]
    return imp + "\n" + content


def main() -> None:
    changed = []
    for path in sorted(Path("lib").rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        original = text
        for pat, rep in TEXT_FIXES:
            text = re.sub(pat, rep, text)
        if "PeeplAppTokens" in text and "peepl_app_tokens.dart" not in text:
            text = add_import(text, path)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed.append(str(path))
    print(f"Pass 3: {len(changed)} files")
    for f in changed:
        print(f"  {f}")


if __name__ == "__main__":
    main()
