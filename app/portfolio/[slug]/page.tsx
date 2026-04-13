import { Metadata } from 'next'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { getProject, getProjectSlugs } from '@/lib/content'

interface Props {
  params: Promise<{ slug: string }>
}

export async function generateStaticParams() {
  return getProjectSlugs().map(slug => ({ slug }))
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const project = await getProject(slug)
  if (!project) return {}
  return {
    title: project.title,
    description: project.description,
  }
}

export default async function ProjectPage({ params }: Props) {
  const { slug } = await params
  const project = await getProject(slug)
  if (!project) notFound()

  const accent = project.accentColor ?? '#8b1a1a'

  return (
    <article>
      {/* ── Atmospheric Header ── */}
      <header
        style={{
          position: 'relative',
          minHeight: 'clamp(35vh, 50vw, 55vh)',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'flex-end',
          padding: '0 clamp(1.25rem, 4vw, 2rem) clamp(2rem, 5vw, 4rem)',
          maxWidth: '1200px',
          margin: '0 auto',
          overflow: 'hidden',
        }}
      >
        {/* Ambient glow based on accent color */}
        <div
          aria-hidden
          style={{
            position: 'absolute',
            bottom: 0,
            left: 0,
            width: '50%',
            height: '70%',
            background: `radial-gradient(ellipse at bottom left, ${accent}18 0%, transparent 65%)`,
            pointerEvents: 'none',
          }}
        />

        {/* Back link */}
        <Link
          href="/portfolio"
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.65rem',
            letterSpacing: '0.2em',
            textTransform: 'uppercase',
            color: '#3a3632',
            marginBottom: '3rem',
            position: 'relative',
            zIndex: 1,
            transition: 'color 0.3s ease',
          }}
          className="link-underline"
        >
          ← Portfolio
        </Link>

        <div style={{ position: 'relative', zIndex: 1 }}>
          {/* Medium + Year */}
          <div
            style={{
              display: 'flex',
              gap: '2rem',
              alignItems: 'center',
              marginBottom: '1.5rem',
            }}
          >
            <span
              style={{
                fontFamily: '"Courier Prime", monospace',
                fontSize: '0.65rem',
                letterSpacing: '0.2em',
                textTransform: 'uppercase',
                color: accent,
              }}
            >
              {project.medium}
            </span>
            <span
              style={{
                fontFamily: '"Courier Prime", monospace',
                fontSize: '0.65rem',
                letterSpacing: '0.1em',
                color: '#3a3632',
              }}
            >
              {project.year}
              {project.runtime && ` · ${project.runtime}`}
            </span>
          </div>

          <h1
            style={{
              fontFamily: '"IM Fell English", Georgia, serif',
              fontSize: 'clamp(2.5rem, 7vw, 6rem)',
              fontWeight: 400,
              lineHeight: 0.95,
              letterSpacing: '-0.02em',
              color: '#e8e4dc',
            }}
          >
            {project.title}
          </h1>
        </div>
      </header>

      {/* ── Hairline ── */}
      <div
        style={{
          maxWidth: '1200px',
          margin: '0 auto',
          padding: '0 clamp(1.25rem, 4vw, 2rem)',
        }}
      >
        <div style={{ height: '1px', backgroundColor: accent, opacity: 0.3 }} />
      </div>


      {/* ── Content ── */}
      <div
        style={{
          maxWidth: '1200px',
          margin: '0 auto',
          padding: 'clamp(1.25rem, 3vw, 2rem) clamp(1.25rem, 4vw, 2rem) clamp(4rem, 8vw, 8rem)',
          display: 'grid',
          gridTemplateColumns: '1fr',
          gap: '0',
        }}
      >
        {/* Sidebar / spacer — intentionally off-center */}
        <div style={{ display: 'none' }} className="project-sidebar" />

        {/* Main content */}
        <div
          className="prose"
          dangerouslySetInnerHTML={{ __html: project.contentHtml ?? '' }}
          style={{ gridColumn: '1 / -1', maxWidth: '100%', overflowWrap: 'break-word' }}
        />
      </div>
    </article>
  )
}
