import { NavLink, Outlet, Link } from 'react-router-dom'
import type { ReactNode } from 'react'
import { Icon, type IconName } from './Icon'
import { UpdateHinweis } from './UpdateHinweis'
import { istTest } from '../lib/config'

type NavPunkt = { pfad: string; label: string; icon: IconName; nurFuer?: 'technik' | 'leitung' }

// Untere Leiste wie im Prototyp. "nurFuer" wird ab Etappe 3 (Login & Rollen) ausgewertet;
// bis dahin sind zum Ausprobieren alle Punkte sichtbar.
const navigation: NavPunkt[] = [
  { pfad: '/', label: 'Heute', icon: 'home' },
  { pfad: '/veranstaltungen', label: 'Veranstaltungen', icon: 'cal' },
  { pfad: '/technik', label: 'Technik', icon: 'box', nurFuer: 'technik' },
  { pfad: '/leute', label: 'Leute', icon: 'users', nurFuer: 'leitung' },
]

export function Layout() {
  return (
    <div className="shell">
      <Outlet />
      <nav className="tabs" aria-label="Hauptnavigation">
        {navigation.map((n) => (
          <NavLink key={n.pfad} to={n.pfad} end={n.pfad === '/'}>
            <Icon name={n.icon} />
            {n.label}
          </NavLink>
        ))}
      </nav>
      <UpdateHinweis />
    </div>
  )
}

/** Dunkler Kopfbereich jeder Seite */
export function Kopf({ titel, sub, zurueck }: { titel: string; sub?: ReactNode; zurueck?: string }) {
  return (
    <header className="top">
      <div className="hrow">
        {zurueck ? (
          <Link to={zurueck} className="hbtn" style={{ border: 0, background: 'none', paddingLeft: 0 }}>
            <Icon name="back" /> Zurück
          </Link>
        ) : (
          <span className="appn">
            JuKi Planer {istTest && <span className="badge-test">TEST</span>}
          </span>
        )}
        <Link to="/status" className="hbtn" aria-label="Status und Version">
          <Icon name="info" />
        </Link>
      </div>
      <h1>{titel}</h1>
      {sub && <div className="sub">{sub}</div>}
    </header>
  )
}

/** Platzhalter, bis die Seite in ihrer Etappe gebaut wird */
export function KommtNoch({ etappe, was }: { etappe: number; was: string }) {
  return (
    <div className="card note">
      <div className="meta" style={{ marginTop: 0 }}>
        <span className="chip acc">Etappe {etappe}</span>
      </div>
      <p>{was}</p>
    </div>
  )
}
