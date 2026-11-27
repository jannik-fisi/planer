-- Etappe 2b, Teil 2: Rechte-Regeln (Row Level Security) nach den Rollen aus dem Konzept
--
-- Grundsätze
--   • Ohne Anmeldung (anon) gibt es keine einzige Tabelle.
--   • Leitung: sieht alles, verwaltet Leute, darf Lager-Teile löschen. Immer mindestens eine Leitung.
--   • Technik: Technik-Bereich (Bestand, Kalender), Anfragen annehmen und planen, sich für Einsätze eintragen.
--   • Mitglied: Veranstaltungen „Alle in der JuKi“ + alles, wo es eine Aufgabe hat oder eingeladen ist.
--   • Gast (Gemeinde): nur Veranstaltungen, zu denen die Gemeinde eingeladen ist; Aufgaben übernehmen,
--     kommentieren, Dateien hochladen. Gesperrte Gemeinden sehen nichts mehr.
--   • Veranstaltungsleitung: verwaltet „ihre“ Veranstaltung (Aufgaben verteilen, Gäste, Zeitplan …).
--
-- Die Prüf-Funktionen liegen im Schema „privat“. Es ist nicht über die Schnittstelle (API) erreichbar,
-- wird aber von den Regeln benutzt. Sie laufen mit erweiterten Rechten („security definer“), damit sich
-- die Regeln nicht gegenseitig blockieren, und geben nur ja/nein bzw. die eigene Kennung zurück.

create schema privat;
revoke all on schema privat from public;
grant usage on schema privat to authenticated;

-- ---------------------------------------------------------------------------
-- Wer bin ich?
-- ---------------------------------------------------------------------------

-- Eigene Person (nur wenn nicht entfernt), sonst leer
create function privat.ich() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.id from public.personen p
  where p.auth_user_id = auth.uid() and p.entfernt_am is null
$$;

-- Eigene Gemeinde bei Gast-Zugang (nur wenn nicht gesperrt), sonst leer
create function privat.meine_gemeinde() returns uuid
language sql stable security definer set search_path = '' as $$
  select g.id from public.gemeinden g
  where g.auth_user_id = auth.uid() and not g.gesperrt
$$;

create function privat.ist_person() returns boolean
language sql stable security definer set search_path = '' as $$
  select privat.ich() is not null
$$;

create function privat.ist_leitung() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.personen p
                 where p.auth_user_id = auth.uid() and p.entfernt_am is null and p.ist_leitung)
$$;

create function privat.ist_technik() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.personen p
                 where p.auth_user_id = auth.uid() and p.entfernt_am is null and p.ist_technik)
$$;

create function privat.technik_oder_leitung() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.personen p
                 where p.auth_user_id = auth.uid() and p.entfernt_am is null
                   and (p.ist_technik or p.ist_leitung))
$$;

-- ---------------------------------------------------------------------------
-- Darf ich diese Veranstaltung sehen? (genau wie canSee() im Prototyp v5)
-- ---------------------------------------------------------------------------

create function privat.darf_sehen(v uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  ich uuid := privat.ich();
  e   public.veranstaltungen;
begin
  select * into e from public.veranstaltungen where id = v;
  if not found then return false; end if;

  -- Gast: nur, wozu die eigene (nicht gesperrte) Gemeinde eingeladen ist
  if ich is null then
    return exists (select 1 from public.veranstaltung_gemeinden vg
                   where vg.veranstaltung_id = v and vg.gemeinde_id = privat.meine_gemeinde());
  end if;

  -- Leitung sieht alles; Veranstaltungsleitung und wer es angelegt hat, sieht die eigene
  if privat.ist_leitung() or e.leitung_id = ich or e.erstellt_von = ich then return true; end if;

  -- Wer eine Aufgabe hat, sieht die Veranstaltung automatisch
  if exists (select 1 from public.aufgaben a where a.veranstaltung_id = v and a.person_id = ich) then
    return true;
  end if;

  -- Technik sieht „Nur Technik“ und alles mit Technik-Anfrage
  if privat.ist_technik() and (e.sichtbarkeit = 'technik'
      or exists (select 1 from public.technik_anfragen t where t.veranstaltung_id = v)) then
    return true;
  end if;

  -- „Helfende gesucht“: für alle sichtbar, bis voll; danach nur noch für Eingetragene
  if e.helfende_gesucht is not null then
    return exists (select 1 from public.helfende h where h.veranstaltung_id = v and h.person_id = ich)
        or (select count(*) from public.helfende h where h.veranstaltung_id = v) < e.helfende_gesucht;
  end if;

  return e.sichtbarkeit = 'alle'
      or (e.sichtbarkeit = 'eingeladene' and exists (
            select 1 from public.veranstaltung_eingeladene ei
            where ei.veranstaltung_id = v and ei.person_id = ich));
end $$;

-- Verwalten = Leitung oder Veranstaltungsleitung
create function privat.darf_verwalten(v uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select privat.ist_leitung()
      or exists (select 1 from public.veranstaltungen e where e.id = v and e.leitung_id = privat.ich())
$$;

-- Ort und Zeitplan: zusätzlich die Technik, wenn es eine Technik-Anfrage gibt
create function privat.darf_zeitplan(v uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select privat.darf_verwalten(v)
      or (privat.ist_technik() and exists (select 1 from public.technik_anfragen t where t.veranstaltung_id = v))
$$;

-- Beteiligt (darf Technik anfragen): verwaltet, angelegt, hat eine Aufgabe, ist Technik oder eingeladene Gemeinde
create function privat.ist_beteiligt(v uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select privat.darf_verwalten(v)
      or privat.ist_technik()
      or exists (select 1 from public.veranstaltungen e where e.id = v and e.erstellt_von = privat.ich())
      or exists (select 1 from public.aufgaben a where a.veranstaltung_id = v
                 and (a.person_id = privat.ich() or a.gemeinde_id = privat.meine_gemeinde()))
      or exists (select 1 from public.veranstaltung_gemeinden vg
                 where vg.veranstaltung_id = v and vg.gemeinde_id = privat.meine_gemeinde())
$$;

-- Leitet mindestens eine Veranstaltung (darf dann neue Gast-Gemeinden anlegen)
create function privat.leitet_eine_veranstaltung() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.veranstaltungen e where e.leitung_id = privat.ich())
$$;

-- Kontaktdaten der Ansprechperson: Leitung, Technik, wer die Anfrage eingetragen hat, Veranstaltungsleitung
create function privat.darf_kontakt_sehen(v uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select privat.technik_oder_leitung()
      or exists (select 1 from public.veranstaltungen e where e.id = v
                 and privat.ich() in (e.erstellt_von, e.leitung_id))
$$;

-- Konzept sehen: alle Personen; Gäste nur, wenn sie zu einer Aufführung eingeladen sind
create function privat.darf_konzept_sehen(k uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select privat.ist_person()
      or exists (select 1 from public.veranstaltungen e
                 join public.veranstaltung_gemeinden vg on vg.veranstaltung_id = e.id
                 where e.konzept_id = k and vg.gemeinde_id = privat.meine_gemeinde())
$$;

-- Gäste sehen nur die Namen von Personen, die in „ihren“ Veranstaltungen vorkommen
create function privat.gast_sieht_person(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  with meine as (
    select vg.veranstaltung_id as v from public.veranstaltung_gemeinden vg
    where vg.gemeinde_id = privat.meine_gemeinde()
  )
  select exists (select 1 from public.veranstaltungen e join meine on meine.v = e.id where e.leitung_id = p)
      or exists (select 1 from public.aufgaben a join meine on meine.v = a.veranstaltung_id where a.person_id = p)
      or exists (select 1 from public.kommentare k join public.aufgaben a on a.id = k.aufgabe_id
                 join meine on meine.v = a.veranstaltung_id where k.person_id = p)
      or exists (select 1 from public.technik_anfragen t join meine on meine.v = t.veranstaltung_id
                 where t.zustaendig_id = p)
      or exists (select 1 from public.technik_vor_ort t join meine on meine.v = t.veranstaltung_id
                 where t.person_id = p)
$$;

revoke all on all functions in schema privat from public;
grant execute on all functions in schema privat to authenticated;

-- ---------------------------------------------------------------------------
-- Grundrechte: anon bekommt nichts. Angemeldete dürfen grundsätzlich lesen/schreiben,
-- die Regeln unten entscheiden pro Zeile. Wo nur bestimmte Spalten änderbar sein sollen,
-- ist das hier eingeschränkt (z. B. kann niemand per App das Login-Konto einer Person umhängen).
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
alter default privileges in schema public revoke all on tables from anon;

revoke insert, update on public.personen from authenticated;
grant insert (id, name, ist_leitung, ist_technik, eingeladen_von) on public.personen to authenticated;
grant update (name, ist_leitung, ist_technik, entfernt_am) on public.personen to authenticated;

revoke insert, update on public.gemeinden from authenticated;
grant insert (id, name, erstellt_von) on public.gemeinden to authenticated;
grant update (name, gesperrt) on public.gemeinden to authenticated;

revoke update on public.veranstaltungen from authenticated;
grant update (titel, datum, art, vorlage_id, ort, sichtbarkeit, leitung_id, konzept_id, nachbesprechung,
              anfrage_von, anfrage_notiz, helfende_gesucht) on public.veranstaltungen to authenticated;

revoke update on public.aufgaben from authenticated;
grant update (titel, beschreibung, person_id, gemeinde_id, faellig_am, erledigt_am) on public.aufgaben to authenticated;

revoke update on public.kommentare from authenticated;
grant update (text) on public.kommentare to authenticated;

revoke update on public.dateien from authenticated;
grant update (titel) on public.dateien to authenticated;

revoke update on public.technik_anfragen from authenticated;
grant update (beschreibung, status, zustaendig_id, ablehnungsgrund) on public.technik_anfragen to authenticated;

revoke update on public.reservierungen from authenticated;
grant update (anzahl, gepackt, raus, zurueck, beschaedigt) on public.reservierungen to authenticated;

revoke update on public.defekte from authenticated;
grant update (beschreibung, foto_pfad, repariert_am, repariert_von) on public.defekte to authenticated;

revoke update on public.inventuren from authenticated;
grant update (abgeschlossen_am, abgeschlossen_von) on public.inventuren to authenticated;

revoke update on public.teile from authenticated;
grant update (name, kategorie, anzahl, lagerort, ist_case, inhalt, notiz, geprueft_am) on public.teile to authenticated;

revoke update on public.konzepte from authenticated;
grant update (name) on public.konzepte to authenticated;

-- Reine Zuordnungen und Verläufe werden nie geändert, nur angelegt oder gelöscht
revoke update on public.veranstaltung_eingeladene, public.veranstaltung_gemeinden, public.helfende,
                 public.technik_vor_ort, public.inventur_pruefungen, public.anfrage_mails,
                 public.leih_protokolle
  from authenticated;

-- Wer etwas anlegt, wird automatisch als Urheber:in eingetragen (die Regeln prüfen es zusätzlich)
alter table public.personen         alter column eingeladen_von         set default privat.ich();
alter table public.gemeinden        alter column erstellt_von           set default privat.ich();
alter table public.konzepte         alter column erstellt_von           set default privat.ich();
alter table public.veranstaltungen  alter column erstellt_von           set default privat.ich();
alter table public.kommentare       alter column person_id              set default privat.ich();
alter table public.kommentare       alter column gemeinde_id            set default privat.meine_gemeinde();
alter table public.dateien          alter column person_id              set default privat.ich();
alter table public.dateien          alter column gemeinde_id            set default privat.meine_gemeinde();
alter table public.helfende         alter column person_id              set default privat.ich();
alter table public.technik_vor_ort  alter column person_id              set default privat.ich();
alter table public.technik_anfragen alter column angefragt_von_person   set default privat.ich();
alter table public.technik_anfragen alter column angefragt_von_gemeinde set default privat.meine_gemeinde();
alter table public.anfrage_mails    alter column person_id              set default privat.ich();
alter table public.teile            alter column erstellt_von           set default privat.ich();
alter table public.defekte          alter column gemeldet_von           set default privat.ich();
alter table public.inventuren       alter column gestartet_von          set default privat.ich();
alter table public.inventur_pruefungen alter column geprueft_von        set default privat.ich();
alter table public.leih_protokolle  alter column erstellt_von           set default privat.ich();

-- ---------------------------------------------------------------------------
-- Regeln pro Tabelle
-- (select …) um die Funktionen sorgt dafür, dass sie pro Anfrage nur einmal laufen.
-- ---------------------------------------------------------------------------

-- Leute ---------------------------------------------------------------------
create policy "Personen: alle Mitglieder sehen Namen und Rollen; Gäste nur Beteiligte"
  on public.personen for select to authenticated
  using ((select privat.ist_person()) or privat.gast_sieht_person(id));
create policy "Personen: nur Leitung lädt ein"
  on public.personen for insert to authenticated
  with check ((select privat.ist_leitung()) and eingeladen_von = (select privat.ich()));
create policy "Personen: nur Leitung ändert Rollen oder entfernt"
  on public.personen for update to authenticated
  using ((select privat.ist_leitung())) with check ((select privat.ist_leitung()));
create policy "Personen: nur offene Einladungen können zurückgezogen werden"
  on public.personen for delete to authenticated
  using ((select privat.ist_leitung()) and auth_user_id is null);

create policy "E-Mails: Leitung und man selbst"
  on public.personen_emails for select to authenticated
  using ((select privat.ist_leitung()) or person_id = (select privat.ich()));
create policy "E-Mails: nur Leitung trägt ein"
  on public.personen_emails for insert to authenticated with check ((select privat.ist_leitung()));
create policy "E-Mails: nur Leitung ändert"
  on public.personen_emails for update to authenticated
  using ((select privat.ist_leitung())) with check ((select privat.ist_leitung()));
create policy "E-Mails: nur Leitung löscht"
  on public.personen_emails for delete to authenticated using ((select privat.ist_leitung()));

-- Gemeinden -----------------------------------------------------------------
create policy "Gemeinden: Mitglieder sehen alle, Gast nur die eigene"
  on public.gemeinden for select to authenticated
  using ((select privat.ist_person()) or id = (select privat.meine_gemeinde()));
create policy "Gemeinden: Leitung oder Veranstaltungsleitung legt neue an"
  on public.gemeinden for insert to authenticated
  with check (erstellt_von = (select privat.ich())
              and ((select privat.ist_leitung()) or (select privat.leitet_eine_veranstaltung())));
create policy "Gemeinden: nur Leitung sperrt oder benennt um"
  on public.gemeinden for update to authenticated
  using ((select privat.ist_leitung())) with check ((select privat.ist_leitung()));
create policy "Gemeinden: nur Leitung löscht"
  on public.gemeinden for delete to authenticated using ((select privat.ist_leitung()));

create policy "Eingeladene Gemeinden: sieht, wer die Veranstaltung sieht"
  on public.veranstaltung_gemeinden for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Eingeladene Gemeinden: Verwaltende laden ein"
  on public.veranstaltung_gemeinden for insert to authenticated with check (privat.darf_verwalten(veranstaltung_id));
create policy "Eingeladene Gemeinden: Verwaltende laden aus"
  on public.veranstaltung_gemeinden for delete to authenticated using (privat.darf_verwalten(veranstaltung_id));

-- Vorlagen & Konzepte -------------------------------------------------------
create policy "Vorlagen: alle Mitglieder sehen" on public.vorlagen for select to authenticated
  using ((select privat.ist_person()));
create policy "Vorlagen: Leitung legt an" on public.vorlagen for insert to authenticated
  with check ((select privat.ist_leitung()));
create policy "Vorlagen: Leitung ändert" on public.vorlagen for update to authenticated
  using ((select privat.ist_leitung())) with check ((select privat.ist_leitung()));
create policy "Vorlagen: Leitung löscht" on public.vorlagen for delete to authenticated
  using ((select privat.ist_leitung()));

create policy "Vorlage-Aufgaben: alle Mitglieder sehen" on public.vorlage_aufgaben for select to authenticated
  using ((select privat.ist_person()));
create policy "Vorlage-Aufgaben: Leitung legt an" on public.vorlage_aufgaben for insert to authenticated
  with check ((select privat.ist_leitung()));
create policy "Vorlage-Aufgaben: Leitung ändert" on public.vorlage_aufgaben for update to authenticated
  using ((select privat.ist_leitung())) with check ((select privat.ist_leitung()));
create policy "Vorlage-Aufgaben: Leitung löscht" on public.vorlage_aufgaben for delete to authenticated
  using ((select privat.ist_leitung()));

create policy "Konzepte: Mitglieder sehen alle, Gäste nur ihre"
  on public.konzepte for select to authenticated using (privat.darf_konzept_sehen(id));
create policy "Konzepte: Mitglieder legen an (z. B. beim „Nochmal aufführen“)"
  on public.konzepte for insert to authenticated
  with check ((select privat.ist_person()) and erstellt_von = (select privat.ich()));
create policy "Konzepte: Leitung oder wer es angelegt hat, benennt um"
  on public.konzepte for update to authenticated
  using ((select privat.ist_leitung()) or erstellt_von = (select privat.ich()))
  with check ((select privat.ist_leitung()) or erstellt_von = (select privat.ich()));
create policy "Konzepte: nur Leitung löscht"
  on public.konzepte for delete to authenticated using ((select privat.ist_leitung()));

-- Veranstaltungen -----------------------------------------------------------
create policy "Veranstaltungen: sehen nach Rolle, Sichtbarkeit und Beteiligung"
  on public.veranstaltungen for select to authenticated using (privat.darf_sehen(id));
create policy "Veranstaltungen: Mitglieder legen an"
  on public.veranstaltungen for insert to authenticated
  with check ((select privat.ist_person()) and erstellt_von = (select privat.ich()));
create policy "Veranstaltungen: Verwaltende ändern (Technik nur den Ort)"
  on public.veranstaltungen for update to authenticated
  using (privat.darf_zeitplan(id))
  with check (true); -- Spalten schützt der Trigger „veranstaltung_pruefen“; so kann die Leitung auch abgegeben werden
create policy "Veranstaltungen: Verwaltende löschen"
  on public.veranstaltungen for delete to authenticated using (privat.darf_verwalten(id));

create policy "Eingeladene: sieht, wer die Veranstaltung sieht"
  on public.veranstaltung_eingeladene for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Eingeladene: Verwaltende laden ein"
  on public.veranstaltung_eingeladene for insert to authenticated with check (privat.darf_verwalten(veranstaltung_id));
create policy "Eingeladene: Verwaltende laden aus"
  on public.veranstaltung_eingeladene for delete to authenticated using (privat.darf_verwalten(veranstaltung_id));

create policy "Zeitplan: sieht, wer die Veranstaltung sieht"
  on public.zeitplan_punkte for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Zeitplan: Verwaltende und Technik legen an"
  on public.zeitplan_punkte for insert to authenticated with check (privat.darf_zeitplan(veranstaltung_id));
create policy "Zeitplan: Verwaltende und Technik ändern"
  on public.zeitplan_punkte for update to authenticated
  using (privat.darf_zeitplan(veranstaltung_id)) with check (privat.darf_zeitplan(veranstaltung_id));
create policy "Zeitplan: Verwaltende und Technik löschen"
  on public.zeitplan_punkte for delete to authenticated using (privat.darf_zeitplan(veranstaltung_id));

-- Aufgaben & Kommentare -----------------------------------------------------
create policy "Aufgaben: sieht, wer die Veranstaltung sieht"
  on public.aufgaben for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Aufgaben: Verwaltende legen an"
  on public.aufgaben for insert to authenticated with check (privat.darf_verwalten(veranstaltung_id));
create policy "Aufgaben: Verwaltende ändern alles, sonst nur eigene oder freie übernehmen"
  on public.aufgaben for update to authenticated
  using (privat.darf_verwalten(veranstaltung_id)
         or person_id = (select privat.ich())
         or gemeinde_id = (select privat.meine_gemeinde())
         or (person_id is null and gemeinde_id is null and privat.darf_sehen(veranstaltung_id)))
  with check (true); -- was genau geändert werden darf, prüft der Trigger „aufgabe_pruefen“
create policy "Aufgaben: Verwaltende löschen"
  on public.aufgaben for delete to authenticated using (privat.darf_verwalten(veranstaltung_id));

create policy "Kommentare: sieht, wer die Aufgabe sieht"
  on public.kommentare for select to authenticated
  using (exists (select 1 from public.aufgaben a where a.id = aufgabe_id and privat.darf_sehen(a.veranstaltung_id)));
create policy "Kommentare: schreibt, wer die Aufgabe sieht, unter eigenem Namen"
  on public.kommentare for insert to authenticated
  with check (exists (select 1 from public.aufgaben a where a.id = aufgabe_id and privat.darf_sehen(a.veranstaltung_id))
              and ((person_id = (select privat.ich()) and gemeinde_id is null)
                or (gemeinde_id = (select privat.meine_gemeinde()) and person_id is null)));
create policy "Kommentare: nur eigene bearbeiten"
  on public.kommentare for update to authenticated
  using (person_id = (select privat.ich()) or gemeinde_id = (select privat.meine_gemeinde()))
  with check (person_id = (select privat.ich()) or gemeinde_id = (select privat.meine_gemeinde()));
create policy "Kommentare: eigene löschen, Verwaltende alle"
  on public.kommentare for delete to authenticated
  using (person_id = (select privat.ich()) or gemeinde_id = (select privat.meine_gemeinde())
         or exists (select 1 from public.aufgaben a where a.id = aufgabe_id and privat.darf_verwalten(a.veranstaltung_id)));

-- Dateien -------------------------------------------------------------------
create policy "Dateien: an Veranstaltung, Konzept oder in der Bibliothek, je nach Sichtbarkeit"
  on public.dateien for select to authenticated
  using (case when veranstaltung_id is not null then privat.darf_sehen(veranstaltung_id)
              when konzept_id is not null then privat.darf_konzept_sehen(konzept_id)
              else (select privat.ist_person()) end);
create policy "Dateien: hinzufügen, wer sie sehen darf (Gäste nur an Veranstaltungen)"
  on public.dateien for insert to authenticated
  with check (((person_id = (select privat.ich()) and gemeinde_id is null)
                or (gemeinde_id = (select privat.meine_gemeinde()) and person_id is null and veranstaltung_id is not null))
              and case when veranstaltung_id is not null then privat.darf_sehen(veranstaltung_id)
                       when konzept_id is not null then (select privat.ist_person())
                       else (select privat.ist_person()) end);
create policy "Dateien: umbenennen durch Hochladende oder Leitung"
  on public.dateien for update to authenticated
  using (person_id = (select privat.ich()) or gemeinde_id = (select privat.meine_gemeinde()) or (select privat.ist_leitung()))
  with check (true);
create policy "Dateien: löschen durch Hochladende, Verwaltende oder Leitung"
  on public.dateien for delete to authenticated
  using (person_id = (select privat.ich()) or gemeinde_id = (select privat.meine_gemeinde()) or (select privat.ist_leitung())
         or (veranstaltung_id is not null and privat.darf_verwalten(veranstaltung_id)));

-- Anfragen & Helfende -------------------------------------------------------
create policy "Ansprechperson: Technik, Leitung, Eintragende und Veranstaltungsleitung sehen"
  on public.ansprechpersonen for select to authenticated using (privat.darf_kontakt_sehen(veranstaltung_id));
create policy "Ansprechperson: dieselben tragen ein"
  on public.ansprechpersonen for insert to authenticated with check (privat.darf_kontakt_sehen(veranstaltung_id));
create policy "Ansprechperson: dieselben ändern"
  on public.ansprechpersonen for update to authenticated
  using (privat.darf_kontakt_sehen(veranstaltung_id)) with check (privat.darf_kontakt_sehen(veranstaltung_id));
create policy "Ansprechperson: dieselben löschen"
  on public.ansprechpersonen for delete to authenticated using (privat.darf_kontakt_sehen(veranstaltung_id));

create policy "Helfende: sieht, wer die Veranstaltung sieht"
  on public.helfende for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Helfende: Mitglieder tragen sich selbst ein"
  on public.helfende for insert to authenticated
  with check (person_id = (select privat.ich()) and privat.darf_sehen(veranstaltung_id));
create policy "Helfende: selbst austragen, Verwaltende können austragen"
  on public.helfende for delete to authenticated
  using (person_id = (select privat.ich()) or privat.darf_verwalten(veranstaltung_id));

-- Technik-Ablauf ------------------------------------------------------------
create policy "Technik-Anfrage: Status sieht, wer die Veranstaltung sieht"
  on public.technik_anfragen for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Technik-Anfrage: Beteiligte fragen an, Technik übernimmt selbst"
  on public.technik_anfragen for insert to authenticated
  with check (privat.darf_sehen(veranstaltung_id) and privat.ist_beteiligt(veranstaltung_id)
              and ((status = 'angefragt'
                    and ((angefragt_von_person = (select privat.ich()) and angefragt_von_gemeinde is null)
                      or (angefragt_von_gemeinde = (select privat.meine_gemeinde()) and angefragt_von_person is null)))
                or ((select privat.ist_technik()) and status = 'angenommen'
                    and zustaendig_id = (select privat.ich()) and angefragt_von_person = (select privat.ich()))));
create policy "Technik-Anfrage: Technik und Leitung bearbeiten (annehmen, planen, ablehnen)"
  on public.technik_anfragen for update to authenticated
  using ((select privat.technik_oder_leitung())) with check ((select privat.technik_oder_leitung()));
create policy "Technik-Anfrage: Technik und Leitung löschen"
  on public.technik_anfragen for delete to authenticated using ((select privat.technik_oder_leitung()));

create policy "Vor Ort: sieht, wer die Veranstaltung sieht"
  on public.technik_vor_ort for select to authenticated using (privat.darf_sehen(veranstaltung_id));
create policy "Vor Ort: Technik trägt sich selbst ein, Leitung trägt Technik ein"
  on public.technik_vor_ort for insert to authenticated
  with check (((select privat.ist_technik()) and person_id = (select privat.ich())) or (select privat.ist_leitung()));
create policy "Vor Ort: selbst austragen oder Leitung"
  on public.technik_vor_ort for delete to authenticated
  using (person_id = (select privat.ich()) or (select privat.ist_leitung()));

create policy "Anfrage-Mails: Technik und Leitung sehen"
  on public.anfrage_mails for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Anfrage-Mails: Technik und Leitung tragen ein"
  on public.anfrage_mails for insert to authenticated
  with check ((select privat.technik_oder_leitung()) and person_id = (select privat.ich()));

create policy "Reservierungen: Technik und Leitung sehen"
  on public.reservierungen for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Reservierungen: Technik und Leitung planen"
  on public.reservierungen for insert to authenticated with check ((select privat.technik_oder_leitung()));
create policy "Reservierungen: Technik und Leitung ändern (Packliste, Raus, Zurück)"
  on public.reservierungen for update to authenticated
  using ((select privat.technik_oder_leitung())) with check ((select privat.technik_oder_leitung()));
create policy "Reservierungen: Technik und Leitung entfernen"
  on public.reservierungen for delete to authenticated using ((select privat.technik_oder_leitung()));

create policy "Leih-Protokolle: Technik und Leitung sehen"
  on public.leih_protokolle for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Leih-Protokolle: Technik und Leitung legen an"
  on public.leih_protokolle for insert to authenticated
  with check ((select privat.technik_oder_leitung()) and erstellt_von = (select privat.ich()));
create policy "Leih-Protokolle: nur Leitung löscht"
  on public.leih_protokolle for delete to authenticated using ((select privat.ist_leitung()));

-- Technik-Bestand -----------------------------------------------------------
create policy "Bestand: Technik und Leitung sehen"
  on public.teile for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Bestand: Technik und Leitung legen an"
  on public.teile for insert to authenticated with check ((select privat.technik_oder_leitung()));
create policy "Bestand: Technik und Leitung bearbeiten"
  on public.teile for update to authenticated
  using ((select privat.technik_oder_leitung())) with check ((select privat.technik_oder_leitung()));
create policy "Bestand: nur Leitung löscht"
  on public.teile for delete to authenticated using ((select privat.ist_leitung()));

create policy "Defekte: Technik und Leitung sehen"
  on public.defekte for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Defekte: Technik und Leitung melden"
  on public.defekte for insert to authenticated
  with check ((select privat.technik_oder_leitung()) and gemeldet_von = (select privat.ich()));
create policy "Defekte: Technik und Leitung bearbeiten (z. B. repariert)"
  on public.defekte for update to authenticated
  using ((select privat.technik_oder_leitung())) with check ((select privat.technik_oder_leitung()));
create policy "Defekte: nur Leitung löscht"
  on public.defekte for delete to authenticated using ((select privat.ist_leitung()));

create policy "Inventur: Technik und Leitung sehen"
  on public.inventuren for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Inventur: Technik und Leitung starten"
  on public.inventuren for insert to authenticated with check ((select privat.technik_oder_leitung()));
create policy "Inventur: Technik und Leitung schließen ab"
  on public.inventuren for update to authenticated
  using ((select privat.technik_oder_leitung())) with check ((select privat.technik_oder_leitung()));
create policy "Inventur: laufende abbrechen (Technik), abgeschlossene löschen (nur Leitung)"
  on public.inventuren for delete to authenticated
  using ((select privat.ist_leitung()) or ((select privat.ist_technik()) and abgeschlossen_am is null));

create policy "Inventur-Prüfungen: Technik und Leitung sehen"
  on public.inventur_pruefungen for select to authenticated using ((select privat.technik_oder_leitung()));
create policy "Inventur-Prüfungen: Technik und Leitung haken ab"
  on public.inventur_pruefungen for insert to authenticated with check ((select privat.technik_oder_leitung()));
create policy "Inventur-Prüfungen: Technik und Leitung nehmen Haken weg"
  on public.inventur_pruefungen for delete to authenticated using ((select privat.technik_oder_leitung()));

-- ---------------------------------------------------------------------------
-- Schutz-Regeln, die über „wer darf“ hinausgehen (Trigger)
-- Meldungen sind auf Deutsch, damit die App sie direkt anzeigen kann.
-- ---------------------------------------------------------------------------

-- Niemand entfernt sich selbst
create function privat.selbst_entfernen_verhindern() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.id = privat.ich() and new.entfernt_am is not null and old.entfernt_am is null then
    raise exception 'Du kannst dich nicht selbst entfernen.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger selbst_entfernen_verhindern
  before update of entfernt_am on public.personen
  for each row execute function privat.selbst_entfernen_verhindern();

-- Immer mindestens eine Leitung (geprüft am Ende der Änderung, damit ein Wechsel in einem Schritt geht)
create function privat.personen_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.personen)
     and not exists (select 1 from public.personen where ist_leitung and entfernt_am is null) then
    raise exception 'Es muss immer mindestens eine Leitung geben.' using errcode = 'P0001';
  end if;
  return null;
end $$;
create constraint trigger mindestens_eine_leitung
  after update or delete on public.personen
  deferrable initially deferred
  for each row execute function privat.personen_pruefen();

-- Beim Entfernen: offene Aufgaben werden frei, Einsätze ausgetragen, künftige Leitungen übernimmt
-- die entfernende Leitung, angenommene Technik-Anfragen gehen zurück an alle Techniker.
create function privat.person_entfernt() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.aufgaben set person_id = null where person_id = new.id and erledigt_am is null;
  delete from public.technik_vor_ort t using public.veranstaltungen e
    where t.veranstaltung_id = e.id and t.person_id = new.id and e.datum >= current_date;
  delete from public.helfende h using public.veranstaltungen e
    where h.veranstaltung_id = e.id and h.person_id = new.id and e.datum >= current_date;
  delete from public.veranstaltung_eingeladene where person_id = new.id;
  update public.veranstaltungen set leitung_id = privat.ich()
    where leitung_id = new.id and datum >= current_date;
  update public.technik_anfragen t set status = 'angefragt', zustaendig_id = null
    from public.veranstaltungen e
    where t.veranstaltung_id = e.id and t.zustaendig_id = new.id and t.status = 'angenommen' and e.datum >= current_date;
  update public.technik_anfragen t set zustaendig_id = null
    from public.veranstaltungen e
    where t.veranstaltung_id = e.id and t.zustaendig_id = new.id and e.datum >= current_date;
  return null;
end $$;
create trigger person_entfernt
  after update of entfernt_am on public.personen
  for each row when (old.entfernt_am is null and new.entfernt_am is not null)
  execute function privat.person_entfernt();

-- Veranstaltung: Technik (ohne Verwaltungsrecht) darf nur den Ort ändern
create function privat.veranstaltung_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not privat.darf_verwalten(old.id)
     and (to_jsonb(new) - 'ort') is distinct from (to_jsonb(old) - 'ort') then
    raise exception 'Du darfst bei dieser Veranstaltung nur Ort und Zeitplan ändern.' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger veranstaltung_pruefen
  before update on public.veranstaltungen
  for each row execute function privat.veranstaltung_pruefen();

-- Aufgaben: Wer nicht verwaltet, darf nur freie Aufgaben übernehmen, eigene abgeben und eigene abhaken.
-- Zuständige Gemeinde muss eingeladen sein, zuständige Person darf nicht entfernt sein.
create function privat.aufgabe_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  ich  uuid := privat.ich();
  gast uuid := privat.meine_gemeinde();
begin
  if tg_op = 'UPDATE' and new.veranstaltung_id is distinct from old.veranstaltung_id then
    raise exception 'Eine Aufgabe kann nicht in eine andere Veranstaltung verschoben werden.' using errcode = '42501';
  end if;

  if new.gemeinde_id is not null and (tg_op = 'INSERT' or new.gemeinde_id is distinct from old.gemeinde_id)
     and not exists (
      select 1 from public.veranstaltung_gemeinden vg
      where vg.veranstaltung_id = new.veranstaltung_id and vg.gemeinde_id = new.gemeinde_id) then
    raise exception 'Die Gemeinde ist zu dieser Veranstaltung nicht eingeladen.' using errcode = 'P0001';
  end if;
  if new.person_id is not null and (tg_op = 'INSERT' or new.person_id is distinct from old.person_id)
     and exists (select 1 from public.personen p where p.id = new.person_id and p.entfernt_am is not null) then
    raise exception 'Diese Person ist nicht mehr dabei.' using errcode = 'P0001';
  end if;

  if tg_op = 'INSERT' or auth.uid() is null or privat.darf_verwalten(new.veranstaltung_id) then
    return new;
  end if;

  if (new.titel, new.beschreibung, new.faellig_am) is distinct from (old.titel, old.beschreibung, old.faellig_am) then
    raise exception 'Titel, Beschreibung und Deadline ändert die Veranstaltungsleitung.' using errcode = '42501';
  end if;
  if (new.person_id, new.gemeinde_id) is distinct from (old.person_id, old.gemeinde_id) then
    -- erlaubt: freie Aufgabe selbst übernehmen, oder eigene Aufgabe wieder abgeben
    if not ((old.person_id is null and old.gemeinde_id is null
             and ((new.person_id = ich and new.gemeinde_id is null) or (new.gemeinde_id = gast and new.person_id is null)))
         or ((old.person_id = ich or old.gemeinde_id = gast) and new.person_id is null and new.gemeinde_id is null)) then
      raise exception 'Du kannst nur freie Aufgaben übernehmen oder deine eigenen abgeben.' using errcode = '42501';
    end if;
  end if;
  if new.erledigt_am is distinct from old.erledigt_am
     and not (new.person_id = ich or new.gemeinde_id = gast) then
    raise exception 'Abhaken kann nur, wer zuständig ist.' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger aufgabe_pruefen
  before insert or update on public.aufgaben
  for each row execute function privat.aufgabe_pruefen();

-- Gemeinde ausgeladen: ihre offenen Aufgaben dort werden wieder frei
create function privat.gemeinde_ausgeladen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.aufgaben set gemeinde_id = null
    where veranstaltung_id = old.veranstaltung_id and gemeinde_id = old.gemeinde_id and erledigt_am is null;
  return null;
end $$;
create trigger gemeinde_ausgeladen
  after delete on public.veranstaltung_gemeinden
  for each row execute function privat.gemeinde_ausgeladen();

-- Helfende: nur bei Helfenden-Suche, nicht mehr als gebraucht, nur aktive Personen
create function privat.helfende_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  gesucht int;
begin
  -- Zeile sperren, damit sich zwei Leute nicht gleichzeitig auf den letzten Platz eintragen
  select helfende_gesucht into gesucht from public.veranstaltungen where id = new.veranstaltung_id for update;
  if gesucht is null then
    raise exception 'Für diese Veranstaltung werden keine Helfenden gesucht.' using errcode = 'P0001';
  end if;
  if (select count(*) from public.helfende where veranstaltung_id = new.veranstaltung_id) >= gesucht then
    raise exception 'Es sind schon genug Leute eingetragen.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger helfende_pruefen
  before insert on public.helfende
  for each row execute function privat.helfende_pruefen();

-- Technik vor Ort: nur Personen mit Rolle Technik
create function privat.vor_ort_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.personen p where p.id = new.person_id and p.ist_technik and p.entfernt_am is null) then
    raise exception 'Vor Ort eintragen kann man nur Leute aus der Technik.' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger vor_ort_pruefen
  before insert on public.technik_vor_ort
  for each row execute function privat.vor_ort_pruefen();

-- Technik-Anfrage: „Geplant“ erst mit mindestens einem Techniker vor Ort; Zuständige:r muss Technik sein;
-- bei „Abgelehnt“ wird die geplante Technik wieder freigegeben.
create function privat.technik_anfrage_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'geplant' and (tg_op = 'INSERT' or old.status <> 'geplant')
     and not exists (select 1 from public.technik_vor_ort t where t.veranstaltung_id = new.veranstaltung_id) then
    raise exception 'Mindestens ein Techniker muss vor Ort eingetragen sein.' using errcode = 'P0001';
  end if;
  if new.zustaendig_id is not null and (tg_op = 'INSERT' or new.zustaendig_id is distinct from old.zustaendig_id)
     and not exists (select 1 from public.personen p where p.id = new.zustaendig_id and p.ist_technik and p.entfernt_am is null) then
    raise exception 'Zuständig kann nur jemand aus der Technik sein.' using errcode = 'P0001';
  end if;
  if new.status = 'abgelehnt' and tg_op = 'UPDATE' and old.status <> 'abgelehnt' then
    delete from public.reservierungen where veranstaltung_id = new.veranstaltung_id;
  end if;
  if tg_op = 'UPDATE' then new.geaendert_am := now(); end if;
  return new;
end $$;
create trigger technik_anfrage_pruefen
  before insert or update on public.technik_anfragen
  for each row execute function privat.technik_anfrage_pruefen();

-- Reservierung: nicht mehr als am Tag frei ist (Bestand minus offene Defekte minus andere
-- Veranstaltungen am selben Tag, abgelehnte Anfragen zählen nicht)
create function privat.reservierung_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  teil   public.teile;
  tag    date;
  defekt int;
  belegt int;
begin
  if tg_op = 'UPDATE' and new.anzahl <= old.anzahl then return new; end if;
  -- Teil sperren, damit zwei Techniker nicht gleichzeitig das letzte Stück verplanen
  select * into teil from public.teile where id = new.teil_id for update;
  select datum into tag from public.veranstaltungen where id = new.veranstaltung_id;
  select count(*) into defekt from public.defekte where teil_id = new.teil_id and repariert_am is null;
  select coalesce(sum(r.anzahl), 0) into belegt
    from public.reservierungen r
    join public.veranstaltungen e on e.id = r.veranstaltung_id
    left join public.technik_anfragen t on t.veranstaltung_id = e.id
    where r.teil_id = new.teil_id and e.datum = tag and r.veranstaltung_id <> new.veranstaltung_id
      and coalesce(t.status, '') <> 'abgelehnt';
  if new.anzahl > teil.anzahl - defekt - belegt then
    raise exception 'Nicht genug frei: % ist am % nur noch %× verfügbar.',
      teil.name, to_char(tag, 'DD.MM.YYYY'), greatest(teil.anzahl - defekt - belegt, 0) using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger reservierung_pruefen
  before insert or update of anzahl on public.reservierungen
  for each row execute function privat.reservierung_pruefen();

-- Defekte: nicht mehr offene Defekte als Stück vorhanden
create function privat.defekt_pruefen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.repariert_am is null and (tg_op = 'INSERT' or old.repariert_am is not null) then
    perform 1 from public.teile where id = new.teil_id for update;
    if (select count(*) from public.defekte where teil_id = new.teil_id and repariert_am is null and id <> new.id)
       >= (select anzahl from public.teile where id = new.teil_id) then
      raise exception 'Alle Stücke sind schon als defekt gemeldet.' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
create trigger defekt_pruefen
  before insert or update of repariert_am on public.defekte
  for each row execute function privat.defekt_pruefen();

-- Inventur abgeschlossen: Prüfdatum bei jedem abgehakten Teil eintragen
create function privat.inventur_abgeschlossen() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.teile t set geprueft_am = (p.geprueft_am at time zone 'Europe/Berlin')::date
    from public.inventur_pruefungen p
    where p.inventur_id = new.id and p.teil_id = t.id;
  return null;
end $$;
create trigger inventur_abgeschlossen
  after update of abgeschlossen_am on public.inventuren
  for each row when (old.abgeschlossen_am is null and new.abgeschlossen_am is not null)
  execute function privat.inventur_abgeschlossen();

-- Trigger-Funktionen sind keine Schnittstelle
revoke execute on function privat.personen_pruefen(), privat.selbst_entfernen_verhindern(), privat.person_entfernt(), privat.veranstaltung_pruefen(),
  privat.aufgabe_pruefen(), privat.gemeinde_ausgeladen(), privat.helfende_pruefen(), privat.vor_ort_pruefen(),
  privat.technik_anfrage_pruefen(), privat.reservierung_pruefen(), privat.defekt_pruefen(),
  privat.inventur_abgeschlossen()
  from authenticated;
