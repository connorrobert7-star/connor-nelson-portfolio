'use client'

import { useState, useCallback, useEffect, useReducer, useRef } from 'react'
import Win95Boot from './Win95Boot'
import Win95Window from './Win95Window'
import DemoReel from './DemoReel'
import dynamic from 'next/dynamic'

const MiiWalker = dynamic(() => import('./MiiWalker'), { ssr: false })

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
  maximized: boolean
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
  | { type: 'OPEN_WINDOW'; payload: Omit<WindowState, 'zIndex' | 'phase' | 'maximized'> & { phase?: 'loading' | 'ready'; maximized?: boolean } }
  | { type: 'CLOSE_WINDOW'; id: string }
  | { type: 'FOCUS_WINDOW'; id: string }
  | { type: 'MINIMIZE_WINDOW'; id: string }
  | { type: 'MAXIMIZE_WINDOW'; id: string }
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
    "GET https://www.youtube.com",
    "Buffering...",
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
    "C:\\APPS> chat.exe",
    "connecting to server...",
    "loading messages...",
    "you are now online.",
  ],
  recyclebin: [
    "C:\\PHOTOS> dir *.jpg /s",
    "scanning photo archive...",
    "14 photos found.",
    "gallery ready.",
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
          maximized: false,
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
    case 'MAXIMIZE_WINDOW':
      return state.map((w) =>
        w.id === action.id ? { ...w, maximized: !w.maximized } : w
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
  { id: 'news', label: 'The Signal', icon: '\uD83D\uDCF0', type: 'news' },
  { id: 'internet', label: 'Internet', icon: '\uD83C\uDF10', type: 'internet' },
  { id: 'minesweeper', label: 'Minesweeper', icon: '\uD83D\uDCA3', type: 'minesweeper' },
  { id: 'notepad', label: 'Guestbook', icon: '\uD83D\uDCD3', type: 'notepad' },
]

function initIcons(): IconState[] {
  const isMobile = typeof window !== 'undefined' && window.innerWidth < 660
  const colWidth = isMobile ? 64 : 80
  const rowHeight = isMobile ? 64 : 76
  const colHeight = 7 // icons per column before wrapping
  return defaultIcons.map((ic, i) => ({
    ...ic,
    x: 12 + Math.floor(i / colHeight) * colWidth,
    y: 12 + (i % colHeight) * rowHeight,
  }))
}

// ── Window configs ──

function getWindowConfig(type: string, id: string, label: string, icon: string, cascadeIndex: number) {
  const baseX = 80 + cascadeIndex * 30
  const baseY = 40 + cascadeIndex * 30

  const configs: Record<string, { title: string; size: { width: number; height: number } }> = {
    films: { title: 'My Films', size: { width: 400, height: 350 } },
    about: { title: 'PRACTICE - Notepad', size: { width: 440, height: 420 } },
    writing: { title: 'Writing', size: { width: 400, height: 300 } },
    contact: { title: 'Contact', size: { width: 280, height: 180 } },
    demoReel: { title: 'Demo Reel', size: { width: 300, height: 220 } },
    influences: { title: 'Influences', size: { width: 350, height: 280 } },
    process: { title: 'Process & Tools', size: { width: 350, height: 280 } },
    minesweeper: { title: 'Minesweeper', size: { width: 280, height: 340 } },
    cineswipe: { title: 'CineSwipe', size: { width: 320, height: 520 } },
    news: { title: 'The Signal - News', size: { width: 540, height: 450 } },
    letterboxd: { title: 'Letterboxd', size: { width: 300, height: 360 } },
    internet: { title: 'Internet Explorer - YouTube', size: { width: 520, height: 440 } },
    notepad: { title: 'Live Chat', size: { width: 360, height: 320 } },
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
    maximized: false,
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
          onMouseDown={e => e.stopPropagation()}
          placeholder="Search The Signal..."
          style={{
            flex: 1, border: 'none', padding: '5px 10px', fontSize: 11,
            outline: 'none', fontFamily: nytSans, color: '#333', background: '#fff',
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

  const demoFrames: CineFrame[] = [
    { id: 'demo-1', film_title: 'Stalker', director: 'Andrei Tarkovsky', year: 1979, cinematographer: 'Alexander Knyazhinsky', aspect_ratio: '1.37:1', cdn_url: null, thumbnail_url: null, tags: { lighting: ['diffused'], lens: ['wide_angle'], color: ['desaturated'], emotional_register: ['mysterious'], composition: ['deep_focus'], era: ['1970s'], subject: ['landscape'], movement: ['tracking'], folder: [] }, camera_model: null, lens_info: null, film_stock: 'Kodak 5247', film_notes: 'The Zone sequences were shot in Estonia near a power plant.' },
    { id: 'demo-2', film_title: 'Mulholland Drive', director: 'David Lynch', year: 2001, cinematographer: 'Peter Deming', aspect_ratio: '1.85:1', cdn_url: null, thumbnail_url: null, tags: { lighting: ['hard_light'], lens: ['telephoto'], color: ['warm'], emotional_register: ['unsettling'], composition: ['shallow_focus'], era: ['2000s'], subject: ['portrait'], movement: ['static'], folder: [] }, camera_model: null, lens_info: null, film_stock: null, film_notes: 'Hollywood noir reimagined as a dream logic puzzle.' },
    { id: 'demo-3', film_title: 'In the Mood for Love', director: 'Wong Kar-wai', year: 2000, cinematographer: 'Christopher Doyle', aspect_ratio: '1.66:1', cdn_url: null, thumbnail_url: null, tags: { lighting: ['soft_light'], lens: ['telephoto'], color: ['saturated'], emotional_register: ['melancholic'], composition: ['framed'], era: ['2000s'], subject: ['portrait'], movement: ['handheld'], folder: [] }, camera_model: null, lens_info: null, film_stock: null, film_notes: 'Slow-motion and step-printing create a sense of suspended time.' },
    { id: 'demo-4', film_title: 'There Will Be Blood', director: 'Paul Thomas Anderson', year: 2007, cinematographer: 'Robert Elswit', aspect_ratio: '2.39:1', cdn_url: null, thumbnail_url: null, tags: { lighting: ['natural'], lens: ['wide_angle'], color: ['earthy'], emotional_register: ['intense'], composition: ['wide_shot'], era: ['2000s'], subject: ['landscape'], movement: ['crane'], folder: [] }, camera_model: 'Panavision XL2', lens_info: 'Panavision C Series', film_stock: 'Kodak Vision2 5218', film_notes: null },
  ]

  const fetchFrame = useCallback((excludeIds: string[]) => {
    setLoading(true)
    setShowInfo(false)
    const exclude = excludeIds.slice(-100).join(',')
    fetch(`/api/cineswipe/frame${exclude ? `?exclude=${exclude}` : ''}`)
      .then(r => r.json())
      .then(d => {
        if (d.frame) {
          setFrame(d.frame)
        } else {
          // Fallback to demo frames
          const available = demoFrames.filter(f => !excludeIds.includes(f.id))
          setFrame(available.length > 0 ? available[Math.floor(Math.random() * available.length)] : null)
        }
      })
      .catch(() => {
        const available = demoFrames.filter(f => !excludeIds.includes(f.id))
        setFrame(available.length > 0 ? available[Math.floor(Math.random() * available.length)] : null)
      })
      .finally(() => setLoading(false))
  // eslint-disable-next-line react-hooks/exhaustive-deps
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

type YouTubeVideo = {
  id: string
  title: string
  thumbnail: string
  views: string
  published: string
}

function YouTubeBluePlayer({ videoId }: { videoId: string }) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [iframeStyle, setIframeStyle] = useState<React.CSSProperties>({ display: 'none' })

  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const calc = () => {
      const { width: w, height: h } = el.getBoundingClientRect()
      if (!w || !h) return

      const isWider = (w / h) > (16 / 9)
      const iW = isWider ? Math.ceil(h * 16 / 9) : w
      const iH = isWider ? h : Math.ceil(w / (16 / 9))

      setIframeStyle({
        position: 'absolute',
        width: iW,
        height: iH,
        left: (w - iW) / 2,
        top: (h - iH) / 2,
        border: 'none',
      })
    }

    requestAnimationFrame(() => requestAnimationFrame(calc))
    const ro = new ResizeObserver(calc)
    ro.observe(el)
    return () => ro.disconnect()
  }, [videoId])

  return (
    <div ref={containerRef} style={{ flex: 1, position: 'relative', background: '#012265', minHeight: 0, overflow: 'hidden' }}>
      <iframe
        src={`https://www.youtube.com/embed/${videoId}?autoplay=1&modestbranding=1&rel=0`}
        style={iframeStyle}
        allow="autoplay; encrypted-media"
        allowFullScreen
      />
    </div>
  )
}

function OldYouTubeApp() {
  const [videos, setVideos] = useState<YouTubeVideo[]>([])
  const [loading, setLoading] = useState(true)
  const [playing, setPlaying] = useState<string | null>(null)

  useEffect(() => {
    fetch('/api/youtube')
      .then(r => r.json())
      .then(d => setVideos(d.videos || []))
      .catch(() => setVideos([]))
      .finally(() => setLoading(false))
  }, [])

  function formatViews(v: string): string {
    const n = parseInt(v)
    if (isNaN(n)) return v
    if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`
    if (n >= 1000) return `${(n / 1000).toFixed(1)}K`
    return `${n}`
  }

  function formatDate(d: string): string {
    if (!d) return ''
    const date = new Date(d)
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    return `${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`
  }

  // Old YouTube 2008 colors
  const ytBg = '#f2f2f2'
  const ytHeader = '#fff'
  const ytRed = '#cc0000'
  const ytLink = '#0033cc'
  const ytGray = '#666'
  const ytBorder = '#ccc'

  if (playing) {
    return (
      <div className="win95-inner-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', background: '#012265' }}>
        <div style={{ padding: '4px 8px', background: ytHeader, borderBottom: `1px solid ${ytBorder}`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={() => setPlaying(null)} style={{
            background: '#f0f0f0', border: `1px solid ${ytBorder}`, padding: '2px 8px',
            fontSize: 10, cursor: 'pointer', fontFamily: 'Arial, sans-serif', color: '#333',
          }}>Back to Videos</button>
          <span style={{ fontFamily: 'Arial, sans-serif', fontSize: 10, color: ytGray }}>
            {videos.find(v => v.id === playing)?.title}
          </span>
        </div>
        <YouTubeBluePlayer videoId={playing} />
      </div>
    )
  }

  return (
    <div className="win95-inner-content" style={{ display: 'flex', flexDirection: 'column', height: '100%', background: ytBg, fontFamily: 'Arial, sans-serif', fontSize: 11 }}>
      {/* Old YouTube header */}
      <div style={{ background: ytHeader, borderBottom: `1px solid ${ytBorder}`, padding: '6px 10px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
            <span style={{ fontSize: 16, fontWeight: 'bold', color: '#000', fontFamily: 'Arial, sans-serif' }}>You</span>
            <span style={{
              fontSize: 16, fontWeight: 'bold', color: '#fff', background: ytRed,
              padding: '0 4px', borderRadius: 3, marginLeft: 0,
            }}>Tube</span>
            <span style={{ fontSize: 9, color: ytGray, marginLeft: 4, fontStyle: 'italic' }}>Broadcast Yourself</span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 4, fontSize: 10 }}>
          <span style={{ fontWeight: 'bold', color: ytRed, borderBottom: `2px solid ${ytRed}`, paddingBottom: 2 }}>Videos</span>
          <span style={{ color: ytGray }}>Channel</span>
        </div>
      </div>

      {/* Channel banner */}
      <div style={{ background: '#fff', borderBottom: `1px solid ${ytBorder}`, padding: '8px 10px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{
          width: 36, height: 36, background: '#e0e0e0', borderRadius: '50%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 14, fontWeight: 'bold', color: '#666', border: '1px solid #ccc',
        }}>CN</div>
        <div>
          <div style={{ fontWeight: 'bold', fontSize: 13, color: '#000' }}>Connor Nelson</div>
          <div style={{ fontSize: 9, color: ytGray }}>{videos.length} videos &bull; Joined Jul 2013</div>
        </div>
        <button style={{
          marginLeft: 'auto', background: ytRed, color: '#fff', border: 'none',
          padding: '3px 10px', fontSize: 10, fontWeight: 'bold', cursor: 'pointer', borderRadius: 2,
        }}>Subscribe</button>
      </div>

      {/* Video list */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 10px' }}>
        {loading ? (
          <div style={{ textAlign: 'center', color: ytGray, padding: '30px 0' }}>Loading videos...</div>
        ) : videos.length === 0 ? (
          <div style={{ textAlign: 'center', color: ytGray, padding: '30px 0' }}>No videos found.</div>
        ) : (
          videos.map(video => (
            <div
              key={video.id}
              onClick={() => setPlaying(video.id)}
              style={{
                display: 'flex', gap: 8, marginBottom: 10, cursor: 'pointer',
                padding: 6, background: '#fff', border: `1px solid ${ytBorder}`,
              }}
            >
              {/* Thumbnail */}
              <div style={{ width: 120, height: 68, flexShrink: 0, background: '#000', position: 'relative', overflow: 'hidden' }}>
                <img
                  src={video.thumbnail}
                  alt={video.title}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <div style={{
                  position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: 'rgba(0,0,0,0.15)',
                }}>
                  <div style={{
                    width: 24, height: 24, background: 'rgba(0,0,0,0.7)', borderRadius: '50%',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <div style={{ width: 0, height: 0, borderTop: '5px solid transparent', borderBottom: '5px solid transparent', borderLeft: '8px solid #fff', marginLeft: 2 }} />
                  </div>
                </div>
              </div>
              {/* Info */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 12, fontWeight: 'bold', color: ytLink, lineHeight: 1.2, marginBottom: 3 }}>
                  {video.title}
                </div>
                <div style={{ fontSize: 10, color: ytGray }}>Connor Nelson</div>
                <div style={{ fontSize: 10, color: ytGray, marginTop: 2 }}>
                  {formatViews(video.views)} views &bull; {formatDate(video.published)}
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Footer */}
      <div style={{
        background: '#fff', borderTop: `1px solid ${ytBorder}`, padding: '4px 10px',
        textAlign: 'center', fontSize: 9, color: '#999',
      }}>
        Copyright &copy; 2008 YouTube, LLC
      </div>
    </div>
  )
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
    <div className="win95-inner-content" style={{ height: '100%', overflowY: 'auto', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000' }}>
      <div style={{ padding: '16px 20px', textAlign: 'center' }}>
        <div style={{ fontWeight: 'bold', fontSize: 13, marginBottom: 12, borderBottom: '1px solid #808080', paddingBottom: 6 }}>
          Recent Watches
        </div>

        {loading ? (
          <div style={{ color: '#808080', padding: '20px 0' }}>Loading...</div>
        ) : reviews.length === 0 ? (
          <div style={{ color: '#808080', padding: '20px 0' }}>No reviews found.</div>
        ) : (
          reviews.map((review, i) => (
            <a
              key={i}
              href={review.link}
              target="_blank"
              rel="noopener noreferrer"
              style={{ display: 'block', textDecoration: 'none', color: 'inherit', marginBottom: 10, paddingBottom: 10, borderBottom: i < reviews.length - 1 ? '1px dotted #c0c0c0' : 'none' }}
            >
              <div style={{ fontWeight: 'bold', fontSize: 13, color: '#000080' }}>{review.title}</div>
              <div style={{ fontSize: 10, color: '#808080', marginBottom: 2 }}>{review.year}</div>
              {review.rating && (
                <div style={{ fontSize: 12, letterSpacing: 1, marginBottom: 2 }}>{review.rating}</div>
              )}
              {review.review && (
                <div style={{ fontSize: 10, color: '#333', fontStyle: 'italic', lineHeight: 1.4 }}>
                  &ldquo;{review.review}&rdquo;
                </div>
              )}
              <div style={{ fontSize: 9, color: '#808080', marginTop: 2 }}>{review.date}</div>
            </a>
          ))
        )}
      </div>
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
  const [name, setName] = useState('')
  const [message, setMessage] = useState('')
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [online, setOnline] = useState(true)
  const chatRef = useRef<HTMLDivElement>(null)

  // Load messages and poll every 10 seconds
  useEffect(() => {
    function fetchMessages() {
      fetch('/api/guestbook')
        .then(r => r.json())
        .then(d => { setEntries((d.entries || []).reverse()); setOnline(true) })
        .catch(() => setOnline(false))
        .finally(() => setLoading(false))
    }
    fetchMessages()
    const interval = setInterval(fetchMessages, 10000)
    return () => clearInterval(interval)
  }, [])

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    if (chatRef.current) {
      chatRef.current.scrollTop = chatRef.current.scrollHeight
    }
  }, [entries])

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
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
          setEntries(prev => [...prev, d.entry])
          setMessage('')
        }
      })
      .catch(() => {})
      .finally(() => setSubmitting(false))
  }

  function formatTime(date: string): string {
    const d = new Date(date)
    const now = new Date()
    const diffMs = now.getTime() - d.getTime()
    const diffDays = Math.floor(diffMs / 86400000)
    const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    if (diffDays === 0) return time
    if (diffDays === 1) return `Yesterday ${time}`
    if (diffDays < 7) return `${d.toLocaleDateString('en-US', { weekday: 'short' })} ${time}`
    return `${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} ${time}`
  }

  // Generate a color from the name
  function nameColor(n: string): string {
    const colors = ['#000080', '#008000', '#800000', '#008080', '#800080', '#808000', '#0000cc', '#cc0000', '#006600']
    let hash = 0
    for (let i = 0; i < n.length; i++) hash = n.charCodeAt(i) + ((hash << 5) - hash)
    return colors[Math.abs(hash) % colors.length]
  }

  return (
    <div className="win95-inner-content" style={{
      display: 'flex', flexDirection: 'column', height: '100%',
      fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000',
    }}>
      {/* Header */}
      <div style={{
        padding: '4px 8px', background: '#c0c0c0', borderBottom: '1px solid #808080',
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        <span style={{ fontWeight: 'bold', fontSize: 11 }}>Live Chat</span>
        <span style={{ fontSize: 9, color: '#666', marginLeft: 'auto' }}>
          {online ? `${entries.length} messages` : 'Offline'}
        </span>
        <span style={{ width: 6, height: 6, borderRadius: '50%', background: online ? '#00cc00' : '#999', display: 'inline-block' }} />
      </div>

      {/* Messages */}
      <div ref={chatRef} style={{
        flex: 1, overflowY: 'auto', padding: '6px 8px', background: '#fff',
      }}>
        {loading ? (
          <div style={{ textAlign: 'center', color: '#808080', padding: '30px 0' }}>Loading...</div>
        ) : entries.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#808080', padding: '30px 0', fontSize: 10 }}>
            No messages yet. Say something!
          </div>
        ) : (
          entries.map(entry => (
            <div key={entry.id} style={{ marginBottom: 6 }}>
              <span style={{ fontWeight: 'bold', color: nameColor(entry.name), fontSize: 11 }}>
                {entry.name}
              </span>
              <span style={{ fontSize: 9, color: '#999', marginLeft: 6 }}>
                {formatTime(entry.created_at)}
              </span>
              <div style={{ fontSize: 11, color: '#000', lineHeight: 1.4, marginTop: 1, paddingLeft: 0 }}>
                {entry.message}
              </div>
            </div>
          ))
        )}
      </div>

      {/* Input */}
      <form onSubmit={handleSubmit} style={{
        padding: '4px 6px', background: '#c0c0c0', borderTop: '1px solid #808080',
        display: 'flex', flexDirection: 'column', gap: 3,
      }}>
        <div style={{ display: 'flex', gap: 4 }}>
          <input
            type="text"
            value={name}
            onChange={e => setName(e.target.value)}
            onMouseDown={e => e.stopPropagation()}
            placeholder="Name"
            maxLength={50}
            style={{
              width: 80, padding: '3px 5px', fontSize: 10,
              border: '1px solid #808080', fontFamily: 'inherit',
              outline: 'none', background: '#fff', color: '#000',
            }}
          />
          <input
            type="text"
            value={message}
            onChange={e => setMessage(e.target.value)}
            onMouseDown={e => e.stopPropagation()}
            placeholder="Type a message..."
            maxLength={500}
            style={{
              flex: 1, padding: '3px 5px', fontSize: 10,
              border: '1px solid #808080', fontFamily: 'inherit',
              outline: 'none', background: '#fff', color: '#000',
            }}
            autoFocus
          />
          <button type="submit" disabled={submitting || !message.trim()} style={{
            padding: '3px 10px', fontSize: 10, cursor: 'pointer', fontFamily: 'inherit', color: '#000',
            background: '#c0c0c0',
            borderTop: '1px solid #fff', borderLeft: '1px solid #fff',
            borderRight: '1px solid #000', borderBottom: '1px solid #000',
            opacity: submitting || !message.trim() ? 0.5 : 1,
          }}>Send</button>
        </div>
      </form>
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
          <div className="win95-inner-content" style={{ height: '100%', overflowY: 'auto', background: '#fff' }}>
            <pre style={{
              padding: '12px 16px',
              fontFamily: "'Courier New', monospace",
              fontSize: 10,
              color: '#000',
              lineHeight: 1.5,
              whiteSpace: 'pre-wrap',
              margin: 0,
            }}>
{`PRACTICE

Written by Connor Nelson


EXT. TUSTIN, MICHIGAN - DAWN

Population sign: TUSTIN. EST. 1872. Below it,
someone has spray-painted the number 200 and
crossed it out. Below that, 198.

A sawmill. Mist off the river. The sound of
the blade before anything else.

A BOY (7) stands at the edge of the property
watching the logs come through. He doesn't look
afraid. He looks like he's memorizing something.

                    CONNOR (V.O.)
          I grew up in a town of two hundred
          people in Michigan, so small we had
          to borrow the newspaper from the
          town over.


INT. TUSTIN PUBLIC LIBRARY - DAY

Small. Four tables. A fish tank with one fish
in it.

A BOY (10) sits alone at a table near the
window. Not reading. Watching a group of KIDS
in the corner on a shared computer, playing
something, laughing at something he can't hear
from here.

He doesn't go over.

He picks up a book. Puts it down. Picks up
another one.

                    CONNOR (V.O.)
          The library had maybe four regulars
          at a time. I was one of them. I
          never asked for books. I was too
          shy to talk to the kids playing
          RuneScape in the corner so I just
          watched from across the room.


EXT. RIVER - NIGHT

A bonfire. Cousins, neighbors, somebody's dad
with a cooler. A BOY (7) stands at the outer
ring of the fire's light, not quite inside the
circle of people.

A COUSIN (12) holds up a camcorder. Points it
at the trees.

                    COUSIN
          We're making a movie. Thirty-foot
          anaconda. In the jungle.

The Boy looks at the camcorder. Something
shifts in his face.

                    CONNOR (V.O.)
          I found film at a bonfire by a
          river. My cousins had a camcorder,
          said they were making a movie about
          a thirty-foot anaconda in the
          jungle. I was seven. That was
          enough.


INT. LOG CABIN - BEDROOM - NIGHT

A desktop computer. Dial-up modem. A loading
bar at 12%.

A BOY (13) sits in front of it. Not frustrated.
Waiting. He's done this before. He'll do it
again.

On screen: a movie player, buffering.

He leans back in his chair and stares at the
ceiling. He's not going anywhere.

                    CONNOR (V.O.)
          I taught myself patience on dial-up
          internet, watching a movie five
          times slower than everyone else.
          Good things come to those who wait.
          And if you don't like it you just
          wait it out.


EXT. CREEK - DAY

A TEENAGER walks the bank alone. No
destination. Turns over a rock. Lets it drop.
Keeps walking.

The creek doesn't care. The woods don't care.
He walks anyway.

                    CONNOR (V.O.)
          I spent a lot of time in my own
          head, walking creek banks alone,
          going into the woods for no reason
          other than to walk and think and
          feel like something was going to
          happen.


INT. FILM SET - VARIOUS - DAY / NIGHT

A YOUNG MAN (20) moves equipment in the dark.
Extension cords. Sandbags. He's not the
director. He's not the DP. Nobody's asking
his name.

He works. The sun goes down. He's still
working.

Close on his hands. Close on a clock. 2 AM.

                    CONNOR (V.O.)
          I've worked fourteen-hour days for
          zero dollars just to be in the room
          where something was being made.
          That's not a complaint. That's how
          I know I mean it.


INT. APARTMENT - NIGHT

A YOUNG MAN (24) sits at a desk covered in
papers, index cards pinned to the wall, a
hand-drawn diagram of something large and
intricate. Kabbalistic. The Tree of Life.
Lines connecting things.

He's not confused by it. He built it.

                    CONNOR (V.O.)
          I make horror films, the
          psychological kind, the kind that
          lives in behavior and obsession and
          the quiet damage people do to each
          other in small spaces. I built a
          whole universe from scratch. I
          write, I direct, I produce, I
          figure it out.


EXT. SAWMILL - TUSTIN, MICHIGAN - DAWN (FLASHBACK)

The Boy from the first scene, still seven,
still watching the blade, still memorizing.

The log splits clean.

                    CONNOR (V.O.)
          I didn't come from money or
          connections. I came from a sawmill
          and a broken car stereo and the
          kind of town where you either find
          a reason to make something or
          you don't.


INT. FILM SET - NIGHT

A YOUNG MAN stands behind a monitor. On the
screen: an actor hitting their mark. The image
is right. He can tell.

He doesn't celebrate. He just nods once.

                    CONNOR (V.O.)
          Everything I've made so far has
          been practice.

He watches the playback. The image holds.

                    CONNOR (V.O.) (CONT'D)
          I'm ready for what comes next.

FADE TO BLACK.

TITLE CARD: PRACTICE


========================================
AWARDS & SELECTIONS
========================================

Wild Winter Film Festival
  Best Director

Sonscreen Film Festival 2025
  Special Jury Award for Best Original Score
    — Fret
  Official Selection
    — Conversation with my Grandpa

End of Year Show
  Best Editor

Lift-Off Global Network Sessions 2023
  Official Selection`}
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
            <div style={{ padding: '16px 20px', fontFamily: "'Tahoma', sans-serif", fontSize: 11, color: '#000', textAlign: 'center' }}>
              <div style={{ fontWeight: 'bold', fontSize: 13, marginBottom: 12, borderBottom: '1px solid #808080', paddingBottom: 6 }}>
                Contact
              </div>
              <div style={{ marginBottom: 10 }}>
                <div style={{ fontSize: 10, color: '#808080', marginBottom: 2 }}>Phone</div>
                <a href="tel:2313882390" style={{ color: '#000080', textDecoration: 'underline', fontSize: 13, fontWeight: 'bold' }}>
                  231-388-2390
                </a>
              </div>
              <div>
                <div style={{ fontSize: 10, color: '#808080', marginBottom: 2 }}>Email</div>
                <a href="mailto:twentymileroad@gmail.com" style={{ color: '#000080', textDecoration: 'underline', fontSize: 13, fontWeight: 'bold' }}>
                  twentymileroad@gmail.com
                </a>
              </div>
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

      case 'news':
        return <SignalNewsApp />

      case 'internet':
        return <OldYouTubeApp />

      case 'notepad':
        return <GuestbookApp />


      default:
        return null
    }
  }

  if (booting) return <Win95Boot onComplete={handleBootComplete} />

  return (
    <div className="win95-desktop" onClick={() => { setSelectedIcon(null); setStartOpen(false) }}>
      {/* ── Windows 98 Bliss wallpaper + 3D Mii ── */}
      <MiiWalker />

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
            maximized={win.maximized}
            focused={win.zIndex === maxZ}
            loadingLines={lines}
            onClose={() => dispatch({ type: 'CLOSE_WINDOW', id: win.id })}
            onMinimize={() => dispatch({ type: 'MINIMIZE_WINDOW', id: win.id })}
            onMaximize={() => dispatch({ type: 'MAXIMIZE_WINDOW', id: win.id })}
            onFocus={() => dispatch({ type: 'FOCUS_WINDOW', id: win.id })}
            onMove={(x, y) => dispatch({ type: 'MOVE_WINDOW', id: win.id, x, y })}
          >
            {renderWindowContent(win)}
          </Win95Window>
        )
      })}


      {/* ── Desktop Scanlines ── */}

      {/* ── Desktop Watermark ── */}
      <div style={{
        position: 'absolute', top: 12, right: 16, zIndex: 0,
        textAlign: 'right', pointerEvents: 'none', userSelect: 'none',
      }}>
        <div style={{
          fontFamily: "'MS Sans Serif', 'Tahoma', sans-serif",
          fontSize: 11, color: 'rgba(255,255,255,0.7)', lineHeight: 1.4,
          textShadow: '1px 1px 2px rgba(0,0,0,0.5)',
        }}>
          <div style={{ fontWeight: 'bold', fontSize: 14 }}>Connor Nelson</div>
          <div>Director</div>
          <div style={{ marginTop: 8, fontSize: 9, color: 'rgba(255,255,255,0.45)', lineHeight: 1.5 }}>
            <div>Wild Winter Film Festival — Best Director</div>
            <div>Sonscreen 2025 — Best Original Score (Fret)</div>
            <div>Sonscreen 2025 — Official Selection (Conversation with my Grandpa)</div>
            <div>End of Year Show — Best Editor</div>
            <div>Lift-Off Global Network — Official Selection</div>
          </div>
        </div>
      </div>

      {/* ── Laurels ── */}
      <div style={{
        position: 'absolute', bottom: 36, right: 16, zIndex: 0,
        display: 'flex', gap: 6, alignItems: 'center',
        pointerEvents: 'none', userSelect: 'none',
      }}>
        <img src="/sonscreen-laurel.png" alt="Sonscreen Film Festival Official Selection 2025" style={{ width: 65, opacity: 0.7 }} />
        <img src="/laurel.png" alt="Lift-Off Global Network Sessions 2023 Official Selection" style={{ width: 65, opacity: 0.7, filter: 'invert(1)' }} />
      </div>

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
