import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [{ id: "111" }, { id: "112" }],
    line: "Every check-in becomes a star in your own sky.",
  },
  {
    phones: [{ id: "113" }, { id: "117" }],
    line: "Patterns from your own tags, worked out on your phone.",
  },
  {
    phones: [{ id: "118" }, { id: "122" }],
    line: "Your month in stars, and a look back. Only you see it.",
  },
];

const reel: Beat[] = [
  { phones: [{ id: "111" }], line: tour[0].line },
  { phones: [{ id: "118" }], line: "Worked out on your phone. Only you see it." },
];

/** Scene 9: Insights (Aura Sky). */
export const SkyScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Insights"
    headline="Aura Sky"
    beats={variant === "tour" ? tour : reel}
  />
);
