import type { Metadata, Viewport } from 'next'
import { IM_Fell_English, Courier_Prime, Josefin_Sans } from 'next/font/google'
import './globals.css'
import Navigation from '@/components/Navigation'
import Footer from '@/components/Footer'
import GrainOverlay from '@/components/GrainOverlay'

const imFell = IM_Fell_English({
  weight: ['400'],
  style: ['normal', 'italic'],
  subsets: ['latin'],
  variable: '--font-fell-var',
  display: 'swap',
})

const courierPrime = Courier_Prime({
  weight: ['400', '700'],
  style: ['normal', 'italic'],
  subsets: ['latin'],
  variable: '--font-courier-var',
  display: 'swap',
})

// Futura fallback — actual Futura loads from system if available
const josefinSans = Josefin_Sans({
  weight: ['400', '600', '700'],
  style: ['normal'],
  subsets: ['latin'],
  variable: '--font-josefin',
  display: 'swap',
})

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
}

export const metadata: Metadata = {
  title: {
    default: 'Connor Nelson',
    template: '%s — Connor Nelson',
  },
  description:
    'Filmmaker, writer, and audio drama creator based in Chattanooga, TN. Films and stories at the intersection of landscape and dread.',
  authors: [{ name: 'Connor Nelson' }],
  creator: 'Connor Nelson',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${imFell.variable} ${courierPrime.variable} ${josefinSans.variable}`}>
      <body>
        <GrainOverlay />
        <Navigation />
        <main style={{ paddingTop: '48px' }}>
          {children}
        </main>
        <Footer />
      </body>
    </html>
  )
}
