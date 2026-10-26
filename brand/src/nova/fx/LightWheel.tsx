import { Mesh, Program, Renderer, Triangle } from 'ogl'
import { useEffect, useRef } from 'react'

/*
 * The hero: the wheel rendered as light in a fragment shader.
 * Eight wedges of molten glass with chromatic fringes, a breathing core, drifting dust.
 * The aimed wedge lifts out and burns cyan-white at its rim; a drop sends a shockwave.
 * Inputs come from the parent through a mutable ref so React never re-renders per frame.
 */
export type WheelInput = {
  /** Wheel centre in CSS px, relative to the canvas. */
  cx: number; cy: number
  /** CSS px per shader unit (the outer radius is ~0.62 units). */
  unit: number
  /** 0 = closed core, 1 = fully open. Animated by the caller. */
  open: number
  /** Aimed wedge index, or -1. */
  aim: number
  /** performance.now() of the last drop, or 0. */
  pulseAt: number
  /** Pointer in CSS px (for the light that follows it). */
  mx: number; my: number
}

const FRAG = /* glsl */ `
precision highp float;
uniform vec2 uRes;      // device px
uniform float uDpr;
uniform float uTime;
uniform vec2 uCenter;   // device px, GL space (y up)
uniform float uUnit;    // device px per unit
uniform float uOpen;
uniform float uAim;
uniform float uPulse;   // seconds since drop (large if none)
uniform vec2 uMouse;    // device px, GL space
varying vec2 vUv;

#define N 8.0
#define TAU 6.28318530718

float hash(vec2 p){ p = fract(p*vec2(123.34, 456.21)); p += dot(p, p+45.32); return fract(p.x*p.y); }
float noise(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x), f.y); }
float fbm(vec2 p){ float v=0.0, a=0.5; for(int i=0;i<4;i++){ v+=a*noise(p); p*=2.03; a*=0.5; } return v; }

vec3 molten(float t){
  t = clamp(t, 0.0, 1.0);
  vec3 a = vec3(1.00, 0.76, 0.29); // solar
  vec3 b = vec3(1.00, 0.35, 0.12); // ember
  vec3 c = vec3(1.00, 0.18, 0.39); // magma
  return t < 0.5 ? mix(a, b, t*2.0) : mix(b, c, (t-0.5)*2.0);
}

// Signed distance to one wedge, evaluated in that wedge's own frame (no sector seams).
float wedgeSDF(vec2 p, float i, float lift){
  float mid = i * (TAU/N);
  vec2 q = p - vec2(sin(mid), cos(mid)) * lift;
  float r = length(q);
  float a = atan(q.x, q.y) - mid;
  a = mod(a + 3.14159265, TAU) - 3.14159265;
  float r0 = mix(0.03, 0.30, uOpen);
  float r1 = mix(0.05, 0.62, uOpen);
  float dAng = (abs(a) - 3.14159265/N) * r + 0.011;
  float dRad = max(r0 - r, r - r1);
  return max(dRad, dAng);
}

// Nearest wedge: distance, its id, and whether it is the aimed one.
float wheelSDF(vec2 p, out float id, out float hot){
  float best = 1e3; id = 0.0; hot = 0.0;
  for (int k = 0; k < 8; k++){
    float i = float(k);
    float h = (uAim >= 0.0 && abs(i - uAim) < 0.5) ? 1.0 : 0.0;
    float d = wedgeSDF(p, i, h * 0.055 * uOpen);
    if (d < best){ best = d; id = i; hot = h; }
  }
  return best;
}

vec3 shade(vec2 p){
  float id, hot;
  float d = wheelSDF(p, id, hot);
  float r = length(p);
  float ang = atan(p.x, p.y);
  vec3 col = vec3(0.0);

  // Molten fill: flowing noise inside each wedge, hue drifting around the ring.
  float flow = fbm(vec2(ang*1.6 + uTime*0.15, r*6.0 - uTime*0.45));
  float hue = fract((ang / TAU) + 0.5 + flow*0.25 + uTime*0.02);
  vec3 m = molten(hue < 0.5 ? hue*2.0 : 2.0 - hue*2.0);
  float inside = 1.0 - smoothstep(-0.004, 0.004, d);
  float body = mix(0.10, 0.55, hot) + flow*0.18;
  col += m * inside * body;

  // Rims: thin bright edge on every wedge, cyan-white on the aimed one.
  float rim = exp(-abs(d) * mix(260.0, 180.0, hot));
  vec3 rimCol = mix(m * 1.3, vec3(0.55, 0.98, 1.0) * 1.6, hot);
  col += rimCol * rim * mix(0.55, 1.4, hot) * uOpen;

  // Bloom: soft light leaking from the ring.
  col += m * exp(-max(d, 0.0) * 18.0) * 0.16 * uOpen;
  col += vec3(0.55, 0.98, 1.0) * hot * exp(-max(d, 0.0) * 42.0) * 0.3;

  // Core: a white-hot point that breathes, brightest when closed.
  float core = exp(-r * mix(10.0, 22.0, uOpen)) * (0.9 + 0.1*sin(uTime*2.0));
  col += mix(vec3(1.0, 0.86, 0.6), vec3(1.0,0.5,0.3), uOpen) * core * mix(1.6, 0.7, uOpen);

  // Shockwave from a drop.
  float sw = uPulse * 1.15;
  float e1 = (r - sw) * 22.0, e2 = (r - sw*0.82) * 30.0;
  float ring = exp(-e1*e1) * exp(-min(uPulse, 20.0) * 2.2);
  col += molten(0.4) * ring * 1.6;
  col += vec3(0.55, 0.98, 1.0) * exp(-e2*e2) * exp(-min(uPulse, 20.0) * 3.0);

  return col;
}

void main(){
  vec2 frag = gl_FragCoord.xy;
  vec2 p = (frag - uCenter) / uUnit;
  float len = length(p);

  // Chromatic dispersion: sample the scene three times with slightly scaled coordinates.
  float k = 0.012 + 0.02 * smoothstep(0.2, 0.9, len);
  vec3 col;
  col.r = shade(p * (1.0 - k)).r;
  col.g = shade(p).g;
  col.b = shade(p * (1.0 + k)).b;

  // Dust and faint orbit lines in the void.
  vec2 uv = frag / uRes.y;
  float dust = pow(noise(uv * 180.0 + uTime*0.6), 22.0) * 0.9;
  col += vec3(1.0, 0.8, 0.7) * dust * (1.0 - smoothstep(0.3, 1.6, len));
  float orbit = exp(-abs(len - 0.86) * 260.0) * 0.05 + exp(-abs(len - 1.12) * 260.0) * 0.03;
  col += vec3(0.9, 0.9, 1.0) * orbit * uOpen;

  // Pointer light.
  vec2 mp = (frag - uMouse) / uUnit;
  col += molten(0.3) * exp(-length(mp) * 4.5) * 0.06;

  // Vignette, tonemap, gentle grain.
  col *= 1.0 - smoothstep(0.4, 2.4, length((frag - uRes*0.5) / uRes.y));
  col = 1.0 - exp(-col * 1.35);
  col += (hash(frag + uTime) - 0.5) * 0.025;
  gl_FragColor = vec4(col, 1.0);
}`

const VERT = /* glsl */ `
attribute vec2 position; attribute vec2 uv; varying vec2 vUv;
void main(){ vUv = uv; gl_Position = vec4(position, 0.0, 1.0); }`

export function LightWheel({ input, className, still }: { input: React.MutableRefObject<WheelInput>; className?: string; still?: boolean }) {
  const host = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = host.current
    if (!el) return
    let renderer: Renderer
    try {
      renderer = new Renderer({ dpr: Math.min(window.devicePixelRatio || 1, 2), alpha: false, antialias: false })
    } catch {
      el.dataset.fallback = '1' // CSS gradient fallback shows instead
      return
    }
    const gl = renderer.gl
    gl.clearColor(0.02, 0.02, 0.03, 1)
    el.appendChild(gl.canvas)
    gl.canvas.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block'

    const program = new Program(gl, {
      vertex: VERT, fragment: FRAG,
      uniforms: {
        uRes: { value: [1, 1] }, uDpr: { value: 1 }, uTime: { value: 0 }, uCenter: { value: [0, 0] }, uUnit: { value: 100 },
        uOpen: { value: 0 }, uAim: { value: -1 }, uPulse: { value: 99 }, uMouse: { value: [0, 0] },
      },
    })
    const mesh = new Mesh(gl, { geometry: new Triangle(gl), program })

    let w = 1, h = 1
    const resize = () => {
      w = el.clientWidth; h = el.clientHeight
      renderer.setSize(w, h)
    }
    const ro = new ResizeObserver(resize)
    ro.observe(el)
    resize()

    let visible = true
    const io = new IntersectionObserver(([e]) => { visible = e.isIntersecting }, { threshold: 0 })
    io.observe(el)

    const t0 = performance.now()
    let raf = 0
    const frame = (now: number) => {
      raf = requestAnimationFrame(frame)
      if (!visible && !still) return
      const i = input.current
      const dpr = renderer.dpr
      const u = program.uniforms
      u.uRes.value = [w * dpr, h * dpr]
      u.uDpr.value = dpr
      u.uTime.value = still ? 6.0 : (now - t0) / 1000
      u.uCenter.value = [i.cx * dpr, (h - i.cy) * dpr]
      u.uUnit.value = i.unit * dpr
      u.uOpen.value = i.open
      u.uAim.value = i.aim
      u.uPulse.value = i.pulseAt ? (now - i.pulseAt) / 1000 : 99
      u.uMouse.value = [i.mx * dpr, (h - i.my) * dpr]
      renderer.render({ scene: mesh })
      if (still) cancelAnimationFrame(raf)
    }
    raf = requestAnimationFrame(frame)

    return () => {
      cancelAnimationFrame(raf); ro.disconnect(); io.disconnect()
      gl.getExtension('WEBGL_lose_context')?.loseContext()
      gl.canvas.remove()
    }
  }, [input, still])

  return (
    <div ref={host} className={className} aria-hidden
      style={{ position: 'absolute', inset: 0, background: 'radial-gradient(circle at 66% 50%, rgba(255,90,31,.35), transparent 40%), #050507' }} />
  )
}
