import React from "react";
import { Beat, FeatureScene } from "../components/FeatureScene";
import { SceneProps } from "../theme";

const tour: Beat[] = [
  {
    phones: [
      { id: "021", label: "English" },
      { id: "200", label: "తెలుగు", labelTelugu: true },
    ],
    line: "Aura speaks English, Telugu and Tenglish.",
  },
  {
    phones: [
      { id: "030", label: "English" },
      { id: "201", label: "తెలుగు", labelTelugu: true },
    ],
    line: "Check in with the words you actually use.",
  },
  {
    phones: [
      { id: "050", label: "English" },
      { id: "203", label: "తెలుగు", labelTelugu: true },
    ],
    line: "Hindi and Hinglish are on the way.",
  },
];

/** Scene 13: English and Telugu side by side. */
export const LanguageScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => (
  <FeatureScene
    variant={variant}
    withBackdrop={withBackdrop}
    eyebrow="Languages"
    headline="Your language"
    beats={tour}
  />
);
