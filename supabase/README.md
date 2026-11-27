# Datenbank (Supabase)

Hier liegen alle Änderungen an der Datenbank als **Migrationsdateien**
(`migrations/JJJJMMTTHHMMSS_beschreibung.sql`). Jede Datei wird genau einmal eingespielt,
in der Reihenfolge ihres Namens. So lässt sich die Datenbank jederzeit nachbauen
(Test, Live, oder bei einem Anbieterwechsel).

## So kommen Änderungen in die Datenbank
Ablauf `.github/workflows/datenbank.yml`:
1. **Pull Request**: „Probelauf mit leerer Datenbank“ spielt alle Dateien in eine frische Supabase-Datenbank auf GitHub ein. Fehler fallen vor dem Merge auf.
2. **Merge auf `main`**: „In juki-test einspielen“ spielt neue Dateien in das Projekt `juki-test` ein.
3. Kontrolle: Status-Seite der App (ⓘ) → „Datenbank eingerichtet · Neueste Änderung vom …“

Geheime Werte dafür liegen nur in GitHub (Settings → Secrets and variables → Actions):
`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD_TEST`.

## Regeln
- Jede Tabelle bekommt **Row Level Security** – ohne Regel sieht niemand etwas.
- Bereits eingespielte Dateien nie ändern, sondern immer eine neue Datei anlegen.
- Keine echten Personendaten in Migrationen. Testdaten nur erfunden.
- Geheime Werte (Passwörter, Secret Key) nie hier, nur in den Einstellungen von Supabase/GitHub.

`config.jsonc` gilt nur für eine lokale Test-Datenbank, nicht für die Projekte in der Cloud.
