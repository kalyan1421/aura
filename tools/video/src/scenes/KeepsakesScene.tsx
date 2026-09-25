import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [{ id: "125" }],
    line: "Small moments, kept. Only you can see them.",
  },
  {
    phones: [{ id: "126", ring: { x: 0.04, y: 0.77, w: 0.92, h: 0.06 } }, { id: "127" }],
    line: "Share a moment, never your mood.",
  },
  {
    phones: [{ id: "128" }, { id: "129" }],
    line: "Cards show your Aura and the moment. Never moods, notes or name.",
  },
];

/** Scene 10: keepsakes and share cards. */
export const KeepsakesScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Keepsakes"
    headline="Keepsakes & share cards"
    beats={tour}
  />
);
