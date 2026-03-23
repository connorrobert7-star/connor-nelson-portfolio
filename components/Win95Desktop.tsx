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
    "GET https://thesignal.connornelson.com",
    "Loading The Signal...",
    "Connected.",
  ],
  cineswipe: [
    "C:\\APPS> cineswipe.exe",
    "initializing display...",
    "loading frame database...",
    "connecting to archive...",
    "CineSwipe ready.",
  ],
  news: [
    "C:\\APPS> signal.exe",
    "GET https://thesignal.connornelson.com",
    "fetching stories...",
    "parsing wire feed...",
    "The Signal loaded.",
  ],
  letterboxd: [
    "C:\\APPS> letterboxd.exe",
    "GET https://letterboxd.com/rss/",
    "parsing film diary...",
    "loading reviews...",
    "ready.",
  ],
  notepad: [
    "C:\\APPS> guestbook.exe",
    "connecting to database...",
    "loading messages...",
    "ready to sign.",
  ],
  recyclebin: [
    "C:\\PHOTOS> dir *.jpg /s",
    "scanning photo archive...",
    "loading gallery...",
    "ready.",
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
  { id: 'about', label: 'About Me', icon: '\uD83D\uDCDD', type: 'about' },
  { id: 'contact', label: 'Contact', icon: '\uD83D\uDCE7', type: 'contact' },
  { id: 'cineswipe', label: 'CineSwipe', icon: '\uD83C\uDFAC', type: 'cineswipe' },
  { id: 'letterboxd', label: 'Letterboxd', icon: '\uD83C\uDF9E\uFE0F', type: 'letterboxd' },
  { id: 'internet', label: 'Internet', icon: '\uD83C\uDF10', type: 'internet' },
  { id: 'minesweeper', label: 'Minesweeper', icon: '\uD83D\uDCA3', type: 'minesweeper' },
  { id: 'notepad', label: 'Guestbook', icon: '\uD83D\uDCDD', type: 'notepad' },
  { id: 'recyclebin', label: 'My Photos', icon: '\uD83D\uDCF7', type: 'recyclebin' },
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
    cineswipe: { title: 'CineSwipe', size: { width: 320, height: 520 } },
    news: { title: 'The Signal - News', size: { width: 500, height: 420 } },
    letterboxd: { title: 'Letterboxd - Recent Watches', size: { width: 380, height: 400 } },
    internet: { title: 'Internet Explorer - The Signal', size: { width: 620, height: 500 } },
    notepad: { title: 'Guestbook', size: { width: 520, height: 380 } },
    recyclebin: { title: 'My Photos', size: { width: 440, height: 380 } },
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

// ── App Components ──

type SignalStory = {
  id: string
  headline: string
  dek: string | null
  body: string
  source_url: string
  source_platform: string
  category: string
  audience_size_estimate: number | null
  documentary_score: number
  found_at: string
}

type CineFrame = {
  id: string
  film_title: string
  director: string
  year: number
  cinematographer: string
  aspect_ratio: string
  cdn_url: string | null
  thumbnail_url: string | null
  tags: {
    lighting: string[]
    lens: string[]
    color: string[]
    emotional_register: string[]
    composition: string[]
    era: string[]
    subject: string[]
    movement: string[]
    folder: string[]
  }
  camera_model: string | null
  lens_info: string | null
  film_stock: string | null
  film_notes: string | null
}

// Win95 button style helper
const w95Btn = (active?: boolean): React.CSSProperties => ({
  padding: '2px 6px',
  fontSize: 9,
  cursor: 'pointer',
  fontFamily: "'Tahoma', sans-serif",
  background: active ? '#000080' : '#c0c0c0',
  color: active ? '#fff' : '#000',
  borderTop: active ? '1px solid #000' : '1px solid #fff',
  borderLeft: active ? '1px solid #000' : '1px solid #fff',
  borderRight: active ? '1px solid #fff' : '1px solid #000',
  borderBottom: active ? '1px solid #fff' : '1px solid #000',
})

function SignalNewsApp() {
  const [stories, setStories] = useState<SignalStory[]>([])
  const [category, setCategory] = useState('all')
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<Array<{ story: SignalStory; explanation: string }> | null>(null)
  const [searching, setSearching] = useState(false)

  useEffect(() => {
    setLoading(true)
    fetch(`/api/stories?category=${category}`)
      .then(r => r.json())
      .then(d => setStories(d.stories || []))
      .catch(() => setStories([]))
      .finally(() => setLoading(false))
  }, [category])

  function handleSearch(e: React.FormEvent) {
    e.preventDefault()
    if (!searchQuery.trim()) { setSearchResults(null); return }
    setSearching(true)
    fetch(`/api/search?q=${encodeURIComponent(searchQuery.trim())}`)
      .then(r => r.json())
      .then(d => setSearchResults(d.results))
      .catch(() => setSearchResults([]))
      .finally(() => setSearching(false))
  }

  function timeAgo(date: string): string {
    const diff = Date.now() - new Date(date).getTime()
    const hours = Math.floor(diff / (1000 * 60 * 60))
    if (hours < 1) return 'now'
    if (hours < 24) return `${hours}h ago`
    return `${Math.floor(hours / 24)}d ago`
  }

  function formatAud(n: number | null): string {
    if (!n) return ''
    if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`
    if (n >= 1000) return `${(n / 1000).toFixed(0)}K`
    return `${n}`
  }

  // NYT-style fonts
  const nytSerif = "Georgia, 'Times New Roman', serif"
  const nytSans = "'Helvetica Neue', Arial, sans-serif"
  const nytFranklin = "'Franklin Gothic Medium', 'Arial Narrow', sans-serif"

  const cats = [
    { key: 'all', label: 'All' },
    { key: 'subcultures', label: 'Subcultures' },
    { key: 'small-town', label: 'Small Town' },
    { key: 'micro-celebrity', label: 'Micro-Celebrity' },
  ]

  const platformMap: Record<string, string> = { reddit: 'Reddit', youtube: 'YouTube', news: 'News', 'google-news': 'Google' }
  const catColors: Record<string, string> = { subcultures: '#567', 'small-town': '#567', 'micro-celebrity': '#567' }

  const lead = stories[0]
  const sidebar = stories.slice(1, 4)
  const grid = stories.slice(4, 10)

  return (
    <div className="win95-inner-content" style={{
      height: '100%', overflowY: 'auto', background: '#fff', color: '#121212',
      fontFamily: nytSerif, fontSize: 13,
    }}>
      {/* NYT Masthead */}
      <div style={{ padding: '8px 14px 6px', borderBottom: '2px solid #121212' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
          <span style={{ fontFamily: nytSans, fontSize: 9, color: '#666' }}>
            {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}
          </span>
          <span style={{ fontFamily: nytSans, fontSize: 9, color: '#666' }}>
            {stories.length} stories
          </span>
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontSize: 32, fontWeight: 700, fontFamily: "'Chomsky', Georgia, 'Old English Text MT', serif",
            letterSpacing: -0.5, lineHeight: 1,
            fontStyle: 'normal',
          }}>
            {/* NYT-style blackletter approximation with Georgia bold */}
            <span style={{ fontFamily: nytSerif, fontWeight: 700, fontSize: 28, letterSpacing: -1 }}>The Signal</span>
          </div>
          <div style={{ fontFamily: nytSans, fontSize: 8, color: '#999', letterSpacing: 1, textTransform: 'uppercase' as const, marginTop: 2 }}>
            Documentary-Worthy American Stories
          </div>
        </div>
      </div>

      {/* Nav bar */}
      <div style={{
        display: 'flex', justifyContent: 'center', gap: 0, padding: '4px 14px',
        borderBottom: '1px solid #e2e2e2', background: '#fff',
      }}>
        {cats.map(c => (
          <button key={c.key} onClick={() => setCategory(c.key)} style={{
            padding: '3px 10px', cursor: 'pointer', border: 'none', background: 'none',
            fontFamily: nytSans, fontSize: 10, fontWeight: category === c.key ? 700 : 400,
            color: category === c.key ? '#121212' : '#666',
            borderBottom: category === c.key ? '2px solid #121212' : '2px solid transparent',
            transition: 'all 0.15s',
          }}>{c.label}</button>
        ))}
      </div>

      {/* Search */}
      <form onSubmit={handleSearch} style={{
        display: 'flex', margin: '8px 14px', border: '1px solid #e2e2e2', borderRadius: 3, overflow: 'hidden',
      }}>
        <input type="text" value={searchQuery}
          onChange={e => { setSearchQuery(e.target.value); if (!e.target.value) setSearchResults(null) }}
          placeholder="Search The Signal..."
          style={{
            flex: 1, border: 'none', padding: '5px 10px', fontSize: 11,
            outline: 'none', fontFamily: nytSans, color: '#333',
          }}
        />
        <button type="submit" disabled={searching} style={{
          padding: '5px 12px', background: '#121212', color: '#fff', border: 'none',
          fontFamily: nytSans, fontSize: 10, fontWeight: 600, cursor: 'pointer',
          opacity: searching ? 0.6 : 1,
        }}>{searching ? '...' : 'Search'}</button>
      </form>

      {/* Content */}
      <div style={{ padding: '0 14px 14px' }}>
        {searchResults ? (
          <>
            <div style={{ fontFamily: nytFranklin, fontSize: 11, fontWeight: 700, paddingBottom: 6, marginBottom: 10, borderBottom: '1px solid #e2e2e2' }}>
              Search Results
            </div>
            {searchResults.length === 0 ? (
              <div style={{ textAlign: 'center', color: '#999', padding: '30px 0', fontFamily: nytSerif, fontStyle: 'italic' }}>No matches found.</div>
            ) : searchResults.map(r => (
              <div key={r.story.id} style={{ marginBottom: 14, paddingBottom: 14, borderBottom: '1px solid #f0f0f0' }}>
                <div style={{ fontFamily: nytSans, fontSize: 9, color: '#999', fontStyle: 'italic', marginBottom: 4 }}>
                  {r.explanation}
                </div>
                <a href={r.story.source_url} target="_blank" rel="noopener noreferrer" style={{ color: '#121212', textDecoration: 'none' }}>
                  <div style={{ fontSize: 15, fontWeight: 700, lineHeight: 1.2, marginBottom: 3 }}>{r.story.headline}</div>
                </a>
                {r.story.dek && <div style={{ fontSize: 12, color: '#555', marginBottom: 3 }}>{r.story.dek}</div>}
                <div style={{ fontSize: 12, color: '#333', lineHeight: 1.6 }}>{r.story.body.slice(0, 200)}</div>
              </div>
            ))}
          </>
        ) : loading ? (
          <div style={{ textAlign: 'center', color: '#999', padding: '40px 0', fontFamily: nytSans, fontSize: 12 }}>Loading...</div>
        ) : stories.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px 0' }}>
            <div style={{ fontFamily: nytSerif, fontSize: 18, fontWeight: 700, color: '#121212' }}>No stories yet.</div>
            <div style={{ fontFamily: nytSans, fontSize: 11, color: '#999', marginTop: 6 }}>
              The scraper runs every 6 hours. Stories are sourced from Reddit, YouTube, Google News, and more.
            </div>
          </div>
        ) : (
          <>
            {/* LEAD + SIDEBAR — NYT above-the-fold */}
            <div style={{ display: 'flex', gap: 14, paddingTop: 10, paddingBottom: 14, borderBottom: '1px solid #e2e2e2', marginBottom: 14 }}>
              {/* Lead story */}
              {lead && (
                <div style={{ flex: 2 }}>
                  <a href={lead.source_url} target="_blank" rel="noopener noreferrer" style={{ color: '#121212', textDecoration: 'none' }}>
                    <div style={{ fontSize: 22, fontWeight: 700, lineHeight: 1.15, marginBottom: 6, letterSpacing: -0.3 }}>
                      {lead.headline}
                    </div>
                  </a>
                  {lead.dek && (
                    <div style={{ fontSize: 13, color: '#555', lineHeight: 1.3, marginBottom: 6 }}>{lead.dek}</div>
                  )}
                  <div style={{ fontSize: 12, color: '#333', lineHeight: 1.65 }}>{lead.body}</div>
                  <div style={{ fontFamily: nytSans, fontSize: 9, color: '#999', marginTop: 6, display: 'flex', gap: 6, alignItems: 'center' }}>
                    <span style={{ fontWeight: 600, textTransform: 'uppercase' as const, letterSpacing: 0.5, color: catColors[lead.category] || '#567' }}>
                      {lead.category.replace('-', ' ')}
                    </span>
                    <span>&middot;</span>
                    <span>{platformMap[lead.source_platform] || lead.source_platform}</span>
                    <span>&middot;</span>
                    <span>{timeAgo(lead.found_at)}</span>
                    {lead.audience_size_estimate ? <><span>&middot;</span><span>~{formatAud(lead.audience_size_estimate)} audience</span></> : null}
                  </div>
                </div>
              )}

              {/* Sidebar stories */}
              {sidebar.length > 0 && (
                <div style={{ flex: 1, borderLeft: '1px solid #e2e2e2', paddingLeft: 14 }}>
                  {sidebar.map((story, i) => (
                    <div key={story.id} style={{ paddingBottom: 10, marginBottom: 10, borderBottom: i < sidebar.length - 1 ? '1px solid #f0f0f0' : 'none' }}>
                      <a href={story.source_url} target="_blank" rel="noopener noreferrer" style={{ color: '#121212', textDecoration: 'none' }}>
                        <div style={{ fontSize: 13, fontWeight: 700, lineHeight: 1.2, marginBottom: 3 }}>{story.headline}</div>
                      </a>
                      <div style={{ fontSize: 11, color: '#333', lineHeight: 1.5 }}>
                        {story.body.slice(0, 100)}{story.body.length > 100 ? '...' : ''}
                      </div>
                      <div style={{ fontFamily: nytSans, fontSize: 8, color: '#999', marginTop: 3 }}>
                        {timeAgo(story.found_at)}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Below the fold — 3-column grid */}
            {grid.length > 0 && (
              <>
                <div style={{ fontFamily: nytFranklin, fontSize: 10, fontWeight: 700, textTransform: 'uppercase' as const, letterSpacing: 1, color: '#121212', marginBottom: 10, paddingBottom: 6, borderBottom: '2px solid #121212' }}>
                  More Stories
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px 14px' }}>
                  {grid.map(story => (
                    <div key={story.id}>
                      <div style={{ fontFamily: nytSans, fontSize: 8, fontWeight: 600, color: '#567', textTransform: 'uppercase' as const, letterSpacing: 0.5, marginBottom: 3 }}>
                        {story.category.replace('-', ' ')}
                      </div>
                      <a href={story.source_url} target="_blank" rel="noopener noreferrer" style={{ color: '#121212', textDecoration: 'none' }}>
                        <div style={{ fontSize: 12, fontWeight: 700, lineHeight: 1.2, marginBottom: 3 }}>{story.headline}</div>
                      </a>
                      <div style={{ fontSize: 10, color: '#555', lineHeight: 1.5 }}>
                        {story.body.slice(0, 80)}{story.body.length > 80 ? '...' : ''}
                      </div>
                      <div style={{ fontFamily: nytSans, fontSize: 8, color: '#bbb', marginTop: 4 }}>
                        {platformMap[story.source_platform] || story.source_platform} &middot; {timeAgo(story.found_at)}
                      </div>
                    </div>
                  ))}
                </div>
              </>
            )}
          </>
        )}

        <div style={{
          textAlign: 'center', fontFamily: nytSans, fontSize: 8, color: '#ccc', marginTop: 16,
          paddingTop: 8, borderTop: '1px solid #f0f0f0', letterSpacing: 0.5,
        }}>
          THE SIGNAL &middot; Stories expire after 6 months &middot; Always rolling
        </div>
      </div>
    </div>
  )
}

function CineSwipeApp() {
  const [frame, setFrame] = useState<CineFrame | null>(null)
  const [loading, setLoading] = useState(true)
  const [saved, setSaved] = useState<CineFrame[]>(() => {
    if (typeof window === 'undefined') return []
    try { return JSON.parse(localStorage.getItem('cineswipe-saved') || '[]') } catch { return [] }
  })
  const [swiped, setSwiped] = useState<string[]>(() => {
    if (typeof window === 'undefined') return []
    try { return JSON.parse(localStorage.getItem('cineswipe-swiped') || '[]') } catch { return [] }
  })
  const [showInfo, setShowInfo] = useState(false)
  const [view, setView] = useState<'swipe' | 'library'>('swipe')
  const [swipeAnim, setSwipeAnim] = useState<'left' | 'right' | null>(null)

  const fetchFrame = useCallback((excludeIds: string[]) => {
    setLoading(true)
    setShowInfo(false)
    const exclude = excludeIds.slice(-100).join(',')
    fetch(`/api/cineswipe/frame${exclude ? `?exclude=${exclude}` : ''}`)
      .then(r => r.json())
      .then(d => setFrame(d.frame || null))
      .catch(() => setFrame(null))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    fetchFrame(swiped)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function handleSwipe(direction: 'left' | 'right') {
    if (!frame) return
    setSwipeAnim(direction)
    setTimeout(() => {
      setSwipeAnim(null)
      const newSwiped = [...swiped, frame.id]
      setSwiped(newSwiped)
      localStorage.setItem('cineswipe-swiped', JSON.stringify(newSwiped))

      if (direction === 'right') {
        const newSaved = [...saved, frame]
        setSaved(newSaved)
        localStorage.setItem('cineswipe-saved', JSON.stringify(newSaved))
      }

      fetchFrame(newSwiped)
    }, 300)
  }

  const allTags = frame ? [
    ...frame.tags.lighting, ...frame.tags.lens, ...frame.tags.color,
    ...frame.tags.composition, ...frame.tags.emotional_register,
  ].slice(0, 5) : []

  if (view === 'library') {
    return (
      <div style={{ flex: 1, overflowY: 'auto', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000', background: '#1a1a1a' }}>
        <div style={{ padding: '8px 10px', borderBottom: '1px solid #333', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ color: '#fff', fontWeight: 'bold', fontSize: 12 }}>Saved Frames ({saved.length})</span>
          <button onClick={() => setView('swipe')} style={w95Btn()}>Back to Swipe</button>
        </div>
        {saved.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#666', padding: '40px 0' }}>No saved frames yet. Start swiping!</div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 2, padding: 2 }}>
            {saved.map(f => (
              <div key={f.id} style={{ position: 'relative', aspectRatio: '16/9', background: '#000', overflow: 'hidden' }}>
                {f.thumbnail_url || f.cdn_url ? (
                  <img src={f.thumbnail_url || f.cdn_url || ''} alt={f.film_title}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  <div style={{ width: '100%', height: '100%', background: 'linear-gradient(135deg, #1a1a2e, #16213e)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <span style={{ fontSize: 20 }}>🎬</span>
                  </div>
                )}
                <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'linear-gradient(transparent, rgba(0,0,0,0.85))', padding: '12px 4px 3px' }}>
                  <div style={{ fontSize: 8, color: '#fff', fontWeight: 'bold', lineHeight: 1.1 }}>{f.film_title}</div>
                  <div style={{ fontSize: 7, color: '#999' }}>{f.director}, {f.year}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    )
  }

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#fff', background: '#0a0a0a', overflow: 'hidden' }}>
      {/* Top bar */}
      <div style={{ padding: '4px 8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #222' }}>
        <span style={{ fontWeight: 'bold', fontSize: 13, letterSpacing: -0.5 }}>CineSwipe</span>
        <div style={{ display: 'flex', gap: 4 }}>
          <button onClick={() => setView('library')} style={w95Btn()}>
            Library ({saved.length})
          </button>
        </div>
      </div>

      {/* Swipe card area */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 8, position: 'relative', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ color: '#444' }}>Loading frame...</div>
        ) : !frame ? (
          <div style={{ textAlign: 'center', color: '#444' }}>
            <div style={{ fontSize: 24, marginBottom: 8 }}>🎬</div>
            <div>No more frames.</div>
            <button onClick={() => { setSwiped([]); localStorage.removeItem('cineswipe-swiped'); fetchFrame([]) }}
              style={{ ...w95Btn(), marginTop: 8 }}>Reset</button>
          </div>
        ) : (
          <div
            onClick={() => setShowInfo(!showInfo)}
            style={{
              width: '100%', maxWidth: 400, aspectRatio: frame.aspect_ratio === '2.39:1' ? '2.39/1' : frame.aspect_ratio === '1.85:1' ? '1.85/1' : '16/9',
              maxHeight: '100%', position: 'relative', cursor: 'pointer', overflow: 'hidden',
              transition: 'transform 0.3s ease, opacity 0.3s ease',
              transform: swipeAnim === 'left' ? 'translateX(-120%) rotate(-12deg)' : swipeAnim === 'right' ? 'translateX(120%) rotate(12deg)' : 'translateX(0)',
              opacity: swipeAnim ? 0.5 : 1,
              boxShadow: '0 4px 24px rgba(0,0,0,0.6)',
            }}
          >
            {/* Frame image */}
            {frame.cdn_url || frame.thumbnail_url ? (
              <img src={frame.cdn_url || frame.thumbnail_url || ''} alt={frame.film_title}
                style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
            ) : (
              <div style={{
                width: '100%', height: '100%',
                background: `linear-gradient(135deg, hsl(${(frame.film_title.length * 37) % 360}, 30%, 15%), hsl(${(frame.film_title.length * 73) % 360}, 20%, 8%))`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <span style={{ fontSize: 40, opacity: 0.3 }}>🎞</span>
              </div>
            )}

            {/* Gradient overlay with info */}
            <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'linear-gradient(transparent, rgba(0,0,0,0.9))', padding: '24px 10px 8px' }}>
              <div style={{ fontSize: 14, fontWeight: 'bold', lineHeight: 1.15 }}>{frame.film_title}</div>
              <div style={{ fontSize: 10, color: '#aaa', marginTop: 2 }}>
                {frame.director} &bull; {frame.year} &bull; DP: {frame.cinematographer}
              </div>
              {allTags.length > 0 && (
                <div style={{ display: 'flex', gap: 3, flexWrap: 'wrap', marginTop: 4 }}>
                  {allTags.map(t => (
                    <span key={t} style={{ fontSize: 8, padding: '1px 4px', background: 'rgba(255,255,255,0.1)', color: '#ccc' }}>
                      {t.replace(/_/g, ' ')}
                    </span>
                  ))}
                </div>
              )}
            </div>

            {/* Detailed info panel */}
            {showInfo && (
              <div style={{
                position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.92)', padding: 10,
                display: 'flex', flexDirection: 'column', justifyContent: 'center', fontSize: 10, lineHeight: 1.6,
              }}>
                <div style={{ fontSize: 13, fontWeight: 'bold', marginBottom: 6 }}>{frame.film_title} ({frame.year})</div>
                <div><b>Director:</b> {frame.director}</div>
                <div><b>Cinematographer:</b> {frame.cinematographer}</div>
                <div><b>Aspect Ratio:</b> {frame.aspect_ratio}</div>
                {frame.camera_model && <div><b>Camera:</b> {frame.camera_model}</div>}
                {frame.lens_info && <div><b>Lens:</b> {frame.lens_info}</div>}
                {frame.film_stock && <div><b>Stock:</b> {frame.film_stock}</div>}
                {frame.film_notes && <div style={{ marginTop: 4, color: '#999', fontStyle: 'italic' }}>{frame.film_notes}</div>}
              </div>
            )}

            {/* Swipe hint labels */}
            {swipeAnim === 'left' && (
              <div style={{ position: 'absolute', top: '40%', left: 12, fontSize: 16, fontWeight: 'bold', color: '#ff4444', transform: 'rotate(-12deg)', border: '2px solid #ff4444', padding: '2px 8px' }}>PASS</div>
            )}
            {swipeAnim === 'right' && (
              <div style={{ position: 'absolute', top: '40%', right: 12, fontSize: 16, fontWeight: 'bold', color: '#44ff44', transform: 'rotate(12deg)', border: '2px solid #44ff44', padding: '2px 8px' }}>SAVE</div>
            )}
          </div>
        )}
      </div>

      {/* Swipe buttons */}
      {frame && !loading && (
        <div style={{ display: 'flex', justifyContent: 'center', gap: 16, padding: '6px 0 10px', borderTop: '1px solid #222' }}>
          <button onClick={() => handleSwipe('left')} style={{
            width: 40, height: 40, borderRadius: '50%', background: 'none',
            border: '2px solid #ff4444', color: '#ff4444', fontSize: 18, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }} title="Pass">✕</button>
          <button onClick={() => setShowInfo(!showInfo)} style={{
            width: 32, height: 32, borderRadius: '50%', background: 'none',
            border: '1px solid #444', color: '#888', fontSize: 12, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', alignSelf: 'center',
          }} title="Info">i</button>
          <button onClick={() => handleSwipe('right')} style={{
            width: 40, height: 40, borderRadius: '50%', background: 'none',
            border: '2px solid #44ff44', color: '#44ff44', fontSize: 18, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }} title="Save">♥</button>
        </div>
      )}

      <div style={{ textAlign: 'center', fontSize: 8, color: '#333', padding: '0 0 4px' }}>
        {swiped.length} swiped &bull; {saved.length} saved &bull; tap card for details
      </div>
    </div>
  )
}

type LetterboxdReview = {
  title: string
  year: string
  rating: string
  review: string
  link: string
  date: string
  image: string
}

function LetterboxdApp() {
  const [reviews, setReviews] = useState<LetterboxdReview[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch('/api/letterboxd')
      .then(r => r.json())
      .then(d => setReviews(d.reviews || []))
      .catch(() => setReviews([]))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="win95-inner-content" style={{ height: '100%', overflowY: 'auto', background: '#14181c', fontFamily: "'Tahoma', sans-serif", fontSize: 11 }}>
      {/* Header */}
      <div style={{ padding: '10px 12px', borderBottom: '1px solid #2c3440', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ width: 24, height: 24, background: '#00e054', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 'bold', color: '#fff' }}>L</div>
        <div>
          <div style={{ color: '#fff', fontWeight: 'bold', fontSize: 12 }}>Recent Watches</div>
          <div style={{ color: '#9ab', fontSize: 9 }}>from Letterboxd</div>
        </div>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', color: '#9ab', padding: '40px 0' }}>Loading reviews...</div>
      ) : reviews.length === 0 ? (
        <div style={{ textAlign: 'center', color: '#9ab', padding: '40px 0' }}>
          <div style={{ fontSize: 13, marginBottom: 4 }}>No reviews found.</div>
          <div style={{ fontSize: 9 }}>Set LETTERBOXD_USERNAME in .env.local</div>
        </div>
      ) : (
        <div>
          {reviews.map((review, i) => (
            <a
              key={i}
              href={review.link}
              target="_blank"
              rel="noopener noreferrer"
              style={{ display: 'flex', gap: 10, padding: '10px 12px', borderBottom: '1px solid #2c3440', textDecoration: 'none', color: 'inherit' }}
            >
              {/* Poster */}
              <div style={{ width: 48, height: 72, flexShrink: 0, background: '#2c3440', overflow: 'hidden' }}>
                {review.image ? (
                  <img src={review.image} alt={review.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#456', fontSize: 18 }}>🎬</div>
                )}
              </div>
              {/* Info */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <div style={{ color: '#fff', fontWeight: 'bold', fontSize: 12 }}>{review.title}</div>
                  <div style={{ color: '#9ab', fontSize: 9, flexShrink: 0 }}>{review.date}</div>
                </div>
                <div style={{ color: '#9ab', fontSize: 9 }}>{review.year}</div>
                {review.rating && (
                  <div style={{ color: '#00e054', fontSize: 11, margin: '2px 0', letterSpacing: 1 }}>{review.rating}</div>
                )}
                {review.review && (
                  <div style={{ color: '#9ab', fontSize: 10, lineHeight: 1.4, marginTop: 2 }}>
                    {review.review.slice(0, 120)}{review.review.length > 120 ? '...' : ''}
                  </div>
                )}
              </div>
            </a>
          ))}
        </div>
      )}
    </div>
  )
}

function PhotoGalleryApp() {
  // Photos stored in /public/photos/ — add your images there
  // For now, show a placeholder with instructions
  const [photos] = useState<string[]>(() => {
    // Will be populated when photos are added to /public/photos/
    return []
  })

  return (
    <div className="win95-inner-content" style={{ height: '100%', overflowY: 'auto', fontFamily: "'Tahoma', sans-serif", fontSize: 11 }}>
      {/* Toolbar */}
      <div style={{ padding: '4px 8px', background: '#c0c0c0', borderBottom: '1px solid #808080', display: 'flex', gap: 4, alignItems: 'center' }}>
        <span style={{ fontSize: 10, color: '#000' }}>My Photos</span>
        <span style={{ fontSize: 9, color: '#808080', marginLeft: 'auto' }}>{photos.length} items</span>
      </div>

      {photos.length === 0 ? (
        <div style={{ padding: 20, textAlign: 'center', color: '#808080' }}>
          <div style={{ fontSize: 36, marginBottom: 8 }}>📷</div>
          <div style={{ fontWeight: 'bold', marginBottom: 4 }}>Photo Gallery</div>
          <div style={{ fontSize: 10, lineHeight: 1.5 }}>
            Add photos to <b>/public/photos/</b><br />
            then list them here to display your work.
          </div>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 2, padding: 2 }}>
          {photos.map((src, i) => (
            <div key={i} style={{ aspectRatio: '1', overflow: 'hidden', background: '#000' }}>
              <img src={src} alt={`Photo ${i + 1}`} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

type GuestbookEntry = {
  id: string
  name: string
  message: string
  created_at: string
}

function GuestbookApp() {
  const [entries, setEntries] = useState<GuestbookEntry[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [name, setName] = useState('')
  const [message, setMessage] = useState('')
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [composing, setComposing] = useState(false)

  useEffect(() => {
    fetch('/api/guestbook')
      .then(r => r.json())
      .then(d => {
        const e = d.entries || []
        setEntries(e)
        if (e.length > 0) setSelectedId(e[0].id)
      })
      .catch(() => setEntries([]))
      .finally(() => setLoading(false))
  }, [])

  function handleSubmit() {
    if (!message.trim()) return
    setSubmitting(true)
    fetch('/api/guestbook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: name.trim() || 'Anonymous', message: message.trim() }),
    })
      .then(r => r.json())
      .then(d => {
        if (d.entry) {
          setEntries(prev => [d.entry, ...prev])
          setSelectedId(d.entry.id)
          setMessage('')
          setName('')
          setComposing(false)
        }
      })
      .catch(() => {})
      .finally(() => setSubmitting(false))
  }

  function formatDate(date: string): string {
    const d = new Date(date)
    const now = new Date()
    const diffMs = now.getTime() - d.getTime()
    const diffDays = Math.floor(diffMs / 86400000)
    if (diffDays === 0) return d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    if (diffDays === 1) return 'Yesterday'
    if (diffDays < 7) return d.toLocaleDateString('en-US', { weekday: 'long' })
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: d.getFullYear() !== now.getFullYear() ? 'numeric' : undefined })
  }

  const selected = entries.find(e => e.id === selectedId)

  // macOS Notes colors
  const sidebar = '#f5f5f5'
  const bg = '#fff'
  const border = '#e0e0e0'
  const accent = '#f5c542'
  const textPrimary = '#1d1d1f'
  const textSecondary = '#86868b'

  return (
    <div className="win95-inner-content" style={{
      display: 'flex', height: '100%', fontFamily: "-apple-system, 'Helvetica Neue', sans-serif", fontSize: 13,
      background: bg, color: textPrimary, overflow: 'hidden',
    }}>
      {/* Sidebar — note list */}
      <div style={{
        width: 180, flexShrink: 0, background: sidebar, borderRight: `1px solid ${border}`,
        display: 'flex', flexDirection: 'column', overflow: 'hidden',
      }}>
        {/* Sidebar toolbar */}
        <div style={{
          padding: '8px 10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          borderBottom: `1px solid ${border}`,
        }}>
          <span style={{ fontWeight: 700, fontSize: 13 }}>Guestbook</span>
          <button onClick={() => { setComposing(true); setSelectedId(null) }} style={{
            background: 'none', border: 'none', cursor: 'pointer', fontSize: 16, color: accent,
            fontWeight: 'bold', lineHeight: 1, padding: 0,
          }} title="New note">+</button>
        </div>

        {/* Search-like count */}
        <div style={{ padding: '4px 10px', fontSize: 11, color: textSecondary }}>
          {entries.length} {entries.length === 1 ? 'note' : 'notes'}
        </div>

        {/* Note list */}
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {loading ? (
            <div style={{ padding: 20, textAlign: 'center', color: textSecondary, fontSize: 12 }}>Loading...</div>
          ) : entries.map(entry => (
            <div
              key={entry.id}
              onClick={() => { setSelectedId(entry.id); setComposing(false) }}
              style={{
                padding: '8px 10px', cursor: 'pointer',
                background: selectedId === entry.id ? accent : 'transparent',
                borderBottom: `1px solid ${selectedId === entry.id ? 'transparent' : border}`,
                borderRadius: selectedId === entry.id ? 6 : 0,
                margin: selectedId === entry.id ? '1px 4px' : '0',
              }}
            >
              <div style={{
                fontWeight: 600, fontSize: 12, lineHeight: 1.2,
                color: selectedId === entry.id ? '#000' : textPrimary,
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
              }}>{entry.name}</div>
              <div style={{
                fontSize: 11, color: selectedId === entry.id ? 'rgba(0,0,0,0.6)' : textSecondary,
                display: 'flex', gap: 6, marginTop: 1,
              }}>
                <span>{formatDate(entry.created_at)}</span>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {entry.message.slice(0, 30)}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Main content area */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {composing ? (
          /* Compose new note */
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '16px 20px' }}>
            <div style={{ fontSize: 11, color: textSecondary, textAlign: 'center', marginBottom: 12 }}>
              New Note
            </div>
            <input
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Your name"
              maxLength={50}
              style={{
                border: 'none', outline: 'none', fontSize: 20, fontWeight: 700,
                fontFamily: 'inherit', color: textPrimary, marginBottom: 8,
                background: 'transparent',
              }}
              autoFocus
            />
            <textarea
              value={message}
              onChange={e => setMessage(e.target.value)}
              placeholder="Start writing..."
              maxLength={500}
              style={{
                flex: 1, border: 'none', outline: 'none', fontSize: 14, lineHeight: 1.6,
                fontFamily: 'inherit', color: textPrimary, resize: 'none',
                background: 'transparent',
              }}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 8 }}>
              <button onClick={() => setComposing(false)} style={{
                padding: '6px 16px', background: '#e5e5e5', border: 'none', borderRadius: 6,
                fontSize: 12, cursor: 'pointer', fontFamily: 'inherit', color: textPrimary,
              }}>Cancel</button>
              <button onClick={handleSubmit} disabled={submitting || !message.trim()} style={{
                padding: '6px 16px', background: accent, border: 'none', borderRadius: 6,
                fontSize: 12, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit',
                color: '#000', opacity: submitting || !message.trim() ? 0.4 : 1,
              }}>{submitting ? 'Signing...' : 'Sign'}</button>
            </div>
          </div>
        ) : selected ? (
          /* Read selected note */
          <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px' }}>
            <div style={{ fontSize: 11, color: textSecondary, textAlign: 'center', marginBottom: 12 }}>
              {new Date(selected.created_at).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' })}
            </div>
            <div style={{ fontSize: 22, fontWeight: 700, marginBottom: 8, lineHeight: 1.2 }}>
              {selected.name}
            </div>
            <div style={{ fontSize: 14, lineHeight: 1.7, color: textPrimary, whiteSpace: 'pre-wrap' }}>
              {selected.message}
            </div>
          </div>
        ) : (
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: textSecondary }}>
            {entries.length === 0 ? (
              <div style={{ textAlign: 'center' }}>
                <div style={{ fontSize: 28, marginBottom: 8 }}>📝</div>
                <div style={{ fontSize: 14 }}>No notes yet</div>
                <div style={{ fontSize: 12, marginTop: 4 }}>Be the first to sign the guestbook</div>
              </div>
            ) : (
              <div style={{ fontSize: 14 }}>Select a note</div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

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

      case 'cineswipe':
        return <CineSwipeApp />

      case 'letterboxd':
        return <LetterboxdApp />

      case 'internet':
        return (
          <div className="win95-inner-content" style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
            <div style={{
              padding: '3px 8px', background: '#c0c0c0', borderBottom: '1px solid #808080',
              display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, fontFamily: "'Tahoma', sans-serif",
            }}>
              <span style={{ color: '#808080' }}>Address:</span>
              <div style={{ flex: 1, background: '#fff', border: '1px solid #808080', padding: '1px 4px', fontSize: 11 }}>
                https://thesignal.connornelson.com
              </div>
            </div>
            <SignalNewsApp />
          </div>
        )

      case 'notepad':
        return <GuestbookApp />

      case 'recyclebin':
        return <PhotoGalleryApp />

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
