import React from "react";
import {
  AbsoluteFill,
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
} from "remotion";
import { Avatar } from "../components/Avatar";
import { Backdrop } from "../components/Backdrop";
import { colors, inter, SceneProps } from "../theme";

/** Scene 1: the avatar, the name, the promise, the publisher. */
export const TitleScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => {
  const frame = useCurrentFrame();
  const isTour = variant === "tour";

  return (
    <AbsoluteFill>
      {withBackdrop ? <Backdrop /> : null}
      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          textAlign: "center",
          paddingLeft: 80,
          paddingRight: 80,
        }}
      >
        <div
          style={{
            opacity: interpolate(frame, [0, 30], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.33, 0, 0.2, 1),
            }),
            scale: interpolate(frame, [0, 60], [0.92, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
              output: "perceptual-scale",
            }),
          }}
        >
          <Avatar height={isTour ? 500 : 760} />
        </div>
        <Interactive.Div
          name="Wordmark"
          style={{
            fontFamily: inter,
            fontSize: isTour ? 150 : 180,
            fontWeight: 300,
            letterSpacing: "0.16em",
            marginLeft: "0.16em",
            color: colors.text,
            lineHeight: 1,
            marginTop: isTour ? 16 : 40,
            opacity: interpolate(frame, [18, 42], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            translate: interpolate(frame, [18, 48], ["0px 30px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          Aura
        </Interactive.Div>
        <Interactive.Div
          name="Tagline"
          style={{
            fontFamily: inter,
            fontSize: isTour ? 54 : 60,
            fontWeight: 400,
            color: colors.soft,
            marginTop: isTour ? 26 : 40,
            maxWidth: isTour ? 1400 : 880,
            textWrap: "balance",
            lineHeight: 1.3,
            opacity: interpolate(frame, [36, 60], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            translate: interpolate(frame, [36, 66], ["0px 24px", "0px 0px"], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          A quiet place to notice how you feel.
        </Interactive.Div>
        <Interactive.Div
          name="Publisher"
          style={{
            fontFamily: inter,
            fontSize: isTour ? 32 : 38,
            fontWeight: 500,
            letterSpacing: "0.22em",
            textTransform: "uppercase",
            color: colors.accent,
            marginTop: isTour ? 34 : 56,
            opacity: interpolate(frame, [56, 80], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          by AKVega
        </Interactive.Div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
