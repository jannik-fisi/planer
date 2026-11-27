# Datenbank (Supabase)

Hier liegen alle Änderungen an der Datenbank als **Migrationsdateien**
(`migrations/JJJJMMTTHHMMSS_beschreibung.sql`). Jede Datei wird genau einmal eingespielt,
in der Reihenfolge ihres Namens. So lässt sich die Datenbank jederzeit nachbauen
(Test, Live, oder bei einem Anbieterwechsel).

## So kommen Änderungen in die Datenbank
Ablauf `.github/workflows/datenbank.yml`:
1. **Pull Request**: „Probelauf mit leerer Datenbank“ spielt alle Dateien in eine frische Supabase-Datenbank auf GitHub ein und testet danach die Rechte-Regeln (einmal leer, einmal mit Testdaten). Fehler fallen vor dem Merge auf.
2. **Merge auf `main`**: „In juki-test einspielen“ spielt neue Dateien und die Testdaten in das Projekt `juki-test` ein.
3. Kontrolle: Status-Seite der App (ⓘ) → „Datenbank eingerichtet · Neueste Änderung vom …“

Geheime Werte dafür liegen nur in GitHub (Settings → Secrets and variables → Actions):
`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD_TEST`.

## Was liegt wo?
| Datei | Inhalt |
|---|---|
| `migrations/…_grundeinrichtung.sql` | Funktion für die Status-Seite (Etappe 2a) |
| `migrations/…_tabellen.sql` | Alle Tabellen (Etappe 2b) |
| `migrations/…_rechte_regeln.sql` | Wer darf was sehen und ändern + Schutz-Regeln (Etappe 2b) |
| `tests/rechte.sql` | Automatische Tests der Rechte-Regeln (laufen bei jedem Pull Request) |
| `seed.sql` | Erfundene Testdaten wie im Prototyp – **nur für juki-test** |

## Wer darf was? (Kurzfassung der Rechte-Regeln)
| | Mitglied | Technik | Leitung | Gast (Gemeinde) |
|---|---|---|---|---|
| Veranstaltungen sehen | „Alle in der JuKi“, eingeladen, eigene Aufgabe, selbst angelegt/geleitet | dazu „Nur Technik“ und alles mit Technik-Anfrage | alles | nur wozu die Gemeinde eingeladen ist |
| Veranstaltung anlegen | ✓ | ✓ | ✓ | – |
| Aufgaben verteilen, Deadlines, Gäste einladen | als Veranstaltungsleitung | als Veranstaltungsleitung | ✓ | – |
| Freie Aufgabe übernehmen, eigene abhaken, kommentieren | ✓ | ✓ | ✓ | ✓ |
| Technik anfragen | wenn beteiligt | ✓ | ✓ | wenn eingeladen |
| Anfrage annehmen/planen/ablehnen, Geräte verplanen | – | ✓ | ✓ | – |
| Status der eigenen Anfrage + wer vor Ort ist | ✓ | ✓ | ✓ | ✓ |
| Geräte, Mailverlauf, Leih-Protokolle | – | ✓ | ✓ | – |
| Ansprechperson (Name, Handy, Mail) | wenn selbst eingetragen oder Veranstaltungsleitung | ✓ | ✓ | – |
| Bestand sehen/anlegen/bearbeiten, Defekte, Inventur | – | ✓ | ✓ | – |
| Lager-Teile löschen | – | – | ✓ | – |
| Leute einladen, Rollen, Entfernen, Gemeinden sperren | – | – | ✓ | – |
| E-Mail-Adressen | nur eigene | nur eigene | alle | – |

Zusätzlich prüft die Datenbank selbst (egal, was die App schickt):
- Es gibt immer mindestens eine Leitung; niemand entfernt sich selbst.
- Entfernte Personen sehen nichts mehr; ihre offenen Aufgaben werden frei, Einsätze ausgetragen.
- „Geplant“ erst mit mindestens einem Techniker vor Ort.
- Am selben Tag wird nicht mehr Technik verplant, als frei ist (defekte Stücke zählen nicht).
- „Helfende gesucht“: nicht mehr Eintragungen als gebraucht.
- Gesperrte Gemeinden sehen nichts mehr; ausgeladene Gemeinden verlieren ihre offenen Aufgaben.
- Wer etwas anlegt oder kommentiert, steht automatisch als Urheber:in drin und kann das nicht fälschen.

## Testdaten
`seed.sql` wird nach dem Merge zusammen mit den Änderungen in **juki-test** eingespielt (`--include-seed`).
Die Datei läuft gefahrlos mehrfach: Was schon da ist, wird nicht überschrieben.
Im Ablauf für **juki-live** (kommt später) darf `--include-seed` **nie** stehen.

## Regeln
- Jede Tabelle bekommt **Row Level Security** – ohne Regel sieht niemand etwas.
- Neue Regel = neuer Test in `tests/rechte.sql`.
- Bereits eingespielte Dateien nie ändern, sondern immer eine neue Datei anlegen.
- Keine echten Personendaten in Migrationen. Testdaten nur erfunden.
- Geheime Werte (Passwörter, Secret Key) nie hier, nur in den Einstellungen von Supabase/GitHub.

`config.jsonc` gilt nur für eine lokale Test-Datenbank, nicht für die Projekte in der Cloud.
