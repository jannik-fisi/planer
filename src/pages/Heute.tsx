import { Link } from 'react-router-dom'
import { Kopf, KommtNoch } from '../components/Layout'

export function Heute() {
  return (
    <>
      <Kopf titel="Hallo!" sub="Hier siehst du bald deine Aufgaben und Einsätze" />
      <main className="main">
        <div className="card note">
          <b>Das Gerüst steht.</b>
          <p className="meta" style={{ display: 'block' }}>
            Diese Version ist die leere Hülle der echten App. Schritt für Schritt kommen jetzt Datenbank, Login und
            alle Funktionen aus dem Prototyp dazu.
          </p>
          <Link to="/status" className="btn ghost wide">
            Verbindung zur Datenbank prüfen
          </Link>
        </div>
        <h3>Was hier später steht</h3>
        <KommtNoch etappe={4} was="Hinweise (unbesetzte Aufgaben, neue Anfragen, gesuchte Helfende) und deine eigenen Aufgaben, gegliedert nach Veranstaltung." />
        <KommtNoch etappe={7} was="„Erinnerung testen“ mit lautem Alarm aufs Handy." />
      </main>
    </>
  )
}
