'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

const links = [
  { href: '/',          label: 'home'    },
  { href: '/portfolio', label: 'work'    },
  { href: '/writing',   label: 'writing' },
  { href: '/about',     label: 'about'   },
  { href: '/contact',   label: 'contact' },
]

export default function Navigation() {
  const pathname = usePathname()

  return (
    <header className="site-nav">
      <div className="site-nav-inner">
        <Link href="/" className="nav-name">Connor Nelson</Link>
        <nav>
          <ul className="nav-links">
            {links.map(({ href, label }) => {
              const active = pathname === href
              return (
                <li key={href}>
                  <Link
                    href={href}
                    style={{ color: active ? 'var(--text-mid)' : undefined }}
                  >
                    {label}
                  </Link>
                </li>
              )
            })}
          </ul>
        </nav>
      </div>
    </header>
  )
}
