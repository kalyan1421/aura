import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const NOT_SCORED = { x: 0.06, y: 0.31, w: 0.88, h: 0.07 };

const tour: Beat[] = [
  {
    phones: [{ id: "050", ring: NOT_SCORED }],
    line: "A quiet place just for you. Nothing here is scored.",
  },
  {
    phones: [{ id: "054" }, { id: "055" }],
    line: "Breathe with your Aura: calm, box or 4-7-8.",
  },
  {
    phones: [{ id: "056" }, { id: "057" }],
    line: "Five senses grounding, one gentle step at a time.",
  },
  {
    phones: [{ id: "058", ring: { x: 0.04, y: 0.3, w: 0.92, h: 0.27 } }, { id: "060" }],
    line: "Mix calm sounds, or let a night wind-down fade to silence.",
  },
];

const reel: Beat[] = [
  { phones: [{ id: "050", ring: NOT_SCORED }], line: tour[0].line },
  { phones: [{ id: "055" }], line: "Breathing, grounding and calm sounds to wind down." },
];

/** Scene 5: Sanctuary hub, Breathe, grounding, Sounds. */
export const SanctuaryScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Calm tools"
    headline="Sanctuary"
    beats={variant === "tour" ? tour : reel}
  />
);
