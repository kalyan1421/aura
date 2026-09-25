import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadTelugu } from "@remotion/google-fonts/NotoSansTelugu";

// Colours from docs/design-system.md (AuraColors in the app).
export const colors = {
  sky: "#0A0C1D",
  deep: "#05060F",
  skyHigh: "#10132A",
  surface: "#151935",
  outline: "#2C3264",
  text: "#F2F0FF",
  soft: "#BDB9E0",
  muted: "#9591BD",
  accent: "#BBAAFF",
  lavender: "#C9BFFF",
  lantern: "#F6C1A4",
  starlight: "#F7E6B5",
  storm: "#AE93FA",
  rain: "#5ACBBE",
  moonlight: "#AFC3F0",
  sunrise: "#F3BE67",
} as const;

export const { fontFamily: inter } = loadInter("normal", {
  weights: ["300", "400", "500", "600"],
  subsets: ["latin"],
});

export const { fontFamily: notoTelugu } = loadTelugu("normal", {
  weights: ["500", "600"],
  subsets: ["telugu"],
});

/** Every scene is used by both videos. The variant picks copy, pacing and layout. */
export type Variant = "tour" | "reel";

export type SceneProps = {
  variant: Variant;
  /** Standalone scene previews draw their own night sky; inside a video the sky is shared. */
  withBackdrop: boolean;
};

/** App screen captures are 1179 x 2556 (iPhone 15, DPR 3). */
export const SCREEN_ASPECT = 1179 / 2556;

export const screen = (id: string) => `screens/${id}.png`;

// Layout numbers per variant. Text sizes follow the video-layout rules
// (84 px headline / 44 px supporting text at 1080 px on the short side).
export const layout = {
  tour: {
    width: 1920,
    height: 1080,
    phoneHeight: 918, // 85% of the frame height
    textLeft: 130,
    textWidth: 660,
    phoneRegionLeft: 850,
    phoneRegionWidth: 940,
    eyebrowSize: 30,
    headlineSize: 92,
    lineSize: 46,
  },
  reel: {
    width: 1080,
    height: 1920,
    phoneHeight: 1170,
    textLeft: 80,
    textWidth: 920,
    phoneRegionLeft: 80,
    phoneRegionWidth: 920,
    eyebrowSize: 34,
    headlineSize: 96,
    lineSize: 52,
  },
} as const;

/** Transition between scenes inside a video (frames at 30 fps). */
export const SCENE_FADE = 18;
