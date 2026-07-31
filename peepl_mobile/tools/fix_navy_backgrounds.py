import re
from pathlib import Path

ROOT = Path("lib")

SHELL_PATTERN = re.compile(
    r"decoration:\s*const BoxDecoration\(\s*"
    r"color:\s*PeeplAppTokens\.textPrimary,\s*"
    r"borderRadius:\s*BorderRadius\.only\(\s*"
    r"topLeft:\s*Radius\.circular\(\d+\),\s*"
    r"topRight:\s*Radius\.circular\(\d+\),\s*"
    r"\),\s*"
    r"\)",
    re.M,
)

SHELL_PATTERN2 = re.compile(
    r"decoration:\s*BoxDecoration\(\s*"
    r"color:\s*PeeplAppTokens\.textPrimary,\s*"
    r"borderRadius:\s*BorderRadius\.only\(\s*"
    r"topLeft:\s*Radius\.circular\(\d+\),\s*"
    r"topRight:\s*Radius\.circular\(\d+\),\s*"
    r"\),\s*"
    r"\)",
    re.M,
)

VERTICAL_SHEET = re.compile(
    r"decoration:\s*const BoxDecoration\(\s*"
    r"color:\s*PeeplAppTokens\.textPrimary,\s*"
    r"borderRadius:\s*BorderRadius\.vertical\(top: Radius\.circular\(\d+\)\),\s*"
    r"\)",
    re.M,
)

CARD_CIRCULAR = re.compile(
    r"decoration:\s*BoxDecoration\(\s*"
    r"color:\s*PeeplAppTokens\.textPrimary,\s*"
    r"borderRadius:\s*BorderRadius\.circular\((\d+)\),\s*"
    r"\)",
    re.M,
)


def main() -> None:
    changed = []
    for path in sorted(ROOT.rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        original = text
        text = SHELL_PATTERN.sub("decoration: PeeplAppTokens.shellBodyDecoration()", text)
        text = SHELL_PATTERN2.sub("decoration: PeeplAppTokens.shellBodyDecoration()", text)
        text = VERTICAL_SHEET.sub("decoration: PeeplAppTokens.shellBodyDecoration()", text)
        text = CARD_CIRCULAR.sub(
            r"decoration: PeeplAppTokens.cardDecoration(color: PeeplAppTokens.card)",
            text,
        )
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed.append(str(path))
    print(f"Fixed {len(changed)} files")
    for f in changed:
        print(f"  {f}")


if __name__ == "__main__":
    main()
