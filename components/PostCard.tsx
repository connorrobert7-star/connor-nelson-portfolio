'use client'

import Link from 'next/link'

interface PostCardProps {
  slug: string
  title: string
  date: string
  category: string
  excerpt: string
  index?: number
}

const categoryColors: Record<string, string> = {
  'Film Analysis': '#c4833a',
  'Essay': '#6b6560',
  'Creative Writing': '#8b1a1a',
  'Review': '#1a3a1a',
}

export default function PostCard({ slug, title, date, category, excerpt, index = 0 }: PostCardProps) {
  const catColor = categoryColors[category] ?? '#6b6560'

  return (
    <article
      style={{
        borderBottom: '1px solid #2a2825',
        paddingBottom: '2rem',
        marginBottom: '2rem',
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '1.5rem',
          marginBottom: '0.75rem',
        }}
      >
        {/* Index number */}
        <span
          style={{
            fontFamily: '"IM Fell English", Georgia, serif',
            fontSize: '0.875rem',
            color: '#2a2825',
            fontStyle: 'italic',
            minWidth: '2ch',
          }}
        >
          {String(index + 1).padStart(2, '0')}.
        </span>

        {/* Category tag */}
        <span
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.6rem',
            letterSpacing: '0.2em',
            textTransform: 'uppercase',
            color: catColor,
            border: `1px solid ${catColor}`,
            padding: '0.15rem 0.5rem',
          }}
        >
          {category}
        </span>

        {/* Date */}
        <span
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.7rem',
            letterSpacing: '0.08em',
            color: '#3a3632',
            marginLeft: 'auto',
          }}
        >
          {date}
        </span>
      </div>

      <Link
        href={`/writing/${slug}`}
        style={{ display: 'block' }}
      >
        <h2
          style={{
            fontFamily: '"IM Fell English", Georgia, serif',
            fontSize: 'clamp(1.25rem, 3vw, 1.75rem)',
            color: '#e8e4dc',
            fontWeight: 400,
            lineHeight: 1.2,
            marginBottom: '0.75rem',
            paddingLeft: '3.5rem',
            transition: 'color 0.3s ease',
          }}
          className="post-title"
          onMouseEnter={e => (e.currentTarget.style.color = '#c4833a')}
          onMouseLeave={e => (e.currentTarget.style.color = '#e8e4dc')}
        >
          {title}
        </h2>
      </Link>

      <p
        style={{
          fontFamily: '"Courier Prime", monospace',
          fontSize: '0.875rem',
          color: '#6b6560',
          lineHeight: 1.7,
          paddingLeft: '3.5rem',
          maxWidth: '60ch',
        }}
      >
        {excerpt}
      </p>

      <div style={{ paddingLeft: '3.5rem', marginTop: '1rem' }}>
        <Link
          href={`/writing/${slug}`}
          className="link-underline"
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.7rem',
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
            color: '#3a3632',
          }}
        >
          Read →
        </Link>
      </div>
    </article>
  )
}
