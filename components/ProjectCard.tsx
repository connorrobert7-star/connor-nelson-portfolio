'use client'

import Link from 'next/link'

interface ProjectCardProps {
  slug: string
  title: string
  medium: string
  year: string
  description: string
  accentColor?: string
  tilt?: 'neg' | 'pos' | 'none'
}

export default function ProjectCard({
  slug,
  title,
  medium,
  year,
  description,
  accentColor = '#8b1a1a',
  tilt = 'none',
}: ProjectCardProps) {
  const tiltStyle =
    tilt === 'neg'
      ? { transform: 'rotate(-0.6deg)' }
      : tilt === 'pos'
      ? { transform: 'rotate(0.6deg)' }
      : {}

  return (
    <Link
      href={`/portfolio/${slug}`}
      style={{
        display: 'block',
        border: '1px solid #2a2825',
        backgroundColor: '#111010',
        transition: 'border-color 0.4s ease, box-shadow 0.4s ease, transform 0.4s ease',
        ...tiltStyle,
      }}
      onMouseEnter={e => {
        const el = e.currentTarget as HTMLElement
        el.style.borderColor = accentColor
        el.style.boxShadow = `0 8px 40px rgba(0,0,0,0.6), 0 0 1px ${accentColor}`
        el.style.transform = `${tiltStyle.transform ?? ''} translateY(-3px)`
      }}
      onMouseLeave={e => {
        const el = e.currentTarget as HTMLElement
        el.style.borderColor = '#2a2825'
        el.style.boxShadow = 'none'
        el.style.transform = tiltStyle.transform ?? ''
      }}
    >
      {/* Image placeholder */}
      <div
        className="img-placeholder"
        style={{
          aspectRatio: '16/9',
          width: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderBottom: '1px solid #2a2825',
        }}
      >
        <svg
          width="40"
          height="40"
          viewBox="0 0 40 40"
          fill="none"
          style={{ opacity: 0.15 }}
        >
          <rect x="2" y="2" width="36" height="36" stroke="#e8e4dc" strokeWidth="0.5" />
          <line x1="2" y1="2" x2="38" y2="38" stroke="#e8e4dc" strokeWidth="0.5" />
          <line x1="38" y1="2" x2="2" y2="38" stroke="#e8e4dc" strokeWidth="0.5" />
        </svg>
      </div>

      {/* Card content */}
      <div style={{ padding: '1.25rem 1.5rem 1.5rem' }}>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'flex-start',
            marginBottom: '0.75rem',
          }}
        >
          <span
            style={{
              fontFamily: '"Courier Prime", monospace',
              fontSize: '0.65rem',
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
              color: accentColor,
            }}
          >
            {medium}
          </span>
          <span
            style={{
              fontFamily: '"Courier Prime", monospace',
              fontSize: '0.65rem',
              letterSpacing: '0.1em',
              color: '#3a3632',
            }}
          >
            {year}
          </span>
        </div>
        <h3
          style={{
            fontFamily: '"IM Fell English", Georgia, serif',
            fontSize: '1.4rem',
            color: '#e8e4dc',
            fontWeight: 400,
            marginBottom: '0.75rem',
            lineHeight: 1.2,
          }}
        >
          {title}
        </h3>
        <p
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.825rem',
            color: '#6b6560',
            lineHeight: 1.6,
          }}
        >
          {description}
        </p>
      </div>
    </Link>
  )
}
