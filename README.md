# JuKi Planer

Die App der JuKi Paulus, um Veranstaltungen zu planen, Aufgaben zu verteilen und die Technik zu verwalten.
Grundlage ist das Konzept „JuKi Planer“ im Claude-Projekt „App für die JuKi“.

## So hängt alles zusammen

| Teil | Wo | Was |
|---|---|---|
| App-Hülle | Cloudflare Pages (aus diesem Repository) | Bildschirme, Knöpfe, Design – **keine Daten** |
| Daten & Anmeldung | Supabase, Frankfurt | Veranstaltungen, Aufgaben, Personen; geschützt durch Regeln pro Rolle |
| Code | dieses Repository (privat) | Jede Änderung als Pull Request, erst nach „Merge“ live |

## Umgebungen

- **Test**: Supabase-Projekt `juki-test`, Werte stehen in `.env` (öffentliche Werte, nicht geheim). Oben in der App steht „TEST“.
- **Live**: kommt später. Die Werte werden in Cloudflare als Umgebungsvariablen gesetzt und haben Vorrang vor `.env`.

**Niemals ins Repository:** Datenbank-Passwort, Supabase Secret Key / `service_role`, Mail-Passwörter.
Solche Werte gehören nur in die geschützten Einstellungen von Supabase, Cloudflare oder GitHub.

## Veröffentlichung mit Cloudflare Pages (einmalig einrichten)

1. Auf [dash.cloudflare.com](https://dash.cloudflare.com) ein kostenloses Konto anlegen (am besten mit der JuKi-Adresse).
2. **Workers & Pages → Erstellen → Pages → Mit Git verbinden** → GitHub erlauben, nur dieses Repository auswählen.
3. Einstellungen:
   - Framework-Voreinstellung: **Vite** (oder „Keine“)
   - Build-Befehl: `npm run build`
   - Ausgabeverzeichnis: `dist`
   - Produktionszweig: `main`
4. Speichern. Danach gilt:
   - **Merge auf `main`** → neue Version unter `https://<projektname>.pages.dev` (ca. 1 Minute)
   - **Jeder Pull Request** bekommt automatisch eine eigene Vorschau-Adresse zum Ausprobieren, bevor gemergt wird
5. Status-Seite in der App öffnen (ⓘ oben rechts) → alle Punkte sollten grün sein.

## Ordner

| Ordner | Inhalt |
|---|---|
| `src/pages` | Die Bildschirme (Heute, Veranstaltungen, Technik, Leute, Status) |
| `src/components` | Bausteine wie Kopfbereich, untere Leiste, Update-Hinweis |
| `src/lib` | Einstellungen und Verbindung zu Supabase |
| `src/styles` | Farben und Design aus dem Prototyp |
| `public` | App-Symbole, Sicherheits-Header für Cloudflare |
| `supabase/migrations` | Datenbank-Aufbau (ab Etappe 2) |
| `.github/workflows` | Automatische Prüfung bei jedem Pull Request |

## Für Entwickler

```bash
npm install
npm run dev      # lokale Vorschau
npm run build    # Typprüfung + fertige App in dist/
```

Technik: Vite, React, TypeScript, Supabase JS, PWA (installierbar, „Neue Version verfügbar“-Hinweis).
Die Schrift Figtree wird lokal ausgeliefert, nicht von Google geladen.
