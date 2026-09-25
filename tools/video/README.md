# Aura product videos

Two silent, captioned product videos for Aura, built with [Remotion](https://www.remotion.dev) from the real app screen captures. This is a self-contained project; it doesn't import anything from the app.

| Composition | Output | Size | Length |
|---|---|---|---|
| `AuraFullTour` | `out/aura-full-tour-16x9.mp4` | 1920×1080, 30 fps | 2:42 (4,866 frames), 14 scenes |
| `Aura60sVertical` | `out/aura-60s-vertical-9x16.mp4` | 1080×1920, 30 fps | 0:56 (1,674 frames), 8 scenes |

Both videos use the same scene components (`src/scenes/*`). The `variant` prop (`"tour"` or `"reel"`) picks the layout, the pacing and which screens a scene shows.

## 1. Get the screens

The screen captures (`docs/design/screens/*.png`) and the avatar art aren't committed here. Copy them in (macOS `sips`, or Python + Pillow elsewhere):

```bash
cd tools/video
npm i
./scripts/copy-screens.sh      # or: npm run screens
```

This writes `public/screens/<id>.png` (for example `030.png`), downscaled to 1,600 px tall, and `public/art/aura.png`. To add a screen, add its id to the list in the script and refer to it by id in a scene.

If the app UI changes, regenerate the captures first:

```bash
cd apps/mobile && flutter test --tags capture --run-skipped test/design_capture
```

Then run the copy script again. `docs/design/screens/INDEX.md` says which file shows which screen and state.

## 2. Preview in Remotion Studio

```bash
npx remotion studio --no-open   # or: npm run dev
```

Open the printed URL. `AuraFullTour` and `Aura60sVertical` are the finished videos. The `Tour-Scenes` and `Reel-Scenes` folders hold each scene on its own.

## 3. Render

```bash
npm run render:tour   # out/aura-full-tour-16x9.mp4
npm run render:reel   # out/aura-60s-vertical-9x16.mp4
npm run render        # both
```

Both renders use H.264 (CRF 21, x264 `slow` preset, `yuv420p`, BT.709), so they play in browsers, WhatsApp, Instagram and QuickTime. Lower `--crf` for higher quality and bigger files; raise it for smaller ones.

To check a few frames as images:

```bash
npx remotion render AuraFullTour out/stills/tour --frames=80,700,2000 --image-format=jpeg
```

## Layout of the code

| Path | What |
|---|---|
| `src/Root.tsx` | Compositions: the two videos plus each scene on its own |
| `src/FullTour.tsx`, `src/Reel.tsx` | Scene order and lengths (`TransitionSeries` with 18-frame fades) |
| `src/components/FeatureScene.tsx` | Shared scene layout: eyebrow, headline, one caption per beat, 1–2 phones per beat, highlight rings |
| `src/components/PhoneFrame.tsx` | The device frame drawn in code around a capture, with timed highlight rings |
| `src/components/Backdrop.tsx` | Night sky: gradient, nebula glows, drifting stars |
| `src/components/Avatar.tsx` | The Aura avatar art with a breathing glow |
| `src/scenes/*.tsx` | One file per scene: its copy, screens and highlight positions |
| `src/theme.ts` | Colours from `docs/design-system.md`, fonts (Inter, Noto Sans Telugu), layout sizes |

A scene is split evenly into beats (use `weight` on a beat to change that). Consecutive beats with the same screens share one set of phones, so only the caption and the ring change. Ring positions are fractions of the capture (`x`, `y`, `w`, `h` from the top left).

If you change a scene's length in `FullTour.tsx` or `Reel.tsx`, update `durationInFrames` for that video in `Root.tsx` too: the total is the sum of the scenes minus 18 frames for each fade.

## Copy rules

- Show only features that exist in the captures. Don't claim health benefits or therapy.
- Say the app is "Coming soon to iPhone and Android". Don't add store badges or "download now".
- Keep captions under about 12 words, and keep each one on screen for at least 2.5 s.
