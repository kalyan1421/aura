import React from "react";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { AbsoluteFill } from "remotion";
import { Backdrop } from "./components/Backdrop";
import { CheckInScene } from "./scenes/CheckInScene";
import { ClosingScene } from "./scenes/ClosingScene";
import { GrowScene } from "./scenes/GrowScene";
import { RoomsScene } from "./scenes/RoomsScene";
import { SafetyScene } from "./scenes/SafetyScene";
import { SanctuaryScene } from "./scenes/SanctuaryScene";
import { SkyScene } from "./scenes/SkyScene";
import { TitleScene } from "./scenes/TitleScene";
import { SCENE_FADE } from "./theme";

const Fade = () => (
  <TransitionSeries.Transition
    presentation={fade({ shouldFadeOutExitingScene: true })}
    timing={linearTiming({ durationInFrames: SCENE_FADE })}
  />
);

/**
 * "Aura in 60 seconds", 1080x1920, 30 fps, for WhatsApp / Instagram / Reels.
 * Uses the same scene components as the full tour with variant="reel".
 */
export const Reel: React.FC = () => (
  <AbsoluteFill>
    <Backdrop />
    <TransitionSeries>
      <TransitionSeries.Sequence name="Title" durationInFrames={150}>
        <TitleScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Check in" durationInFrames={300}>
        <CheckInScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Your Aura grows" durationInFrames={210}>
        <GrowScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Sanctuary" durationInFrames={210}>
        <SanctuaryScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Rooms" durationInFrames={300}>
        <RoomsScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Aura Sky" durationInFrames={210}>
        <SkyScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Safety" durationInFrames={210}>
        <SafetyScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="Closing" durationInFrames={210}>
        <ClosingScene variant="reel" withBackdrop={false} />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  </AbsoluteFill>
);
