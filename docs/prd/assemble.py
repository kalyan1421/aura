#!/usr/bin/env python3
"""Assemble docs/prd/sections/*.md into docs/PRD.md with numbered sections and a TOC."""
import re
from pathlib import Path

ROOT = Path(__file__).parent
SECTIONS = ROOT / "sections"
OUT = ROOT.parent / "PRD.md"

ORDER = [
    "01-overview.md",
    "02-goals-metrics.md",
    "03-personas.md",
    "05-user-journey.md",
    "04-user-stories.md",
    "06a-features-core.md",
    "06b-features-social.md",
    "06c-features-platform.md",
    "11-competitive.md",
    "09-technical-constraints.md",
    "10-data-model.md",
    "12-notifications.md",
    "13-analytics.md",
    "14-states.md",
    "15-permissions.md",
    "16-offline.md",
    "17-accessibility.md",
    "18-localization.md",
    "19-admin-console.md",
    "20-timeline.md",
    "21-open-questions.md",
    "22-out-of-scope.md",
]


def slug(text: str) -> str:
    s = text.lower()
    s = re.sub(r"[^\w\s-]", "", s)
    return re.sub(r"\s", "-", s.strip())


def main() -> None:
    header = (SECTIONS / "00-header.md").read_text().rstrip() + "\n"
    body, toc = [], []
    for n, name in enumerate(ORDER, start=1):
        path = SECTIONS / name
        if not path.exists():
            raise SystemExit(f"missing section: {name}")
        text = path.read_text().strip()
        lines = text.splitlines()
        if not lines[0].startswith("## "):
            raise SystemExit(f"{name}: first line must be '## Title'")
        title = lines[0][3:].strip()
        numbered = f"{n}. {title}"
        lines[0] = f"## {numbered}"
        toc.append(f"{n}. [{title}](#{slug(numbered)})")
        body.append("\n".join(lines))
    footer = "\n---\n\n*Confidential — Asan Innovators © 2026 | Building Beyond Boundaries*\n"
    doc = header + "\n## Contents\n\n" + "\n".join(toc) + "\n\n---\n\n" + "\n\n---\n\n".join(body) + "\n" + footer
    OUT.write_text(doc)
    words = len(re.findall(r"\S+", doc))
    print(f"wrote {OUT} ({words:,} words, {len(ORDER)} sections)")


if __name__ == "__main__":
    main()
