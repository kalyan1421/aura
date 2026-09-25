import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const DRAINED = { x: 0.056, y: 0.588, w: 0.425, h: 0.06 };
const NOTE = { x: 0.05, y: 0.585, w: 0.9, h: 0.14 };
const MINUTE = { x: 0.05, y: 0.626, w: 0.9, h: 0.16 };

const tour: Beat[] = [
  {
    phones: [{ id: "030" }, { id: "031", ring: DRAINED }],
    line: "Pick the closest feeling. There's no wrong answer.",
  },
  {
    phones: [{ id: "033", ring: NOTE }],
    line: "Add a tag or a few words. Only you can read them.",
  },
  {
    phones: [{ id: "036" }, { id: "037", ring: MINUTE }],
    line: "Your Aura answers kindly, and offers a minute for you.",
  },
];

const reel: Beat[] = [
  { phones: [{ id: "031", ring: DRAINED }], line: tour[0].line },
  { phones: [{ id: "033", ring: NOTE }], line: tour[1].line },
  { phones: [{ id: "037", ring: MINUTE }], line: tour[2].line },
];

/** Scene 3: mood grid, details, saved moment. */
export const CheckInScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Check-in"
    headline="Check in in seconds"
    beats={variant === "tour" ? tour : reel}
  />
);
