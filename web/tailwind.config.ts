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
        // Material 3 Expressive Colors mapped to CSS variables
        background: 'var(--color-bg, #0F1416)',
        surface: 'var(--color-surface, #111416)',
        surfaceContainerLowest: 'var(--color-surface-lowest, #070F11)',
        surfaceContainerLow: 'var(--color-surface-low, #151C1F)',
        surfaceContainer: 'var(--color-surface-container, #192023)',
        surfaceContainerHigh: 'var(--color-surface-high, #232A2E)',
        surfaceContainerHighest: 'var(--color-surface-highest, #2E3539)',
        surfaceHigh: 'var(--color-surface-highest, #2E3539)', // Backwards compatibility
        primary: {
          DEFAULT: 'var(--color-primary, #85D2E0)',
          container: 'var(--color-primary-container, #004F58)',
          onContainer: 'var(--color-on-primary-container, #A1EFFF)',
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
        onSurface: 'var(--color-on-surface, #E1E3E4)',
        onSurfaceVariant: 'var(--color-on-surface-variant, #BFC8CA)',
        outline: 'var(--color-outline, #899295)',
        outlineVariant: 'var(--color-outline-variant, #3F484B)',
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
