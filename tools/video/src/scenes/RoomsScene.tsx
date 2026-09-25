import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const LANTERN = { x: 0.04, y: 0.378, w: 0.92, h: 0.142 };
const REFLECTION = { x: 0.03, y: 0.296, w: 0.94, h: 0.21 };
const REPORT_BLOCK_MUTE = { x: 0.04, y: 0.59, w: 0.92, h: 0.07 };

const tour: Beat[] = [
  {
    phones: [{ id: "080" }, { id: "085", ring: LANTERN }],
    line: "Small rooms of people who feel the same, right now.",
  },
  {
    phones: [{ id: "086" }, { id: "087", ring: REFLECTION }],
    line: "Short, moderated reflections, answered only with warm gestures.",
  },
  {
    phones: [{ id: "089", ring: REPORT_BLOCK_MUTE }],
    line: "A fresh name in every room. No messages, no DMs.",
  },
];

const reel: Beat[] = [
  { phones: [{ id: "085", ring: LANTERN }], line: tour[0].line },
  { phones: [{ id: "087", ring: REFLECTION }], line: tour[1].line },
  { phones: [{ id: "089", ring: REPORT_BLOCK_MUTE }], line: tour[2].line },
];

/** Scene 7: mood rooms, Lantern Hour, gestures, member safety. */
export const RoomsScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Rooms"
    headline="Rooms, gently"
    beats={variant === "tour" ? tour : reel}
  />
);
