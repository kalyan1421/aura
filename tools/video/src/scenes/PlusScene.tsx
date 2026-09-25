import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [{ id: "130", ring: { x: 0.03, y: 0.212, w: 0.94, h: 0.186 } }, { id: "132" }],
    line: "More of what you already have: deeper insights, sounds and skies.",
  },
  {
    phones: [{ id: "130", ring: { x: 0.03, y: 0.41, w: 0.94, h: 0.13 } }, { id: "132" }],
    line: "Everything that helps you feel better stays free.",
  },
];

/** Scene 12: Aura Plus paywall and sky themes. */
export const PlusScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Optional"
    headline="Aura Plus"
    beats={tour}
  />
);
