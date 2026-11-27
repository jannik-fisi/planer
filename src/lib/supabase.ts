import { createClient } from '@supabase/supabase-js'
import { config } from './config'

// Eine einzige Verbindung für die ganze App.
// Sicherheit steckt NICHT in diesem Schlüssel, sondern in den Regeln (Row Level Security)
// der Datenbank – die kommen in Etappe 2.
export const supabase = createClient(config.supabaseUrl || 'http://fehlt.invalid', config.supabaseKey || 'fehlt', {
  auth: {
    persistSession: true, // dauerhaft angemeldet auf dem Gerät
    autoRefreshToken: true,
    detectSessionInUrl: false, // Anmeldung per Code, nicht per Link
  },
})

export type VerbindungsErgebnis =
  | { ok: true; selbstRegistrierungAus: boolean; dauerMs: number }
  | { ok: false; fehler: string }

/** Prüft, ob die Datenbank erreichbar ist und wie die Anmeldung eingestellt ist. */
export async function pruefeVerbindung(): Promise<VerbindungsErgebnis> {
  const start = performance.now()
  try {
    const res = await fetch(`${config.supabaseUrl}/auth/v1/settings`, {
      headers: { apikey: config.supabaseKey },
      cache: 'no-store',
    })
    if (!res.ok) return { ok: false, fehler: `Server antwortet mit Fehler ${res.status}` }
    const daten = (await res.json()) as { disable_signup?: boolean }
    return { ok: true, selbstRegistrierungAus: daten.disable_signup === true, dauerMs: Math.round(performance.now() - start) }
  } catch {
    return { ok: false, fehler: 'Keine Verbindung (offline oder falsche Adresse)' }
  }
}
