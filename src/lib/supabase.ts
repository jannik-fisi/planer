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

/**
 * Neueste eingespielte Datenbank-Änderung, z. B. „27.11.2026, 17:00“.
 * null = noch keine Änderung eingespielt (Ablauf „Datenbank“ lief noch nicht).
 */
export async function holeDatenbankStand(): Promise<{ ok: true; stand: string | null } | { ok: false }> {
  const { data, error } = await supabase.rpc('datenbank_stand')
  if (error) {
    // Funktion existiert noch nicht → noch nichts eingespielt
    if (error.code === 'PGRST202' || error.code === '42883') return { ok: true, stand: null }
    return { ok: false }
  }
  const v = String(data ?? '')
  const m = v.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/)
  return { ok: true, stand: m ? `${m[3]}.${m[2]}.${m[1]}, ${m[4]}:${m[5]}` : v || null }
}

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
