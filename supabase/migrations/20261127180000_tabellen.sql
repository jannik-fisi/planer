-- Etappe 2b, Teil 1: Tabellen für alle Bereiche aus dem Konzept
--
-- Aufbau (Prototyp v5 als Vorlage):
--   Leute & Rollen ........ personen, personen_emails
--   Gemeinden (Gäste) ..... gemeinden, veranstaltung_gemeinden
--   Vorlagen & Konzepte ... vorlagen, vorlage_aufgaben, konzepte
--   Veranstaltungen ....... veranstaltungen, veranstaltung_eingeladene, zeitplan_punkte
--   Aufgaben .............. aufgaben, kommentare
--   Dateien ............... dateien (Link oder kleines Foto; an Veranstaltung, Konzept oder Bibliothek)
--   Anfragen & Helfende ... ansprechpersonen, helfende
--   Technik-Ablauf ........ technik_anfragen, technik_vor_ort, anfrage_mails, reservierungen, leih_protokolle
--   Technik-Bestand ....... teile, defekte, inventuren, inventur_pruefungen
--
-- Wer was sehen und ändern darf, steht in der nächsten Datei (…_rechte_regeln.sql).
-- Bis dahin ist jede Tabelle sofort gesperrt (Row Level Security ohne Regel = niemand sieht etwas).

-- ---------------------------------------------------------------------------
-- Leute & Rollen
-- ---------------------------------------------------------------------------

create table public.personen (
  id             uuid primary key default gen_random_uuid(),
  name           text not null check (length(btrim(name)) between 1 and 60),
  ist_leitung    boolean not null default false,
  ist_technik    boolean not null default false,
  -- Wird beim ersten Login mit dem Supabase-Konto verbunden (Etappe 3). Leer = Einladung noch offen.
  auth_user_id   uuid unique references auth.users (id) on delete set null,
  eingeladen_am  timestamptz not null default now(),
  eingeladen_von uuid references public.personen (id) on delete set null,
  -- Entfernte Personen bleiben als Name erhalten (z. B. an alten Kommentaren), können aber nichts mehr.
  entfernt_am    timestamptz,
  erstellt_am    timestamptz not null default now()
);
comment on table public.personen is 'Mitglieder der JuKi mit Rolle. Mitglied = alle; dazu optional Leitung und/oder Technik.';

-- E-Mail-Adressen getrennt, damit nur die Leitung (und man selbst) sie sieht.
create table public.personen_emails (
  person_id uuid primary key references public.personen (id) on delete cascade,
  email     text not null check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);
create unique index personen_emails_email_eindeutig on public.personen_emails (lower(email));

-- ---------------------------------------------------------------------------
-- Gemeinden mit Gastzugang
-- ---------------------------------------------------------------------------

create table public.gemeinden (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(btrim(name)) between 1 and 80),
  gesperrt     boolean not null default false,
  -- Dauerhafter Zugang der Gemeinde (Code-Login kommt in Etappe 3)
  auth_user_id uuid unique references auth.users (id) on delete set null,
  erstellt_am  timestamptz not null default now(),
  erstellt_von uuid references public.personen (id) on delete set null
);
create unique index gemeinden_name_eindeutig on public.gemeinden (lower(name));

-- ---------------------------------------------------------------------------
-- Vorlagen & Konzepte
-- ---------------------------------------------------------------------------

create table public.vorlagen (
  id                uuid primary key default gen_random_uuid(),
  name              text not null unique check (length(btrim(name)) between 1 and 60),
  -- z. B. [{"zeit":"15:00","was":"Aufbau"},{"zeit":"18:00","was":"Beginn"}]
  standard_zeitplan jsonb not null default '[]' check (jsonb_typeof(standard_zeitplan) = 'array'),
  reihenfolge       int not null default 0
);

create table public.vorlage_aufgaben (
  id           uuid primary key default gen_random_uuid(),
  vorlage_id   uuid not null references public.vorlagen (id) on delete cascade,
  titel        text not null check (length(btrim(titel)) between 1 and 120),
  -- Abstand zur Veranstaltung in Tagen: -14 = zwei Wochen vorher, 1 = am Tag danach
  tage_relativ int not null default 0,
  reihenfolge  int not null default 0
);
create index on public.vorlage_aufgaben (vorlage_id);

create table public.konzepte (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(btrim(name)) between 1 and 120),
  erstellt_am  timestamptz not null default now(),
  erstellt_von uuid references public.personen (id) on delete set null
);

-- ---------------------------------------------------------------------------
-- Veranstaltungen (auch Anfragen von außen sind Veranstaltungen mit art = 'anfrage')
-- ---------------------------------------------------------------------------

create table public.veranstaltungen (
  id               uuid primary key default gen_random_uuid(),
  titel            text not null check (length(btrim(titel)) between 1 and 120),
  datum            date not null,
  art              text not null default 'juki' check (art in ('juki', 'anfrage')),
  vorlage_id       uuid references public.vorlagen (id) on delete set null,
  ort              text not null default 'Pauluskirche' check (length(ort) <= 120),
  sichtbarkeit     text not null default 'alle' check (sichtbarkeit in ('alle', 'technik', 'eingeladene')),
  leitung_id       uuid references public.personen (id) on delete set null,
  erstellt_von     uuid references public.personen (id) on delete set null,
  konzept_id       uuid references public.konzepte (id) on delete set null,
  nachbesprechung  text check (length(nachbesprechung) <= 5000),
  -- Nur bei Anfragen: von wem und wie sie reinkam, und der Wortlaut
  anfrage_von      text check (length(anfrage_von) <= 200),
  anfrage_notiz    text check (length(anfrage_notiz) <= 2000),
  -- „Helfende gesucht“: so viele Personen werden gebraucht (leer = keine Helfenden-Suche)
  helfende_gesucht int check (helfende_gesucht between 1 and 100),
  erstellt_am      timestamptz not null default now()
);
create index on public.veranstaltungen (datum);
create index on public.veranstaltungen (leitung_id);
create index on public.veranstaltungen (konzept_id);

-- Bei Sichtbarkeit „Nur Eingeladene“
create table public.veranstaltung_eingeladene (
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  person_id        uuid not null references public.personen (id) on delete cascade,
  primary key (veranstaltung_id, person_id)
);
create index on public.veranstaltung_eingeladene (person_id);

-- Gemeinden, die zu einer Veranstaltung eingeladen sind
create table public.veranstaltung_gemeinden (
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  gemeinde_id      uuid not null references public.gemeinden (id) on delete cascade,
  eingeladen_am    timestamptz not null default now(),
  primary key (veranstaltung_id, gemeinde_id)
);
create index on public.veranstaltung_gemeinden (gemeinde_id);

-- Einfacher Zeitplan (15:00 Aufbau · 16:00 Probe · 18:00 Beginn)
create table public.zeitplan_punkte (
  id               uuid primary key default gen_random_uuid(),
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  uhrzeit          time not null,
  was              text not null check (length(btrim(was)) between 1 and 80)
);
create index on public.zeitplan_punkte (veranstaltung_id);

-- ---------------------------------------------------------------------------
-- Aufgaben & Kommentare
-- ---------------------------------------------------------------------------

create table public.aufgaben (
  id               uuid primary key default gen_random_uuid(),
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  titel            text not null check (length(btrim(titel)) between 1 and 120),
  beschreibung     text check (length(beschreibung) <= 2000),
  -- Zuständig: eine Person ODER eine Gast-Gemeinde ODER noch niemand („Sucht noch jemanden“)
  person_id        uuid references public.personen (id) on delete set null,
  gemeinde_id      uuid references public.gemeinden (id) on delete set null,
  faellig_am       date not null,
  erledigt_am      timestamptz,
  erstellt_am      timestamptz not null default now(),
  check (person_id is null or gemeinde_id is null)
);
create index on public.aufgaben (veranstaltung_id);
create index on public.aufgaben (person_id) where erledigt_am is null;
create index on public.aufgaben (gemeinde_id) where gemeinde_id is not null;
create index on public.aufgaben (faellig_am) where erledigt_am is null;

create table public.kommentare (
  id          uuid primary key default gen_random_uuid(),
  aufgabe_id  uuid not null references public.aufgaben (id) on delete cascade,
  person_id   uuid references public.personen (id) on delete cascade,
  gemeinde_id uuid references public.gemeinden (id) on delete cascade,
  text        text not null check (length(btrim(text)) between 1 and 2000),
  erstellt_am timestamptz not null default now(),
  check (num_nonnulls(person_id, gemeinde_id) = 1)
);
create index on public.kommentare (aufgabe_id);

-- ---------------------------------------------------------------------------
-- Dateien: zum Start als Link (OneDrive/SharePoint) oder kleines Foto im Supabase-Speicher.
-- Hängt an einer Veranstaltung, an einem Konzept (dann in allen Aufführungen sichtbar)
-- oder an nichts von beidem (= Vorlagen-Bibliothek).
-- ---------------------------------------------------------------------------

create table public.dateien (
  id               uuid primary key default gen_random_uuid(),
  veranstaltung_id uuid references public.veranstaltungen (id) on delete cascade,
  konzept_id       uuid references public.konzepte (id) on delete cascade,
  titel            text not null check (length(btrim(titel)) between 1 and 160),
  link             text check (link ~ '^https://' and length(link) <= 2000),
  speicher_pfad    text check (length(speicher_pfad) <= 500),
  person_id        uuid references public.personen (id) on delete set null,
  gemeinde_id      uuid references public.gemeinden (id) on delete set null,
  erstellt_am      timestamptz not null default now(),
  check (num_nonnulls(link, speicher_pfad) = 1),
  check (veranstaltung_id is null or konzept_id is null),
  check (person_id is null or gemeinde_id is null)
);
create index on public.dateien (veranstaltung_id);
create index on public.dateien (konzept_id);

-- ---------------------------------------------------------------------------
-- Anfragen & Helfende
-- ---------------------------------------------------------------------------

-- Ansprechperson einer Anfrage (externe Person, Löschfrist folgt vor dem Go-Live)
create table public.ansprechpersonen (
  veranstaltung_id uuid primary key references public.veranstaltungen (id) on delete cascade,
  name             text check (length(name) <= 100),
  handy            text check (length(handy) <= 40),
  email            text check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  erstellt_am      timestamptz not null default now(),
  check (num_nonnulls(name, handy, email) >= 1)
);

create table public.helfende (
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  person_id        uuid not null references public.personen (id) on delete cascade,
  eingetragen_am   timestamptz not null default now(),
  primary key (veranstaltung_id, person_id)
);
create index on public.helfende (person_id);

-- ---------------------------------------------------------------------------
-- Technik-Ablauf: Angefragt → Angenommen → Geplant (oder Abgelehnt)
-- ---------------------------------------------------------------------------

create table public.technik_anfragen (
  veranstaltung_id       uuid primary key references public.veranstaltungen (id) on delete cascade,
  beschreibung           text not null check (length(btrim(beschreibung)) between 1 and 2000),
  status                 text not null default 'angefragt'
                         check (status in ('angefragt', 'angenommen', 'geplant', 'abgelehnt')),
  angefragt_von_person   uuid references public.personen (id) on delete set null,
  angefragt_von_gemeinde uuid references public.gemeinden (id) on delete set null,
  -- Der Techniker, der sich kümmert und die Details klärt
  zustaendig_id          uuid references public.personen (id) on delete set null,
  ablehnungsgrund        text check (length(ablehnungsgrund) <= 1000),
  erstellt_am            timestamptz not null default now(),
  geaendert_am           timestamptz not null default now(),
  check (status <> 'angenommen' or zustaendig_id is not null),
  check (status <> 'abgelehnt' or length(btrim(ablehnungsgrund)) > 0),
  check (angefragt_von_person is null or angefragt_von_gemeinde is null)
);
create index on public.technik_anfragen (status);

-- Techniker vor Ort (mehrere möglich; „Geplant“ erst mit mindestens einem)
create table public.technik_vor_ort (
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  person_id        uuid not null references public.personen (id) on delete cascade,
  eingetragen_am   timestamptz not null default now(),
  primary key (veranstaltung_id, person_id)
);
create index on public.technik_vor_ort (person_id);

-- Mailverlauf an der Anfrage (automatische Mails, Rückfragen, übernommene Antworten)
create table public.anfrage_mails (
  id               uuid primary key default gen_random_uuid(),
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  art              text not null check (art in ('annahme', 'zusage', 'absage', 'rueckfrage', 'antwort', 'protokoll')),
  text             text not null check (length(btrim(text)) between 1 and 5000),
  person_id        uuid references public.personen (id) on delete set null,
  erstellt_am      timestamptz not null default now()
);
create index on public.anfrage_mails (veranstaltung_id);

-- ---------------------------------------------------------------------------
-- Technik-Bestand
-- ---------------------------------------------------------------------------

create table public.teile (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(btrim(name)) between 1 and 120),
  kategorie    text not null default 'Sonstiges' check (kategorie in ('Ton', 'Licht', 'Video', 'Kabel', 'Sonstiges')),
  anzahl       int not null default 1 check (anzahl between 1 and 9999),
  lagerort     text check (length(lagerort) <= 120),
  ist_case     boolean not null default false,
  inhalt       text check (length(inhalt) <= 1000),
  notiz        text check (length(notiz) <= 1000),
  geprueft_am  date,
  erstellt_am  timestamptz not null default now(),
  erstellt_von uuid references public.personen (id) on delete set null
);

-- Geplante Technik pro Veranstaltung, mit Packliste und Leihgabe (Raus / Zurück / Schaden)
create table public.reservierungen (
  veranstaltung_id uuid not null references public.veranstaltungen (id) on delete cascade,
  teil_id          uuid not null references public.teile (id) on delete cascade,
  anzahl           int not null check (anzahl between 1 and 9999),
  gepackt          boolean not null default false,
  raus             boolean not null default false,
  zurueck          boolean not null default false,
  beschaedigt      boolean not null default false,
  primary key (veranstaltung_id, teil_id),
  check (raus or not zurueck),
  check (zurueck or not beschaedigt)
);
create index on public.reservierungen (teil_id);

-- Ein Eintrag = ein defektes Stück. Offen, solange „repariert_am“ leer ist.
create table public.defekte (
  id               uuid primary key default gen_random_uuid(),
  teil_id          uuid not null references public.teile (id) on delete cascade,
  beschreibung     text check (length(beschreibung) <= 2000),
  foto_pfad        text check (length(foto_pfad) <= 500),
  veranstaltung_id uuid references public.veranstaltungen (id) on delete set null,
  gemeldet_von     uuid references public.personen (id) on delete set null,
  gemeldet_am      timestamptz not null default now(),
  repariert_am     timestamptz,
  repariert_von    uuid references public.personen (id) on delete set null,
  check (num_nonnulls(beschreibung, foto_pfad) >= 1)
);
create index on public.defekte (teil_id) where repariert_am is null;

create table public.inventuren (
  id                uuid primary key default gen_random_uuid(),
  gestartet_am      timestamptz not null default now(),
  gestartet_von     uuid references public.personen (id) on delete set null,
  abgeschlossen_am  timestamptz,
  abgeschlossen_von uuid references public.personen (id) on delete set null
);
-- Immer nur eine laufende Inventur
create unique index inventuren_nur_eine_offen on public.inventuren ((true)) where abgeschlossen_am is null;

create table public.inventur_pruefungen (
  inventur_id  uuid not null references public.inventuren (id) on delete cascade,
  teil_id      uuid not null references public.teile (id) on delete cascade,
  geprueft_von uuid references public.personen (id) on delete set null,
  geprueft_am  timestamptz not null default now(),
  primary key (inventur_id, teil_id)
);

-- Leih-Protokoll mit Unterschrift (Bild im Supabase-Speicher), je eins für Ausgabe und Rückgabe
create table public.leih_protokolle (
  id                uuid primary key default gen_random_uuid(),
  veranstaltung_id  uuid not null references public.veranstaltungen (id) on delete cascade,
  art               text not null check (art in ('ausgabe', 'rueckgabe')),
  name              text not null check (length(btrim(name)) between 1 and 100),
  unterschrift_pfad text not null check (length(unterschrift_pfad) <= 500),
  teile_text        text not null check (length(teile_text) <= 4000),
  erstellt_am       timestamptz not null default now(),
  erstellt_von      uuid references public.personen (id) on delete set null,
  unique (veranstaltung_id, art)
);

-- ---------------------------------------------------------------------------
-- Sicherheit: Row Level Security auf JEDER Tabelle. Ohne Regel sieht niemand etwas.
-- ---------------------------------------------------------------------------

do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
end $$;
