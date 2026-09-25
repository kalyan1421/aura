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

const ease = Easing.bezier(0.16, 1, 0.3, 1);

/** Last scene: avatar, name, one-line summary, website, availability, copyright. */
export const ClosingScene: React.FC<SceneProps> = ({ variant, withBackdrop }) => {
  const frame = useCurrentFrame();
  const isTour = variant === "tour";

  const rise = (delay: number) => ({
    opacity: interpolate(frame, [delay, delay + 22], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: ease,
    }),
    translate: interpolate(frame, [delay, delay + 26], ["0px 24px", "0px 0px"], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: ease,
    }),
  });

  return (
    <AbsoluteFill>
      {withBackdrop ? <Backdrop /> : null}
      <AbsoluteFill
        style={{
          display: "flex",
          flexDirection: isTour ? "row" : "column",
          alignItems: "center",
          justifyContent: "center",
          gap: isTour ? 110 : 30,
          paddingLeft: isTour ? 130 : 80,
          paddingRight: isTour ? 130 : 80,
        }}
      >
        <div
          style={{
            flexShrink: 0,
            opacity: interpolate(frame, [0, 26], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.33, 0, 0.2, 1),
            }),
          }}
        >
          <Avatar height={isTour ? 720 : 640} glow={1.2} />
        </div>
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: isTour ? "flex-start" : "center",
            textAlign: isTour ? "left" : "center",
            maxWidth: isTour ? 820 : 920,
          }}
        >
          <Interactive.Div
            name="Wordmark"
            style={{
              fontFamily: inter,
              fontSize: isTour ? 140 : 160,
              fontWeight: 300,
              letterSpacing: "0.16em",
              lineHeight: 1,
              color: colors.text,
              ...rise(10),
            }}
          >
            Aura
          </Interactive.Div>
          <Interactive.Div
            name="Summary"
            style={{
              fontFamily: inter,
              fontSize: isTour ? 52 : 56,
              fontWeight: 400,
              lineHeight: 1.3,
              color: colors.soft,
              marginTop: isTour ? 30 : 34,
              textWrap: "balance",
              ...rise(24),
            }}
          >
            Private mood check-ins, gentle rooms, calm tools.
          </Interactive.Div>
          <Interactive.Div
            name="Website"
            style={{
              fontFamily: inter,
              fontSize: isTour ? 46 : 50,
              fontWeight: 600,
              color: colors.accent,
              marginTop: isTour ? 44 : 50,
              ...rise(40),
            }}
          >
            aura-akvega.web.app
          </Interactive.Div>
          <Interactive.Div
            name="Availability"
            style={{
              fontFamily: inter,
              fontSize: isTour ? 44 : 48,
              fontWeight: 500,
              color: colors.starlight,
              marginTop: isTour ? 18 : 22,
              ...rise(52),
            }}
          >
            Coming soon to iPhone and Android
          </Interactive.Div>
          <Interactive.Div
            name="Copyright"
            style={{
              fontFamily: inter,
              fontSize: isTour ? 30 : 34,
              fontWeight: 400,
              letterSpacing: "0.08em",
              color: colors.muted,
              marginTop: isTour ? 44 : 50,
              ...rise(64),
            }}
          >
            © AKVega
          </Interactive.Div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
