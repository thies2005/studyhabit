import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import path from "path"

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  // Fail the production build loudly if the API URL is unset. Previously the
  // client silently fell back to http://localhost:3001, so a production SPA
  // built without the build arg pointed at a dev backend.
  if (mode === 'production' && !env.VITE_API_URL) {
    throw new Error(
      'VITE_API_URL must be set for a production build. Pass it as a build arg ' +
      '(e.g. vite build --mode production) or Dockerfile ARG.'
    )
  }

  return {
    plugins: [
      react(),
      VitePWA({
        registerType: 'autoUpdate',
        injectRegister: 'auto',
        // Keep the service worker out of dev so stale builds aren't cached
        // during local development.
        devOptions: {
          enabled: false
        },
        manifest: {
          name: 'Studyhabit',
          short_name: 'Studyhabit',
          description: 'Your ultimate study tracking companion',
          theme_color: '#000000',
          background_color: '#ffffff',
          display: 'standalone',
          icons: [
            {
              // Maskable icon with padding for adaptive Android display.
              src: '/pwa-192.png',
              sizes: '192x192',
              type: 'image/png',
              purpose: 'any maskable'
            },
            {
              src: '/pwa-512.png',
              sizes: '512x512',
              type: 'image/png',
              purpose: 'any maskable'
            }
          ]
        }
      })
    ],
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "./src"),
      },
    },
  }
})
