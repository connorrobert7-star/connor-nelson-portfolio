import { Metadata } from 'next'
import Link from 'next/link'
import { getAllProjects } from '@/lib/content'

export const metadata: Metadata = {
  title: 'Work',
  description: 'Films, audio dramas, and projects by Connor Nelson.',
}

export default function PortfolioPage() {
  const projects = getAllProjects()

  return (
    <div className="site-wrap" style={{ padding: 'clamp(1.5rem, 4vw, 2.5rem) 20px clamp(3rem, 6vw, 6rem)' }}>

      <div style={{ marginBottom: '2.5rem' }}>
        <Link href="/" className="dim-link">← home</Link>
      </div>

      <h1
        className="fell"
        style={{
          fontSize: 'clamp(1.75rem, 4vw, 3rem)',
          fontWeight: 400,
          color: 'var(--text)',
          marginBottom: '0.4rem',
        }}
      >
        Work
      </h1>
      <p
        style={{
          fontFamily: 'var(--font-futura)',
          fontSize: '0.56rem',
          letterSpacing: '0.2em',
          textTransform: 'uppercase',
          color: 'var(--text-dim)',
          marginBottom: '2.5rem',
        }}
      >
        Films · Audio · Ongoing
      </p>

      <div style={{ borderTop: '1px solid var(--border-dim)' }}>
        {projects.map(p => (
          <Link
            key={p.slug}
            href={`/portfolio/${p.slug}`}
            style={{
              display: 'flex',
              gap: '2rem',
              padding: '1.4rem 0',
              borderBottom: '1px solid var(--border-dim)',
              alignItems: 'flex-start',
              transition: 'background 0.2s',
            }}
          >
            {/* Image thumbnail */}
            <div
              className="img-ph portfolio-thumb"
              style={{
                width: 'clamp(60px, 12vw, 100px)',
                aspectRatio: '16/9',
                flexShrink: 0,
              }}
            >
              <svg width="20" height="20" viewBox="0 0 20 20" fill="none" style={{ opacity: 0.1 }}>
                <rect x="1" y="1" width="18" height="18" stroke="#ddd" strokeWidth="0.5" />
                <line x1="1" y1="1" x2="19" y2="19" stroke="#ddd" strokeWidth="0.5" />
                <line x1="19" y1="1" x2="1" y2="19" stroke="#ddd" strokeWidth="0.5" />
              </svg>
            </div>

            <div style={{ flex: 1, minWidth: 0 }}>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'baseline',
                  gap: '1rem',
                  marginBottom: '0.4rem',
                }}
              >
                <span
                  className="fell u-link"
                  style={{ fontSize: '1.15rem' }}
                >
                  {p.title}
                </span>
                <span
                  style={{
                    fontFamily: 'var(--font-futura)',
                    fontSize: '0.52rem',
                    letterSpacing: '0.15em',
                    textTransform: 'uppercase',
                    color: 'var(--text-ghost)',
                    flexShrink: 0,
                  }}
                >
                  {p.year}{p.runtime ? ` · ${p.runtime}` : ''}
                </span>
              </div>

              <p
                style={{
                  fontFamily: 'var(--font-futura)',
                  fontSize: '0.56rem',
                  letterSpacing: '0.15em',
                  textTransform: 'uppercase',
                  color: 'var(--red)',
                  marginBottom: '0.5rem',
                }}
              >
                {p.medium}
              </p>

              <p
                style={{
                  fontSize: '0.82rem',
                  color: 'var(--text-dim)',
                  lineHeight: 1.65,
                  maxWidth: 'min(60ch, 100%)',
                }}
              >
                {p.description}
              </p>
            </div>
          </Link>
        ))}
      </div>

    </div>
  )
}
