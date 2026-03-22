import { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Contact',
  description: 'Get in touch with Connor Nelson.',
}

export default function ContactPage() {
  return (
    <div
      className="site-wrap"
      style={{
        padding: '2.5rem 1.25rem 6rem',
        minHeight: '75vh',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
      }}
    >
      <div style={{ marginBottom: '3rem' }}>
        <Link href="/" className="dim-link">← home</Link>
      </div>

      <div style={{ maxWidth: '520px' }}>
        <h1
          className="fell"
          style={{
            fontSize: 'clamp(1.75rem, 4vw, 3rem)',
            fontWeight: 400,
            color: 'var(--text)',
            marginBottom: '0.5rem',
          }}
        >
          Contact
        </h1>

        <div
          style={{
            borderTop: '1px solid var(--border-dim)',
            paddingTop: '2rem',
            marginTop: '1.5rem',
          }}
        >
          <p
            style={{
              fontSize: '0.875rem',
              color: 'var(--text-mid)',
              lineHeight: 1.85,
              marginBottom: '2rem',
            }}
          >
            For collaboration, festival inquiries, press, or just to say
            something in the direction of the dark.
          </p>

          <a
            href="mailto:hello@connornelson.com"
            className="fell u-link"
            style={{
              fontSize: 'clamp(1.15rem, 3vw, 1.5rem)',
              fontStyle: 'italic',
              display: 'inline-block',
              marginBottom: '3rem',
            }}
          >
            hello@connornelson.com
          </a>

          <p
            style={{
              fontFamily: 'var(--font-futura)',
              fontSize: '0.52rem',
              letterSpacing: '0.2em',
              textTransform: 'uppercase',
              color: 'var(--text-ghost)',
              lineHeight: 2.2,
            }}
          >
            Filmmaker · Writer · Rural Michigan
            <br />
            Response time: when the signal is clear
          </p>
        </div>
      </div>
    </div>
  )
}
