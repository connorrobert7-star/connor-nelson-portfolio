'use client'

import { useRef, useEffect, useState, useCallback } from 'react'

interface Win95WindowProps {
  id: string
  title: string
  icon?: string
  position: { x: number; y: number }
  size: { width: number; height: number }
  zIndex: number
  phase: 'loading' | 'ready'
  minimized: boolean
  maximized?: boolean
  focused?: boolean
  loadingLines?: string[]
  onClose: () => void
  onMinimize: () => void
  onMaximize?: () => void
  onFocus: () => void
  onMove: (x: number, y: number) => void
  children: React.ReactNode
}

export default function Win95Window({
  title,
  icon,
  position,
  size,
  zIndex,
  phase,
  minimized,
  maximized = false,
  focused = false,
  loadingLines = [],
  onClose,
  onMinimize,
  onMaximize,
  onFocus,
  onMove,
  children,
}: Win95WindowProps) {
  const dragRef = useRef<{
    startX: number
    startY: number
    origX: number
    origY: number
  } | null>(null)

  // Loading terminal animation
  const [visibleLines, setVisibleLines] = useState<string[]>([])

  useEffect(() => {
    if (phase !== 'loading') return
    setVisibleLines([])
    let i = 0
    const timer = setInterval(() => {
      if (i >= loadingLines.length) {
        clearInterval(timer)
        return
      }
      setVisibleLines((prev) => [...prev, loadingLines[i]])
      i++
    }, 150)
    return () => clearInterval(timer)
  }, [phase, loadingLines])

  const handleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      onFocus()
      dragRef.current = {
        startX: e.clientX,
        startY: e.clientY,
        origX: position.x,
        origY: position.y,
      }
      e.preventDefault()
    },
    [position, onFocus],
  )

  const handleTouchStart = useCallback(
    (e: React.TouchEvent) => {
      onFocus()
      const touch = e.touches[0]
      dragRef.current = {
        startX: touch.clientX,
        startY: touch.clientY,
        origX: position.x,
        origY: position.y,
      }
    },
    [position, onFocus],
  )

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!dragRef.current) return
      onMove(
        dragRef.current.origX + (e.clientX - dragRef.current.startX),
        dragRef.current.origY + (e.clientY - dragRef.current.startY),
      )
    }
    const handleTouchMove = (e: TouchEvent) => {
      if (!dragRef.current) return
      const touch = e.touches[0]
      onMove(
        dragRef.current.origX + (touch.clientX - dragRef.current.startX),
        dragRef.current.origY + (touch.clientY - dragRef.current.startY),
      )
    }
    const handleEnd = () => {
      dragRef.current = null
    }

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseup', handleEnd)
    window.addEventListener('touchmove', handleTouchMove)
    window.addEventListener('touchend', handleEnd)
    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleEnd)
      window.removeEventListener('touchmove', handleTouchMove)
      window.removeEventListener('touchend', handleEnd)
    }
  }, [onMove])

  if (minimized) return null

  return (
    <div
      className={`win95-window ${focused ? 'focused' : ''}`}
      style={{
        position: maximized ? 'absolute' : 'absolute',
        left: maximized ? 0 : position.x,
        top: maximized ? 0 : position.y,
        width: maximized ? '100%' : size.width,
        height: maximized ? 'calc(100% - 28px)' : size.height,
        maxWidth: maximized ? undefined : 'calc(100vw - 8px)',
        maxHeight: maximized ? undefined : 'calc(100vh - 36px)',
        overflow: 'hidden',
        zIndex,
      }}
      onMouseDown={() => onFocus()}
    >
      <div
        className="win95-titlebar"
        onMouseDown={maximized ? undefined : handleMouseDown}
        onTouchStart={maximized ? undefined : handleTouchStart}
        onDoubleClick={() => onMaximize?.()}
      >
        {icon && <span className="win95-titlebar-icon">{icon}</span>}
        <span className="win95-titlebar-text">{title}</span>
        <div className="win95-titlebar-buttons">
          <button
            onClick={(e) => {
              e.stopPropagation()
              onMinimize()
            }}
            aria-label="Minimize"
          >
            _
          </button>
          <button
            aria-label="Maximize"
            onClick={(e) => {
              e.stopPropagation()
              onMaximize?.()
            }}
          >
            {maximized ? '❐' : '□'}
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation()
              onClose()
            }}
            aria-label="Close"
          >
            x
          </button>
        </div>
      </div>

      <div className="win95-menu-bar">
        <span>File</span>
        <span>Edit</span>
        <span>View</span>
        <span>Help</span>
      </div>

      <div className="win95-content">
        <div className="win95-content-inset" />
        {phase === 'loading' ? (
          <div className="win95-loading-terminal">
            {visibleLines.map((line, i) => (
              <div key={i} className="win95-loading-line">{line}</div>
            ))}
            <span className="win95-loading-cursor">_</span>
          </div>
        ) : (
          children
        )}
      </div>
    </div>
  )
}
