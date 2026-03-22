import { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'About',
  description: 'Connor Nelson — filmmaker, writer, and audio drama creator from rural Michigan.',
}

export default function AboutPage() {
  return (
    <div className="site-wrap" style={{ padding: '2.5rem 1.25rem 6rem' }}>

      <div style={{ marginBottom: '2.5rem' }}>
        <Link href="/" className="dim-link">← home</Link>
      </div>

      <div className="two-col">

        {/* Left */}
        <div className="main-col">
          <h1
            className="fell"
            style={{
              fontSize: 'clamp(1.75rem, 4vw, 3rem)',
              fontWeight: 400,
              color: 'var(--text)',
              marginBottom: '2rem',
            }}
          >
            About
          </h1>

          <div className="prose" style={{ marginBottom: '3rem' }}>
            <p>
              I grew up in rural Michigan — the kind of place where the
              distance between one thing and the next is long enough to
              become something else entirely. That geography is in everything
              I make.
            </p>
            <p>
              I'm a filmmaker, writer, and audio drama creator. My work
              tends toward the dark: psychological horror, folk horror,
              slow cinema. Stories that take the landscape seriously as a
              character. Stories where the dread is earned rather than
              announced.
            </p>
            <p>
              <em>Dead on TV</em> was my debut short — eighteen minutes shot
              in February in rural Michigan, about grief and static and the
              permeable membrane between what we know and what we've lost.
              It started as a question: what does grief look like when it has
              nowhere to go?
            </p>
            <p>
              <em>Everywhere You Go</em> came out of research into Slavic
              folklore and the immigrant communities of the Great Lakes
              region. What crosses an ocean with you. What transforms.
              What refuses to.
            </p>
            <p>
              <em>Twenty Mile Road</em> is an audio drama — a story told
              entirely in sound because some places refuse to be photographed.
              I've been working on it for three years. It's almost ready.
            </p>
            <p>
              I write about film — mostly horror, slow cinema, and the
              American landscape. Influences: Lynch, Malick, Béla Tarr,
              Kiyoshi Kurosawa, Flannery O'Connor, Denis Johnson.
            </p>
          </div>

          <div
            style={{
              borderTop: '1px solid var(--border-dim)',
              paddingTop: '1.5rem',
            }}
          >
            <Link
              href="/contact"
              style={{
                fontFamily: 'var(--font-futura)',
                fontSize: '0.6rem',
                letterSpacing: '0.18em',
                textTransform: 'uppercase',
                color: 'var(--amber)',
                border: '1px solid var(--amber)',
                padding: '0.55rem 1.2rem',
                display: 'inline-block',
                transition: 'background 0.25s, color 0.25s',
              }}
            >
              Get in touch →
            </Link>
          </div>
        </div>

        {/* Right sidebar */}
        <aside style={{ width: '195px', flexShrink: 0 }}>

          {/* Portrait */}
          <div
            className="img-ph"
            style={{
              width: '100%',
              aspectRatio: '3/4',
              marginBottom: '1.25rem',
              transform: 'rotate(-0.8deg)',
            }}
          >
            <svg width="28" height="28" viewBox="0 0 40 40" fill="none" style={{ opacity: 0.08 }}>
              <circle cx="20" cy="14" r="6" stroke="#ddd" strokeWidth="0.5" />
              <path d="M5 38C5 27 35 27 35 38" stroke="#ddd" strokeWidth="0.5" fill="none" />
            </svg>
          </div>

          {/* Info table */}
          <div className="widget">
            <div className="widget-head"><span>◈</span> info</div>
            <div className="widget-body">
              <table style={{ width: '100%', borderSpacing: 0 }}>
                {[
                  ['medium',    'film, audio, writing'],
                  ['based',     'rural michigan'],
                  ['genre',     'horror / literary'],
                  ['mode',      'slow, dark, specific'],
                ].map(([k, v]) => (
                  <tr key={k}>
                    <td
                      style={{
                        fontFamily: 'var(--font-futura)',
                        fontSize: '0.5rem',
                        letterSpacing: '0.15em',
                        textTransform: 'uppercase',
                        color: 'var(--text-dim)',
                        paddingRight: '0.5rem',
                        paddingBottom: '0.4rem',
                        verticalAlign: 'top',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {k}
                    </td>
                    <td
                      style={{
                        fontSize: '0.76rem',
                        color: 'var(--text-mid)',
                        paddingBottom: '0.4rem',
                      }}
                    >
                      {v}
                    </td>
                  </tr>
                ))}
              </table>
            </div>
          </div>

          {/* Influences */}
          <div className="widget">
            <div className="widget-head"><span>◈</span> influences</div>
            <div className="widget-body">
              <ul
                style={{
                  listStyle: 'none',
                  fontSize: '0.78rem',
                  color: 'var(--text-dim)',
                  lineHeight: 1.9,
                }}
              >
                {[
                  'Lynch', 'Malick', 'Béla Tarr',
                  'Kurosawa (K.)', 'Flannery O\'Connor',
                  'Denis Johnson', 'VHS artifact',
                  'field recordings', 'the U.P. in February',
                ].map(i => (
                  <li key={i}>— {i}</li>
                ))}
              </ul>
            </div>
          </div>

        </aside>
      </div>
    </div>
  )
}
