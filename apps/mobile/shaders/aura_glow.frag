// Aura glow: the soft, breathing light behind the character.
//
// A warm core fading into a hue-tinted body of light with slow fbm "wisps"
// drifting outward, plus an optional halo ring (radiance/constellation).
// Output is premultiplied alpha. Every uniform is used so the compiler never
// strips one (indices in Dart must stay in declaration order).
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;       // 0,1   canvas size (px)
uniform vec2 uCenter;     // 2,3   glow centre (px)
uniform float uRadius;    // 4     glow radius (px)
uniform float uTime;      // 5     seconds
uniform vec3 uColor;      // 6-8   hue colour (0-1)
uniform vec3 uCore;       // 9-11  inner core colour (0-1)
uniform float uIntensity; // 12    0..1.4
uniform float uHalo;      // 13    0..1
uniform float uSeed;      // 14    per-avatar noise offset

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 4; i++) {
    v += amp * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    amp *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 d = (frag - uCenter) / uRadius;
  d.y *= 0.82; // a little taller than wide
  float r = length(d);
  float ang = atan(d.y, d.x);

  // One slow breath every ~6 s.
  float breath = 0.5 + 0.5 * sin(uTime * 1.0472);

  // Wisps drift outward, very slowly.
  vec2 q = vec2(cos(ang), sin(ang)) * (r * 1.6 - uTime * 0.06) + vec2(uSeed);
  float wisps = fbm(q * 1.8 + vec2(uTime * 0.025, 0.0));

  // Gaussian falloffs: bright near the heart, a soft body of light, and a
  // thin halo ring at radiance — never a flat disc.
  float core = exp(-r * r * 6.0);
  float body = exp(-r * r * 3.4) * (0.6 + 0.5 * wisps);
  float glow = (core * 0.6 + body * 0.5) * uIntensity * (0.9 + 0.1 * breath);
  float halo = uHalo * exp(-pow((r - 0.58) / 0.07, 2.0)) * (0.4 + 0.6 * wisps) * 0.32;

  // Gaussians already reach ~0 by r = 1; this only guarantees no cut-off,
  // plus a soft fade at the canvas edge.
  float fade = 1.0 - smoothstep(0.85, 1.1, r);
  float edge = min(min(frag.x, frag.y), min(uSize.x - frag.x, uSize.y - frag.y));
  fade *= smoothstep(0.0, 18.0, edge);

  vec3 col = mix(uCore, uColor, smoothstep(0.0, 0.6, r));
  vec3 rgb = col * glow + mix(uColor, vec3(1.0), 0.45) * halo;
  float a = clamp((glow + halo) * fade, 0.0, 0.88);
  rgb = min(rgb * fade, vec3(a));
  fragColor = vec4(rgb, a);
}
