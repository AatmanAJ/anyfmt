/**
 * Streaks: soft red-orange light streaks burning in from a corner, like light thrown through
 * ribbed glass and caught out of focus. Each streak is a Gaussian ridge with its own width,
 * strength and reach, a thin warm specular edge, and a slow breath. They ignite outward on load,
 * part around the pointer, and the field outputs premultiplied alpha so it sits on any background.
 */

import { useEffect, useRef } from 'react'

const VERT = `attribute vec2 a;void main(){gl_Position=vec4(a,0.,1.);}`

const FRAG = `
precision highp float;
uniform vec2 uRes;
uniform float uTime;
uniform float uIntro;     // 0 → 1 ignition
uniform vec3 uMouse;      // xy in field units, z presence
uniform vec2 uCorner;     // 1,1 = top right, 0,0 = bottom left
uniform float uScale;     // streak spacing scale
uniform float uReach;     // overall reach
uniform float uDark;      // 1 on dark backgrounds: deeper core, no white haze

float hash(float n){ return fract(sin(n * 127.1) * 43758.5453); }
float hash2(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(float x){ float i = floor(x), f = fract(x); f = f*f*(3.-2.*f); return mix(hash(i), hash(i+1.), f); }

vec3 palette(float v){
  vec3 c = vec3(1.0, 0.80, 0.76);                                   // pink haze
  c = mix(c, vec3(1.0, 0.56, 0.26), smoothstep(0.10, 0.34, v));     // orange
  c = mix(c, vec3(1.0, 0.25, 0.08), smoothstep(0.26, 0.54, v));     // red orange
  c = mix(c, vec3(0.96, 0.07, 0.04), smoothstep(0.50, 0.88, v));    // deep red
  return c;
}

void main(){
  float aspect = uRes.x / uRes.y;
  vec2 p = gl_FragCoord.xy / uRes.y;                                // y 0..1, x 0..aspect
  vec2 corner = vec2(uCorner.x * aspect, uCorner.y);
  vec2 q = p - corner;
  // mirror so the math always reads from a top right corner
  q.x *= uCorner.x > 0.5 ? 1.0 : -1.0;
  q.y *= uCorner.y > 0.5 ? 1.0 : -1.0;

  float ang = 0.50;                                                  // streak tilt from vertical
  vec2 dir = vec2(sin(ang), cos(ang));
  vec2 nrm = vec2(cos(ang), -sin(ang));
  float along = -dot(q, dir);                                        // distance from the corner along a streak
  float across = dot(q, nrm);

  // pointer: streaks part around it like a hand passing over ribbed glass
  vec2 m = uMouse.xy - corner;
  m.x *= uCorner.x > 0.5 ? 1.0 : -1.0;
  m.y *= uCorner.y > 0.5 ? 1.0 : -1.0;
  vec2 dm = q - m;
  float md = length(dm);
  float bend = uMouse.z * exp(-md * md / 0.035);
  across += bend * 0.07 * sign(dot(dm, nrm) + 1e-4) * smoothstep(0.0, 0.12, md);

  // a slow sway along each streak
  across += 0.012 * sin(along * 4.0 + uTime * 0.35);

  float P = 0.088 * uScale;
  float idx = floor(across / P);
  float sum = 0.0, spec = 0.0, haze = 0.0;
  for (int k = -2; k <= 2; k++) {
    float i = idx + float(k);
    float h1 = hash(i * 1.37 + 3.1), h2 = hash(i * 2.11 + 7.7), h3 = hash(i * 0.73 + 1.9);
    float center = (i + 0.5 + (h1 - 0.5) * 0.5) * P + 0.01 * sin(uTime * 0.25 + h2 * 6.28);
    float w = P * mix(0.26, 0.58, h2);
    float amp = mix(0.7, 1.25, h3) * (0.82 + 0.18 * sin(uTime * 0.45 + h1 * 6.28));
    float reach = uReach * mix(0.7, 1.35, h1) * (0.94 + 0.06 * sin(uTime * 0.3 + h3 * 6.28));
    reach *= uIntro * (0.6 + 0.4 * smoothstep(0.0, 1.0, uIntro + h2 * 0.3 - 0.3));
    float d = (across - center) / w;
    float tail = 1.0 - smoothstep(reach * 0.3, reach, along);
    tail *= smoothstep(-0.25, 0.08, along);                          // fade past the corner edge
    // uneven brightness along the streak, like light through imperfect glass
    float flick = 0.75 + 0.25 * vnoise(along * 6.0 + i * 3.7 - uTime * 0.4);
    float ridge = exp(-d * d) * amp * tail * flick;
    sum += ridge;
    // thin warm specular edge on the leading side
    float e = (across - (center - w * 1.05)) / (P * 0.035);
    spec += exp(-e * e) * tail * mix(0.35, 1.0, h3) * flick * step(0.35, h2);
    haze += exp(-d * d * 0.2) * tail * 0.32;
  }

  // envelope: the field lives in the corner and falls away down and left
  float env = smoothstep(-0.86 * uReach, -0.38 * uReach, across) * smoothstep(0.56 * uReach, 0.2 * uReach, across);
  float v = 1.0 - exp(-(sum * 1.2 + haze * 0.45) * env * 1.35);   // tone map: overlaps deepen, never clip flat
  float hz = clamp(haze * env, 0.0, 1.0);
  float sp = clamp(spec * env, 0.0, 1.0);

  vec3 col = palette(v);
  col = mix(col, vec3(1.0, 0.95, 0.84), sp * (0.9 - uDark * 0.3));    // pale gold edge
  float alpha = clamp(max(v * 1.5, hz * 0.7), 0.0, 1.0);
  alpha = max(alpha, sp * 0.9);
  if (uDark > 0.5) { col *= mix(0.55, 1.0, smoothstep(0.0, 0.6, v)); }

  // grain to keep the gradients from banding
  float g = (hash2(gl_FragCoord.xy + fract(uTime) * 91.0) - 0.5) * 0.035;
  col = clamp(col + g, 0.0, 1.0);
  gl_FragColor = vec4(col * alpha, alpha);
}`

export interface StreaksProps {
  className?: string
  corner?: 'tr' | 'bl' | 'br' | 'tl'
  scale?: number
  reach?: number
  dark?: boolean
}

export function Streaks({ className = '', corner = 'tr', scale = 1, reach = 1, dark = false }: StreaksProps) {
  const ref = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = ref.current
    if (!canvas) return
    const gl = canvas.getContext('webgl', { premultipliedAlpha: true, alpha: true, antialias: false })
    if (!gl) return
    const sh = (type: number, src: string) => { const s = gl.createShader(type)!; gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) console.error(gl.getShaderInfoLog(s)); return s }
    const prog = gl.createProgram()!
    gl.attachShader(prog, sh(gl.VERTEX_SHADER, VERT))
    gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FRAG))
    gl.linkProgram(prog)
    gl.useProgram(prog)
    const buf = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buf)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW)
    const loc = gl.getAttribLocation(prog, 'a')
    gl.enableVertexAttribArray(loc)
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0)
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    const U = (n: string) => gl.getUniformLocation(prog, n)
    const uRes = U('uRes'), uTime = U('uTime'), uIntro = U('uIntro'), uMouse = U('uMouse')
    gl.uniform2f(U('uCorner'), corner.includes('r') ? 1 : 0, corner.includes('t') ? 1 : 0)
    gl.uniform1f(U('uScale'), scale)
    gl.uniform1f(U('uReach'), reach)
    gl.uniform1f(U('uDark'), dark ? 1 : 0)

    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let raf = 0, inView = true, visible = !document.hidden
    const start = performance.now()
    const mouse = { x: 0, y: 0, z: 0, tx: 0, ty: 0, tz: 0 }
    let rect = canvas.getBoundingClientRect()

    const resize = () => {
      rect = canvas.getBoundingClientRect()
      const dpr = Math.min(window.devicePixelRatio || 1, 1.5)
      let w = Math.max(1, Math.round(rect.width * dpr)), h = Math.max(1, Math.round(rect.height * dpr))
      const cap = Math.min(1, Math.sqrt(1_800_000 / (w * h)))
      w = Math.round(w * cap); h = Math.round(h * cap)
      if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; gl.viewport(0, 0, w, h) }
    }
    const onMove = (e: PointerEvent) => {
      rect = canvas.getBoundingClientRect()
      const inside = e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom
      mouse.tz = inside && e.pointerType === 'mouse' ? 1 : 0
      mouse.tx = (e.clientX - rect.left) / rect.height
      mouse.ty = 1 - (e.clientY - rect.top) / rect.height
    }
    const frame = (now: number) => {
      raf = 0
      if (!inView || !visible) return
      resize()
      const t = (now - start) / 1000
      const intro = reduce ? 1 : Math.min(1, t / 2.2)
      const k = 0.08
      mouse.x += (mouse.tx - mouse.x) * k; mouse.y += (mouse.ty - mouse.y) * k; mouse.z += (mouse.tz - mouse.z) * 0.05
      gl.uniform2f(uRes, canvas.width, canvas.height)
      gl.uniform1f(uTime, reduce ? 4 : t)
      gl.uniform1f(uIntro, 1 - (1 - intro) ** 3)
      gl.uniform3f(uMouse, mouse.x, mouse.y, mouse.z)
      gl.clearColor(0, 0, 0, 0)
      gl.clear(gl.COLOR_BUFFER_BIT)
      gl.drawArrays(gl.TRIANGLES, 0, 3)
      if (!reduce || intro < 1) raf = requestAnimationFrame(frame)
    }
    const kick = () => { if (!raf) raf = requestAnimationFrame(frame) }
    const io = new IntersectionObserver(([e]) => { inView = e.isIntersecting; if (inView) kick() })
    io.observe(canvas)
    const onVis = () => { visible = !document.hidden; if (visible) kick() }
    document.addEventListener('visibilitychange', onVis)
    window.addEventListener('pointermove', onMove, { passive: true })
    const ro = new ResizeObserver(() => { resize(); kick() })
    ro.observe(canvas)
    kick()
    return () => {
      cancelAnimationFrame(raf); io.disconnect(); ro.disconnect()
      document.removeEventListener('visibilitychange', onVis)
      window.removeEventListener('pointermove', onMove)
      gl.deleteBuffer(buf); gl.deleteProgram(prog)
    }
  }, [corner, scale, reach, dark])

  return <canvas ref={ref} aria-hidden className={className} style={{ display: 'block', width: '100%', height: '100%' }} />
}
