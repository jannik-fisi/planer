# Datenbank (Supabase)

Hier liegen ab Etappe 2 alle Änderungen an der Datenbank als **Migrationsdateien**
(`migrations/JJJJMMTTHHMMSS_beschreibung.sql`). Jede Datei wird genau einmal eingespielt,
in der Reihenfolge ihres Namens. So lässt sich die Datenbank jederzeit nachbauen
(Test, Live, oder bei einem Anbieterwechsel).

Regeln:
- Jede Tabelle bekommt **Row Level Security** – ohne Regel sieht niemand etwas.
- Keine echten Personendaten in Migrationen. Testdaten nur als `seed.sql` für `juki-test`.
- Geheime Werte (Passwörter, Secret Key) nie hier, nur in den Einstellungen von Supabase/GitHub.
