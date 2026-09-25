import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [{ id: "010" }, { id: "011", ring: { x: 0.05, y: 0.272, w: 0.9, h: 0.15 } }],
    line: "Your notes are encrypted. Nobody sees how you feel unless you share.",
  },
  {
    phones: [{ id: "010" }, { id: "011", ring: { x: 0.05, y: 0.428, w: 0.9, h: 0.148 } }],
    line: "Wellness support, not therapy. It never diagnoses or treats anything.",
  },
];

/** Scene 2: the onboarding trust screen. */
export const PrivacyScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Privacy"
    headline="Private by default"
    beats={tour}
  />
);
