import { Metadata } from 'next'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { getPost, getPostSlugs } from '@/lib/content'

interface Props {
  params: Promise<{ slug: string }>
}

export async function generateStaticParams() {
  return getPostSlugs().map(slug => ({ slug }))
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  if (!post) return {}
  return {
    title: post.title,
    description: post.excerpt,
  }
}

const categoryColors: Record<string, string> = {
  'Film Analysis': '#c4833a',
  'Essay': '#6b6560',
  'Creative Writing': '#8b1a1a',
  'Review': '#1a3a1a',
}

export default async function PostPage({ params }: Props) {
  const { slug } = await params
  const post = await getPost(slug)
  if (!post) notFound()

  const catColor = categoryColors[post.category] ?? '#6b6560'

  return (
    <article>
      {/* ── Header ── */}
      <header
        style={{
          maxWidth: '1200px',
          margin: '0 auto',
          padding: '5rem clamp(1.25rem, 5vw, 2rem) 4rem',
        }}
      >
        <Link
          href="/writing"
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.65rem',
            letterSpacing: '0.2em',
            textTransform: 'uppercase',
            color: '#3a3632',
            display: 'inline-block',
            marginBottom: '3rem',
          }}
          className="link-underline"
        >
          ← Writing
        </Link>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '1.5rem',
            flexWrap: 'wrap',
            marginBottom: '1.5rem',
          }}
        >
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
            {post.category}
          </span>
          <span
            style={{
              fontFamily: '"Courier Prime", monospace',
              fontSize: '0.7rem',
              letterSpacing: '0.08em',
              color: '#3a3632',
            }}
          >
            {post.date}
          </span>
        </div>

        <h1
          style={{
            fontFamily: '"IM Fell English", Georgia, serif',
            fontSize: 'clamp(2rem, 5vw, 4rem)',
            fontWeight: 400,
            lineHeight: 1.05,
            letterSpacing: '-0.01em',
            color: '#e8e4dc',
            maxWidth: '18ch',
          }}
        >
          {post.title}
        </h1>

        {post.excerpt && (
          <p
            style={{
              fontFamily: '"Courier Prime", monospace',
              fontSize: '1rem',
              color: '#6b6560',
              lineHeight: 1.7,
              maxWidth: 'min(55ch, 100%)',
              marginTop: '1.5rem',
              fontStyle: 'italic',
            }}
          >
            {post.excerpt}
          </p>
        )}

        <div className="hairline" style={{ marginTop: '3rem' }} />
      </header>

      {/* ── Body ── */}
      <div
        style={{
          maxWidth: '1200px',
          margin: '0 auto',
          padding: '3rem clamp(1.25rem, 5vw, 2rem) 8rem',
        }}
      >
        <div
          className="prose"
          dangerouslySetInnerHTML={{ __html: post.contentHtml ?? '' }}
          style={{ marginLeft: 'auto', marginRight: 'auto' }}
        />

        {/* Tags */}
        {post.tags && post.tags.length > 0 && (
          <div
            style={{
              borderTop: '1px solid #2a2825',
              marginTop: '4rem',
              paddingTop: '2rem',
              maxWidth: 'min(65ch, 100%)',
              margin: '4rem auto 0',
            }}
          >
            <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
              {post.tags.map(tag => (
                <span
                  key={tag}
                  style={{
                    fontFamily: '"Courier Prime", monospace',
                    fontSize: '0.6rem',
                    letterSpacing: '0.15em',
                    textTransform: 'uppercase',
                    color: '#3a3632',
                    border: '1px solid #2a2825',
                    padding: '0.2rem 0.6rem',
                  }}
                >
                  {tag}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>
    </article>
  )
}
