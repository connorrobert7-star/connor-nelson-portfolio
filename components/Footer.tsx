export default function Footer() {
  return (
    <footer
      style={{
        borderTop: '1px solid var(--border-dim)',
        marginTop: '4rem',
        padding: '2rem 0 2.5rem',
      }}
    >
      <div
        className="site-wrap"
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '0.5rem',
        }}
      >
        <span
          style={{
            fontFamily: 'var(--font-futura)',
            fontSize: '0.55rem',
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            color: 'var(--text-ghost)',
          }}
        >
          Connor Nelson · Filmmaker / Writer · Chattanooga, TN
        </span>
        <span
          style={{
            fontFamily: 'var(--font-futura)',
            fontSize: '0.55rem',
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            color: 'var(--text-ghost)',
          }}
        >
          handmade in the dark
        </span>
      </div>
    </footer>
  )
}
