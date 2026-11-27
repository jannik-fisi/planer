-- Grundeinrichtung (Etappe 2a)
-- Prüft, dass der automatische Ablauf „Datenbank“ funktioniert:
-- Die App kann damit anzeigen, welcher Datenbank-Stand eingespielt ist.
-- Gibt nur die Nummer der neuesten Änderung zurück, keine Daten.

create or replace function public.datenbank_stand()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select max(version) from supabase_migrations.schema_migrations;
$$;

comment on function public.datenbank_stand() is
  'Neueste eingespielte Datenbank-Änderung (Zeitstempel), angezeigt auf der Status-Seite der App';

revoke all on function public.datenbank_stand() from public;
grant execute on function public.datenbank_stand() to anon, authenticated;
