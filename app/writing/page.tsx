import { Metadata } from 'next'
import { getAllPosts } from '@/lib/content'
import PostCard from '@/components/PostCard'

export const metadata: Metadata = {
  title: 'Writing',
  description: 'Film analysis, essays, creative writing, and reviews by Connor Nelson.',
}

const CATEGORIES = ['All', 'Film Analysis', 'Essay', 'Creative Writing', 'Review']

export default function WritingPage() {
  const posts = getAllPosts()

  return (
    <div
      style={{
        maxWidth: '1200px',
        margin: '0 auto',
        padding: 'clamp(2.5rem, 5vw, 5rem) 20px clamp(4rem, 8vw, 8rem)',
      }}
    >
      {/* Header */}
      <header style={{ marginBottom: 'clamp(2.5rem, 5vw, 5rem)' }}>
        <p
          style={{
            fontFamily: '"Courier Prime", monospace',
            fontSize: '0.65rem',
            letterSpacing: '0.25em',
            textTransform: 'uppercase',
            color: '#3a3632',
            marginBottom: '1.5rem',
          }}
        >
          Essays / Analysis / Fiction
        </p>
        <h1
          style={{
            fontFamily: '"IM Fell English", Georgia, serif',
            fontSize: 'clamp(2.5rem, 6vw, 5rem)',
            fontWeight: 400,
            lineHeight: 0.95,
            color: '#e8e4dc',
          }}
        >
          Writing
        </h1>

        {/* Category legend */}
        <div
          style={{
            display: 'flex',
            gap: '1.5rem',
            flexWrap: 'wrap',
            marginTop: '2.5rem',
          }}
        >
          {[
            { label: 'Film Analysis', color: '#c4833a' },
            { label: 'Essay', color: '#6b6560' },
            { label: 'Creative Writing', color: '#8b1a1a' },
            { label: 'Review', color: '#1a3a1a' },
          ].map(cat => (
            <span
              key={cat.label}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                fontFamily: '"Courier Prime", monospace',
                fontSize: '0.6rem',
                letterSpacing: '0.15em',
                textTransform: 'uppercase',
                color: '#3a3632',
              }}
            >
              <span
                style={{
                  display: 'inline-block',
                  width: '6px',
                  height: '6px',
                  backgroundColor: cat.color,
                }}
              />
              {cat.label}
            </span>
          ))}
        </div>

        <div className="hairline" style={{ marginTop: '2rem' }} />
      </header>

      {/* Post list */}
      <div style={{ maxWidth: '800px' }}>
        {posts.map((post, i) => (
          <PostCard
            key={post.slug}
            slug={post.slug}
            title={post.title}
            date={post.date}
            category={post.category}
            excerpt={post.excerpt}
            index={i}
          />
        ))}

        {posts.length === 0 && (
          <p
            style={{
              fontFamily: '"Courier Prime", monospace',
              fontSize: '0.875rem',
              color: '#3a3632',
              fontStyle: 'italic',
            }}
          >
            Nothing here yet. Come back when the dark settles.
          </p>
        )}
      </div>
    </div>
  )
}
