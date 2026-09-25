import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [{ id: "072" }, { id: "073", ring: { x: 0.04, y: 0.668, w: 0.92, h: 0.138 } }],
    line: "Write to future you, and seal it until a date.",
  },
  {
    phones: [{ id: "074", ring: { x: 0.485, y: 0.234, w: 0.41, h: 0.052 } }, { id: "071" }],
    line: "Or for a feeling. It opens the next time you feel it.",
  },
  {
    phones: [{ id: "075" }, { id: "076" }],
    line: "When it opens, past you gets to look after you.",
  },
];

/** Scene 6: time capsules. */
export const FutureYouScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Time capsules"
    headline="Future you"
    beats={tour}
  />
);
