import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [{ id: "106" }, { id: "107" }],
    line: "Breath Ripples: three quiet minutes with others. No words, no score.",
  },
  {
    phones: [{ id: "100" }, { id: "101" }],
    line: "Quiet Together: study, read or rest alongside others.",
  },
  {
    phones: [{ id: "098" }],
    line: "Wind down together in Lantern Hour, with one shared sound.",
  },
];

/** Scene 8: Breath Ripples, Quiet Together, wind-down together. */
export const TogetherScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Together"
    headline="Breathe and sit together"
    beats={tour}
  />
);
