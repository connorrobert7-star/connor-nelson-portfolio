'use client'

import { useState, useEffect, useCallback } from 'react'

const bootMessages = [
  { text: 'CONNOR NELSON FILMS \u2014 SYSTEM v2.0', hl: true },
  { text: 'Copyright (C) 2024-2026', hl: false },
  { text: '', hl: false },
  { text: 'Initializing film archive... OK', hl: false },
  { text: 'Loading codec library... OK', hl: false },
  { text: 'Mounting /dev/16mm... OK', hl: false },
  { text: 'Scanning field recordings... 847 files', hl: false },
  { text: '', hl: false },
  { text: 'C:\\FILMS> map --connect-all', hl: true },
  { text: '', hl: false },
  { text: 'Mapping neural connections...', hl: true },
]

export default function Win95Boot({ onComplete }: { onComplete: () => void }) {
  const [lines, setLines] = useState<typeof bootMessages>([])
  const [progress, setProgress] = useState(0)
  const [showProgress, setShowProgress] = useState(false)
  const [phase, setPhase] = useState<'typing' | 'progress' | 'flash' | 'done'>('typing')

  const finish = useCallback(() => {
    if (phase === 'flash' || phase === 'done') return
    setPhase('flash')
    setTimeout(() => {
      setPhase('done')
      onComplete()
    }, 150)
  }, [phase, onComplete])

  // Type out lines
  useEffect(() => {
    if (phase !== 'typing') return
    let i = 0
    const timer = setInterval(() => {
      if (i >= bootMessages.length) {
        clearInterval(timer)
        setShowProgress(true)
        setPhase('progress')
        return
      }
      const msg = bootMessages[i]
      i++
      setLines((prev) => [...prev, msg])
    }, 100)
    return () => clearInterval(timer)
  }, [phase])

  // Progress bar
  useEffect(() => {
    if (phase !== 'progress') return
    const timer = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          clearInterval(timer)
          finish()
          return 100
        }
        return prev + 5
      })
    }, 30)
    return () => clearInterval(timer)
  }, [phase, finish])

  return (
    <div
      className="win95-boot"
      onClick={finish}
      style={{
        background: phase === 'flash' ? '#fafafa' : '#000',
        transition: phase === 'flash' ? 'background 0.1s' : 'none',
      }}
    >
      {phase !== 'flash' && phase !== 'done' && (
        <>
          {lines.map((line, i) => (
            <div key={i} className={`win95-boot-line ${line.hl ? 'highlight' : ''}`}>
              {line.text}
            </div>
          ))}

          {showProgress && (
            <div style={{ marginTop: '12px' }}>
              <div className="win95-boot-line highlight">Starting...</div>
              <div className="win95-boot-progress">
                <div className="win95-boot-progress-fill" style={{ width: `${progress}%` }} />
              </div>
            </div>
          )}

          <span className="win95-boot-cursor">_</span>

          <div style={{
            position: 'absolute',
            bottom: '24px',
            right: '24px',
            color: '#333',
            fontSize: '10px',
            fontFamily: 'var(--font-mono)',
          }}>
            click to skip
          </div>
        </>
      )}
    </div>
  )
}
