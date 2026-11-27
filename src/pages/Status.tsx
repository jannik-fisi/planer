import { useEffect, useState } from 'react'
import { Kopf } from '../components/Layout'
import { config, fehlendeEinstellungen } from '../lib/config'
import { pruefeVerbindung, type VerbindungsErgebnis } from '../lib/supabase'

type Zeile = { farbe: 'grn' | 'org' | 'red' | ''; titel: string; text: string }

function StatusZeile({ farbe, titel, text }: Zeile) {
  return (
    <div className="row">
      <span className={`dot ${farbe}`} />
      <div className="grow">
        <span className="t">{titel}</span>
        <div className="meta">{text}</div>
      </div>
    </div>
  )
}

export function Status() {
  const [ergebnis, setErgebnis] = useState<VerbindungsErgebnis | null>(null)
  const [laeuft, setLaeuft] = useState(false)
  const fehlt = fehlendeEinstellungen()

  const pruefen = async () => {
    setLaeuft(true)
    setErgebnis(await pruefeVerbindung())
    setLaeuft(false)
  }
  useEffect(() => {
    if (!fehlt.length) void pruefen()
  }, []) // nur einmal beim Öffnen

  const installiert = window.matchMedia('(display-mode: standalone)').matches
  const projekt = config.supabaseUrl.replace(/^https:\/\//, '').split('.')[0] || '–'

  const zeilen: Zeile[] = [
    fehlt.length
      ? { farbe: 'red', titel: 'Einstellungen fehlen', text: fehlt.join(', ') }
      : { farbe: 'grn', titel: 'Einstellungen vollständig', text: `Datenbank-Projekt ${projekt}` },
    !ergebnis
      ? { farbe: '', titel: 'Datenbank', text: laeuft ? 'Wird geprüft …' : 'Noch nicht geprüft' }
      : ergebnis.ok
        ? { farbe: 'grn', titel: 'Datenbank erreichbar', text: `Antwort in ${ergebnis.dauerMs} ms (Supabase Frankfurt)` }
        : { farbe: 'red', titel: 'Datenbank nicht erreichbar', text: ergebnis.fehler },
    ergebnis?.ok
      ? ergebnis.selbstRegistrierungAus
        ? { farbe: 'grn', titel: 'Selbst-Registrierung aus', text: 'Nur eingeladene Adressen bekommen einen Code.' }
        : {
            farbe: 'org',
            titel: 'Selbst-Registrierung ist noch AN',
            text: 'Vor dem Login (Etappe 3) in Supabase abschalten: Authentication → Sign In / Providers → „Allow new users to sign up“ aus.',
          }
      : { farbe: '', titel: 'Selbst-Registrierung', text: 'Wird nach der Verbindung angezeigt' },
    {
      farbe: installiert ? 'grn' : '',
      titel: installiert ? 'Als App installiert' : 'Im Browser geöffnet',
      text: installiert ? 'Läuft vom Startbildschirm.' : 'Über „Zum Home-Bildschirm“ lässt sich die App installieren.',
    },
  ]

  return (
    <>
      <Kopf titel="Status" sub="Technischer Check der App" zurueck="/" />
      <main className="main">
        <div className="card">
          {zeilen.map((z) => (
            <StatusZeile key={z.titel} {...z} />
          ))}
        </div>
        <button className="btn ghost wide" onClick={pruefen} disabled={laeuft || fehlt.length > 0}>
          {laeuft ? 'Prüfe …' : 'Erneut prüfen'}
        </button>

        <h3>Version</h3>
        <div className="card">
          <StatusZeile farbe="" titel={`Version ${config.version}`} text={`Stand ${config.commit} · gebaut ${new Date(config.buildZeit).toLocaleString('de-DE')}`} />
          <StatusZeile
            farbe={config.umgebung === 'live' ? 'grn' : 'org'}
            titel={config.umgebung === 'live' ? 'Live-Umgebung' : 'Test-Umgebung'}
            text={config.umgebung === 'live' ? 'Echte Daten' : 'Nur erfundene Daten verwenden'}
          />
        </div>
      </main>
    </>
  )
}
