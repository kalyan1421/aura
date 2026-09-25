import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const GLOW = { x: 0.04, y: 0.34, w: 0.92, h: 0.08 };
const STREAK = { x: 0.04, y: 0.242, w: 0.92, h: 0.14 };
const HABITS = { x: 0.04, y: 0.462, w: 0.92, h: 0.228 };

const tour: Beat[] = [
  {
    phones: [{ id: "020" }, { id: "021", ring: GLOW }],
    line: "Your Aura glows a little brighter each time you show up.",
  },
  {
    phones: [{ id: "022", ring: STREAK }],
    line: "Gentle streaks with rest days saved. Nothing is ever taken away.",
  },
  {
    phones: [{ id: "022", ring: HABITS }],
    line: "Small things for today: hydrate, move, sleep on time.",
  },
];

const reel: Beat[] = [
  { phones: [{ id: "021", ring: GLOW }], line: tour[0].line },
  { phones: [{ id: "022", ring: STREAK }], line: tour[1].line },
];

/** Scene 4: Home, the avatar, streaks and habits. */
export const GrowScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Your Aura"
    headline="Your Aura grows"
    beats={variant === "tour" ? tour : reel}
  />
);
