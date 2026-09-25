import React from "react";
import {
  AbsoluteFill,
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { colors, inter, layout, notoTelugu, screen, Variant } from "../theme";
import { Backdrop } from "./Backdrop";
import { PhoneFrame, phoneWidthFor, Rect, TimedRing } from "./PhoneFrame";

export type PhoneSpec = {
  /** Capture id, e.g. "030" (see docs/design/screens/INDEX.md). */
  id: string;
  ring?: Rect;
  ringColor?: string;
  /** Small label above the phone (used for the language comparison). */
  label?: string;
  labelTelugu?: boolean;
};

export type Beat = {
  phones: PhoneSpec[];
  /** Supporting caption. Keep it under ~12 words. */
  line: string;
  /** Relative length of this beat inside the scene (default 1). */
  weight?: number;
};

type Props = {
  variant: Variant;
  withBackdrop: boolean;
  eyebrow: string;
  headline: string;
  beats: Beat[];
};

/** Keep "wind-down" or "Tele-MANAS" on one line. */
const noBreakHyphens = (text: string) => text.replace(/(\w)-(\w)/g, "$1\u2011$2");

/** Half of the overlap used when one set of phones hands over to the next. */
const H = 10;
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const easeInOut = Easing.bezier(0.45, 0, 0.2, 1);

type Shot = { start: number; end: number; beats: { beat: Beat; start: number; end: number }[] };

const buildTimeline = (beats: Beat[], duration: number) => {
  const total = beats.reduce((a, b) => a + (b.weight ?? 1), 0);
  let acc = 0;
  const timed = beats.map((beat) => {
    const start = Math.round((acc / total) * duration);
    acc += beat.weight ?? 1;
    const end = Math.round((acc / total) * duration);
    return { beat, start, end };
  });
  const shots: Shot[] = [];
  for (const t of timed) {
    const key = t.beat.phones.map((p) => p.id).join(",");
    const last = shots[shots.length - 1];
    const lastKey = last?.beats[0].beat.phones.map((p) => p.id).join(",");
    if (last && lastKey === key) {
      last.end = t.end;
      last.beats.push(t);
    } else {
      shots.push({ start: t.start, end: t.end, beats: [t] });
    }
  }
  return { timed, shots };
};

/**
 * One feature of the app: an eyebrow, a headline, one changing supporting line
 * and 1-3 phones per beat. Used by both videos; `variant` switches between the
 * 16:9 side-by-side layout and the 9:16 stacked layout.
 */
export const FeatureScene: React.FC<Props> = ({
  variant,
  withBackdrop,
  eyebrow,
  headline,
  beats,
}) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const L = layout[variant];
  const isTour = variant === "tour";
  const { timed, shots } = buildTimeline(beats, durationInFrames);

  const textIn = (delay: number) => ({
    opacity: interpolate(frame, [delay, delay + 20], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: ease,
    }),
    translate: interpolate(frame, [delay, delay + 24], ["0px 24px", "0px 0px"], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: ease,
    }),
  });

  const lineHeightPx = L.lineSize * 1.35;

  const lines = (
    <div
      style={{
        position: "relative",
        width: L.textWidth,
        height: lineHeightPx * (isTour ? 3 : 2) + 8,
      }}
    >
      {timed.map(({ beat, start, end }, i) => {
        const first = i === 0;
        const last = i === timed.length - 1;
        const inStart = first ? 22 : start;
        const outEnd = last ? durationInFrames + 1 : end + 2;
        if (frame < inStart - 1 || frame > outEnd + 1) return null;
        return (
          <Interactive.Div
            key={i}
            name="Supporting line"
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              width: L.textWidth,
              fontFamily: inter,
              fontSize: L.lineSize,
              fontWeight: 400,
              lineHeight: 1.35,
              color: colors.soft,
              textAlign: isTour ? "left" : "center",
              textWrap: "balance",
              opacity: interpolate(
                frame,
                last
                  ? [inStart, inStart + 16]
                  : [inStart, inStart + 16, outEnd - 12, outEnd],
                last ? [0, 1] : [0, 1, 1, 0],
                { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeInOut },
              ),
              translate: interpolate(frame, [inStart, inStart + 20], ["0px 18px", "0px 0px"], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
                easing: ease,
              }),
            }}
          >
            {noBreakHyphens(beat.line)}
          </Interactive.Div>
        );
      })}
    </div>
  );

  const headlineBlock = (
    <>
      <Interactive.Div
        name="Eyebrow"
        style={{
          fontFamily: inter,
          fontSize: L.eyebrowSize,
          fontWeight: 600,
          letterSpacing: "0.2em",
          textTransform: "uppercase",
          color: colors.accent,
          marginBottom: isTour ? 22 : 18,
          ...textIn(4),
        }}
      >
        {eyebrow}
      </Interactive.Div>
      <Interactive.Div
        name="Headline"
        style={{
          fontFamily: inter,
          fontSize: L.headlineSize,
          fontWeight: 600,
          lineHeight: 1.06,
          letterSpacing: "-0.02em",
          color: colors.text,
          textWrap: "balance",
          ...textIn(10),
        }}
      >
        {headline}
      </Interactive.Div>
    </>
  );

  // Phone geometry
  const renderShot = (shot: Shot, index: number) => {
    const first = index === 0;
    const last = index === shots.length - 1;
    // Hand-over between phone sets: the old set leaves just before the beat
    // boundary and the new one arrives just after, so they barely overlap.
    const inStart = first ? 8 : shot.start - 2;
    const inEnd = first ? 38 : shot.start + 22;
    const outStart = shot.end - 16;
    const outEnd = shot.end + 2;
    if (frame < inStart || (!last && frame > outEnd)) return null;

    const phones = shot.beats[0].beat.phones;
    const n = phones.length;
    const hasLabels = phones.some((p) => p.label);
    const labelSpace = hasLabels ? (isTour ? 78 : 90) : 0;
    const gap = isTour ? 48 : 36;
    let ph = L.phoneHeight - labelSpace;
    const fits = (h: number) => n * phoneWidthFor(h) + (n - 1) * gap <= L.phoneRegionWidth;
    while (!fits(ph)) ph -= 4;
    const pw = phoneWidthFor(ph);
    const groupW = n * pw + (n - 1) * gap;
    const left0 = L.phoneRegionLeft + (L.phoneRegionWidth - groupW) / 2;
    const blockH = ph + labelSpace;
    const top = isTour ? (L.height - blockH) / 2 : 440 + (L.phoneHeight - blockH) / 2;

    return (
      <React.Fragment key={index}>
        {phones.map((p, j) => {
          const rings: TimedRing[] = shot.beats
            .map(({ beat, start, end }) => {
              const spec = beat.phones[j];
              if (!spec?.ring) return null;
              const from = start === 0 ? 40 : start + (start === shot.start ? 20 : 4);
              return {
                rect: spec.ring,
                color: spec.ringColor ?? colors.starlight,
                from,
                to: end === shot.end && !last ? end - 10 : end + 2,
              };
            })
            .filter((r): r is TimedRing => r !== null);
          const stagger = j * 5;
          return (
            <div
              key={p.id + j}
              style={{
                position: "absolute",
                left: left0 + j * (pw + gap),
                top,
                width: pw,
                height: blockH,
                opacity: interpolate(
                  frame,
                  last
                    ? [inStart + stagger, inEnd + stagger]
                    : [inStart + stagger, inEnd + stagger, outStart, outEnd],
                  last ? [0, 1] : [0, 1, 1, 0],
                  { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeInOut },
                ),
                translate: interpolate(
                  frame,
                  last
                    ? [inStart + stagger, inEnd + stagger]
                    : [inStart + stagger, inEnd + stagger, outStart, outEnd],
                  last
                    ? ["120px 0px", "0px 0px"]
                    : ["120px 0px", "0px 0px", "0px 0px", "-120px 0px"],
                  { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease },
                ),
                scale: interpolate(frame, [shot.start, shot.end + H], [0.985, 1.02], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                }),
              }}
            >
              {hasLabels ? (
                <div
                  style={{
                    height: labelSpace,
                    display: "flex",
                    alignItems: "flex-start",
                    justifyContent: "center",
                    fontFamily: p.labelTelugu ? notoTelugu : inter,
                    fontSize: isTour ? 44 : 50,
                    fontWeight: 600,
                    lineHeight: 1.2,
                    color: colors.starlight,
                  }}
                >
                  {p.label}
                </div>
              ) : null}
              <PhoneFrame src={screen(p.id)} height={ph} rings={rings} />
            </div>
          );
        })}
      </React.Fragment>
    );
  };

  return (
    <AbsoluteFill>
      {withBackdrop ? <Backdrop /> : null}
      {shots.map(renderShot)}
      {isTour ? (
        <div
          style={{
            position: "absolute",
            left: L.textLeft,
            top: 0,
            bottom: 0,
            width: L.textWidth,
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
          }}
        >
          {headlineBlock}
          <div style={{ height: 40 }} />
          {lines}
        </div>
      ) : (
        <>
          <div
            style={{
              position: "absolute",
              left: L.textLeft,
              top: 110,
              width: L.textWidth,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              textAlign: "center",
            }}
          >
            {headlineBlock}
          </div>
          <div style={{ position: "absolute", left: L.textLeft, top: 1650 }}>{lines}</div>
        </>
      )}
    </AbsoluteFill>
  );
};
