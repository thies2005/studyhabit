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
        // Stitch Design System Colors
        background: '#101415',
        surface: '#1C2021',
        surfaceHigh: '#323536',
        primary: {
          DEFAULT: '#85D2E0',
          container: '#006874',
        },
        tertiary: '#FDB87C',
        onSurface: '#E0E3E3',
      },
      fontFamily: {
        heading: ['"Plus Jakarta Sans"', 'sans-serif'],
        body: ['"DM Sans"', 'sans-serif'],
        data: ['"Space Grotesk"', 'monospace'],
      },
      borderRadius: {
        '2xl': '1rem', // 16dp as per Stitch design
      },
    },
  },
  plugins: [],
} satisfies Config
