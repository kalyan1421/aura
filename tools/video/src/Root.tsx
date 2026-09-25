import React from "react";
import { Composition, Folder } from "remotion";
import { FullTour } from "./FullTour";
import { Reel } from "./Reel";
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

// Full tour: 5100 frames of scenes - 13 fades x 18 frames = 4866 frames (2:42.2).
// Reel: 1800 frames of scenes - 7 fades x 18 frames = 1674 frames (0:55.8).

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="AuraFullTour"
        component={FullTour}
        width={1920}
        height={1080}
        fps={30}
        durationInFrames={4866}
      />
      <Composition
        id="Aura60sVertical"
        component={Reel}
        width={1080}
        height={1920}
        fps={30}
        durationInFrames={1674}
      />
      <Folder name="Tour-Scenes">
        <Composition id="Tour01-Title" component={TitleScene} width={1920} height={1080} fps={30} durationInFrames={240} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour02-Privacy" component={PrivacyScene} width={1920} height={1080} fps={30} durationInFrames={330} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour03-CheckIn" component={CheckInScene} width={1920} height={1080} fps={30} durationInFrames={390} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour04-Grow" component={GrowScene} width={1920} height={1080} fps={30} durationInFrames={360} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour05-Sanctuary" component={SanctuaryScene} width={1920} height={1080} fps={30} durationInFrames={420} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour06-FutureYou" component={FutureYouScene} width={1920} height={1080} fps={30} durationInFrames={390} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour07-Rooms" component={RoomsScene} width={1920} height={1080} fps={30} durationInFrames={420} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour08-Together" component={TogetherScene} width={1920} height={1080} fps={30} durationInFrames={390} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour09-Sky" component={SkyScene} width={1920} height={1080} fps={30} durationInFrames={390} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour10-Keepsakes" component={KeepsakesScene} width={1920} height={1080} fps={30} durationInFrames={360} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour11-Safety" component={SafetyScene} width={1920} height={1080} fps={30} durationInFrames={390} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour12-Plus" component={PlusScene} width={1920} height={1080} fps={30} durationInFrames={330} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour13-Language" component={LanguageScene} width={1920} height={1080} fps={30} durationInFrames={360} defaultProps={{ variant: "tour", withBackdrop: true }} />
        <Composition id="Tour14-Closing" component={ClosingScene} width={1920} height={1080} fps={30} durationInFrames={330} defaultProps={{ variant: "tour", withBackdrop: true }} />
      </Folder>
      <Folder name="Reel-Scenes">
        <Composition id="Reel1-Title" component={TitleScene} width={1080} height={1920} fps={30} durationInFrames={150} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel2-CheckIn" component={CheckInScene} width={1080} height={1920} fps={30} durationInFrames={300} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel3-Grow" component={GrowScene} width={1080} height={1920} fps={30} durationInFrames={210} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel4-Sanctuary" component={SanctuaryScene} width={1080} height={1920} fps={30} durationInFrames={210} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel5-Rooms" component={RoomsScene} width={1080} height={1920} fps={30} durationInFrames={300} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel6-Sky" component={SkyScene} width={1080} height={1920} fps={30} durationInFrames={210} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel7-Safety" component={SafetyScene} width={1080} height={1920} fps={30} durationInFrames={210} defaultProps={{ variant: "reel", withBackdrop: true }} />
        <Composition id="Reel8-Closing" component={ClosingScene} width={1080} height={1920} fps={30} durationInFrames={210} defaultProps={{ variant: "reel", withBackdrop: true }} />
      </Folder>
    </>
  );
};
