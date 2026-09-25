import React, { useMemo } from "react";
import {
  AbsoluteFill,
  Interactive,
  random,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { colors } from "../theme";

type Star = {
  x: number;
  y: number;
  size: number;
  base: number;
  speed: number;
  phase: number;
  twinkle: number;
  warm: boolean;
};

const STAR_COUNT = 240;

/**
 * The Aura night sky: a deep gradient, two slow nebula glows and a field of
 * stars that drift upward very slowly and twinkle. Everything is driven by
 * the frame number, so it renders the same every time.
 */
export const Backdrop: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();

  const stars = useMemo<Star[]>(
    () =>
      new Array(STAR_COUNT).fill(true).map((_, i) => {
        const big = random(`big-${i}`) > 0.93;
        return {
          x: random(`x-${i}`),
          y: random(`y-${i}`),
          size: big ? 2.4 + random(`s-${i}`) * 1.6 : 0.9 + random(`s-${i}`) * 1.3,
          base: big ? 0.75 : 0.25 + random(`b-${i}`) * 0.45,
          speed: 0.04 + random(`v-${i}`) * 0.12,
          phase: random(`p-${i}`) * Math.PI * 2,
          twinkle: 0.02 + random(`t-${i}`) * 0.05,
          warm: random(`w-${i}`) > 0.8,
        };
      }),
    [],
  );

  return (
    <AbsoluteFill
      style={{
        background: `linear-gradient(180deg, ${colors.sky} 0%, #0B0E24 45%, ${colors.deep} 100%)`,
        overflow: "hidden",
      }}
    >
      <Interactive.Div
        name="Nebula lavender"
        style={{
          position: "absolute",
          width: width * 0.9,
          height: width * 0.9,
          left: width * 0.45 + Math.sin(frame / 260) * width * 0.04,
          top: -width * 0.35 + Math.cos(frame / 310) * height * 0.04,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(187,170,255,0.16) 0%, rgba(187,170,255,0.05) 40%, rgba(187,170,255,0) 70%)",
        }}
      />
      <Interactive.Div
        name="Nebula peach"
        style={{
          position: "absolute",
          width: width * 0.8,
          height: width * 0.8,
          left: -width * 0.3 + Math.cos(frame / 280) * width * 0.04,
          top: height - width * 0.45 + Math.sin(frame / 240) * height * 0.03,
          borderRadius: "50%",
          background:
            "radial-gradient(circle, rgba(246,193,164,0.09) 0%, rgba(246,193,164,0.03) 40%, rgba(246,193,164,0) 70%)",
        }}
      />
      {stars.map((s, i) => {
        const y = (((s.y * height - frame * s.speed) % height) + height) % height;
        const opacity =
          s.base * (0.65 + 0.35 * Math.sin(frame * s.twinkle + s.phase));
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: s.x * width,
              top: y,
              width: s.size,
              height: s.size,
              borderRadius: "50%",
              background: s.warm ? colors.starlight : "#FFFFFF",
              opacity,
              boxShadow:
                s.size > 2.2
                  ? `0 0 ${s.size * 4}px ${s.warm ? "rgba(247,230,181,0.7)" : "rgba(201,191,255,0.7)"}`
                  : undefined,
            }}
          />
        );
      })}
      {/* Soft vignette keeps the edges calm and the centre bright. */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 45%, rgba(5,6,15,0) 55%, rgba(5,6,15,0.55) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};
