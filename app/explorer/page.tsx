'use client'

import { useEffect, useState, useCallback } from 'react'
import type { Story } from '@/lib/supabase'

type SearchResult = {
  story: Story
  explanation: string
}

const CATEGORIES = [
  { key: 'all', label: 'All' },
  { key: 'subcultures', label: 'Subcultures' },
  { key: 'small-town', label: 'Small Town' },
  { key: 'micro-celebrity', label: 'Micro-Celebrity' },
]

const PLATFORM_LABELS: Record<string, string> = {
  reddit: 'Reddit',
  youtube: 'YouTube',
  news: 'News',
  instagram: 'Instagram',
  tiktok: 'TikTok',
  '4chan': '4chan',
}

const CATEGORY_LABELS: Record<string, string> = {
  subcultures: 'Subcultures',
  'small-town': 'Small Town',
  'micro-celebrity': 'Micro-Celebrity',
}

function formatAudience(n: number | null): string {
  if (!n) return '—'
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`
  if (n >= 1000) return `${(n / 1000).toFixed(0)}K`
  return n.toString()
}

function daysUntilExpiry(foundAt: string): number {
  const found = new Date(foundAt)
  const expiry = new Date(found)
  expiry.setMonth(expiry.getMonth() + 6)
  return Math.max(0, Math.ceil((expiry.getTime() - Date.now()) / (1000 * 60 * 60 * 24)))
}

function timeAgo(date: string): string {
  const diff = Date.now() - new Date(date).getTime()
  const hours = Math.floor(diff / (1000 * 60 * 60))
  if (hours < 1) return 'just now'
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 7) return `${days}d ago`
  return `${Math.floor(days / 7)}w ago`
}

export default function ExplorerPage() {
  const [stories, setStories] = useState<Story[]>([])
  const [category, setCategory] = useState('all')
  const [searchResults, setSearchResults] = useState<SearchResult[] | null>(null)
  const [loading, setLoading] = useState(true)
  const [query, setQuery] = useState('')
  const [searching, setSearching] = useState(false)

  const fetchStories = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`/api/stories?category=${category}`)
      const data = await res.json()
      setStories(data.stories || [])
    } catch {
      setStories([])
    } finally {
      setLoading(false)
    }
  }, [category])

  useEffect(() => {
    fetchStories()
  }, [fetchStories])

  async function handleSearch(e: React.FormEvent) {
    e.preventDefault()
    if (!query.trim()) { setSearchResults(null); return }
    setSearching(true)
    try {
      const res = await fetch(`/api/search?q=${encodeURIComponent(query.trim())}`)
      const data = await res.json()
      setSearchResults(data.results)
    } catch {
      setSearchResults([])
    } finally {
      setSearching(false)
    }
  }

  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  })

  const scanTime = stories[0]?.found_at
    ? new Date(stories[0].found_at).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
    : '—'

  const lead = stories[0]
  const sidebar = stories.slice(1, 4)
  const grid = stories.slice(4)

  return (
    <div className="site-wrap" style={{ paddingTop: '2rem', paddingBottom: '4rem', overflowWrap: 'break-word', wordBreak: 'break-word' }}>
      {/* Masthead */}
      <header style={{ borderBottom: '1px solid var(--border)', paddingBottom: '1.25rem', marginBottom: '1.5rem' }}>
        <div style={{ textAlign: 'center' }}>
          <div className="label" style={{ marginBottom: '0.25rem' }}>{today}</div>
          <h1 className="fell" style={{ fontSize: 'clamp(2.5rem, 6vw, 4rem)', letterSpacing: '-0.02em', lineHeight: 1 }}>
            The Signal
          </h1>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '1rem', marginTop: '0.5rem' }}>
            <span className="label">{stories.length} stories</span>
            <span style={{ color: 'var(--text-ghost)' }}>|</span>
            <span className="label" style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
              <span style={{
                width: 6, height: 6, borderRadius: '50%', background: '#22c55e',
                display: 'inline-block', boxShadow: '0 0 4px #22c55e',
              }} />
              Last scan: {scanTime}
            </span>
          </div>
        </div>
      </header>

      {/* Search */}
      <form onSubmit={handleSearch} style={{ marginBottom: '1.25rem' }}>
        <div style={{ display: 'flex', border: '1px solid var(--border)' }}>
          <input
            type="text"
            value={query}
            onChange={e => { setQuery(e.target.value); if (!e.target.value.trim()) setSearchResults(null) }}
            placeholder='Search stories... (e.g. "find me something like the adult baby town story")'
            style={{
              flex: 1, minWidth: 0, padding: '0.5rem 0.75rem', background: 'var(--bg-raise)', color: 'var(--text)',
              border: 'none', outline: 'none', fontFamily: 'var(--font-mono)', fontSize: '0.8rem',
            }}
          />
          <button
            type="submit"
            disabled={searching}
            style={{
              padding: '0.5rem 1rem', background: 'var(--text-dim)', color: 'var(--text)',
              border: 'none', fontFamily: 'var(--font-futura)', fontSize: '0.55rem',
              fontWeight: 600, letterSpacing: '0.18em', textTransform: 'uppercase' as const,
              cursor: 'pointer', opacity: searching ? 0.5 : 1, flexShrink: 0, whiteSpace: 'nowrap' as const,
            }}
          >
            {searching ? 'Searching...' : 'Search'}
          </button>
        </div>
      </form>

      {searchResults ? (
        /* Search results */
        <div>
          <div className="rule-text">Search Results</div>
          {searchResults.length === 0 ? (
            <p style={{ textAlign: 'center', color: 'var(--text-mid)', fontStyle: 'italic', padding: '3rem 0' }}>
              No matching stories found.
            </p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
              {searchResults.map(result => (
                <div key={result.story.id}>
                  <p style={{ fontSize: '0.7rem', color: 'var(--text-dim)', fontStyle: 'italic', marginBottom: '0.5rem' }}>
                    Match: {result.explanation}
                  </p>
                  <StoryCard story={result.story} variant="grid" />
                </div>
              ))}
            </div>
          )}
        </div>
      ) : (
        <>
          {/* Category nav */}
          <nav style={{ display: 'flex', flexWrap: 'wrap', gap: '0.25rem', marginBottom: '1.5rem', borderBottom: '1px solid var(--border-dim)', paddingBottom: '0.75rem' }}>
            {CATEGORIES.map(cat => (
              <button
                key={cat.key}
                onClick={() => setCategory(cat.key)}
                className="label"
                style={{
                  padding: '0.25rem 0.6rem',
                  background: category === cat.key ? 'var(--text-dim)' : 'transparent',
                  color: category === cat.key ? 'var(--text)' : 'var(--text-dim)',
                  border: 'none', cursor: 'pointer', transition: 'all 0.2s',
                }}
              >
                {cat.label}
              </button>
            ))}
          </nav>

          {loading ? (
            <p style={{ textAlign: 'center', color: 'var(--text-mid)', fontStyle: 'italic', padding: '4rem 0' }}>
              Loading...
            </p>
          ) : stories.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '4rem 0' }}>
              <p className="fell" style={{ fontSize: '1.5rem', color: 'var(--text-mid)', fontStyle: 'italic' }}>
                No stories yet.
              </p>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-dim)', marginTop: '0.5rem' }}>
                The scraper runs every 6 hours. Check back soon.
              </p>
            </div>
          ) : (
            <>
              {/* Above the fold: lead + sidebar */}
              <div style={{
                display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 320px), 1fr))', gap: '1.5rem',
                marginBottom: '2rem', paddingBottom: '2rem', borderBottom: '1px solid var(--border-dim)',
              }}>
                {lead && <StoryCard story={lead} variant="lead" />}
                <div style={{ display: 'flex', flexDirection: 'column' }}>
                  {sidebar.map(story => (
                    <StoryCard key={story.id} story={story} variant="sidebar" />
                  ))}
                </div>
              </div>

              {/* Below the fold: grid */}
              {grid.length > 0 && (
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 280px), 1fr))', gap: '1.5rem' }}>
                  {grid.map(story => (
                    <StoryCard key={story.id} story={story} variant="grid" />
                  ))}
                </div>
              )}
            </>
          )}
        </>
      )}

      <footer style={{
        marginTop: '3rem', paddingTop: '1rem', borderTop: '1px solid var(--border-dim)',
        textAlign: 'center', fontSize: '0.6rem', color: 'var(--text-ghost)',
        fontFamily: 'var(--font-futura)', letterSpacing: '0.15em', textTransform: 'uppercase' as const,
      }}>
        The Signal — Stories expire after 6 months. Always rolling. Always fresh.
      </footer>
    </div>
  )
}

function StoryCard({ story, variant }: { story: Story; variant: 'lead' | 'sidebar' | 'grid' }) {
  const expiryDays = daysUntilExpiry(story.found_at)

  const meta = (
    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap', fontSize: '0.6rem', color: 'var(--text-dim)', fontFamily: 'var(--font-futura)', letterSpacing: '0.1em' }}>
      <span style={{ color: 'var(--text-mid)', fontWeight: 600 }}>
        {PLATFORM_LABELS[story.source_platform] || story.source_platform}
      </span>
      <span>~{formatAudience(story.audience_size_estimate)}</span>
      <span>{timeAgo(story.found_at)}</span>
      <span style={{
        padding: '1px 4px',
        background: expiryDays < 30 ? 'rgba(122, 24, 24, 0.2)' : 'rgba(255,255,255,0.03)',
        color: expiryDays < 30 ? 'var(--red)' : 'var(--text-dim)',
      }}>
        {expiryDays}d
      </span>
    </div>
  )

  const categoryTag = (
    <span style={{
      fontFamily: 'var(--font-futura)', fontSize: '0.5rem', fontWeight: 600,
      letterSpacing: '0.2em', textTransform: 'uppercase' as const, color: 'var(--red)',
    }}>
      {CATEGORY_LABELS[story.category] || story.category}
    </span>
  )

  if (variant === 'lead') {
    return (
      <article style={{ paddingRight: '1.5rem', borderRight: '1px solid var(--border-dim)' }}>
        {categoryTag}
        <h2 className="fell" style={{ fontSize: 'clamp(1.5rem, 3vw, 2.25rem)', lineHeight: 1.15, margin: '0.25rem 0 0.5rem' }}>
          <a href={story.source_url} target="_blank" rel="noopener noreferrer" className="u-link">
            {story.headline}
          </a>
        </h2>
        {story.dek && (
          <p style={{ fontSize: '0.9rem', color: 'var(--text-mid)', fontStyle: 'italic', marginBottom: '0.75rem' }}>
            {story.dek}
          </p>
        )}
        <p style={{ fontSize: '0.85rem', lineHeight: 1.75, marginBottom: '0.75rem' }}>
          {story.body}
        </p>
        {meta}
      </article>
    )
  }

  if (variant === 'sidebar') {
    return (
      <article style={{ paddingBottom: '0.75rem', marginBottom: '0.75rem', borderBottom: '1px solid var(--border-dim)' }}>
        {categoryTag}
        <h3 className="fell" style={{ fontSize: '1rem', lineHeight: 1.25, margin: '0.15rem 0 0.3rem' }}>
          <a href={story.source_url} target="_blank" rel="noopener noreferrer" className="u-link">
            {story.headline}
          </a>
        </h3>
        <p style={{ fontSize: '0.75rem', lineHeight: 1.6, color: 'var(--text-mid)', marginBottom: '0.4rem' }}>
          {story.body.slice(0, 180)}{story.body.length > 180 ? '...' : ''}
        </p>
        {meta}
      </article>
    )
  }

  return (
    <article>
      {categoryTag}
      <h3 className="fell" style={{ fontSize: '1.1rem', lineHeight: 1.25, margin: '0.15rem 0 0.3rem' }}>
        <a href={story.source_url} target="_blank" rel="noopener noreferrer" className="u-link">
          {story.headline}
        </a>
      </h3>
      {story.dek && (
        <p style={{ fontSize: '0.7rem', fontStyle: 'italic', color: 'var(--text-dim)', marginBottom: '0.25rem' }}>
          {story.dek}
        </p>
      )}
      <p style={{ fontSize: '0.75rem', lineHeight: 1.6, color: 'var(--text-mid)', marginBottom: '0.4rem' }}>
        {story.body.slice(0, 220)}{story.body.length > 220 ? '...' : ''}
      </p>
      {meta}
    </article>
  )
}
