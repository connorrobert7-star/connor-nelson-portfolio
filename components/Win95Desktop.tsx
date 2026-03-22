'use client'

import { useState, useCallback, useEffect, useReducer, useRef } from 'react'
import Win95Boot from './Win95Boot'
import Win95Window from './Win95Window'
import DemoReel from './DemoReel'

// ── Types ──

interface Project {
  slug: string
  title: string
  medium: string
  year: string
  description: string
  content: string
  runtime?: string
  accentColor?: string
}

interface Post {
  slug: string
  title: string
  date: string
  category: string
  excerpt: string
  content: string
}

interface WindowState {
  id: string
  type: string
  title: string
  icon: string
  position: { x: number; y: number }
  size: { width: number; height: number }
  zIndex: number
  phase: 'loading' | 'ready'
  minimized: boolean
}

interface IconState {
  id: string
  label: string
  icon: string
  type: string
  x: number
  y: number
}

type Action =
  | { type: 'OPEN_WINDOW'; payload: Omit<WindowState, 'zIndex' | 'phase'> & { phase?: 'loading' | 'ready' } }
  | { type: 'CLOSE_WINDOW'; id: string }
  | { type: 'FOCUS_WINDOW'; id: string }
  | { type: 'MINIMIZE_WINDOW'; id: string }
  | { type: 'MOVE_WINDOW'; id: string; x: number; y: number }
  | { type: 'SET_READY'; id: string }

// ── Code snippets for loading animations ──

const loadingCodeBank: Record<string, string[]> = {
  films: [
    "C:\\FILMS> dir /s",
    "import { load } from './archive'",
    "scanning ./rushes/...",
    "loading film metadata...",
    "found 3 projects",
    "indexing complete.",
  ],
  about: [
    "C:\\> type README.md",
    "cat ~/README.md",
    "parsing bio.txt...",
    "loading profile data...",
    "done.",
  ],
  writing: [
    "C:\\WRITING> dir *.md",
    "ls ./posts/*.md",
    "found 2 entries",
    "parsing frontmatter...",
    "ready.",
  ],
  contact: [
    "C:\\> ping vimeo.com",
    "nslookup vimeo.com",
    "establishing connections...",
    "resolving endpoints...",
    "links ready.",
  ],
  demoReel: [
    "C:\\REEL> play reel.mp4",
    "ffmpeg -i reel.mp4 -c copy -loop 1",
    "buffering stream...",
    "streaming...",
  ],
  influences: [
    "C:\\> type influences.dat",
    'ref.cite("Pulse", 2001)',
    'ref.cite("Inland Empire", 2006)',
    "loading references...",
    "4 entries loaded.",
  ],
  process: [
    "C:\\TOOLS> scan --init",
    "scan --resolution 4k --format dpx",
    "initializing pipeline...",
    "calibrating...",
    "ready.",
  ],
  project: [
    "C:\\FILMS> type project.md",
    "loading project data...",
    "parsing markdown content...",
    "rendering...",
    "done.",
  ],
  minesweeper: [
    "C:\\WINDOWS> winmine.exe",
    "loading minefield...",
    "placing 10 mines...",
    "generating grid...",
    "ready to play.",
  ],
  internet: [
    "C:\\WINDOWS> iexplore.exe",
    "Connecting to dial-up...",
    "AT&T WorldNet dialing...",
    "CONNECT 56000",
    "Loading homepage...",
    "Connected.",
  ],
  notepad: [
    "C:\\WINDOWS> notepad.exe",
    "loading editor...",
    "ready.",
  ],
  recyclebin: [
    "C:\\> dir /s RECYCLER",
    "scanning deleted items...",
    "0 items found.",
    "bin is empty.",
  ],
}

// ── Reducer ──

function windowReducer(state: WindowState[], action: Action): WindowState[] {
  switch (action.type) {
    case 'OPEN_WINDOW': {
      // If window already open, just focus it
      const existing = state.find((w) => w.id === action.payload.id)
      if (existing) {
        const maxZ = Math.max(...state.map((w) => w.zIndex), 0)
        return state.map((w) =>
          w.id === action.payload.id
            ? { ...w, minimized: false, zIndex: maxZ + 1 }
            : w
        )
      }
      const maxZ = Math.max(...state.map((w) => w.zIndex), 0)
      return [
        ...state,
        {
          ...action.payload,
          phase: action.payload.phase ?? 'loading',
          zIndex: maxZ + 1,
        },
      ]
    }
    case 'CLOSE_WINDOW':
      return state.filter((w) => w.id !== action.id)
    case 'FOCUS_WINDOW': {
      const maxZ = Math.max(...state.map((w) => w.zIndex), 0)
      return state.map((w) =>
        w.id === action.id ? { ...w, zIndex: maxZ + 1, minimized: false } : w
      )
    }
    case 'MINIMIZE_WINDOW':
      return state.map((w) =>
        w.id === action.id ? { ...w, minimized: !w.minimized } : w
      )
    case 'MOVE_WINDOW':
      return state.map((w) =>
        w.id === action.id ? { ...w, position: { x: action.x, y: action.y } } : w
      )
    case 'SET_READY':
      return state.map((w) =>
        w.id === action.id ? { ...w, phase: 'ready' as const } : w
      )
    default:
      return state
  }
}

// ── Desktop icon definitions ──

const defaultIcons: Omit<IconState, 'x' | 'y'>[] = [
  { id: 'films', label: 'My Films', icon: '\uD83C\uDFAC', type: 'films' },
  { id: 'about', label: 'About Me', icon: '\uD83D\uDCDD', type: 'about' },
  { id: 'writing', label: 'Writing', icon: '\uD83D\uDCD6', type: 'writing' },
  { id: 'contact', label: 'Contact', icon: '\uD83D\uDCE7', type: 'contact' },
  { id: 'demoReel', label: 'Demo Reel', icon: '\uD83D\uDCFC', type: 'demoReel' },
  { id: 'influences', label: 'Influences', icon: '\uD83C\uDFAD', type: 'influences' },
  { id: 'process', label: 'Process', icon: '\uD83D\uDD27', type: 'process' },
  { id: 'minesweeper', label: 'Minesweeper', icon: '\uD83D\uDCA3', type: 'minesweeper' },
  { id: 'internet', label: 'Internet', icon: '\uD83C\uDF10', type: 'internet' },
  { id: 'notepad', label: 'Notepad', icon: '\uD83D\uDCC4', type: 'notepad' },
  { id: 'recyclebin', label: 'Recycle Bin', icon: '\uD83D\uDDD1\uFE0F', type: 'recyclebin' },
]

function initIcons(): IconState[] {
  const colHeight = 7 // icons per column before wrapping
  return defaultIcons.map((ic, i) => ({
    ...ic,
    x: 12 + Math.floor(i / colHeight) * 80,
    y: 12 + (i % colHeight) * 76,
  }))
}

// ── Window configs ──

function getWindowConfig(type: string, id: string, label: string, icon: string, cascadeIndex: number) {
  const baseX = 80 + cascadeIndex * 30
  const baseY = 40 + cascadeIndex * 30

  const configs: Record<string, { title: string; size: { width: number; height: number } }> = {
    films: { title: 'My Films', size: { width: 400, height: 350 } },
    about: { title: 'About Me - Notepad', size: { width: 420, height: 340 } },
    writing: { title: 'Writing', size: { width: 400, height: 300 } },
    contact: { title: 'Contact', size: { width: 340, height: 220 } },
    demoReel: { title: 'Demo Reel', size: { width: 300, height: 220 } },
    influences: { title: 'Influences', size: { width: 350, height: 280 } },
    process: { title: 'Process & Tools', size: { width: 350, height: 280 } },
    minesweeper: { title: 'Minesweeper', size: { width: 280, height: 340 } },
    internet: { title: 'Internet Explorer', size: { width: 500, height: 400 } },
    notepad: { title: 'Untitled - Notepad', size: { width: 400, height: 300 } },
    recyclebin: { title: 'Recycle Bin', size: { width: 300, height: 200 } },
  }

  const cfg = configs[type] || { title: label, size: { width: 400, height: 350 } }

  return {
    id,
    type,
    title: cfg.title,
    icon,
    position: { x: baseX, y: baseY },
    size: cfg.size,
    minimized: false,
  }
}

// ── Connection rules ──

const connectionRules = [
  { a: 'films', b: 'demoReel', code: "stream('./reel.mp4')" },
  { a: 'films', b: 'project-twenty-mile-road', code: "load('./twenty_mile_road')" },
  { a: 'films', b: 'project-dead-on-tv', code: "load('./dead_on_tv')" },
  { a: 'films', b: 'project-everywhere-you-go', code: "load('./everywhere_you_go')" },
  { a: 'about', b: 'influences', code: "ref.cite('influences.dat')" },
  { a: 'films', b: 'process', code: "scan --pipeline init" },
]

// ── Minesweeper Game ──

function MinesweeperGame() {
  const ROWS = 9
  const COLS = 9
  const MINES = 10

  const [grid, setGrid] = useState<number[][]>([])
  const [revealed, setRevealed] = useState<boolean[][]>([])
  const [flagged, setFlagged] = useState<boolean[][]>([])
  const [gameOver, setGameOver] = useState(false)
  const [won, setWon] = useState(false)
  const [started, setStarted] = useState(false)

  const initGame = useCallback(() => {
    // Place mines
    const g: number[][] = Array.from({ length: ROWS }, () => Array(COLS).fill(0))
    let placed = 0
    while (placed < MINES) {
      const r = Math.floor(Math.random() * ROWS)
      const c = Math.floor(Math.random() * COLS)
      if (g[r][c] !== -1) {
        g[r][c] = -1
        placed++
      }
    }
    // Count neighbors
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (g[r][c] === -1) continue
        let count = 0
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            const nr = r + dr, nc = c + dc
            if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS && g[nr][nc] === -1) count++
          }
        }
        g[r][c] = count
      }
    }
    setGrid(g)
    setRevealed(Array.from({ length: ROWS }, () => Array(COLS).fill(false)))
    setFlagged(Array.from({ length: ROWS }, () => Array(COLS).fill(false)))
    setGameOver(false)
    setWon(false)
    setStarted(true)
  }, [])

  useEffect(() => { initGame() }, [initGame])

  const reveal = useCallback((r: number, c: number) => {
    if (gameOver || won || !started) return
    if (revealed[r]?.[c] || flagged[r]?.[c]) return
    if (grid[r][c] === -1) {
      // Hit mine
      setRevealed(Array.from({ length: ROWS }, () => Array(COLS).fill(true)))
      setGameOver(true)
      return
    }
    const newRevealed = revealed.map((row) => [...row])
    const flood = (rr: number, cc: number) => {
      if (rr < 0 || rr >= ROWS || cc < 0 || cc >= COLS) return
      if (newRevealed[rr][cc]) return
      newRevealed[rr][cc] = true
      if (grid[rr][cc] === 0) {
        for (let dr = -1; dr <= 1; dr++)
          for (let dc = -1; dc <= 1; dc++) flood(rr + dr, cc + dc)
      }
    }
    flood(r, c)
    setRevealed(newRevealed)
    // Check win
    let unrevealed = 0
    for (let rr = 0; rr < ROWS; rr++)
      for (let cc = 0; cc < COLS; cc++)
        if (!newRevealed[rr][cc]) unrevealed++
    if (unrevealed === MINES) setWon(true)
  }, [gameOver, won, started, revealed, flagged, grid])

  const toggleFlag = useCallback((e: React.MouseEvent, r: number, c: number) => {
    e.preventDefault()
    if (gameOver || won || revealed[r][c]) return
    setFlagged((prev) => {
      const n = prev.map((row) => [...row])
      n[r][c] = !n[r][c]
      return n
    })
  }, [gameOver, won, revealed])

  const numColors: Record<number, string> = {
    1: '#0000ff', 2: '#008000', 3: '#ff0000', 4: '#000080',
    5: '#800000', 6: '#008080', 7: '#000', 8: '#808080',
  }

  if (!started) return null

  return (
    <div style={{ padding: 4, background: '#c0c0c0', height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '4px 8px', marginBottom: 4, border: '2px inset #fff' }}>
        <span style={{ fontFamily: "'Courier New'", fontSize: 14, fontWeight: 'bold', color: '#ff0000' }}>
          {'\uD83D\uDCA3'} {MINES - flagged.flat().filter(Boolean).length}
        </span>
        <button onClick={initGame} style={{ fontSize: 16, cursor: 'pointer', background: '#c0c0c0', border: '2px outset #fff', padding: '0 6px', lineHeight: '24px' }}>
          {gameOver ? '\uD83D\uDE35' : won ? '\uD83D\uDE0E' : '\uD83D\uDE42'}
        </button>
        <span style={{ fontFamily: "'Courier New'", fontSize: 14, fontWeight: 'bold', color: '#ff0000' }}>
          {'\u23F1\uFE0F'}
        </span>
      </div>
      <div style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${COLS}, 1fr)`,
        gap: 0,
        border: '2px inset #808080',
        flex: 1,
      }}>
        {grid.map((row, r) =>
          row.map((cell, c) => {
            const isRevealed = revealed[r]?.[c]
            const isFlagged = flagged[r]?.[c]
            return (
              <button
                key={`${r}-${c}`}
                onClick={() => reveal(r, c)}
                onContextMenu={(e) => toggleFlag(e, r, c)}
                style={{
                  width: '100%',
                  aspectRatio: '1',
                  border: isRevealed ? '1px solid #808080' : '2px outset #fff',
                  background: isRevealed ? '#c0c0c0' : '#c0c0c0',
                  cursor: 'pointer',
                  fontSize: 11,
                  fontWeight: 'bold',
                  fontFamily: "'Tahoma', sans-serif",
                  color: cell > 0 ? numColors[cell] || '#000' : '#000',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: 0,
                  lineHeight: 1,
                }}
              >
                {isRevealed
                  ? cell === -1
                    ? '\uD83D\uDCA3'
                    : cell > 0
                      ? cell
                      : ''
                  : isFlagged
                    ? '\uD83D\uDEA9'
                    : ''}
              </button>
            )
          })
        )}
      </div>
      {(gameOver || won) && (
        <div style={{ textAlign: 'center', padding: 4, fontWeight: 'bold', fontSize: 11, color: gameOver ? '#ff0000' : '#008000' }}>
          {gameOver ? 'Game Over! Click the face to retry.' : 'You Win!'}
        </div>
      )}
    </div>
  )
}

// ── Component ──

export default function Win95Desktop({
  projects,
  posts,
}: {
  projects: Project[]
  posts: Post[]
}) {
  const [booting, setBooting] = useState(true)
  const [startOpen, setStartOpen] = useState(false)
  const [clock, setClock] = useState('')
  const [windows, dispatch] = useReducer(windowReducer, [])
  const [selectedIcon, setSelectedIcon] = useState<string | null>(null)
  const [icons, setIcons] = useState<IconState[]>(initIcons)
  const iconDragRef = useRef<{ id: string; startX: number; startY: number; origX: number; origY: number } | null>(null)
  const cascadeRef = useRef(0)
  const demoReelOpened = useRef(false)

  // Icon dragging
  useEffect(() => {
    const handleMove = (e: MouseEvent) => {
      const drag = iconDragRef.current
      if (!drag) return
      const dx = e.clientX - drag.startX
      const dy = e.clientY - drag.startY
      const dragId = drag.id
      const origX = drag.origX
      const origY = drag.origY
      setIcons((prev) =>
        prev.map((ic) =>
          ic.id === dragId
            ? { ...ic, x: origX + dx, y: origY + dy }
            : ic
        )
      )
    }
    const handleUp = () => { iconDragRef.current = null }
    window.addEventListener('mousemove', handleMove)
    window.addEventListener('mouseup', handleUp)
    return () => {
      window.removeEventListener('mousemove', handleMove)
      window.removeEventListener('mouseup', handleUp)
    }
  }, [])

  // Boot check
  useEffect(() => {
    try {
      if (sessionStorage.getItem('cn-boot-done') === '1') setBooting(false)
    } catch { /* ignore */ }
  }, [])

  // Clock
  useEffect(() => {
    const update = () =>
      setClock(
        new Date().toLocaleTimeString('en-US', {
          hour: 'numeric',
          minute: '2-digit',
          hour12: true,
        }),
      )
    update()
    const interval = setInterval(update, 30000)
    return () => clearInterval(interval)
  }, [])

  // Close start menu on outside click
  useEffect(() => {
    if (!startOpen) return
    const handler = (e: MouseEvent) => {
      const t = e.target as HTMLElement
      if (!t.closest('.win95-start-menu') && !t.closest('.win95-start-btn'))
        setStartOpen(false)
    }
    window.addEventListener('mousedown', handler)
    return () => window.removeEventListener('mousedown', handler)
  }, [startOpen])

  const handleBootComplete = useCallback(() => {
    setBooting(false)
    try {
      sessionStorage.setItem('cn-boot-done', '1')
    } catch { /* ignore */ }
  }, [])

  // Auto-open demo reel after boot
  useEffect(() => {
    if (booting || demoReelOpened.current) return
    demoReelOpened.current = true
    const timer = setTimeout(() => {
      const x = typeof window !== 'undefined' ? window.innerWidth - 340 : 500
      const y = typeof window !== 'undefined' ? window.innerHeight - 290 : 400
      dispatch({
        type: 'OPEN_WINDOW',
        payload: {
          id: 'demoReel',
          type: 'demoReel',
          title: 'Demo Reel',
          icon: '\uD83D\uDCFC',
          position: { x, y },
          size: { width: 300, height: 220 },
          minimized: false,
        },
      })
      setTimeout(() => dispatch({ type: 'SET_READY', id: 'demoReel' }), 1500)
    }, 600)
    return () => clearTimeout(timer)
  }, [booting])

  // Handle SET_READY after loading phase
  const openWindow = useCallback(
    (type: string, id: string, label: string, icon: string, posOverride?: { x: number; y: number }, sizeOverride?: { width: number; height: number }) => {
      // Don't re-open if exists
      const existing = windows.find((w) => w.id === id)
      if (existing) {
        dispatch({ type: 'FOCUS_WINDOW', id })
        return
      }

      const cfg = getWindowConfig(type, id, label, icon, cascadeRef.current)
      cascadeRef.current = (cascadeRef.current + 1) % 10

      dispatch({
        type: 'OPEN_WINDOW',
        payload: {
          ...cfg,
          position: posOverride || cfg.position,
          size: sizeOverride || cfg.size,
        },
      })

      // After 1.5s, set to ready
      setTimeout(() => dispatch({ type: 'SET_READY', id }), 1500)
    },
    [windows],
  )

  const handleIconDoubleClick = useCallback(
    (iconDef: { id: string; type: string; label: string; icon: string }) => {
      openWindow(iconDef.type, iconDef.id, iconDef.label, iconDef.icon)
    },
    [openWindow],
  )

  const openProjectWindow = useCallback(
    (project: Project) => {
      const id = `project-${project.slug}`
      openWindow('project', id, project.title, '\uD83C\uDFAC', undefined, { width: 450, height: 380 })
    },
    [openWindow],
  )

  // ── Connection lines ──
  const activeConnections = connectionRules.filter((rule) => {
    const wA = windows.find((w) => w.id === rule.a)
    const wB = windows.find((w) => w.id === rule.b)
    return wA && wB && !wA.minimized && !wB.minimized
  })

  function getWindowCenter(w: WindowState) {
    return {
      x: w.position.x + w.size.width / 2,
      y: w.position.y + w.size.height / 2,
    }
  }

  // ── Render content for each window type ──
  function renderWindowContent(win: WindowState) {
    switch (win.type) {
      case 'films':
        return (
          <div className="win95-inner-content">
            <div style={{ padding: '8px 12px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
              <div style={{ fontWeight: 'bold', marginBottom: 8, borderBottom: '1px solid #808080', paddingBottom: 4 }}>
                Film Projects
              </div>
              {projects.map((p) => (
                <div key={p.slug} style={{ marginBottom: 10, paddingBottom: 8, borderBottom: '1px dotted #c0c0c0' }}>
                  <div>
                    <button
                      onClick={() => openProjectWindow(p)}
                      style={{
                        background: 'none',
                        border: 'none',
                        color: '#000080',
                        textDecoration: 'underline',
                        cursor: 'pointer',
                        fontFamily: 'inherit',
                        fontSize: 12,
                        fontWeight: 'bold',
                        padding: 0,
                      }}
                    >
                      {p.title}
                    </button>
                    <span style={{ color: '#808080', marginLeft: 8, fontSize: 10 }}>({p.year})</span>
                  </div>
                  <div style={{ fontSize: 10, color: '#808080', marginTop: 1 }}>{p.medium}</div>
                  <div style={{ fontSize: 10, color: '#444', marginTop: 2, lineHeight: 1.4 }}>{p.description}</div>
                </div>
              ))}
            </div>
          </div>
        )

      case 'about':
        return (
          <div className="win95-inner-content" style={{ background: '#fff' }}>
            <pre style={{
              padding: '10px 14px',
              fontFamily: "'Courier New', monospace",
              fontSize: 11,
              color: '#000',
              lineHeight: 1.6,
              whiteSpace: 'pre-wrap',
              margin: 0,
            }}>
{`CONNOR NELSON
========================================
Filmmaker / Writer / Audio Drama
Rural Michigan

I make dark things. Films, audio dramas,
essays. Mostly about what happens in the
peripheral vision.

Based in the UP. Working slowly and on purpose.

CURRENTLY
watching:  Werckmeister Harmonies
reading:   Denis Johnson
working:   Twenty Mile Road`}
            </pre>
          </div>
        )

      case 'writing':
        return (
          <div className="win95-inner-content">
            <div style={{ padding: '8px 12px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
              <div style={{ fontWeight: 'bold', marginBottom: 8, borderBottom: '1px solid #808080', paddingBottom: 4 }}>
                Posts
              </div>
              {posts.map((p) => (
                <div key={p.slug} style={{ marginBottom: 8, paddingBottom: 6, borderBottom: '1px dotted #c0c0c0' }}>
                  <div style={{ fontWeight: 'bold', fontSize: 11 }}>{p.title}</div>
                  <div style={{ fontSize: 10, color: '#808080', marginTop: 1 }}>
                    {p.date} &middot; {p.category}
                  </div>
                  <div style={{ fontSize: 10, color: '#444', marginTop: 2, lineHeight: 1.4 }}>{p.excerpt}</div>
                </div>
              ))}
              {posts.length === 0 && (
                <div style={{ color: '#808080', fontStyle: 'italic' }}>No posts found.</div>
              )}
            </div>
          </div>
        )

      case 'contact':
        return (
          <div className="win95-inner-content">
            <div style={{ padding: '10px 14px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
              <div style={{ fontWeight: 'bold', marginBottom: 8, borderBottom: '1px solid #808080', paddingBottom: 4 }}>
                Links
              </div>
              {[
                { label: 'Letterboxd', href: '#', icon: '\uD83C\uDFAC' },
                { label: 'Vimeo', href: '#', icon: '\u25B6' },
                { label: 'SoundCloud', href: '#', icon: '\uD83C\uDFB5' },
                { label: 'Substack', href: '#', icon: '\u2709' },
              ].map((link) => (
                <div key={link.label} style={{ marginBottom: 6 }}>
                  <a
                    href={link.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{ color: '#000080', textDecoration: 'underline', cursor: 'pointer' }}
                  >
                    {link.icon} {link.label}
                  </a>
                </div>
              ))}
            </div>
          </div>
        )

      case 'demoReel':
        return (
          <div className="win95-inner-content" style={{ background: '#000', overflow: 'hidden' }}>
            <DemoReel projects={projects} />
          </div>
        )

      case 'influences':
        return (
          <div className="win95-inner-content">
            <div style={{ padding: '10px 14px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
              <div style={{ fontWeight: 'bold', marginBottom: 8, borderBottom: '1px solid #808080', paddingBottom: 4 }}>
                Key Influences
              </div>
              {[
                { name: 'Kiyoshi Kurosawa', note: 'Networked dread. Pulse, Cure. Horror as atmosphere.' },
                { name: 'David Lynch', note: 'The space past comfort. Inland Empire. Letting things breathe.' },
                { name: 'B\u00E9la Tarr', note: 'Duration as meaning. Werckmeister Harmonies. Patient camera.' },
                { name: 'Denis Johnson', note: 'Prose as weather. Jesus\' Son. Language that knows things.' },
              ].map((inf) => (
                <div key={inf.name} style={{ marginBottom: 8, paddingBottom: 6, borderBottom: '1px dotted #c0c0c0' }}>
                  <div style={{ fontWeight: 'bold', fontStyle: 'italic' }}>{inf.name}</div>
                  <div style={{ fontSize: 10, color: '#444', marginTop: 2, lineHeight: 1.4 }}>{inf.note}</div>
                </div>
              ))}
            </div>
          </div>
        )

      case 'process':
        return (
          <div className="win95-inner-content">
            <div style={{ padding: '10px 14px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
              <div style={{ fontWeight: 'bold', marginBottom: 8, borderBottom: '1px solid #808080', paddingBottom: 4 }}>
                Tools & Process
              </div>
              {[
                { tool: '16mm Film', desc: 'Shooting on Bolex. Hand-processed. Pushed for contrast and grain.' },
                { tool: 'Field Recording', desc: 'Zoom H6. Ambisonic capture. Real spaces, real acoustic signatures.' },
                { tool: 'VHS Artifacts', desc: 'Signal degradation as aesthetic. Dropout, noise, generation loss.' },
                { tool: 'DaVinci Resolve', desc: 'Primary edit and grade. Film emulation LUTs. Deliberate pacing.' },
              ].map((item) => (
                <div key={item.tool} style={{ marginBottom: 8, paddingBottom: 6, borderBottom: '1px dotted #c0c0c0' }}>
                  <div style={{ fontWeight: 'bold' }}>{item.tool}</div>
                  <div style={{ fontSize: 10, color: '#444', marginTop: 2, lineHeight: 1.4 }}>{item.desc}</div>
                </div>
              ))}
            </div>
          </div>
        )

      case 'project': {
        const slug = win.id.replace('project-', '')
        const project = projects.find((p) => p.slug === slug)
        if (!project) return <div style={{ padding: 12, color: '#000' }}>Project not found.</div>
        return (
          <div className="win95-inner-content">
            <div style={{ padding: '10px 14px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
              <div style={{ fontSize: 14, fontWeight: 'bold', marginBottom: 4 }}>{project.title}</div>
              <div style={{ fontSize: 10, color: '#808080', marginBottom: 2 }}>
                {project.year} &middot; {project.medium}
                {project.runtime && <> &middot; {project.runtime}</>}
              </div>
              <div style={{ borderBottom: '1px solid #808080', marginBottom: 8, paddingBottom: 4 }} />
              <div style={{ fontSize: 11, color: '#000', marginBottom: 8, lineHeight: 1.5 }}>
                {project.description}
              </div>
              <div style={{
                fontSize: 10,
                color: '#333',
                lineHeight: 1.6,
                whiteSpace: 'pre-wrap',
                maxHeight: 220,
                overflowY: 'auto',
              }}>
                {project.content}
              </div>
            </div>
          </div>
        )
      }

      case 'minesweeper':
        return <MinesweeperGame />

      case 'internet':
        return (
          <div className="win95-inner-content" style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <div style={{
              padding: '4px 8px',
              background: '#c0c0c0',
              borderBottom: '1px solid #808080',
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              fontSize: 11,
              fontFamily: "'Tahoma', sans-serif",
            }}>
              <span style={{ color: '#808080' }}>Address:</span>
              <div style={{
                flex: 1,
                background: '#fff',
                border: '1px solid #808080',
                padding: '1px 4px',
                fontSize: 11,
              }}>
                https://connornelson.com
              </div>
            </div>
            <div style={{ flex: 1, padding: '16px 20px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000', overflowY: 'auto' }}>
              <div style={{ textAlign: 'center', marginBottom: 16 }}>
                <div style={{ fontSize: 20, fontWeight: 'bold', color: '#000080' }}>Welcome to Connor Nelson Films</div>
                <div style={{ fontSize: 10, color: '#808080', marginTop: 4 }}>Best viewed in Internet Explorer 5.0 at 800x600</div>
                <hr style={{ border: 'none', borderTop: '2px solid #000080', margin: '12px 0' }} />
              </div>
              <p style={{ marginBottom: 8, lineHeight: 1.6 }}>
                You have reached the homepage of <b>Connor Nelson</b>, filmmaker and writer from rural Michigan.
              </p>
              <p style={{ marginBottom: 8, lineHeight: 1.6 }}>
                I make dark things. Films, audio dramas, essays. Mostly about what happens in the peripheral vision.
              </p>
              <div style={{ marginTop: 16, padding: 8, border: '1px solid #c0c0c0', background: '#f0f0f0' }}>
                <div style={{ fontWeight: 'bold', marginBottom: 4 }}>Links:</div>
                {['Letterboxd', 'Vimeo', 'SoundCloud', 'Substack'].map((s) => (
                  <div key={s} style={{ marginBottom: 2 }}>
                    <a href="#" style={{ color: '#000080', textDecoration: 'underline' }}>{s}</a>
                  </div>
                ))}
              </div>
              <div style={{ marginTop: 16, textAlign: 'center', fontSize: 10, color: '#808080' }}>
                <img alt="" src="" style={{ display: 'none' }} />
                Visitor #{Math.floor(Math.random() * 9000) + 1000} | Last updated: March 2026
              </div>
            </div>
          </div>
        )

      case 'notepad':
        return (
          <div className="win95-inner-content" style={{ height: '100%' }}>
            <textarea
              style={{
                width: '100%',
                height: '100%',
                border: 'none',
                outline: 'none',
                resize: 'none',
                fontFamily: "'Courier New', monospace",
                fontSize: 12,
                padding: '8px 10px',
                lineHeight: 1.5,
                color: '#000',
                background: '#fff',
              }}
              defaultValue="Type here..."
              spellCheck={false}
            />
          </div>
        )

      case 'recyclebin':
        return (
          <div className="win95-inner-content">
            <div style={{
              padding: '20px',
              textAlign: 'center',
              fontFamily: "'Tahoma', sans-serif",
              fontSize: 11,
              color: '#808080',
            }}>
              <div style={{ fontSize: 36, marginBottom: 8 }}>{'\uD83D\uDDD1\uFE0F'}</div>
              <div>Recycle Bin is empty.</div>
              <div style={{ fontSize: 10, marginTop: 4, fontStyle: 'italic' }}>
                Nothing has been deleted yet.
              </div>
            </div>
          </div>
        )

      default:
        return null
    }
  }

  if (booting) return <Win95Boot onComplete={handleBootComplete} />

  return (
    <div className="win95-desktop" onClick={() => { setSelectedIcon(null); setStartOpen(false) }}>
      {/* ── YouTube wallpaper ── */}
      <div style={{
        position: 'absolute',
        top: 0,
        bottom: 30,
        left: 0,
        right: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 0,
        pointerEvents: 'none',
        background: '#012265',
        overflow: 'hidden',
      }}>
        <iframe
          src="https://www.youtube.com/embed/HghxOQ12dy4?autoplay=1&mute=1&loop=1&controls=0&showinfo=0&modestbranding=1&playlist=HghxOQ12dy4&disablekb=1"
          style={{
            height: '100%',
            aspectRatio: '16 / 9',
            border: 'none',
            pointerEvents: 'none',
          }}
          allow="autoplay; encrypted-media"
          title="Live wallpaper"
        />
        {/* Thin blue overlays to cover YouTube's internal black padding — frames the video like a painting */}
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 57, background: '#012265', zIndex: 1 }} />
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 6, background: '#012265', zIndex: 1 }} />
        <div style={{ position: 'absolute', top: 0, bottom: 0, left: 0, width: 256, background: '#012265', zIndex: 1 }} />
        <div style={{ position: 'absolute', top: 0, bottom: 0, right: 0, width: 256, background: '#012265', zIndex: 1 }} />
      </div>

      {/* ── Desktop Icons (draggable) ── */}
      {icons.map((iconDef) => (
        <button
          key={iconDef.id}
          className={`desktop-icon ${selectedIcon === iconDef.id ? 'desktop-icon-selected' : ''}`}
          style={{
            position: 'absolute',
            left: iconDef.x,
            top: iconDef.y,
            zIndex: 2,
          }}
          onClick={(e) => { e.stopPropagation(); setSelectedIcon(iconDef.id) }}
          onDoubleClick={(e) => { e.stopPropagation(); handleIconDoubleClick(iconDef) }}
          onMouseDown={(e) => {
            iconDragRef.current = {
              id: iconDef.id,
              startX: e.clientX,
              startY: e.clientY,
              origX: iconDef.x,
              origY: iconDef.y,
            }
          }}
        >
          <span className="desktop-icon-img">{iconDef.icon}</span>
          <span className="desktop-icon-label">{iconDef.label}</span>
        </button>
      ))}

      {/* ── SVG Connection Layer ── */}
      {activeConnections.length > 0 && (
        <svg
          className="connection-layer"
          style={{
            position: 'absolute',
            inset: 0,
            width: '100%',
            height: '100%',
            pointerEvents: 'none',
            zIndex: 1,
          }}
        >
          <defs>
            {activeConnections.map((conn, i) => {
              const wA = windows.find((w) => w.id === conn.a)!
              const wB = windows.find((w) => w.id === conn.b)!
              const cA = getWindowCenter(wA)
              const cB = getWindowCenter(wB)
              const mx = (cA.x + cB.x) / 2
              const my = (cA.y + cB.y) / 2 - 40
              return (
                <path
                  key={`cpath-def-${i}`}
                  id={`cpath-${i}`}
                  d={`M ${cA.x} ${cA.y} Q ${mx} ${my} ${cB.x} ${cB.y}`}
                  fill="none"
                />
              )
            })}
          </defs>
          {activeConnections.map((conn, i) => {
            const wA = windows.find((w) => w.id === conn.a)!
            const wB = windows.find((w) => w.id === conn.b)!
            const cA = getWindowCenter(wA)
            const cB = getWindowCenter(wB)
            const mx = (cA.x + cB.x) / 2
            const my = (cA.y + cB.y) / 2 - 40
            return (
              <g key={`conn-${i}`}>
                <path
                  d={`M ${cA.x} ${cA.y} Q ${mx} ${my} ${cB.x} ${cB.y}`}
                  stroke="rgba(255,255,255,0.08)"
                  strokeWidth="1"
                  fill="none"
                />
                {[0, 1, 2].map((j) => (
                  <text
                    key={`ct-${i}-${j}`}
                    fill="rgba(255,255,255,0.2)"
                    fontSize="9"
                    fontFamily="'Courier New', monospace"
                  >
                    <animateMotion
                      dur={`${5 + (i % 3)}s`}
                      repeatCount="indefinite"
                      begin={`${j * 2}s`}
                    >
                      <mpath href={`#cpath-${i}`} />
                    </animateMotion>
                    {conn.code}
                  </text>
                ))}
              </g>
            )
          })}
        </svg>
      )}

      {/* ── Windows ── */}
      {windows.map((win) => {
        const codeType = win.type === 'project' ? 'project' : win.type
        const lines = loadingCodeBank[codeType] || loadingCodeBank.films
        const maxZ = Math.max(...windows.map((w) => w.zIndex), 0)
        return (
          <Win95Window
            key={win.id}
            id={win.id}
            title={win.title}
            icon={win.icon}
            position={win.position}
            size={win.size}
            zIndex={win.zIndex}
            phase={win.phase}
            minimized={win.minimized}
            focused={win.zIndex === maxZ}
            loadingLines={lines}
            onClose={() => dispatch({ type: 'CLOSE_WINDOW', id: win.id })}
            onMinimize={() => dispatch({ type: 'MINIMIZE_WINDOW', id: win.id })}
            onFocus={() => dispatch({ type: 'FOCUS_WINDOW', id: win.id })}
            onMove={(x, y) => dispatch({ type: 'MOVE_WINDOW', id: win.id, x, y })}
          >
            {renderWindowContent(win)}
          </Win95Window>
        )
      })}

      {/* ── Taskbar ── */}
      <div className="win95-taskbar" onClick={(e) => e.stopPropagation()}>
        <button
          className={`win95-start-btn ${startOpen ? 'pressed' : ''}`}
          onClick={(e) => {
            e.stopPropagation()
            setStartOpen(!startOpen)
          }}
        >
          <span className="win95-start-flag">
            <span className="win95-flag-r" />
            <span className="win95-flag-g" />
            <span className="win95-flag-b" />
            <span className="win95-flag-y" />
          </span>
          Start
        </button>

        <div className="win95-taskbar-divider" />

        <div className="win95-taskbar-windows">
          {windows.map((win) => {
            const maxZ = Math.max(...windows.map((w) => w.zIndex), 0)
            const isActive = win.zIndex === maxZ && !win.minimized
            return (
              <button
                key={win.id}
                className={`win95-taskbar-btn ${isActive ? 'active' : ''}`}
                onClick={() => {
                  if (!win.minimized && win.zIndex === maxZ) {
                    dispatch({ type: 'MINIMIZE_WINDOW', id: win.id })
                  } else {
                    dispatch({ type: 'FOCUS_WINDOW', id: win.id })
                  }
                }}
              >
                <span style={{ fontSize: 12 }}>{win.icon}</span>
                {win.title}
              </button>
            )
          })}
        </div>

        <div className="win95-taskbar-divider" />

        <div className="win95-clock">
          <span style={{ fontSize: 13 }}>{'\uD83D\uDD53'}</span>
          {clock}
        </div>

        {/* Start Menu */}
        {startOpen && (
          <div className="win95-start-menu" onClick={(e) => e.stopPropagation()}>
            <div className="win95-start-sidebar">
              <span>CN Films</span>
            </div>
            <div className="win95-start-items">
              {icons.map((iconDef) => (
                <button
                  key={iconDef.id}
                  className="win95-start-item-btn"
                  onClick={() => {
                    setStartOpen(false)
                    handleIconDoubleClick(iconDef)
                  }}
                >
                  {iconDef.icon} {iconDef.label}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
