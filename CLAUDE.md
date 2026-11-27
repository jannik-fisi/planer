# Hinweise für Claude

Dieses Repository ist der **JuKi Planer** der Jugendkirche JuKi Paulus. Grundlage sind die Dokumente
„Konzept JuKi Planer“ und „Setup-Stand JuKi Planer“ im Claude-Projekt „App für die JuKi“ – vor größeren
Änderungen dort nachlesen. Der Owner ist kein Entwickler: Erklärungen auf Deutsch, einfach, ohne Fachjargon.

## Arbeitsweise
- Jede Änderung in einem eigenen Zweig, als Pull Request mit deutscher Beschreibung (was, warum, wie testen).
- Nie direkt auf `main`. Erst nach „Merge“ durch den Owner geht etwas live.
- Vor dem Pull Request: `npm run build` muss fehlerfrei laufen.
- Nach jeder Etappe den „Setup-Stand“ im Claude-Projekt aktualisieren.

## Technik
- Vite + React + TypeScript, PWA über `vite-plugin-pwa` (Update-Hinweis, kein stilles Update)
- Supabase (`src/lib/supabase.ts`), Werte aus `.env` (Test) bzw. Cloudflare-Umgebungsvariablen (Live)
- Veröffentlichung: Cloudflare Pages (Build `npm run build`, Ausgabe `dist`), Sicherheits-Header in `public/_headers`
- Design aus Prototyp v5: Variablen in `src/styles/app.css`, mobil zuerst, Tippflächen ≥ 44 px
- Texte in der App: Deutsch, freundlich, kurz, „du“

## Sicherheit
- Nie geheime Schlüssel in Code oder Chat (DB-Passwort, `sb_secret_…`, `service_role`, Mail-Passwörter).
- Sicherheit liegt in Row Level Security auf **jeder** Tabelle, nicht im Verstecken von Code.
- Keine echten Personendaten im Repository.
