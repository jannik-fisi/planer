# JuKi Planer

Die App der JuKi Paulus, um Veranstaltungen zu planen, Aufgaben zu verteilen und die Technik zu verwalten.
Grundlage ist das Konzept „JuKi Planer“ im Claude-Projekt „App für die JuKi“.

## So hängt alles zusammen

| Teil | Wo | Was |
|---|---|---|
| App-Hülle | GitHub Pages (aus diesem Repository) | Bildschirme, Knöpfe, Design – **keine Daten** |
| Daten & Anmeldung | Supabase, Frankfurt | Veranstaltungen, Aufgaben, Personen; geschützt durch Regeln pro Rolle |
| Code | dieses Repository (öffentlich) | Jede Änderung als Pull Request, erst nach „Merge“ live |

## Umgebungen

- **Test**: Supabase-Projekt `juki-test`, Werte stehen in `.env` (öffentliche Werte, nicht geheim). Oben in der App steht „TEST“.
- **Live**: kommt später, mit eigenen Werten im Veröffentlichungs-Ablauf.

**Niemals ins Repository:** Datenbank-Passwort, Supabase Secret Key / `service_role`, Mail-Passwörter.
Solche Werte gehören nur in die geschützten Einstellungen von Supabase oder GitHub (Secrets).

## Veröffentlichung mit GitHub Pages (einmalig einrichten)

Das Repository ist **öffentlich**, damit GitHub Pages kostenlos ist. Öffentlich ist nur der Code –
Daten liegen geschützt in Supabase. Geheime Werte stehen nie im Code.

1. **Settings → Pages → Build and deployment → Source: „GitHub Actions“** auswählen
2. **Settings → Advanced Security** (bzw. „Code security“): **Secret Protection** und **Push protection** einschalten
   – GitHub blockiert dann Uploads, in denen ein geheimer Schlüssel steckt
3. Danach gilt: **Merge auf `main`** → der Ablauf „Veröffentlichen“ baut die App und stellt sie online
   (ca. 1–2 Minuten, Fortschritt unter dem Reiter **Actions**)
4. Adresse: `https://jannik-fisi.github.io/planer/` (nach dem Umzug in die Organisation: `https://juki-paulus.github.io/planer/`)
5. In der App ⓘ oben rechts öffnen → alle Punkte sollten grün sein

## Ordner

| Ordner | Inhalt |
|---|---|
| `src/pages` | Die Bildschirme (Heute, Veranstaltungen, Technik, Leute, Status) |
| `src/components` | Bausteine wie Kopfbereich, untere Leiste, Update-Hinweis |
| `src/lib` | Einstellungen und Verbindung zu Supabase |
| `src/styles` | Farben und Design aus dem Prototyp |
| `public` | App-Symbole |
| `supabase/migrations` | Datenbank-Aufbau (ab Etappe 2) |
| `.github/workflows` | Automatische Prüfung bei jedem Pull Request und Veröffentlichung nach dem Merge |

## Für Entwickler

```bash
npm install
npm run dev      # lokale Vorschau
npm run build    # Typprüfung + fertige App in dist/
```

Technik: Vite, React, TypeScript, Supabase JS, PWA (installierbar, „Neue Version verfügbar“-Hinweis).
Die Schrift Figtree wird lokal ausgeliefert, nicht von Google geladen.
