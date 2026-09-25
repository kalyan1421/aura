import React from "react";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { AbsoluteFill } from "remotion";
import { Backdrop } from "./components/Backdrop";
import { CheckInScene } from "./scenes/CheckInScene";
import { ClosingScene } from "./scenes/ClosingScene";
import { FutureYouScene } from "./scenes/FutureYouScene";
import { GrowScene } from "./scenes/GrowScene";
import { KeepsakesScene } from "./scenes/KeepsakesScene";
import { LanguageScene } from "./scenes/LanguageScene";
import { PlusScene } from "./scenes/PlusScene";
import { PrivacyScene } from "./scenes/PrivacyScene";
import { RoomsScene } from "./scenes/RoomsScene";
import { SafetyScene } from "./scenes/SafetyScene";
import { SanctuaryScene } from "./scenes/SanctuaryScene";
import { SkyScene } from "./scenes/SkyScene";
import { TitleScene } from "./scenes/TitleScene";
import { TogetherScene } from "./scenes/TogetherScene";
import { SCENE_FADE } from "./theme";

const Fade = () => (
  <TransitionSeries.Transition
    presentation={fade({ shouldFadeOutExitingScene: true })}
    timing={linearTiming({ durationInFrames: SCENE_FADE })}
  />
);

/**
 * "Aura: full tour", 1920x1080, 30 fps. Scene lengths are in frames; the
 * composition length in Root.tsx is their sum minus 13 fades of SCENE_FADE.
 */
export const FullTour: React.FC = () => (
  <AbsoluteFill>
    <Backdrop />
    <TransitionSeries>
      <TransitionSeries.Sequence name="1 Title" durationInFrames={240}>
        <TitleScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="2 Private by default" durationInFrames={330}>
        <PrivacyScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="3 Check in" durationInFrames={390}>
        <CheckInScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="4 Your Aura grows" durationInFrames={360}>
        <GrowScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="5 Sanctuary" durationInFrames={420}>
        <SanctuaryScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="6 Future you" durationInFrames={390}>
        <FutureYouScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="7 Rooms" durationInFrames={420}>
        <RoomsScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="8 Together" durationInFrames={390}>
        <TogetherScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="9 Aura Sky" durationInFrames={390}>
        <SkyScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="10 Keepsakes" durationInFrames={360}>
        <KeepsakesScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="11 Safety" durationInFrames={390}>
        <SafetyScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="12 Aura Plus" durationInFrames={330}>
        <PlusScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="13 Your language" durationInFrames={360}>
        <LanguageScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
      {Fade()}
      <TransitionSeries.Sequence name="14 Closing" durationInFrames={330}>
        <ClosingScene variant="tour" withBackdrop={false} />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  </AbsoluteFill>
);
