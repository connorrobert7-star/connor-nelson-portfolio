'use client'

import { useRef, useEffect } from 'react'

const BASE_GRID = 8
const FONT = 7
const RADIUS = 80
const PUSH = 500
const FRICTION = 0.88
const SPRING = 0.06
const CHARS = '.:-=+*#%@'
const MAX_PARTICLES = 4000

const IMAGES = [
  { src: '/photos/golden-spiral.jpg', w: 900, h: 600, invert: true, threshold: 160 },
]

interface Particle {
  homeX: number
  homeY: number
  x: number
  y: number
  vx: number
  vy: number
  ci: number // character index into atlas
}

export default function AsciiBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const mouseRef = useRef({ x: -9999, y: -9999 })
  const rafRef = useRef<number>(0)
  const particlesRef = useRef<Particle[]>([])
  const prevSizeRef = useRef({ w: 0, h: 0 })

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d', { alpha: true })
    if (!ctx) return

    let destroyed = false

    // Pre-render character atlas for performance
    const atlasSize = FONT + 4
    const charAtlases: HTMLCanvasElement[] = []
    for (let i = 0; i < CHARS.length; i++) {
      const c = document.createElement('canvas')
      c.width = atlasSize * 2
      c.height = atlasSize * 2
      const ac = c.getContext('2d')!
      ac.fillStyle = 'rgb(255, 255, 255)'
      ac.font = `${FONT}px monospace`
      ac.textBaseline = 'middle'
      ac.textAlign = 'center'
      ac.fillText(CHARS[i], atlasSize, atlasSize)
      charAtlases.push(c)
    }
    const atlasHalf = atlasSize

    const offscreen = document.createElement('canvas')
    const offCtx = offscreen.getContext('2d')!

    const imgs: HTMLImageElement[] = IMAGES.map(cfg => {
      const img = new Image()
      img.crossOrigin = 'anonymous'
      img.src = cfg.src
      return img
    })

    let loadedCount = 0

    function sampleImage(
      img: HTMLImageElement,
      cfg: typeof IMAGES[0],
      grid: number,
    ): Particle[] {
      const particles: Particle[] = []
      const w = cfg.w
      const h = cfg.h

      offscreen.width = w
      offscreen.height = h
      offCtx.clearRect(0, 0, w, h)

      const scale = Math.min(w / img.naturalWidth, h / img.naturalHeight)
      const dw = img.naturalWidth * scale
      const dh = img.naturalHeight * scale
      const ox = (w - dw) / 2
      const oy = (h - dh) / 2
      offCtx.drawImage(img, ox, oy, dw, dh)

      const data = offCtx.getImageData(0, 0, w, h)

      for (let py = 0; py < h; py += grid) {
        for (let px = 0; px < w; px += grid) {
          const i = (py * w + px) * 4
          const r = data.data[i]
          const g = data.data[i + 1]
          const b = data.data[i + 2]
          const a = data.data[i + 3]

          if (a < 64) continue

          const brightness = 0.299 * r + 0.587 * g + 0.114 * b

          if (cfg.invert) {
            if (brightness > cfg.threshold) continue
            const darkness = 1 - brightness / cfg.threshold
            const ci = Math.min(CHARS.length - 1, Math.floor(darkness * CHARS.length))
            particles.push({ homeX: px, homeY: py, x: px, y: py, vx: 0, vy: 0, ci })
          } else {
            if (brightness < (255 - cfg.threshold)) continue
            const lightness = (brightness - (255 - cfg.threshold)) / cfg.threshold
            const ci = Math.min(CHARS.length - 1, Math.floor(lightness * CHARS.length))
            particles.push({ homeX: px, homeY: py, x: px, y: py, vx: 0, vy: 0, ci })
          }
        }
      }
      return particles
    }

    function buildAll() {
      if (!canvas || !ctx) return
      const dpr = window.devicePixelRatio || 1
      const container = canvas.parentElement
      if (!container) return
      const rect = container.getBoundingClientRect()
      const rw = Math.round(rect.width)
      const rh = Math.round(rect.height)

      // Skip rebuild if size unchanged
      if (rw === prevSizeRef.current.w && rh === prevSizeRef.current.h && particlesRef.current.length > 0) return
      prevSizeRef.current = { w: rw, h: rh }

      canvas.width = rw * dpr
      canvas.height = rh * dpr
      canvas.style.width = `${rw}px`
      canvas.style.height = `${rh}px`
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

      // Auto-increase grid if too many particles
      let grid = BASE_GRID
      let allParticles: Particle[] = []

      for (let attempt = 0; attempt < 5; attempt++) {
        allParticles = []
        for (let idx = 0; idx < imgs.length; idx++) {
          const img = imgs[idx]
          if (!img.complete || img.naturalWidth === 0) continue
          allParticles.push(...sampleImage(img, IMAGES[idx], grid))
        }
        if (allParticles.length <= MAX_PARTICLES) break
        grid++
      }

      particlesRef.current = allParticles
    }

    function onImageLoad() {
      loadedCount++
      if (!destroyed) buildAll()
    }

    imgs.forEach(img => {
      img.onload = onImageLoad
      if (img.complete && img.naturalWidth > 0) loadedCount++
    })

    if (loadedCount > 0) buildAll()

    const handleResize = () => {
      prevSizeRef.current = { w: 0, h: 0 } // force rebuild
      buildAll()
    }

    const handleMouseMove = (e: MouseEvent) => {
      const rect = canvas.getBoundingClientRect()
      mouseRef.current = { x: e.clientX - rect.left, y: e.clientY - rect.top }
    }

    const draw = () => {
      if (destroyed) return
      const container = canvas.parentElement
      if (!container) { rafRef.current = requestAnimationFrame(draw); return }
      const rect = container.getBoundingClientRect()
      const w = rect.width
      const h = rect.height

      ctx.clearRect(0, 0, w, h)
      ctx.globalAlpha = 0.7

      const mx = mouseRef.current.x
      const my = mouseRef.current.y
      const rSq = RADIUS * RADIUS
      const particles = particlesRef.current

      for (let i = 0; i < particles.length; i++) {
        const p = particles[i]

        // Skip physics for stationary particles far from mouse
        const distHomeX = p.x - p.homeX
        const distHomeY = p.y - p.homeY
        const dx = p.x - mx
        const dy = p.y - my
        const dSq = dx * dx + dy * dy
        const isNearMouse = dSq < rSq

        if (!isNearMouse && distHomeX * distHomeX + distHomeY * distHomeY < 0.5 && p.vx * p.vx + p.vy * p.vy < 0.01) {
          // Stationary — just draw at home, skip physics
          p.x = p.homeX
          p.y = p.homeY
          ctx.drawImage(charAtlases[p.ci], p.x - atlasHalf, p.y - atlasHalf)
          continue
        }

        if (isNearMouse && dSq > 0.1) {
          const d = Math.sqrt(dSq)
          p.vx += (dx / d) * PUSH / d
          p.vy += (dy / d) * PUSH / d
        }

        p.vx += (p.homeX - p.x) * SPRING
        p.vy += (p.homeY - p.y) * SPRING
        p.vx *= FRICTION
        p.vy *= FRICTION
        p.x += p.vx
        p.y += p.vy

        ctx.drawImage(charAtlases[p.ci], p.x - atlasHalf, p.y - atlasHalf)
      }

      ctx.globalAlpha = 1.0
      rafRef.current = requestAnimationFrame(draw)
    }

    rafRef.current = requestAnimationFrame(draw)
    window.addEventListener('resize', handleResize)
    document.addEventListener('mousemove', handleMouseMove)

    return () => {
      destroyed = true
      cancelAnimationFrame(rafRef.current)
      window.removeEventListener('resize', handleResize)
      document.removeEventListener('mousemove', handleMouseMove)
    }
  }, [])

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 28,
        left: 0,
        width: 900,
        height: 600,
        margin: 0,
        padding: 0,
        zIndex: 0,
        pointerEvents: 'none',
        overflow: 'visible',
      }}
      aria-hidden="true"
    >
      <canvas ref={canvasRef} style={{ display: 'block', width: '100%', height: '100%' }} />
    </div>
  )
}
