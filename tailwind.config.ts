import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        background: '#0a0908',
        surface: '#111010',
        'surface-light': '#1a1917',
        border: '#2a2825',
        'text-primary': '#e8e4dc',
        'text-muted': '#6b6560',
        'text-ghost': '#3a3632',
        'accent-red': '#8b1a1a',
        'accent-amber': '#c4833a',
        'accent-green': '#1a3a1a',
      },
      fontFamily: {
        heading: ['"IM Fell English"', 'Georgia', 'serif'],
        body: ['"Courier Prime"', 'Courier New', 'monospace'],
        ui: ['system-ui', 'sans-serif'],
      },
      fontSize: {
        'display': ['clamp(4rem, 12vw, 9rem)', { lineHeight: '0.9', letterSpacing: '-0.02em' }],
        'display-sm': ['clamp(2.5rem, 6vw, 5rem)', { lineHeight: '1', letterSpacing: '-0.01em' }],
      },
      borderRadius: {
        DEFAULT: '0',
        none: '0',
      },
      transitionDuration: {
        '400': '400ms',
        '600': '600ms',
      },
      animation: {
        'flicker': 'flicker 8s infinite',
        'grain': 'grain 0.5s steps(1) infinite',
      },
      keyframes: {
        flicker: {
          '0%, 100%': { opacity: '1' },
          '92%': { opacity: '1' },
          '93%': { opacity: '0.8' },
          '94%': { opacity: '1' },
          '96%': { opacity: '0.9' },
          '97%': { opacity: '1' },
        },
        grain: {
          '0%, 100%': { transform: 'translate(0, 0)' },
          '10%': { transform: 'translate(-2%, -3%)' },
          '20%': { transform: 'translate(3%, 1%)' },
          '30%': { transform: 'translate(-1%, 4%)' },
          '40%': { transform: 'translate(2%, -2%)' },
          '50%': { transform: 'translate(-3%, 3%)' },
          '60%': { transform: 'translate(1%, -1%)' },
          '70%': { transform: 'translate(-2%, 2%)' },
          '80%': { transform: 'translate(3%, -3%)' },
          '90%': { transform: 'translate(-1%, 1%)' },
        },
      },
    },
  },
  plugins: [],
}
export default config
