#!/usr/bin/env python3
"""Génère docs/PRIVACY.md (fr) et docs/PRIVACY.en.md (en) depuis Localizable.xcstrings.

La politique de confidentialité n'a qu'une source : les clés `policy.*` du catalogue
de traductions, affichées dans l'app par PrivacyPolicySheet. Ce script en tire les
pages publiques liées depuis App Store Connect.

Usage (depuis la racine du dépôt) :
    python3 scripts/privacy_policy.py          # régénère les deux fichiers
    python3 scripts/privacy_policy.py --check  # échoue si les fichiers ne sont pas à jour
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "AquApp" / "Localizable.xcstrings"
LEGAL_INFO = ROOT / "AquApp" / "Data" / "LegalInfo.swift"

OUTPUTS = {
    "fr": (ROOT / "docs" / "PRIVACY.md", "English version: [PRIVACY.en.md](PRIVACY.en.md)"),
    "en": (ROOT / "docs" / "PRIVACY.en.md", "Version française : [PRIVACY.md](PRIVACY.md)"),
}
GENERATED = "<!-- Fichier généré par scripts/privacy_policy.py depuis AquApp/Localizable.xcstrings : ne pas modifier à la main. -->"


def sections() -> list[str]:
    """Ordre des sections, lu dans LegalInfo.policySections."""
    source = LEGAL_INFO.read_text(encoding="utf-8")
    match = re.search(r"policySections:\s*\[String\]\s*=\s*\[(.*?)\]", source, re.S)
    if not match:
        sys.exit("policySections introuvable dans LegalInfo.swift")
    return re.findall(r'"([a-z_]+)"', match.group(1))


def strings(lang: str) -> dict[str, str]:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    out = {}
    for key, entry in catalog.items():
        if key.startswith("policy."):
            value = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {}).get("value")
            if value is None:
                sys.exit(f"Traduction « {lang} » manquante pour {key}")
            out[key] = value
    return out


def markdown_body(text: str) -> str:
    """Puces « • » de l'app → listes Markdown ; les autres lignes deviennent des paragraphes."""
    blocks, bullets = [], []
    for line in text.split("\n"):
        if line.startswith("• "):
            bullets.append("- " + line[2:])
            continue
        if bullets:
            blocks.append("\n".join(bullets))
            bullets = []
        if line.strip():
            blocks.append(line)
    if bullets:
        blocks.append("\n".join(bullets))
    return "\n\n".join(blocks)


def render(lang: str) -> str:
    s = strings(lang)
    _, switch = OUTPUTS[lang]
    parts = [
        GENERATED,
        "",
        f"# {s['policy.title']} — AquApp",
        "",
        f"*{s['policy.updated']}*",
        "",
        f"> {switch}",
    ]
    for section in sections():
        for suffix in ("title", "body"):
            if f"policy.{section}.{suffix}" not in s:
                sys.exit(f"Clé manquante : policy.{section}.{suffix}")
        parts += ["", "---", "", f"## {s[f'policy.{section}.title']}", "", markdown_body(s[f"policy.{section}.body"])]
    return "\n".join(parts) + "\n"


def main() -> None:
    check = "--check" in sys.argv
    stale = []
    for lang, (path, _) in OUTPUTS.items():
        content = render(lang)
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                stale.append(path.relative_to(ROOT))
        else:
            path.write_text(content, encoding="utf-8")
            print(f"✓ {path.relative_to(ROOT)}")
    if stale:
        sys.exit("Politique à régénérer (python3 scripts/privacy_policy.py) : " + ", ".join(map(str, stale)))


if __name__ == "__main__":
    main()
