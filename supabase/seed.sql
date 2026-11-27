-- Erfundene Testdaten für juki-test (wie im Prototyp v5)
--
-- NUR für die Test-Umgebung. Niemals ins Live-Projekt einspielen.
-- Alle Namen, Adressen und Telefonnummern sind ausgedacht (Domains .invalid / .example).
--
-- Die Datei kann gefahrlos mehrfach laufen: Feste Kennungen + „on conflict do nothing“.
-- Bereits vorhandene Einträge werden nicht überschrieben, Änderungen in der App bleiben erhalten.

-- Feste, lesbare Kennungen: k('person/tim') ergibt immer dieselbe UUID
create function pg_temp.k(schluessel text) returns uuid
language sql immutable as $$ select md5('juki-test/' || schluessel)::uuid $$;

-- Leute ---------------------------------------------------------------------
-- Alex = Leitung & Technik (im Prototyp „Du“). Für Etappe 3 kann der Owner im Supabase-Dashboard
-- bei einer Testperson die eigene E-Mail-Adresse eintragen, um sich so anzumelden.
insert into public.personen (id, name, ist_leitung, ist_technik, eingeladen_am) values
  (pg_temp.k('person/alex'),  'Alex',  true,  true,  '2026-11-01'),
  (pg_temp.k('person/tim'),   'Tim',   false, true,  '2026-11-01'),
  (pg_temp.k('person/paul'),  'Paul',  false, true,  '2026-11-01'),
  (pg_temp.k('person/lena'),  'Lena',  false, false, '2026-11-01'),
  (pg_temp.k('person/mia'),   'Mia',   false, false, '2026-11-01'),
  (pg_temp.k('person/noah'),  'Noah',  false, false, '2026-11-01'),
  (pg_temp.k('person/emma'),  'Emma',  false, false, '2026-11-01'),
  (pg_temp.k('person/jonas'), 'Jonas', false, false, '2026-11-23')
on conflict (id) do nothing;

insert into public.personen_emails (person_id, email) values
  (pg_temp.k('person/alex'),  'alex@juki-test.invalid'),
  (pg_temp.k('person/tim'),   'tim@juki-test.invalid'),
  (pg_temp.k('person/paul'),  'paul@juki-test.invalid'),
  (pg_temp.k('person/lena'),  'lena@juki-test.invalid'),
  (pg_temp.k('person/mia'),   'mia@juki-test.invalid'),
  (pg_temp.k('person/noah'),  'noah@juki-test.invalid'),
  (pg_temp.k('person/emma'),  'emma@juki-test.invalid'),
  (pg_temp.k('person/jonas'), 'jonas@juki-test.invalid')
on conflict do nothing;

insert into public.gemeinden (id, name, erstellt_von) values
  (pg_temp.k('gemeinde/marien'), 'St. Marien',     pg_temp.k('person/alex')),
  (pg_temp.k('gemeinde/nord'),   'Gemeinde Nord',  pg_temp.k('person/lena'))
on conflict do nothing;

-- Vorlagen ------------------------------------------------------------------
insert into public.vorlagen (id, name, standard_zeitplan, reihenfolge) values
  (pg_temp.k('vorlage/godi'),   'Motto-Gottesdienst', '[{"zeit":"15:00","was":"Aufbau"},{"zeit":"16:00","was":"Probe"},{"zeit":"18:00","was":"Beginn"}]', 1),
  (pg_temp.k('vorlage/event'),  'Konzert & Event',    '[{"zeit":"15:00","was":"Aufbau"},{"zeit":"16:00","was":"Probe"},{"zeit":"18:00","was":"Beginn"}]', 2),
  (pg_temp.k('vorlage/social'), 'Soziale Aktion',     '[]', 3)
on conflict do nothing;

insert into public.vorlage_aufgaben (id, vorlage_id, titel, tage_relativ, reihenfolge)
select pg_temp.k('vorlage-aufgabe/' || v || '/' || nr), pg_temp.k('vorlage/' || v), titel, tage, nr
from (values
  ('godi', 1, 'Motto & Thema festlegen', -42), ('godi', 2, 'Ablauf schreiben', -21),
  ('godi', 3, 'Band & Lieder auswählen', -21), ('godi', 4, 'Licht- und Tonplan erstellen', -14),
  ('godi', 5, 'Plakat & Instagram-Post', -14), ('godi', 6, 'Deko besorgen', -7),
  ('godi', 7, 'Technik aufbauen', -1), ('godi', 8, 'Abbau & Nachbesprechung', 1),
  ('event', 1, 'Programm planen', -35), ('event', 2, 'Werbung starten', -21),
  ('event', 3, 'Getränke & Snacks', -5), ('event', 4, 'Aufbau', -1), ('event', 5, 'Abbau', 1),
  ('social', 1, 'Partner anfragen', -35), ('social', 2, 'Helfende einteilen', -14),
  ('social', 3, 'Einkauf planen', -7), ('social', 4, 'Einkaufen', -2),
  ('social', 5, 'Aufbau & Durchführung', 0), ('social', 6, 'Dankeschön schreiben', 3)
) as t (v, nr, titel, tage)
on conflict do nothing;

insert into public.konzepte (id, name, erstellt_von) values
  (pg_temp.k('konzept/starwars'), 'Star-Wars-GoDi', pg_temp.k('person/emma')),
  (pg_temp.k('konzept/abba'),     'ABBA-GoDi',      pg_temp.k('person/alex'))
on conflict do nothing;

-- Veranstaltungen -----------------------------------------------------------
insert into public.veranstaltungen
  (id, titel, datum, art, vorlage_id, ort, sichtbarkeit, leitung_id, erstellt_von, konzept_id,
   nachbesprechung, anfrage_von, anfrage_notiz, helfende_gesucht)
select pg_temp.k('va/' || key), titel, datum::date, art, case when vorlage is null then null else pg_temp.k('vorlage/' || vorlage) end,
       ort, sicht, pg_temp.k('person/' || leitung), pg_temp.k('person/' || von),
       case when konzept is null then null else pg_temp.k('konzept/' || konzept) end,
       nachbesprechung, anfrage_von, notiz, helfende
from (values
  ('p1', 'Star-Wars-GoDi', '2025-05-04', 'juki', 'godi', 'Pauluskirche', 'alle', 'emma', 'emma', 'starwars',
   'Lichtschwerter aus LED-Stäben kamen super an. Nebel sparsamer einsetzen, der Rauchmelder hätte fast ausgelöst.', null, null, null),
  ('p2', 'Star-Wars-GoDi', '2026-05-03', 'juki', 'godi', 'Kirche Gemeinde Nord', 'alle', 'emma', 'emma', 'starwars',
   'Bühne dort kleiner, nur 4 Moving Heads passten. Aufbau eine Stunde früher einplanen.', null, null, null),
  ('p3', 'ABBA-GoDi', '2025-11-30', 'juki', 'godi', 'Pauluskirche', 'alle', 'alex', 'alex', 'abba',
   'Mitsing-Texte auf der Leinwand waren der Hit. Zweites Funkmikro für den Chor einplanen.', null, null, null),
  ('e1', 'Adventsessen mit der Tafel', '2026-12-13', 'juki', 'social', 'Gemeindehaus', 'alle', 'lena', 'lena', null,
   null, null, null, null),
  ('e2', 'Weihnachts-GoDi „ABBA Christmas“', '2026-12-20', 'juki', 'godi', 'Pauluskirche', 'alle', 'alex', 'alex', 'abba',
   null, null, null, null),
  ('e4', 'Krippenspiel Gemeinde Nord', '2026-12-24', 'anfrage', null, 'Kirche Gemeinde Nord', 'technik', 'lena', 'lena', null,
   null, 'Ev. Kirchengemeinde Nord, per WhatsApp an Lena',
   'Sie brauchen Funkmikros für die Kinder und jemanden, der kurz erklärt, wie sie funktionieren.', null),
  ('e6', 'Konfi-Abschluss Gemeinde Süd', '2026-12-06', 'anfrage', null, 'Kirche Gemeinde Süd', 'technik', 'mia', 'mia', null,
   null, 'Gemeinde Süd, Pfarrer Krüger, im Gespräch nach dem GoDi', 'Sie wollen „Ton und Licht“ für den Altarraum.', null),
  ('e8', 'Seniorenadvent Gemeinde Ost', '2026-12-12', 'anfrage', null, 'Gemeindehaus Ost', 'alle', 'lena', 'lena', null,
   null, 'Gemeinde Ost, per Mail an Lena', 'Sie suchen 3 Leute, die Kaffee ausschenken und beim Aufbau helfen.', 3),
  ('e9', 'Jugendabend Gemeinde West', '2027-01-23', 'anfrage', null, 'Jugendhaus West', 'technik', 'alex', 'alex', null,
   null, 'Gemeinde West, Jugendreferentin Sarah, beim Treffen',
   '„Wir brauchen Ton für eine Band.“ Unklar, ob Mikros oder nur Boxen gemeint sind.', null),
  ('e7', 'Inventur & Kabel-Check', '2026-12-02', 'juki', null, 'Pauluskirche', 'technik', 'tim', 'tim', null,
   null, null, null, null),
  ('e3', '7 Jahre JuKi: Geburtstags-GoDi', '2027-01-17', 'juki', 'godi', 'Pauluskirche', 'alle', 'emma', 'emma', null,
   null, null, null, null),
  ('e5', 'Gemeinsamer Jugend-GoDi mit St. Marien', '2027-02-07', 'juki', 'godi', 'Pauluskirche', 'eingeladene', 'alex', 'alex', null,
   null, null, null, null)
) as t (key, titel, datum, art, vorlage, ort, sicht, leitung, von, konzept, nachbesprechung, anfrage_von, notiz, helfende)
on conflict do nothing;

insert into public.veranstaltung_eingeladene (veranstaltung_id, person_id) values
  (pg_temp.k('va/e5'), pg_temp.k('person/alex')),
  (pg_temp.k('va/e5'), pg_temp.k('person/noah'))
on conflict do nothing;

insert into public.veranstaltung_gemeinden (veranstaltung_id, gemeinde_id) values
  (pg_temp.k('va/e4'), pg_temp.k('gemeinde/nord')),
  (pg_temp.k('va/e5'), pg_temp.k('gemeinde/marien'))
on conflict do nothing;

insert into public.zeitplan_punkte (id, veranstaltung_id, uhrzeit, was)
select pg_temp.k('zeit/' || va || '/' || uhrzeit), pg_temp.k('va/' || va), uhrzeit::time, was
from (values
  ('p1', '14:00', 'Aufbau'), ('p1', '16:00', 'Probe'), ('p1', '18:00', 'Gottesdienst'),
  ('p2', '13:00', 'Aufbau'), ('p2', '15:30', 'Probe'), ('p2', '17:00', 'Gottesdienst'),
  ('p3', '15:00', 'Aufbau'), ('p3', '16:30', 'Probe'), ('p3', '18:00', 'Gottesdienst'),
  ('e1', '14:00', 'Aufbau & Kochen'), ('e1', '17:00', 'Essen'), ('e1', '20:00', 'Abbau'),
  ('e2', '15:00', 'Aufbau Technik'), ('e2', '16:00', 'Probe mit Band'), ('e2', '17:30', 'Einlass'),
  ('e2', '18:00', 'Gottesdienst'), ('e2', '20:00', 'Abbau'),
  ('e4', '10:00', 'Abholung im Technikraum'), ('e4', '14:00', 'Einweisung Mikros'), ('e4', '15:30', 'Krippenspiel')
) as t (va, uhrzeit, was)
on conflict do nothing;

insert into public.ansprechpersonen (veranstaltung_id, name, handy, email) values
  (pg_temp.k('va/e4'), 'Frau Berger', '0170 5550123', 'berger@gemeinde-nord.example'),
  (pg_temp.k('va/e6'), 'Pfarrer Krüger', '05731 5550184', 'krueger@gemeinde-sued.example'),
  (pg_temp.k('va/e9'), 'Sarah (Jugendreferentin)', '0151 5550777', 'sarah@gemeinde-west.example')
on conflict do nothing;

insert into public.helfende (veranstaltung_id, person_id) values
  (pg_temp.k('va/e8'), pg_temp.k('person/lena')),
  (pg_temp.k('va/e8'), pg_temp.k('person/noah'))
on conflict do nothing;

-- Aufgaben & Kommentare -----------------------------------------------------
insert into public.aufgaben (id, veranstaltung_id, titel, person_id, gemeinde_id, faellig_am, erledigt_am)
select pg_temp.k('aufgabe/' || va || '/' || titel), pg_temp.k('va/' || va), titel,
       case when wer like 'p:%' then pg_temp.k('person/' || substr(wer, 3)) end,
       case when wer like 'g:%' then pg_temp.k('gemeinde/' || substr(wer, 3)) end,
       faellig::date, case when erledigt then faellig::timestamptz end
from (values
  ('e1', 'Partner anfragen', 'p:lena', '2026-11-08', true),
  ('e1', 'Helfende einteilen', 'p:alex', '2026-11-29', false),
  ('e1', 'Einkauf planen', 'p:mia', '2026-12-06', false),
  ('e1', 'Einkaufen', null, '2026-12-11', false),
  ('e1', 'Aufbau & Durchführung', 'p:lena', '2026-12-13', false),
  ('e2', 'Motto & Thema festlegen', 'p:alex', '2026-11-08', true),
  ('e2', 'Ablauf schreiben', 'p:alex', '2026-11-22', false),
  ('e2', 'Plakat & Instagram-Post', 'p:emma', '2026-11-23', false),
  ('e2', 'Band & Lieder auswählen', 'p:noah', '2026-11-29', false),
  ('e2', 'Licht- und Tonplan erstellen', 'p:tim', '2026-12-06', false),
  ('e2', 'Deko besorgen', null, '2026-12-13', false),
  ('e2', 'Technik aufbauen', 'p:tim', '2026-12-19', false),
  ('e2', 'Abbau & Nachbesprechung', null, '2026-12-21', false),
  ('e7', 'Kabel-Cases durchprüfen', 'p:paul', '2026-12-02', false),
  ('e7', 'Nebelmaschine zur Reparatur bringen', 'p:tim', '2026-11-28', false),
  ('e7', 'Ersatz-Akkus bestellen', null, '2026-11-30', false),
  ('e3', 'Motto & Thema festlegen', 'p:emma', '2026-12-06', false),
  ('e3', 'Ablauf schreiben', null, '2026-12-27', false),
  ('e3', 'Einladung an Ehemalige', 'p:mia', '2026-12-15', false),
  ('p1', 'Motto & Thema festlegen', 'p:emma', '2025-03-20', true),
  ('p1', 'Lichtschwerter besorgen', 'p:noah', '2025-04-20', true),
  ('p1', 'Ablauf schreiben', 'p:emma', '2025-04-13', true),
  ('p2', 'Ablauf an die Kirche anpassen', 'p:emma', '2026-04-12', true),
  ('p2', 'Kostüme organisieren', 'p:mia', '2026-04-26', true),
  ('p3', 'Liedtexte für die Leinwand', 'p:noah', '2025-11-20', true),
  ('p3', 'Chor anfragen', 'p:alex', '2025-11-01', true),
  ('e5', 'Gemeinsames Thema finden', 'p:alex', '2026-12-10', false),
  ('e5', 'Band aus beiden Gemeinden', 'g:marien', '2027-01-10', false),
  ('e5', 'Raum in St. Marien buchen', 'g:marien', '2026-12-15', false),
  ('e5', 'Plakat gestalten', 'p:noah', '2027-01-15', false)
) as t (va, titel, wer, faellig, erledigt)
on conflict do nothing;

insert into public.kommentare (id, aufgabe_id, person_id, gemeinde_id, text, erstellt_am)
select pg_temp.k('kommentar/' || nr), pg_temp.k('aufgabe/' || aufgabe),
       case when wer like 'p:%' then pg_temp.k('person/' || substr(wer, 3)) end,
       case when wer like 'g:%' then pg_temp.k('gemeinde/' || substr(wer, 3)) end,
       text, am::timestamptz
from (values
  (1, 'e2/Plakat & Instagram-Post', 'p:emma', 'Entwurf ist bei den Dateien. Passt das Pink?', '2026-11-21 18:00'),
  (2, 'e2/Plakat & Instagram-Post', 'p:alex', 'Sieht super aus, gerne etwas mehr Glitzer!', '2026-11-22 10:00'),
  (3, 'e2/Deko besorgen', 'p:emma', 'Vielleicht eine Discokugel passend zu ABBA?', '2026-11-20 19:30'),
  (4, 'e5/Band aus beiden Gemeinden', 'g:marien', 'Wir hätten Schlagzeug und Bass. Habt ihr jemanden für Keys?', '2026-11-19 20:00'),
  (5, 'e5/Band aus beiden Gemeinden', 'p:noah', 'Ja, ich spiele Keyboard!', '2026-11-20 08:15')
) as t (nr, aufgabe, wer, text, am)
on conflict do nothing;

-- Dateien (zum Start als Link; example.org ist eine reservierte Beispiel-Adresse)
insert into public.dateien (id, veranstaltung_id, titel, link, person_id, gemeinde_id, erstellt_am)
select pg_temp.k('datei/' || va || '/' || titel), pg_temp.k('va/' || va), titel,
       'https://example.org/juki-test/' || titel,
       case when wer like 'p:%' then pg_temp.k('person/' || substr(wer, 3)) end,
       case when wer like 'g:%' then pg_temp.k('gemeinde/' || substr(wer, 3)) end,
       am::timestamptz
from (values
  ('e2', 'Ablaufplan_ABBA_Christmas.docx', 'p:alex', '2026-11-15'),
  ('e2', 'Liedliste.pdf', 'p:noah', '2026-11-18'),
  ('e2', 'Plakat_Entwurf.png', 'p:emma', '2026-11-21'),
  ('e1', 'Helferplan.pdf', 'p:lena', '2026-11-10'),
  ('p1', 'Ablauf_Star_Wars.docx', 'p:emma', '2025-04-14'),
  ('p2', 'Ablauf_Star_Wars_Nord.docx', 'p:emma', '2026-04-12'),
  ('p3', 'ABBA_Liedtexte.pptx', 'p:noah', '2025-11-21'),
  ('e5', 'Ideensammlung_St_Marien.pdf', 'g:marien', '2026-11-19')
) as t (va, titel, wer, am)
on conflict do nothing;

-- Technik-Bestand -----------------------------------------------------------
insert into public.teile (id, name, kategorie, anzahl, lagerort, ist_case, inhalt, geprueft_am, erstellt_von)
select pg_temp.k('teil/' || key), name, kat, anzahl, ort, ist_case, inhalt, '2026-03-14', pg_temp.k('person/tim')
from (values
  ('i1', 'Funkmikrofon (Hand)', 'Ton', 4, 'Mikro-Case', false, null),
  ('i2', 'Headset-Mikrofon', 'Ton', 2, 'Mikro-Case', false, null),
  ('i3', 'Mischpult-Case', 'Ton', 1, 'Technikraum', true, 'Digitalpult, Stagebox, Netzteil, Tablet'),
  ('i4', 'Aktivbox 12 Zoll', 'Ton', 4, 'Keller', false, null),
  ('i5', 'Subwoofer', 'Ton', 2, 'Keller', false, null),
  ('i6', 'Moving-Head-Case', 'Licht', 2, 'Kiste L1', true, 'je 3 Moving Heads, Stromkabel, Safeties'),
  ('i7', 'LED-Scheinwerfer', 'Licht', 12, 'Kiste L2', false, null),
  ('i8', 'Nebelmaschine', 'Licht', 1, 'Regal B', false, null),
  ('i9', 'Lichtpult', 'Licht', 1, 'Technikraum', false, null),
  ('i10', 'Beamer', 'Video', 1, 'Schrank Büro', false, null),
  ('i11', 'Leinwand 3 m', 'Video', 1, 'Keller', false, null),
  ('i12', 'Kabel-Case', 'Kabel', 3, 'Kabelregal', true, 'XLR 10 m ×10, DMX ×8, Strom ×6, Mehrfachstecker ×4')
) as t (key, name, kat, anzahl, ort, ist_case, inhalt)
on conflict do nothing;

insert into public.defekte (id, teil_id, beschreibung, gemeldet_von, gemeldet_am) values
  (pg_temp.k('defekt/nebel'), pg_temp.k('teil/i8'), 'Pumpe läuft, aber es kommt kein Nebel.', pg_temp.k('person/paul'), '2026-11-14')
on conflict do nothing;

-- Technik-Ablauf (erst „vor Ort“, dann die Anfragen, weil „Geplant“ mindestens einen Techniker braucht)
insert into public.technik_vor_ort (veranstaltung_id, person_id) values
  (pg_temp.k('va/e1'), pg_temp.k('person/paul')),
  (pg_temp.k('va/e2'), pg_temp.k('person/tim')),
  (pg_temp.k('va/e2'), pg_temp.k('person/paul')),
  (pg_temp.k('va/e4'), pg_temp.k('person/tim'))
on conflict do nothing;

insert into public.technik_anfragen (veranstaltung_id, beschreibung, status, angefragt_von_person, zustaendig_id, erstellt_am)
select pg_temp.k('va/' || va), text, status, pg_temp.k('person/' || von),
       case when zust is null then null else pg_temp.k('person/' || zust) end, '2026-11-15'
from (values
  ('e1', 'Etwas Musik im Hintergrund und ein Mikro für die Begrüßung.', 'geplant', 'lena', 'paul'),
  ('e2', 'Volles Programm: Band mit 5 Leuten, Lichtshow, Beamer für die Liedtexte.', 'geplant', 'alex', 'tim'),
  ('e4', 'Funkmikros für die Kinder, kurze Einweisung vor Ort.', 'geplant', 'lena', 'tim'),
  ('e6', 'Ton und Licht für den Altarraum, wenn möglich ein Beamer.', 'angefragt', 'mia', null),
  ('e9', 'Ton für eine Band.', 'angenommen', 'alex', 'tim')
) as t (va, text, status, von, zust)
on conflict do nothing;

insert into public.anfrage_mails (id, veranstaltung_id, art, text, person_id, erstellt_am) values
  (pg_temp.k('mail/e9/1'), pg_temp.k('va/e9'), 'annahme',
   'Automatische Mail: Tim von der JuKi-Technik kümmert sich um eure Anfrage und meldet sich bei Rückfragen.',
   pg_temp.k('person/tim'), '2026-11-22 09:00'),
  (pg_temp.k('mail/e9/2'), pg_temp.k('va/e9'), 'rueckfrage',
   'Meint ihr mit Ton Mikros für Gesang oder nur Boxen für Musik vom Laptop?',
   pg_temp.k('person/tim'), '2026-11-22 09:05')
on conflict do nothing;

insert into public.reservierungen (veranstaltung_id, teil_id, anzahl, gepackt)
select pg_temp.k('va/' || va), pg_temp.k('teil/' || teil), anzahl, coalesce(gepackt, false)
from (values
  ('e2', 'i1', 1, null), ('e2', 'i2', 2, null), ('e2', 'i3', 1, true), ('e2', 'i4', 2, null),
  ('e2', 'i6', 2, null), ('e2', 'i7', 8, null), ('e2', 'i9', 1, null), ('e2', 'i10', 1, null),
  ('e2', 'i12', 2, true),
  ('e4', 'i1', 3, null),
  ('e1', 'i4', 2, null), ('e1', 'i1', 1, null), ('e1', 'i12', 1, null),
  ('p1', 'i6', 2, null), ('p1', 'i7', 8, null), ('p1', 'i3', 1, null), ('p1', 'i12', 2, null),
  ('p2', 'i6', 1, null), ('p2', 'i7', 6, null), ('p2', 'i3', 1, null), ('p2', 'i12', 2, null),
  ('p3', 'i1', 2, null), ('p3', 'i3', 1, null), ('p3', 'i10', 1, null), ('p3', 'i11', 1, null)
) as t (va, teil, anzahl, gepackt)
on conflict do nothing;
