/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string
  readonly VITE_SUPABASE_PUBLISHABLE_KEY: string
  /** "test" oder "live" – steuert u. a. das TEST-Schild oben in der App */
  readonly VITE_UMGEBUNG: string
}
interface ImportMeta {
  readonly env: ImportMetaEnv
}

declare const __BUILD_ZEIT__: string
declare const __APP_VERSION__: string
declare const __COMMIT__: string
