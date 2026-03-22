'use client'

import { useState, useEffect, useCallback } from 'react'

interface Project {
  slug: string
  title: string
  medium: string
  year: string
  description: string
  accentColor?: string
}

export default function DemoReel({ projects }: { projects: Project[] }) {
  const [currentIndex, setCurrentIndex] = useState(0)
  const [playing, setPlaying] = useState(true)
  const [progress, setProgress] = useState(0)
  const DURATION = 5000 // ms per card

  // Auto-advance
  useEffect(() => {
    if (!playing || projects.length === 0) return
    const start = Date.now()
    const timer = setInterval(() => {
      const elapsed = Date.now() - start
      const pct = Math.min(100, (elapsed / DURATION) * 100)
      setProgress(pct)
      if (elapsed >= DURATION) {
        setCurrentIndex((prev) => (prev + 1) % projects.length)
        setProgress(0)
        clearInterval(timer)
      }
    }, 50)
    return () => clearInterval(timer)
  }, [playing, currentIndex, projects.length])

  const togglePlay = useCallback(() => {
    setPlaying((p) => !p)
  }, [])

  const goNext = useCallback(() => {
    setCurrentIndex((prev) => (prev + 1) % projects.length)
    setProgress(0)
  }, [projects.length])

  const goPrev = useCallback(() => {
    setCurrentIndex((prev) => (prev - 1 + projects.length) % projects.length)
    setProgress(0)
  }, [projects.length])

  if (projects.length === 0) return null
  const current = projects[currentIndex]

  return (
    <div className="demo-reel">
      {/* Background color wash per project */}
      {projects.map((p, i) => (
        <div
          key={p.slug}
          className={`demo-reel-card ${i !== currentIndex ? 'hidden' : ''}`}
        >
          <div
            className="demo-reel-bg"
            style={{
              background: `radial-gradient(ellipse at 25% 30%, ${p.accentColor || '#333'} 0%, transparent 55%),
                           radial-gradient(ellipse at 75% 70%, ${p.accentColor || '#333'} 0%, transparent 60%)`,
            }}
          />
          <div className="demo-reel-gradient" />

          {/* Info */}
          <div style={{ position: 'relative', zIndex: 1 }}>
            <div className="demo-reel-year">{p.year}</div>
            <div className="demo-reel-title">{p.title}</div>
            <div className="demo-reel-medium">{p.medium}</div>
            <div className="demo-reel-desc">{p.description}</div>
          </div>
        </div>
      ))}

      {/* REC indicator */}
      <div className="demo-reel-rec">
        <span className="demo-reel-rec-dot" />
        {playing ? 'PLAYING' : 'PAUSED'}
      </div>

      {/* Counter */}
      <div className="demo-reel-counter">
        {String(currentIndex + 1).padStart(2, '0')} / {String(projects.length).padStart(2, '0')}
      </div>

      {/* Transport controls */}
      <div className="demo-reel-transport">
        <button className="demo-reel-play-btn" onClick={goPrev}>
          {'|<'}
        </button>
        <button className="demo-reel-play-btn" onClick={togglePlay}>
          {playing ? '||' : '\u25B6'}
        </button>
        <button className="demo-reel-play-btn" onClick={goNext}>
          {'>|'}
        </button>
        <div className="demo-reel-progress">
          <div
            className="demo-reel-progress-fill"
            style={{ width: `${progress}%` }}
          />
        </div>
        <div className="demo-reel-time">
          {String(currentIndex + 1).padStart(2, '0')}:{String(Math.floor(progress / 100 * 5)).padStart(2, '0')}
        </div>
      </div>
    </div>
  )
}
