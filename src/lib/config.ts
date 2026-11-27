// Alle Einstellungen an einer Stelle. Werte kommen aus .env (bzw. später aus dem Veröffentlichungs-Ablauf).

export const config = {
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL ?? '',
  supabaseKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? '',
  umgebung: (import.meta.env.VITE_UMGEBUNG ?? 'test') as 'test' | 'live',
  version: __APP_VERSION__,
  commit: __COMMIT__,
  buildZeit: __BUILD_ZEIT__,
}

export const istTest = config.umgebung !== 'live'

/** Liefert eine Liste fehlender Einstellungen (leer = alles da). */
export function fehlendeEinstellungen(): string[] {
  const fehlt: string[] = []
  if (!config.supabaseUrl) fehlt.push('VITE_SUPABASE_URL')
  if (!config.supabaseKey) fehlt.push('VITE_SUPABASE_PUBLISHABLE_KEY')
  // Schutz: Ein geheimer Schlüssel darf nie in der App landen
  if (config.supabaseKey.startsWith('sb_secret_') || config.supabaseKey.includes('service_role')) {
    fehlt.push('Achtung: Statt des öffentlichen wurde ein GEHEIMER Schlüssel eingetragen!')
  }
  return fehlt
}
