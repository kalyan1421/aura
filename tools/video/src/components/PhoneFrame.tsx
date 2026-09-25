import React from "react";
import { Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { colors, SCREEN_ASPECT } from "../theme";

/** A rectangle on the screen capture, in fractions of its width and height. */
export type Rect = { x: number; y: number; w: number; h: number };

export type TimedRing = {
  rect: Rect;
  color: string;
  /** Scene frames between which the ring is shown. */
  from: number;
  to: number;
};

/** Frame width for a given frame height (screen plus bezel on both sides). */
export const phoneWidthFor = (height: number) => {
  const bezel = height * 0.018;
  const screenH = height - bezel * 2;
  return screenH * SCREEN_ASPECT + bezel * 2;
};

/**
 * A rounded device frame drawn in code around a real app capture, with a soft
 * lavender glow. Rings highlight one UI element at a time.
 */
export const PhoneFrame: React.FC<{
  src: string;
  height: number;
  rings?: TimedRing[];
}> = ({ src, height, rings = [] }) => {
  const frame = useCurrentFrame();
  const bezel = height * 0.018;
  const screenH = height - bezel * 2;
  const screenW = screenH * SCREEN_ASPECT;
  const width = screenW + bezel * 2;
  const outerRadius = width * 0.15;
  const innerRadius = outerRadius - bezel;

  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: outerRadius,
        background: "linear-gradient(145deg, #3A3F63 0%, #1A1D36 35%, #0E1024 70%, #2A2E4E 100%)",
        boxShadow: `0 0 0 1.5px rgba(201,191,255,0.28), 0 0 ${height * 0.09}px rgba(187,170,255,0.22), 0 ${height * 0.04}px ${height * 0.09}px rgba(0,0,0,0.55)`,
      }}
    >
      {/* Side buttons */}
      <div style={{ position: "absolute", left: -3, top: height * 0.2, width: 3, height: height * 0.05, borderRadius: 2, background: "#2A2E4E" }} />
      <div style={{ position: "absolute", left: -3, top: height * 0.28, width: 3, height: height * 0.08, borderRadius: 2, background: "#2A2E4E" }} />
      <div style={{ position: "absolute", left: -3, top: height * 0.38, width: 3, height: height * 0.08, borderRadius: 2, background: "#2A2E4E" }} />
      <div style={{ position: "absolute", right: -3, top: height * 0.3, width: 3, height: height * 0.12, borderRadius: 2, background: "#2A2E4E" }} />

      <div
        style={{
          position: "absolute",
          left: bezel,
          top: bezel,
          width: screenW,
          height: screenH,
          borderRadius: innerRadius,
          overflow: "hidden",
          background: colors.sky,
        }}
      >
        <Img
          src={staticFile(src)}
          style={{ width: screenW, height: screenH, display: "block" }}
        />
        {/* Dynamic Island */}
        <div
          style={{
            position: "absolute",
            left: (screenW - screenW * 0.31) / 2,
            top: screenW * 0.028,
            width: screenW * 0.31,
            height: screenW * 0.09,
            borderRadius: screenW * 0.045,
            background: "#000",
          }}
        />
        {/* Glass sheen */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "linear-gradient(125deg, rgba(255,255,255,0.06) 0%, rgba(255,255,255,0) 30%)",
          }}
        />
        {rings.map((r, i) => {
          const pad = screenW * 0.015;
          const opacity = interpolate(
            frame,
            [r.from, r.from + 12, r.to - 10, r.to],
            [0, 1, 1, 0],
            {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.33, 0, 0.2, 1),
            },
          );
          const pulse = 0.5 + 0.5 * Math.sin((frame - r.from) / 11);
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: r.rect.x * screenW - pad,
                top: r.rect.y * screenH - pad,
                width: r.rect.w * screenW + pad * 2,
                height: r.rect.h * screenH + pad * 2,
                borderRadius: screenW * 0.05,
                border: `${Math.max(2.5, screenW * 0.007)}px solid ${r.color}`,
                boxShadow: `0 0 ${14 + pulse * 16}px ${r.color}, inset 0 0 ${10 + pulse * 10}px ${r.color}55`,
                opacity,
                scale: interpolate(frame, [r.from, r.from + 16], [1.06, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                  easing: Easing.bezier(0.16, 1, 0.3, 1),
                }),
              }}
            />
          );
        })}
      </div>
    </div>
  );
};
