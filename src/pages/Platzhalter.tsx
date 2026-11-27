import { Link } from 'react-router-dom'
import { Kopf, KommtNoch } from '../components/Layout'

export function Veranstaltungen() {
  return (
    <>
      <Kopf titel="Veranstaltungen" sub="Alles, was du sehen darfst" />
      <main className="main">
        <KommtNoch etappe={4} was="Liste und Kalender, Filter, Anlegen mit Vorlage, Aufgaben verteilen, Kommentare, Archiv und „Nochmal aufführen“." />
        <KommtNoch etappe={6} was="Dateien an Veranstaltungen und Konzepten (zum Start als Link, Fotos direkt)." />
      </main>
    </>
  )
}

export function Technik() {
  return (
    <>
      <Kopf titel="Technik" sub="Kalender und Bestand" />
      <main className="main">
        <KommtNoch etappe={5} was="Anfragen (Angefragt → Angenommen → Geplant), Kalender mit Bedarfsprüfung, Bestand mit Cases, Defekte, Inventur, Packliste und Leih-Protokoll mit Unterschrift." />
      </main>
    </>
  )
}

export function Leute() {
  return (
    <>
      <Kopf titel="Leute" sub="Nur für die Leitung" />
      <main className="main">
        <KommtNoch etappe={3} was="Leute per E-Mail einladen, Rollen vergeben, entfernen. Gemeinden mit Gast-Code verwalten." />
      </main>
    </>
  )
}

export function NichtGefunden() {
  return (
    <>
      <Kopf titel="Nicht gefunden" zurueck="/" />
      <main className="main">
        <div className="card empty">
          Diese Seite gibt es nicht.{' '}
          <Link to="/">Zur Startseite</Link>
        </div>
      </main>
    </>
  )
}
