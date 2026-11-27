import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

const buildZeit = new Date().toISOString()

export default defineConfig({
  define: {
    __BUILD_ZEIT__: JSON.stringify(buildZeit),
    __APP_VERSION__: JSON.stringify(process.env.npm_package_version ?? '0.0.0'),
    // Cloudflare Pages setzt CF_PAGES_COMMIT_SHA beim Bauen automatisch
    __COMMIT__: JSON.stringify((process.env.CF_PAGES_COMMIT_SHA ?? 'lokal').slice(0, 7)),
  },
  plugins: [
    react(),
    VitePWA({
      // Neue Version wird nicht still eingespielt, sondern per Hinweis angeboten
      registerType: 'prompt',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'JuKi Planer',
        short_name: 'JuKi Planer',
        description: 'Veranstaltungen, Aufgaben und Technik der JuKi Paulus',
        lang: 'de',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#f7f5f2',
        theme_color: '#1d1724',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,woff2}'],
        navigateFallback: '/index.html',
        // Daten von Supabase nie zwischenspeichern – immer frisch vom Server
        navigateFallbackDenylist: [/^\/auth/, /^\/rest/],
      },
    }),
  ],
})
