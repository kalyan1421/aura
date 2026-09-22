// Resting Nebula: soft, slowly folding clouds around the lower body.
//
// Domain-warped fbm inside an elliptical mask. `uBand` = 1 draws only the
// lower part (the wisp layer in front of the legs), 0 draws the full cloud
// behind the character. A look, not a penalty: no grey, no darkening of the
// face. Output is premultiplied alpha.
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;    // 0,1    canvas size (px)
uniform vec2 uCenter;  // 2,3    cloud centre (px)
uniform vec2 uRadii;   // 4,5    cloud radii (px)
uniform float uTime;   // 6      seconds
uniform vec3 uColorA;  // 7-9    deep cloud colour
uniform vec3 uColorB;  // 10-12  lit cloud colour
uniform float uAlpha;  // 13     overall opacity
uniform float uBand;   // 14     0 = full, 1 = lower band only

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73));
  p += dot(p, p + 23.45);
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
  for (int i = 0; i < 5; i++) {
    v += amp * noise(p);
    p = p * 2.02 + vec2(3.1, 7.7);
    amp *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 q = (frag - uCenter) / uRadii;
  float r = length(q);
  float mask = 1.0 - smoothstep(0.45, 1.0, r);

  vec2 p = q * 1.7;
  float t = uTime * 0.035;
  vec2 w = vec2(fbm(p + vec2(0.0, t)), fbm(p + vec2(5.2, -t) + 1.3));
  float n = fbm(p + 1.6 * w + vec2(t * 0.6, -t * 0.4));
  float cloud = smoothstep(0.36, 0.8, n) * mask;

  // Front band: only below the waist, fading in softly.
  cloud *= mix(1.0, smoothstep(-0.2, 0.3, q.y), uBand);

  float edge = min(min(frag.x, frag.y), min(uSize.x - frag.x, uSize.y - frag.y));
  cloud *= smoothstep(0.0, 18.0, edge);

  vec3 col = mix(uColorA, uColorB, smoothstep(0.3, 0.9, n));
  float a = clamp(cloud * uAlpha, 0.0, 1.0);
  fragColor = vec4(col * a, a);
}
