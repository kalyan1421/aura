import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { colors, SceneProps } from "../theme";

const PILL_HOME = { x: 0.33, y: 0.075, w: 0.415, h: 0.058 };
const PILL_ROOM = { x: 0.568, y: 0.073, w: 0.418, h: 0.06 };
const TELE_MANAS = { x: 0.04, y: 0.37, w: 0.92, h: 0.1 };

const tour: Beat[] = [
  {
    phones: [
      { id: "020", ring: PILL_HOME, ringColor: colors.lantern },
      { id: "085", ring: PILL_ROOM, ringColor: colors.lantern },
    ],
    line: "“I need help now” sits at the top of every screen.",
  },
  {
    phones: [{ id: "152", ring: TELE_MANAS, ringColor: colors.lantern }, { id: "153" }],
    line: "Helplines like Tele-MANAS, and gentle help if a note sounds heavy.",
  },
  {
    phones: [{ id: "017", ring: { x: 0.04, y: 0.43, w: 0.92, h: 0.295 }, ringColor: colors.lantern }],
    line: "Aura is for 13 and older. Younger visitors see helplines instead.",
  },
];

const reel: Beat[] = [
  { phones: [{ id: "020", ring: PILL_HOME, ringColor: colors.lantern }], line: tour[0].line },
  {
    phones: [{ id: "152", ring: TELE_MANAS, ringColor: colors.lantern }],
    line: "Real helplines, like Tele-MANAS in India, one tap away.",
  },
];

/** Scene 11: the help pill, support sheet, helplines, under-13 protection. */
export const SafetyScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Safety"
    headline="Safety, one tap away"
    beats={variant === "tour" ? tour : reel}
  />
);
