import React from "react";
import { Img, random, staticFile, useCurrentFrame } from "remotion";
import { colors } from "../theme";

const SPARKS = 14;

/**
 * The Aura avatar art from the app (apps/mobile/assets/avatar/aura_base.png),
 * breathing slowly inside a soft glow with a few drifting sparks.
 */
export const Avatar: React.FC<{ height: number; glow?: number }> = ({ height, glow = 1 }) => {
  const frame = useCurrentFrame();
  const width = height * (1000 / 1200);
  const breathe = Math.sin(frame / 38);

  return (
    <div style={{ position: "relative", width, height }}>
      <div
        style={{
          position: "absolute",
          left: -width * 0.35,
          top: -height * 0.2,
          width: width * 1.7,
          height: height * 1.4,
          borderRadius: "50%",
          background: `radial-gradient(circle at 50% 52%, rgba(187,170,255,${0.34 * glow}) 0%, rgba(175,195,240,${0.14 * glow}) 32%, rgba(10,12,29,0) 64%)`,
          opacity: 0.85 + 0.15 * breathe,
        }}
      />
      {new Array(SPARKS).fill(true).map((_, i) => {
        const angle = random(`a-${i}`) * Math.PI * 2 + frame / (260 + random(`r-${i}`) * 200);
        const radius = 0.42 + random(`d-${i}`) * 0.22;
        const x = width / 2 + Math.cos(angle) * width * radius;
        const y = height * 0.53 + Math.sin(angle) * height * radius * 0.8;
        const size = 3 + random(`s-${i}`) * 5;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: y,
              width: size,
              height: size,
              borderRadius: "50%",
              background: i % 3 === 0 ? colors.starlight : "#FFFFFF",
              boxShadow: `0 0 ${size * 3}px rgba(247,230,181,0.8)`,
              opacity: 0.35 + 0.45 * (0.5 + 0.5 * Math.sin(frame / 14 + i * 1.7)),
            }}
          />
        );
      })}
      <Img
        src={staticFile("art/aura.png")}
        style={{
          position: "absolute",
          inset: 0,
          width,
          height,
          scale: String(1 + 0.018 * breathe),
          translate: `0px ${-6 * breathe}px`,
          filter: `drop-shadow(0 0 ${height * 0.04}px rgba(201,191,255,0.55))`,
        }}
      />
    </div>
  );
};
