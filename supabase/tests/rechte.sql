-- Automatische Tests der Rechte-Regeln
--
-- Läuft im „Probelauf“ bei jedem Pull Request (siehe .github/workflows/datenbank.yml).
-- Alles passiert in einer einzigen Transaktion, die am Ende zurückgerollt wird:
-- Die Tests legen eigene erfundene Personen an und hinterlassen keine Spuren.
--
-- Jede Zeile „✓ …“ ist eine bestandene Prüfung. Schlägt eine fehl, steht dort „✗ …“
-- und der Probelauf wird rot.

\set ON_ERROR_STOP on
\set QUIET on
\pset tuples_only on
\o /dev/null
set client_min_messages = notice;

begin;
set constraints all immediate; -- „mindestens eine Leitung“ sofort prüfen, nicht erst am Ende

-- ---------------------------------------------------------------------------
-- Werkzeuge
-- ---------------------------------------------------------------------------
create schema test;
grant usage on schema test to anon, authenticated;
create table test.konten (name text primary key, uid uuid not null);
create table test.fehler (nr serial, text text);
grant select on test.konten to anon, authenticated;
grant insert on test.fehler to anon, authenticated;
grant usage on sequence test.fehler_nr_seq to anon, authenticated;

-- Als wer läuft die nächste Prüfung? Bildet eine echte Anmeldung nach (wie Supabase es macht).
create function test.als(wer text) returns void language plpgsql as $$
begin
  if wer = 'niemand' then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    perform set_config('role', 'anon', true);
  else
    perform set_config('request.jwt.claims',
      json_build_object('sub', (select uid from test.konten where name = wer), 'role', 'authenticated')::text, true);
    perform set_config('role', 'authenticated', true);
  end if;
end $$;

create function test.pruefe(ok boolean, beschreibung text) returns void language plpgsql as $$
begin
  if coalesce(ok, false) then
    raise notice '✓ %', beschreibung;
  else
    insert into test.fehler (text) values (beschreibung);
    raise notice '✗ %', beschreibung;
  end if;
end $$;

-- Erwartet: Es wird abgelehnt (Fehlermeldung) oder es betrifft keine einzige Zeile.
-- Wird in jedem Fall zurückgenommen.
create function test.verboten(befehl text, beschreibung text) returns void language plpgsql as $$
declare n int;
begin
  begin
    execute befehl;
    get diagnostics n = row_count;
    raise exception 'TEST_ZURUECK:%', n;
  exception when others then
    if sqlerrm like 'TEST_ZURUECK:%' and split_part(sqlerrm, ':', 2)::int > 0 then
      perform test.pruefe(false, beschreibung || ' (war aber erlaubt)');
    else
      perform test.pruefe(true, beschreibung);
    end if;
  end;
end $$;

-- Erwartet: klappt und betrifft mindestens eine Zeile. Die Änderung bleibt bestehen.
create function test.erlaubt(befehl text, beschreibung text) returns void language plpgsql as $$
declare n int;
begin
  execute befehl;
  get diagnostics n = row_count;
  perform test.pruefe(n > 0, beschreibung || case when n = 0 then ' (keine Zeile betroffen)' else '' end);
exception when others then
  perform test.pruefe(false, beschreibung || ' (Fehler: ' || sqlerrm || ')');
end $$;

create function test.anzahl(abfrage text) returns int language plpgsql as $$
declare n int;
begin
  execute 'select count(*) from (' || abfrage || ') x' into n;
  return n;
end $$;

grant execute on all functions in schema test to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Erfundene Probe-Daten (nur für diesen Testlauf)
-- ---------------------------------------------------------------------------
insert into test.konten values
  ('Leitung', 'e0000000-0000-4000-8000-000000000001'),
  ('Tim',     'e0000000-0000-4000-8000-000000000002'),
  ('Paul',    'e0000000-0000-4000-8000-000000000003'),
  ('Mia',     'e0000000-0000-4000-8000-000000000004'),
  ('Emma',    'e0000000-0000-4000-8000-000000000005'),
  ('Noah',    'e0000000-0000-4000-8000-000000000006'),
  ('Ehemalig','e0000000-0000-4000-8000-000000000007'),
  ('Nord',    'e0000000-0000-4000-8000-000000000008'),
  ('Süd',     'e0000000-0000-4000-8000-000000000009'),
  ('Fremd',   'e0000000-0000-4000-8000-000000000010');
insert into auth.users (id, email) select uid, lower(name) || '@test.invalid' from test.konten;

insert into public.personen (id, name, ist_leitung, ist_technik, auth_user_id, entfernt_am) values
  ('e1000000-0000-4000-8000-000000000001', 'T Leitung', true,  false, 'e0000000-0000-4000-8000-000000000001', null),
  ('e1000000-0000-4000-8000-000000000002', 'T Tim',     false, true,  'e0000000-0000-4000-8000-000000000002', null),
  ('e1000000-0000-4000-8000-000000000003', 'T Paul',    false, true,  'e0000000-0000-4000-8000-000000000003', null),
  ('e1000000-0000-4000-8000-000000000004', 'T Mia',     false, false, 'e0000000-0000-4000-8000-000000000004', null),
  ('e1000000-0000-4000-8000-000000000005', 'T Emma',    false, false, 'e0000000-0000-4000-8000-000000000005', null),
  ('e1000000-0000-4000-8000-000000000006', 'T Noah',    false, false, 'e0000000-0000-4000-8000-000000000006', null),
  ('e1000000-0000-4000-8000-000000000007', 'T Ehemalig',false, false, 'e0000000-0000-4000-8000-000000000007', now());
insert into public.personen_emails (person_id, email)
  select id, lower(replace(name, 'T ', '')) || '@test.invalid' from public.personen where id::text like 'e1000000%';

-- Andere Daten (z. B. Testdaten aus seed.sql) dürfen die Prüfungen nicht beeinflussen:
-- Für diesen Lauf ist nur die Probe-Leitung Leitung.
update public.personen set ist_leitung = false where id::text not like 'e1000000%';

insert into public.gemeinden (id, name, gesperrt, auth_user_id) values
  ('e2000000-0000-4000-8000-000000000001', 'Test-Gemeinde Nord', false, 'e0000000-0000-4000-8000-000000000008'),
  ('e2000000-0000-4000-8000-000000000002', 'Test-Gemeinde Süd',  true,  'e0000000-0000-4000-8000-000000000009');

-- Veranstaltungen (in 30 Tagen, damit nichts im Archiv liegt)
insert into public.veranstaltungen (id, titel, datum, art, sichtbarkeit, leitung_id, erstellt_von, helfende_gesucht) values
  ('e3000000-0000-4000-8000-000000000001', 'T: Für alle',          current_date + 30, 'juki',    'alle',        'e1000000-0000-4000-8000-000000000005', 'e1000000-0000-4000-8000-000000000005', null),
  ('e3000000-0000-4000-8000-000000000002', 'T: Nur Technik',       current_date + 30, 'juki',    'technik',     'e1000000-0000-4000-8000-000000000002', 'e1000000-0000-4000-8000-000000000002', null),
  ('e3000000-0000-4000-8000-000000000003', 'T: Nur Eingeladene',   current_date + 31, 'juki',    'eingeladene', 'e1000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001', null),
  ('e3000000-0000-4000-8000-000000000004', 'T: Technik-Anfrage',   current_date + 32, 'anfrage', 'technik',     'e1000000-0000-4000-8000-000000000004', 'e1000000-0000-4000-8000-000000000004', null),
  ('e3000000-0000-4000-8000-000000000005', 'T: Helfende gesucht',  current_date + 33, 'anfrage', 'alle',        'e1000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001', 2),
  ('e3000000-0000-4000-8000-000000000006', 'T: Mia hat Aufgabe',   current_date + 34, 'juki',    'eingeladene', 'e1000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001', null),
  ('e3000000-0000-4000-8000-000000000007', 'T: Gleicher Tag',      current_date + 32, 'juki',    'technik',     'e1000000-0000-4000-8000-000000000002', 'e1000000-0000-4000-8000-000000000002', null);
insert into public.veranstaltung_eingeladene values
  ('e3000000-0000-4000-8000-000000000003', 'e1000000-0000-4000-8000-000000000006');
insert into public.veranstaltung_gemeinden (veranstaltung_id, gemeinde_id) values
  ('e3000000-0000-4000-8000-000000000003', 'e2000000-0000-4000-8000-000000000001'),
  ('e3000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000002');
insert into public.aufgaben (id, veranstaltung_id, titel, person_id, gemeinde_id, faellig_am) values
  ('e4000000-0000-4000-8000-000000000001', 'e3000000-0000-4000-8000-000000000001', 'Freie Aufgabe',     null, null, current_date + 20),
  ('e4000000-0000-4000-8000-000000000002', 'e3000000-0000-4000-8000-000000000001', 'Emmas Aufgabe',     'e1000000-0000-4000-8000-000000000005', null, current_date + 20),
  ('e4000000-0000-4000-8000-000000000003', 'e3000000-0000-4000-8000-000000000006', 'Mias Aufgabe',      'e1000000-0000-4000-8000-000000000004', null, current_date + 20),
  ('e4000000-0000-4000-8000-000000000004', 'e3000000-0000-4000-8000-000000000003', 'Aufgabe der Gemeinde', null, 'e2000000-0000-4000-8000-000000000001', current_date + 20);
insert into public.technik_anfragen (veranstaltung_id, beschreibung, angefragt_von_person) values
  ('e3000000-0000-4000-8000-000000000004', 'Ton und Licht', 'e1000000-0000-4000-8000-000000000004');
insert into public.ansprechpersonen (veranstaltung_id, name, email) values
  ('e3000000-0000-4000-8000-000000000004', 'Frau Beispiel', 'beispiel@test.invalid');
insert into public.helfende (veranstaltung_id, person_id) values
  ('e3000000-0000-4000-8000-000000000005', 'e1000000-0000-4000-8000-000000000006');
insert into public.teile (id, name, kategorie, anzahl) values
  ('e5000000-0000-4000-8000-000000000001', 'T: Funkmikrofon', 'Ton', 4);

-- ---------------------------------------------------------------------------
-- Nicht angemeldet
-- ---------------------------------------------------------------------------
\echo
\echo '— Nicht angemeldet'
select test.als('niemand');
select test.verboten('select * from public.veranstaltungen', 'Ohne Anmeldung sieht man keine Veranstaltungen');
select test.verboten('select * from public.personen', 'Ohne Anmeldung sieht man keine Personen');
select test.verboten('select * from public.teile', 'Ohne Anmeldung sieht man keinen Technik-Bestand');
select test.verboten($$insert into public.veranstaltungen (titel, datum) values ('Hack', current_date)$$,
                     'Ohne Anmeldung kann man nichts anlegen');
reset role;

-- Ein Konto, das zu keiner Person/Gemeinde gehört (z. B. irgendwie angelegt), sieht nichts
select test.als('Fremd');
select test.pruefe(test.anzahl('select * from public.veranstaltungen') = 0, 'Fremdes Konto ohne Einladung sieht keine Veranstaltung');
select test.pruefe(test.anzahl('select * from public.personen') = 0, 'Fremdes Konto ohne Einladung sieht keine Personen');
reset role;

-- ---------------------------------------------------------------------------
-- Mitglied (Mia)
-- ---------------------------------------------------------------------------
\echo
\echo '— Mitglied'
select test.als('Mia');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Für alle'$$) = 1,
  'Mitglied sieht Veranstaltung „Alle in der JuKi“');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Nur Technik'$$) = 0,
  'Mitglied sieht keine Nur-Technik-Veranstaltung');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Nur Eingeladene'$$) = 0,
  'Mitglied sieht keine Veranstaltung, zu der es nicht eingeladen ist');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Mia hat Aufgabe'$$) = 1,
  'Mitglied sieht Veranstaltung, in der es eine Aufgabe hat');
select test.pruefe(test.anzahl($$select * from public.technik_anfragen where status = 'angefragt'
    and veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$) = 1,
  'Mitglied sieht den Status seiner eigenen Technik-Anfrage');
select test.pruefe(test.anzahl('select * from public.ansprechpersonen') = 1,
  'Mitglied sieht die Ansprechperson seiner eigenen Anfrage');
select test.pruefe(test.anzahl('select * from public.teile') = 0, 'Mitglied sieht keinen Technik-Bestand');
select test.pruefe(test.anzahl('select * from public.reservierungen') = 0, 'Mitglied sieht keine geplanten Geräte');
select test.pruefe(test.anzahl('select * from public.personen_emails') = 1, 'Mitglied sieht nur die eigene E-Mail-Adresse');
select test.pruefe(test.anzahl('select * from public.personen') >= 7, 'Mitglied sieht Namen und Rollen der anderen');
select test.verboten($$update public.personen set ist_leitung = true where name = 'T Mia'$$,
  'Mitglied kann sich nicht selbst zur Leitung machen');
select test.verboten($$update public.personen set auth_user_id = null where name = 'T Emma'$$,
  'Niemand kann per App das Login-Konto einer Person umhängen');
select test.erlaubt($$update public.aufgaben set person_id = privat.ich() where titel = 'Freie Aufgabe'$$,
  'Mitglied übernimmt eine freie Aufgabe');
select test.verboten($$update public.aufgaben set person_id = privat.ich() where titel = 'Emmas Aufgabe'$$,
  'Mitglied kann keine Aufgabe übernehmen, die schon jemand anderes hat');
select test.verboten($$update public.aufgaben set faellig_am = current_date + 99 where titel = 'Freie Aufgabe'$$,
  'Mitglied kann die Deadline nicht ändern (macht die Veranstaltungsleitung)');
select test.erlaubt($$update public.aufgaben set erledigt_am = now() where titel = 'Mias Aufgabe'$$,
  'Mitglied hakt eigene Aufgabe ab');
select test.verboten($$update public.aufgaben set erledigt_am = now() where titel = 'Emmas Aufgabe'$$,
  'Mitglied kann fremde Aufgaben nicht abhaken');
select test.verboten($$insert into public.aufgaben (veranstaltung_id, titel, faellig_am)
    values ('e3000000-0000-4000-8000-000000000001', 'Neu', current_date)$$,
  'Mitglied legt in fremder Veranstaltung keine Aufgaben an');
select test.erlaubt($$insert into public.kommentare (aufgabe_id, text) values ('e4000000-0000-4000-8000-000000000002', 'Frage!')$$,
  'Mitglied kommentiert eine Aufgabe');
select test.verboten($$insert into public.kommentare (aufgabe_id, person_id, text)
    values ('e4000000-0000-4000-8000-000000000002', 'e1000000-0000-4000-8000-000000000005', 'Gefälscht')$$,
  'Mitglied kann nicht unter fremdem Namen kommentieren');
select test.verboten($$insert into public.helfende (veranstaltung_id, person_id)
    values ('e3000000-0000-4000-8000-000000000005', 'e1000000-0000-4000-8000-000000000005')$$,
  'Mitglied kann niemand anderen als Helfende:n eintragen');
select test.erlaubt($$insert into public.helfende (veranstaltung_id) values ('e3000000-0000-4000-8000-000000000005')$$,
  'Mitglied trägt sich als Helfende:r ein (damit ist die Anfrage voll)');
select test.verboten($$insert into public.technik_vor_ort (veranstaltung_id) values ('e3000000-0000-4000-8000-000000000004')$$,
  'Mitglied ohne Technik-Rolle kann sich nicht vor Ort eintragen');
select test.verboten($$update public.technik_anfragen set status = 'abgelehnt', ablehnungsgrund = 'x'$$,
  'Mitglied kann Technik-Anfragen nicht annehmen oder ablehnen');
select test.erlaubt($$insert into public.veranstaltungen (titel, datum) values ('T: Von Mia', current_date + 40)$$,
  'Mitglied legt eine Veranstaltung an');
select test.verboten($$insert into public.veranstaltungen (titel, datum, erstellt_von)
    values ('T: Gefälscht', current_date + 40, 'e1000000-0000-4000-8000-000000000005')$$,
  'Mitglied kann keine Veranstaltung im Namen von jemand anderem anlegen');
select test.verboten($$insert into public.teile (name) values ('Hack')$$, 'Mitglied legt keine Lager-Teile an');
reset role;

-- ---------------------------------------------------------------------------
-- Andere Mitglieder (Emma, Noah)
-- ---------------------------------------------------------------------------
select test.als('Emma');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Helfende gesucht'$$) = 0,
  'Volle Helfenden-Anfrage ist für Nicht-Eingetragene nicht mehr sichtbar');
select test.verboten($$insert into public.helfende (veranstaltung_id) values ('e3000000-0000-4000-8000-000000000005')$$,
  'Bei voller Helfenden-Anfrage kann sich niemand mehr eintragen');
select test.pruefe(test.anzahl('select * from public.ansprechpersonen') = 0,
  'Mitglied sieht keine Ansprechpersonen fremder Anfragen');
select test.erlaubt($$update public.veranstaltungen set leitung_id = 'e1000000-0000-4000-8000-000000000006'
    where titel = 'T: Für alle'$$,
  'Veranstaltungsleitung kann die Leitung an jemand anderen abgeben');
reset role;

select test.als('Noah');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Nur Eingeladene'$$) = 1,
  'Eingeladenes Mitglied sieht die Veranstaltung „Nur Eingeladene“');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Helfende gesucht'$$) = 1,
  'Eingetragene:r sieht die volle Helfenden-Anfrage weiterhin');
select test.erlaubt($$update public.aufgaben set faellig_am = current_date + 25 where titel = 'Emmas Aufgabe'$$,
  'Neue Veranstaltungsleitung verteilt Aufgaben und ändert Deadlines');
reset role;

-- ---------------------------------------------------------------------------
-- Technik (Tim)
-- ---------------------------------------------------------------------------
\echo
\echo '— Technik'
select test.als('Tim');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Nur Technik'$$) = 1,
  'Technik sieht Nur-Technik-Veranstaltungen');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Technik-Anfrage'$$) = 1,
  'Technik sieht Anfragen, die Technik brauchen');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel = 'T: Nur Eingeladene'$$) = 0,
  'Technik sieht keine Veranstaltung „Nur Eingeladene“ ohne Einladung');
select test.pruefe(test.anzahl($$select * from public.ansprechpersonen
    where veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$) = 1, 'Technik sieht die Ansprechperson einer Anfrage');
select test.pruefe(test.anzahl('select * from public.personen_emails') = 1, 'Technik sieht nur die eigene E-Mail-Adresse');
select test.pruefe(test.anzahl('select * from public.teile') >= 1, 'Technik sieht den Bestand');
select test.erlaubt($$insert into public.teile (name, kategorie, anzahl) values ('T: Kabel', 'Kabel', 10)$$,
  'Technik legt ein neues Teil an');
select test.verboten($$delete from public.teile where name = 'T: Kabel'$$, 'Technik kann keine Lager-Teile löschen');
select test.erlaubt($$update public.technik_anfragen set status = 'angenommen', zustaendig_id = privat.ich()
    where veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$,
  'Technik nimmt eine Anfrage an');
select test.verboten($$update public.technik_anfragen set status = 'geplant'
    where veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$,
  '„Geplant“ geht erst mit mindestens einem Techniker vor Ort');
select test.verboten($$insert into public.technik_vor_ort (veranstaltung_id, person_id)
    values ('e3000000-0000-4000-8000-000000000004', 'e1000000-0000-4000-8000-000000000003')$$,
  'Technik trägt keine anderen Techniker vor Ort ein');
select test.erlaubt($$insert into public.technik_vor_ort (veranstaltung_id) values ('e3000000-0000-4000-8000-000000000004')$$,
  'Technik trägt sich selbst vor Ort ein');
select test.erlaubt($$update public.technik_anfragen set status = 'geplant'
    where veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$,
  'Mit Techniker vor Ort kann die Anfrage auf „Geplant“');
select test.verboten($$update public.veranstaltungen set titel = 'Umbenannt' where titel = 'T: Technik-Anfrage'$$,
  'Technik kann den Titel einer fremden Anfrage nicht ändern');
select test.erlaubt($$update public.veranstaltungen set ort = 'Gemeindehaus' where titel = 'T: Technik-Anfrage'$$,
  'Technik passt den Ort einer Anfrage an');
select test.erlaubt($$insert into public.zeitplan_punkte (veranstaltung_id, uhrzeit, was)
    values ('e3000000-0000-4000-8000-000000000004', '15:00', 'Aufbau')$$,
  'Technik trägt den Zeitplan einer Anfrage ein');
select test.erlaubt($$insert into public.reservierungen (veranstaltung_id, teil_id, anzahl)
    values ('e3000000-0000-4000-8000-000000000004', 'e5000000-0000-4000-8000-000000000001', 3)$$,
  'Technik verplant 3 von 4 Funkmikros');
select test.verboten($$insert into public.reservierungen (veranstaltung_id, teil_id, anzahl)
    values ('e3000000-0000-4000-8000-000000000007', 'e5000000-0000-4000-8000-000000000001', 2)$$,
  'Am selben Tag lassen sich nicht mehr Mikros verplanen, als frei sind');
select test.erlaubt($$insert into public.defekte (teil_id, beschreibung) values ('e5000000-0000-4000-8000-000000000001', 'Wackelkontakt')$$,
  'Technik meldet einen Defekt');
select test.verboten($$insert into public.reservierungen (veranstaltung_id, teil_id, anzahl)
    values ('e3000000-0000-4000-8000-000000000007', 'e5000000-0000-4000-8000-000000000001', 1)$$,
  'Defekte Stücke zählen nicht als verfügbar');
select test.erlaubt($$insert into public.anfrage_mails (veranstaltung_id, art, text)
    values ('e3000000-0000-4000-8000-000000000004', 'rueckfrage', 'Mikros oder nur Boxen?')$$,
  'Technik hält eine Rückfrage im Mailverlauf fest');
reset role;

-- Anfragende sehen nur Status und wer vor Ort ist, keine Geräte und keine Mails
select test.als('Mia');
select test.pruefe(test.anzahl($$select * from public.technik_anfragen where status = 'geplant'
                 and veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$) = 1
               and test.anzahl($$select * from public.technik_vor_ort
                 where veranstaltung_id = 'e3000000-0000-4000-8000-000000000004'$$) = 1,
  'Anfragende sehen „Geplant“ und wer vor Ort ist');
select test.pruefe(test.anzahl('select * from public.reservierungen') = 0
               and test.anzahl('select * from public.anfrage_mails') = 0,
  'Anfragende sehen keine Geräte und keinen Mailverlauf');
reset role;

-- ---------------------------------------------------------------------------
-- Gast-Gemeinde
-- ---------------------------------------------------------------------------
\echo
\echo '— Gast'
select test.als('Nord');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel like 'T:%'$$) = 1,
  'Gast sieht nur die Veranstaltung, zu der die Gemeinde eingeladen ist');
select test.pruefe(test.anzahl('select * from public.gemeinden') = 1, 'Gast sieht nur die eigene Gemeinde');
select test.pruefe(test.anzahl('select * from public.personen_emails') = 0, 'Gast sieht keine E-Mail-Adressen');
select test.pruefe(test.anzahl($$select * from public.personen where name = 'T Mia'$$) = 0,
  'Gast sieht keine Namen von Leuten, die mit der Veranstaltung nichts zu tun haben');
select test.pruefe(test.anzahl($$select * from public.personen where name = 'T Leitung'$$) = 1,
  'Gast sieht die Veranstaltungsleitung');
select test.erlaubt($$update public.aufgaben set erledigt_am = now() where titel = 'Aufgabe der Gemeinde'$$,
  'Gast hakt die Aufgabe der eigenen Gemeinde ab');
select test.erlaubt($$insert into public.kommentare (aufgabe_id, text) values ('e4000000-0000-4000-8000-000000000004', 'Erledigt!')$$,
  'Gast kommentiert');
select test.erlaubt($$insert into public.dateien (veranstaltung_id, titel, link)
    values ('e3000000-0000-4000-8000-000000000003', 'Ideen', 'https://example.org/ideen')$$,
  'Gast fügt eine Datei (Link) hinzu');
select test.verboten($$insert into public.veranstaltungen (titel, datum) values ('Gast-Event', current_date)$$,
  'Gast legt keine Veranstaltungen an');
select test.verboten($$insert into public.veranstaltung_gemeinden (veranstaltung_id, gemeinde_id)
    values ('e3000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000001')$$,
  'Gast lädt sich nicht selbst zu anderen Veranstaltungen ein');
reset role;

select test.als('Süd');
select test.pruefe(test.anzahl('select * from public.veranstaltungen') = 0,
  'Gesperrte Gemeinde sieht nichts mehr, obwohl sie eingeladen ist');
reset role;

-- ---------------------------------------------------------------------------
-- Leitung
-- ---------------------------------------------------------------------------
\echo
\echo '— Leitung'
select test.als('Leitung');
select test.pruefe(test.anzahl($$select * from public.veranstaltungen where titel like 'T:%'$$) = 8,
  'Leitung sieht alle Veranstaltungen');
select test.pruefe(test.anzahl('select * from public.personen_emails') >= 7, 'Leitung sieht alle E-Mail-Adressen');
select test.pruefe(test.anzahl('select * from public.teile') >= 2, 'Leitung sieht den Bestand');
select test.verboten($$update public.personen set entfernt_am = now() where name = 'T Leitung'$$,
  'Leitung kann sich nicht selbst entfernen');
select test.verboten($$update public.personen set ist_leitung = false where name = 'T Leitung'$$,
  'Die letzte Leitung kann ihre Rolle nicht abgeben');
select test.erlaubt($$update public.personen set ist_technik = true where name = 'T Emma'$$, 'Leitung ändert Rollen');
select test.erlaubt($$update public.personen set entfernt_am = now() where name = 'T Paul'$$, 'Leitung entfernt eine Person');
select test.erlaubt($$delete from public.teile where name = 'T: Kabel'$$, 'Leitung löscht ein Lager-Teil');
select test.erlaubt($$update public.gemeinden set gesperrt = true where name = 'Test-Gemeinde Nord'$$, 'Leitung sperrt eine Gemeinde');
select test.erlaubt($$insert into public.personen (name) values ('T: Neue Person')$$, 'Leitung lädt eine neue Person ein');
select test.erlaubt($$delete from public.personen where name = 'T: Neue Person'$$, 'Leitung zieht eine offene Einladung zurück');
select test.verboten($$delete from public.personen where name = 'T Mia'$$,
  'Wer schon angemeldet war, wird nicht gelöscht, sondern entfernt (Namen bleiben erhalten)');
reset role;

-- Folgen des Entfernens und Sperrens
select test.als('Leitung');
select test.erlaubt($$update public.personen set entfernt_am = now() where name = 'T Emma'$$, 'Leitung entfernt Emma');
select test.pruefe(test.anzahl($$select * from public.aufgaben where titel = 'Emmas Aufgabe' and person_id is null$$) = 1,
  'Offene Aufgaben einer entfernten Person werden wieder frei');
reset role;
select test.als('Emma');
select test.pruefe(test.anzahl('select * from public.veranstaltungen') = 0, 'Entfernte Person sieht nichts mehr');
reset role;
select test.als('Ehemalig');
select test.pruefe(test.anzahl('select * from public.personen') = 0, 'Entfernte Person sieht keine Personen');
reset role;
select test.als('Nord');
select test.pruefe(test.anzahl('select * from public.veranstaltungen') = 0, 'Gemeinde sieht nach dem Sperren nichts mehr');
reset role;

-- ---------------------------------------------------------------------------
-- Ergebnis
-- ---------------------------------------------------------------------------
\echo
do $$
declare n int; f text;
begin
  select count(*), string_agg('  ✗ ' || text, e'\n' order by nr) into n, f from test.fehler;
  if n > 0 then
    raise exception e'% Prüfung(en) fehlgeschlagen:\n%', n, f;
  end if;
  raise notice 'Alle Prüfungen bestanden.';
end $$;

rollback;
