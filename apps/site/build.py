#!/usr/bin/env python3
"""Builds apps/site/public/**/index.html from pages/*.html and site.json.

Contact details live only in site.json. Edit them there, run
`python3 apps/site/build.py`, then deploy with `firebase deploy --only hosting`.
Page fragments use {{key}} placeholders from site.json.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
SITE = json.loads((ROOT / "site.json").read_text())

PAGES = {
    "index": ("", "Aura: a quiet place to notice how you feel"),
    "privacy": ("privacy/", "Privacy policy · Aura"),
    "terms": ("terms/", "Terms of use · Aura"),
    "support": ("support/", "Support and Grievance Officer · Aura"),
    "delete-account": ("delete-account/", "Delete your Aura account"),
    "child-safety": ("child-safety/", "Child safety standards · Aura"),
}

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="Aura by AKVega: a private mood check-in with gentle rooms, calm tools and time capsules.">
<meta name="theme-color" content="#0a0c1d">
<link rel="stylesheet" href="/style.css">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
</head>
<body>
<header class="top">
  <a class="brand" href="/">Aura</a>
  <a class="help" href="/support/#help-now">&#9829; I need help now</a>
</header>
<main>
"""

FOOT = """</main>
<footer>
  <nav>
    <a href="/privacy/">Privacy policy</a>
    <a href="/terms/">Terms of use</a>
    <a href="/support/">Support &amp; Grievance Officer</a>
    <a href="/delete-account/">Delete your account</a>
    <a href="/child-safety/">Child safety</a>
  </nav>
  <div>Aura is published by {publisher}. Aura is not a medical device or an emergency service.</div>
</footer>
</body>
</html>
"""


def fill(text: str) -> str:
    for k, v in SITE.items():
        text = text.replace("{{" + k + "}}", v)
    assert "{{" not in text, "unknown placeholder in page"
    return text


def main() -> None:
    public = ROOT / "public"
    for name, (path, title) in PAGES.items():
        body = fill((ROOT / "pages" / f"{name}.html").read_text())
        out = public / path / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(HEAD.format(title=title) + body + FOOT.format(publisher=SITE["publisher"]))
        print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
