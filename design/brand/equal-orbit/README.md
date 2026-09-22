# Aura — Equal Orbit

Approval-stage logo package for Aura. These assets are design masters and references; they are **not wired into the iOS or Android launcher icon sets**.

## Brand idea

Four equal orbital segments surround one calm center.

- The four arcs represent Aura's equal emotional quadrants. Every segment has identical radius, length, thickness and endpoint treatment, so none appears more important, damaged or negative.
- The central starlight circle represents the user's private, protected self: feelings can move around it without displacing it.
- Primary tagline: **Every feeling belongs.**

## Master geometry

The mark is constructed on a 512 × 512 coordinate system:

- center: `(256, 256)`
- orbit centerline radius: `150`
- each arc: `70°`
- gap between arcs: `20°`
- arc stroke: `50`, round caps
- center circle radius: `54`
- maximum construction envelope: `81–431` on both axes
- built-in optical padding: `81` units, about 15.8% per side

The app-icon master scales that same geometry exactly 2× onto a 1024 × 1024 full-bleed `skyDeep` square. It intentionally has no baked-in corner radius; Apple and Android apply platform masks.

## Palette

| Role | Position | Hex |
|---|---|---:|
| `skyDeep` | app-icon background | `#05060F` |
| `sunrise` | upper-left arc | `#F3BE67` |
| `rain` | upper-right arc | `#5ACBBE` |
| `moonlight` | lower-left arc | `#AFC3F0` |
| `storm` | lower-right arc | `#AE93FA` |
| `starlight` | protected center | `#F7E6B5` |
| `text` | monochrome light master | `#F2F0FF` |

All masters use exact flat fills/strokes. Do not add gradients, glow, shadows, textures or per-segment size changes to the core mark.

## Usage rules

- **Clear space:** keep at least one arc-stroke width around the visible mark. The supplied square masters already exceed this minimum.
- **Minimum digital size:** 24 × 24px. At 24–32px, use the mark alone and test on the final background; do not add the tagline.
- **Minimum print size:** 8mm square for the mark. Use the monochrome master when production cannot preserve the full palette.
- Keep the mark upright and retain the quadrant positions. Do not rotate, mirror, reorder, recolor, crop or stretch individual arcs.
- On dark brand surfaces, use the full-color or monochrome-light mark. On untested backgrounds, place the app-icon master or verify contrast before use.
- The raster concept images are visual references, not export sources. The SVG files are the deterministic geometry masters.

## Accessibility

- The four colors never communicate a ranked emotional value. In product UI, pair any quadrant reference with text, a glyph and state—not color alone.
- When the mark is adjacent to the visible Aura name, treat it as decorative. When it stands alone as an interactive control, use the accessible name “Aura.”
- Preserve a quiet background around the mark; visual effects that blur the gaps can make the four equal parts unreadable at small sizes.
- The monochrome master preserves the complete silhouette for color-vision-independent and single-color use.
- On `skyDeep`, the full-color elements range from 8.04:1 (Storm) to 16.30:1 (Starlight); the monochrome-light mark is 17.98:1. These checks support clear silhouette recognition but do not make the logo a substitute for text labels in UI.

## Files

### Editable masters

- `masters/equal-orbit-mark-color.svg` — transparent, full-color mark
- `masters/equal-orbit-mark-mono-light.svg` — transparent, monochrome light mark
- `masters/equal-orbit-app-icon.svg` — square `skyDeep` app-icon master

### Concept references

- `references/equal-orbit-brand-board-concept.png`
- `references/equal-orbit-app-icon-concept.png`
- `references/equal-orbit-transparent-mark-concept.png`

### Preview

- `previews/equal-orbit-app-icon-preview.png` — local verification render; not a launcher export

## Approval and production handoff

User approval is required before replacing any launcher icon. After approval, make platform-specific exports from the app-icon SVG, visually inspect them at every required size, and then update the existing iOS and Android icon sets in a separate implementation task. Do not use the generated raster concept as a production launcher asset.
