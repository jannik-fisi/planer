import { useRegisterSW } from 'virtual:pwa-register/react'

// Zeigt "Neue Version verfügbar", sobald eine neue App-Hülle online ist.
// Die Daten bleiben dabei unberührt – nur Bildschirme und Knöpfe werden ausgetauscht.
export function UpdateHinweis() {
  const {
    needRefresh: [neuVerfuegbar, setNeuVerfuegbar],
    updateServiceWorker,
  } = useRegisterSW({
    onRegisteredSW(_url, registrierung) {
      // Jede Stunde und beim Zurückkehren in die App nach Updates schauen
      if (!registrierung) return
      const pruefen = () => registrierung.update().catch(() => {})
      setInterval(pruefen, 60 * 60 * 1000)
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') pruefen()
      })
    },
  })

  if (!neuVerfuegbar) return null
  return (
    <div className="toast" role="status">
      <span className="grow">Neue Version verfügbar.</span>
      <button className="btn sm" onClick={() => updateServiceWorker(true)}>
        Aktualisieren
      </button>
      <button className="btn sm ghost" onClick={() => setNeuVerfuegbar(false)} aria-label="Später">
        Später
      </button>
    </div>
  )
}
