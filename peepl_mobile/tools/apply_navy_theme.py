import re
from pathlib import Path

ROOT = Path("lib")
SKIP = {
    "peepl_app_tokens.dart",
    "peepl_home_tokens.dart",
    "peepl_detail_tokens.dart",
    "peepl_merchant_tokens.dart",
}


def rel_import(path: Path) -> str:
    depth = len(path.relative_to(ROOT).parts) - 1
    prefix = "../" * depth
    return f"import '{prefix}theme/peepl_app_tokens.dart';"


def add_import(content: str, imp: str) -> str:
    if "peepl_app_tokens.dart" in content:
        return content
    m = re.search(r"^(import .+;\n)+", content, re.M)
    if m:
        return content[: m.end()] + imp + "\n" + content[m.end() :]
    return imp + "\n" + content


def transform(content: str) -> tuple[str, bool]:
    original = content
    content = content.replace("kPeeplPortedBlue", "PeeplAppTokens.shellNavy")

    replacements = [
        (r"backgroundColor:\s*const Color\(0xFF1565C0\)", "backgroundColor: PeeplAppTokens.shellNavy"),
        (r"backgroundColor:\s*Color\(0xFF1565C0\)", "backgroundColor: PeeplAppTokens.shellNavy"),
        (r"backgroundColor:\s*const Color\(0xFF0D47A1\)", "backgroundColor: PeeplAppTokens.shellNavy"),
        (r"backgroundColor:\s*Color\(0xFF0D47A1\)", "backgroundColor: PeeplAppTokens.shellNavy"),
        (r"backgroundColor:\s*const Color\(0xFF2244EE\)", "backgroundColor: PeeplAppTokens.background"),
        (r"backgroundColor:\s*Color\(0xFF2244EE\)", "backgroundColor: PeeplAppTokens.background"),
        (r"backgroundColor:\s*Colors\.white\b", "backgroundColor: PeeplAppTokens.background"),
        (r"color:\s*Colors\.white\b(?!\.)", "color: PeeplAppTokens.textPrimary"),
        (r"foregroundColor:\s*Colors\.white\b", "foregroundColor: PeeplAppTokens.textPrimary"),
        (r"const Color\(0xFF1565C0\)", "PeeplAppTokens.accentBlue"),
        (r"Color\(0xFF1565C0\)", "PeeplAppTokens.accentBlue"),
        (r"const Color\(0xFF0D47A1\)", "PeeplAppTokens.shellNavy"),
        (r"Color\(0xFF0D47A1\)", "PeeplAppTokens.shellNavy"),
        (r"const Color\(0xFF1976D2\)", "PeeplAppTokens.accentBlue"),
        (r"Color\(0xFF1976D2\)", "PeeplAppTokens.accentBlue"),
        (r"const Color\(0xFF2244EE\)", "PeeplAppTokens.background"),
        (r"Color\(0xFF2244EE\)", "PeeplAppTokens.background"),
        (
            r"Color\(\(ad\['accentColor'\] as int\?\) \?\? 0xFF1565C0\)",
            "Color((ad['accentColor'] as int?) ?? 0xFF2E6CFF)",
        ),
    ]
    for pat, rep in replacements:
        content = re.sub(pat, rep, content)

    content = re.sub(r"color:\s*Colors\.grey\[600\]", "color: PeeplAppTokens.textSecondary", content)
    content = re.sub(r"color:\s*Colors\.grey\[500\]", "color: PeeplAppTokens.textMuted", content)
    content = re.sub(r"color:\s*Colors\.grey\[800\]", "color: PeeplAppTokens.textSecondary", content)
    content = re.sub(r"color:\s*Colors\.black54", "color: PeeplAppTokens.textMuted", content)
    content = re.sub(r"color:\s*Colors\.black38", "color: PeeplAppTokens.textMuted", content)
    content = re.sub(r"Colors\.grey\.shade600", "PeeplAppTokens.textSecondary", content)

    return content, content != original


def main() -> None:
    changed_files: list[str] = []
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name in SKIP:
            continue
        text = path.read_text(encoding="utf-8")
        if not re.search(
            r"0xFF1565C0|0xFF0D47A1|0xFF1976D2|0xFF2244EE|kPeeplPortedBlue|backgroundColor:\s*Colors\.white|color:\s*Colors\.grey",
            text,
        ):
            continue
        new_text, _ = transform(text)
        if "PeeplAppTokens" in new_text:
            new_text = add_import(new_text, rel_import(path))
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed_files.append(str(path))

    print(f"Updated {len(changed_files)} files:")
    for f in changed_files:
        print(f"  {f}")


if __name__ == "__main__":
    main()
