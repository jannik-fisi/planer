import { copyFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// GitHub Pages stellt die App unter https://<konto>.github.io/planer/ bereit.
// Mit eigener Adresse (z. B. planer.juki-paulus.de) später BASE_PATH=/ setzen.
const base = process.env.BASE_PATH ?? '/planer/'
const buildZeit = new Date().toISOString()

// Sicherheitsregeln für den Browser (nur im fertigen Build, nicht beim Entwickeln):
// Die App darf nur mit sich selbst und mit Supabase sprechen.
const csp = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob: https://*.supabase.co",
  "font-src 'self'",
  "connect-src 'self' https://*.supabase.co wss://*.supabase.co",
  "worker-src 'self'",
  "manifest-src 'self'",
  "base-uri 'self'",
  "form-action 'self'",
].join('; ')

function sicherheitUndSeitenFallback(): Plugin {
  return {
    name: 'juki-sicherheit-und-404',
    apply: 'build',
    transformIndexHtml: (html) =>
      html.replace('<head>', `<head>\n    <meta http-equiv="Content-Security-Policy" content="${csp}" />`),
    // GitHub Pages kennt keine Weiterleitungen: 404.html = index.html,
    // damit Links wie /planer/technik auch beim direkten Aufruf funktionieren.
    closeBundle() {
      const dist = resolve(__dirname, 'dist')
      copyFileSync(resolve(dist, 'index.html'), resolve(dist, '404.html'))
    },
  }
}

export default defineConfig({
  base,
  define: {
    __BUILD_ZEIT__: JSON.stringify(buildZeit),
    __APP_VERSION__: JSON.stringify(process.env.npm_package_version ?? '0.0.0'),
    // GitHub Actions setzt GITHUB_SHA beim Bauen automatisch
    __COMMIT__: JSON.stringify((process.env.GITHUB_SHA ?? 'lokal').slice(0, 7)),
  },
  plugins: [
    react(),
    sicherheitUndSeitenFallback(),
    VitePWA({
      // Neue Version wird nicht still eingespielt, sondern per Hinweis angeboten
      registerType: 'prompt',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'JuKi Planer',
        short_name: 'JuKi Planer',
        description: 'Veranstaltungen, Aufgaben und Technik der JuKi Paulus',
        lang: 'de',
        start_url: base,
        scope: base,
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
        globIgnores: ['404.html'],
        navigateFallback: `${base}index.html`,
      },
    }),
  ],
})
