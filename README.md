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

## Für Entwickler

```bash
npm install
npm run dev      # lokale Vorschau
npm run build    # Typprüfung + fertige App in dist/
```

Technik: Vite, React, TypeScript, Supabase JS, PWA (installierbar, „Neue Version verfügbar“-Hinweis).
Die Schrift Figtree wird lokal ausgeliefert, nicht von Google geladen.
