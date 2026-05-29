import type { Config } from 'tailwindcss'

export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Material 3 Expressive Colors
        background: '#0F1416',
        surface: '#111416',
        surfaceContainerLowest: '#070F11',
        surfaceContainerLow: '#151C1F',
        surfaceContainer: '#192023',
        surfaceContainerHigh: '#232A2E',
        surfaceContainerHighest: '#2E3539',
        surfaceHigh: '#2E3539', // Keeping for backwards compatibility
        primary: {
          DEFAULT: 'var(--color-primary, #85D2E0)',
          container: 'var(--color-primary-container, #004F58)',
          onContainer: '#A1EFFF',
        },
        secondary: {
          DEFAULT: '#B1CBD0',
          container: '#334A4F',
        },
        tertiary: {
          DEFAULT: '#FDB87C',
          container: '#663D16',
        },
        error: {
          DEFAULT: '#FFB4AB',
          container: '#93000A',
        },
        onSurface: '#E1E3E4',
        onSurfaceVariant: '#BFC8CA',
        outline: '#899295',
        outlineVariant: '#3F484B',
      },
      fontFamily: {
        heading: ['"Plus Jakarta Sans"', 'sans-serif'],
        body: ['"DM Sans"', 'sans-serif'],
        data: ['"Space Grotesk"', 'monospace'],
      },
      borderRadius: {
        'xl': '1rem', // 16px
        '2xl': '1.5rem', // 24px
        '3xl': '2rem', // 32px for expressive cards
      },
    },
  },
  plugins: [],
} satisfies Config
