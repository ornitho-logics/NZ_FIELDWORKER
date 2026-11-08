<!-- English-source-md5: 9defd4aa587832c9447b862e39ef16aa -->

# Banded Dotterel / Pohowera — Kurzleitfaden für das Kernteam

**Kurzleitfaden für das Kernteam · Ausgabe 2 · 3. November 2026**

Für erfahrene Teammitglieder, die nach den genehmigten Erlaubnissen,
der praktischen Einweisung, und den Vorgaben für ihren Studienort arbeiten.
Dieser Leitfaden fasst das [vollständige Protokollhandbuch](manual-de.md)
zusammen. Die vollständigen Anforderungen und Ausnahmen stehen in den
verlinkten Verfahren. Bei Unklarheiten die tatsächliche Beobachtung
wahrheitsgetreu festhalten und das betreffende Verfahren nachlesen oder
Luke Eberhart-Hertel fragen.

## Inhalt

- [1. Vor dem Aufbruch](#core-section-1)
- [2. Den tatsächlichen Vorgang dokumentieren](#core-section-2)
- [3. Familienbeobachtungen richtig verknüpfen](#core-section-3)
- [4. Nestbesuche und Eier](#core-section-4)
- [5. Handling, Markierung, und Fotos](#core-section-5)
- [6. Fang- und Geolocator-Beschränkungen](#core-section-6)
- [7. Nachkontrollen und Tagesabschluss](#core-section-7)

<a id="core-section-1"></a>

## 1. Vor dem Aufbruch

- Das **Referenzdatum** des To-Do-PDFs, die Teamzuteilung, und die offenen
  Arbeiten vom Vortag prüfen. Eine fehlende Aufgabe beweist nicht, dass sie
  erledigt ist.
- Fangbeschränkungen vor der Fangplanung prüfen. Die zugeteilten Metallringe,
  Farbringe, und Flaggen mitnehmen; Garmin-/Kamera-IDs, Akkus, und die
  neuseeländische Uhrzeit kontrollieren.
- `BADO` und den genehmigten Gebietscode verwenden. Die Cass-River-Vorgaben
  für Nest-IDs, Markierungen, und Geolocatoren gelten nicht automatisch anderswo.

<a id="core-section-2"></a>

## 2. Den tatsächlichen Vorgang dokumentieren

| Was ist passiert? | Eintrag |
|---|---|
| Nest oder Nestmulde besucht | Eine `NESTS`-Zeile pro tatsächlichem Besuch. |
| Eier vermessen | Eine `EGGS`-Zeile pro vermessenem Ei. |
| Vogel gehandhabt | Eine `CAPTURES`-Zeile pro Vogel und Handling-Vorgang. |
| Vogel beobachtet | Eine `RESIGHTINGS`-Zeile pro Vogel und Beobachtung. |
| Küken im Versteck fotografiert | Eine eigene `RESIGHTINGS`-Zeile pro Küken mit `rclass = H`, zusätzlich zu einem etwaigen Fangdatensatz. |

Keine Sichtung erfinden, nur weil ein Vogel gefangen wurde. Eine echte
Beobachtung vor dem Handling darf separat eingetragen werden. Auch
Geschwister mit demselben Farbring benötigen eigene Datensätze.

**Kommentare ergänzen Ereignisse; sie ersetzen sie nicht.** Der To-Do-Algorithmus
liest Freitextkommentare nicht als Ersatz für die erforderlichen
Ereignisdatensätze. Eine ausschließlich im Kommentar eingetragene Beobachtung
wird deshalb als Nachweis für die entsprechende Aufgabenentscheidung
übergangen. Fehlende Ereignisse können Elternzuordnungen offen lassen oder
den Arbeitsplan unvollständig oder irreführend machen.

Die Identität eines Vogels in `NESTS.comments` ist beispielsweise keine
Wiederbeobachtung. Der Nestbesuch gehört in `NESTS`; der beobachtete Vogel
gehört separat in `RESIGHTINGS`, mit seinen tatsächlichen Markierungen,
Geschlecht, Verhalten, Nest-ID, und den weiteren erforderlichen Angaben.
`behav = IN` nur verwenden, wenn der Vogel tatsächlich inkubiert hat.
`bird_inc` hält Anwesenheit/Geschlecht fest, nicht die individuelle Identität,
und ersetzt die Wiederbeobachtung ebenfalls nicht. Das gilt für jeden Vorgang
mit vorgeschriebenem eigenem Datensatz: in das richtige Formular eintragen,
nicht nur in den Kommentar einer anderen Zeile.

**Die richtige ID behalten.** Die positive ID eines bekannten Nests bleibt
bei seiner mobilen Brut. Eine negative ID bedeutet, dass Nest/Ursprung nie
gefunden wurden: Minuszeichen beibehalten und nur in Vogeltabellen verwenden,
nie in `NESTS` oder `EGGS`. Unsichere Identität rechtfertigt keine erfundene
negative ID. Eindeutig nestunabhängige Altvogelfänge haben eine leere `nest_id`
und beide GPS-Felder; niemals `NO_NEST` eintragen.

**Leere Felder haben eine Bedeutung.** Null ist eine beobachtete Anzahl oder
ein zutreffendes „Nein“, nicht „unbekannt“. `X` bedeutet ein beobachtetes leeres
Ringsegment; `?` bedeutet bei Wiederbeobachtungen unleserliche Markierungen,
nicht ein leeres Segment. In den Beinmarkierungsfeldern von Fängen darf kein
`?` stehen.

[Datensatz- und ID-Regeln](manual-de.md#section-2)

<a id="core-section-3"></a>

## 3. Familienbeobachtungen richtig verknüpfen

Bei der Begegnung einen Wegpunkt aufnehmen und **beide** Werte notieren:
`gps_id` und `gps_point`. Eltern- und Kükeneinträge derselben Familienbegegnung
müssen bei Datum, Gebiet, und gemeinsamem GPS-Paar übereinstimmen. Bei einer
späteren Begegnung an einem anderen Ort einen neuen Wegpunkt aufnehmen.

- Erster Nestbesuch: GPS eintragen. Spätere Besuche am ortsfesten Nest: beide
  GPS-Felder leer lassen.
- Vogeleinträge mit negativer ID, jede neue H-Fotozeile, und Wiederfänge der
  Altersklasse C mit Status R oder C benötigen beide GPS-Felder, auch bei
  bekannter positiver ID.
- Altvogelfänge mit Küken benötigen das GPS-Paar und den tatsächlichen
  `caught_with`-Eintrag. Erste Kükeneinfänge benötigen die tatsächliche
  positive oder negative ID.
- Andere Vorgänge an positiven Nestern haben genaue GPS-/Leerfeld-Ausnahmen:
  die [GPS-Anforderungen](manual-de.md#section-3) beachten, statt pauschal jedes
  Feld auszufüllen.

Jeden tatsächlich beobachteten Elternvogel eintragen, auch einen unberingten
als **X-X** (`LL = X`, `LR = X`). Keinen abwesenden Partner erfinden. Das
tatsächlich beobachtete Verhalten verwenden: **AT ist nicht AC**. `BC`, `FC`,
und `AC` beschreiben Kükenbetreuung; `IN`, `NM`, `SC`, und `BW` können ebenfalls
eine Nestzuordnung bestätigen, aber BW allein belegt keine beobachteten
Küken. Anderes geeignetes Verhalten benötigt drei passende Beobachtungen,
um die Zuordnung dieses Individuums zu belegen. Eine Beobachtung niemals
aufteilen oder doppelt eintragen, um drei zu erreichen. Geeignete
nestbezogene TN-, TB-, oder HA-Fänge können die Zuordnung direkt belegen;
die tatsächliche Methode und den Kontext eintragen, statt einen stärkeren
Code auszuwählen.

Ein MM-Fang allein beweist keine Elternschaft. Bei einem zuverlässig
identifizierten Vogel können frühere geeignete Nachweise mitzählen; X-X ist
über mehrere Tage keine eindeutige individuelle Identität. Nach der
genehmigten Annahme zum gezielten Fang kann ein einzelner geeigneter
Erstberingungsfang bestätigende X-X-Nachweise vom selben Tag, Geschlecht,
und Nest übernehmen. Konkurrierende Identitäten oder geänderte Nestzuordnungen
zur Prüfung weitergeben, statt zu raten.

**Reihenfolge beim Speichern:** zuerst GPS hochladen. Wenn Küken gehandhabt
wurden, ihre tatsächlichen Fänge vor den davon abhängigen Elternsichtungen
oder H-Zeilen speichern. Eltern- und Kükensichtungen derselben Begegnung
gemeinsam abschicken. Ein früherer Elternfang ersetzt nicht die begleitende
Elternbeobachtung für neue Kükensichtungen. Wenn tatsächlich kein Elternvogel
beobachtet wurde, Kükenbeobachtungen, Wegpunkt, und eine konkrete Erklärung
behalten; das Ausnahmeverfahren befolgen, statt einen Elternvogel zu erfinden.

[Familien-, Elternzuordnungs-, und Ausnahmeverfahren](manual-de.md#section-5)

<a id="core-section-4"></a>

## 4. Nestbesuche und Eier

- Ein Vogel am Nest benötigt einen eigenen Wiederbeobachtungsdatensatz;
  seine Identität allein im Nestkommentar liefert keinen To-Do-Zuordnungsnachweis.
- Neue leere Nestmulde: `S`, null Eier. Neues Nest mit Eiern: `F`. Bei weiteren
  Besuchen dieselbe ID behalten und tatsächliche Anzahlen, Zeiten, und Nachweise
  eintragen.
- Seltener Erstfund frisch geschlüpfter Küken **innerhalb eines eindeutig
  erkennbaren Nests**: positive ID, F und mindestens eine Minute später H,
  wahrheitsgetreue Anzahlen, und eine Erklärung. Küken außerhalb eines nie
  gefundenen Nests erhalten eine negative Brut-ID, keine erfundenen Nestbesuche.
  Bei blockierender Prüfung das Verfahren für den seltenen Erstfund nachlesen.
- `clutch_size` bedeutet verbliebene Eier; `brood_size` bedeutet beobachtete
  Küken. `hatch_state` beschreibt die Eier: N kein Anzeichen, S Stern, C Riss,
  CC mehrere/große Risse. H nicht wieder zu I machen, weil ein Ei übrig ist.
- Nur geeignete Eier vermessen; **keinen Schwimmtest an Eiern mit Stern oder
  beginnendem Schlupf durchführen**. Tatsächliche Messzeiten behalten. Die
  Schwimmtest-Felder untergetauchter Eier nicht wie Oberflächenmessungen ausfüllen.
- Das erste H mit null verbliebenen Eiern und vorhandenen Küken ist der letzte
  Schlupfbesuch. Spätere Begegnungen mit der mobilen Brut gehören in
  Vogeltabellen. Der abschließende `notA`-Besuch bleibt separat.
- Wenn später einzeln beringte Küken ein bekanntes vollständiges Gelege
  vollständig abdecken, kann das To-Do null verbleibende Eier ableiten und
  einen `notA nest-check` anfordern. Das erfindet weder einen Nestbesuch noch
  schließt es das Nest. Die tatsächlichen Anzahlen jedes Besuchs beibehalten;
  die vorsichtige Ableitung erfordert derzeit ein vollständiges Gelege mit
  mindestens 3 Eiern und verlässliche Zuordnungen der ursprünglichen Küken.

[Nest- und Eierverfahren](manual-de.md#section-4) ·
[Schicksal und Abschluss](manual-de.md#section-9)

<a id="core-section-5"></a>

## 5. Handling, Markierung, und Fotos

Metallring und tatsächliche Eingangsmarkierungen vor jeder Änderung ablesen.
Die tatsächlichen Freilassungsmarkierungen separat eintragen: **F** erste
Markierung, **R** unveränderter Wiederfang, **C** geänderte Kombination,
**D** Totfund. Bei D die gefundenen Markierungen in die Eingangsfelder setzen;
Freilassungsmarkierungen und Freilassungszeit bleiben leer. Keine Freilassung
erfinden. Die alters-/statusabhängigen Messungen, Proben, und zutreffenden
Kennzeichnungen nach den [Fanganforderungen](manual-de.md#section-6) ausfüllen.

Dem Flagging-To-Do und der Wohlfahrtsbeurteilung folgen: Nachkontrollen beginnen
ab Tag 21, aber **unter 22 g oder 27 mm Tarsus keine Flagge anbringen**. Die
Grenzen ersetzen nicht das Urteil der beringenden Person. Eine Flagge bei einem
bereits beringten Küken ändert seine Kombination: Status C. Nur das zugeteilte
Markierungsschema verwenden.

**Versteckfoto:** möglichst vor dem tatsächlichen Alter von sieben Tagen.
Jedes fotografierte Küken benötigt eine eigene Wiederbeobachtung mit Alter C,
Geschlecht U, Klasse H, ausdrücklich gültiger positiver/negativer ID,
bekanntem Metallring, tatsächlichen Beinablesungen, beiden GPS-Feldern,
Kamera-ID, und vollständigem erstem/letztem Fotodateinamen. Erforderliche
Beringungsdatensätze zuerst speichern. Tatsächliche Beobachtungen anwesender
Elternvögel mit der Eingabe abgeben.

Ein Zeltfoto gehört zum Fang; ein Versteckfoto zu H. Weder das Foto-Kennzeichen
im Fang noch die Zeltsequenz ersetzt den H-Datensatz. Originaldateinamen
behalten und Individuen über ihren Metallring unterscheiden. Dass die
Fotoaufgabe an Tag sieben ausläuft, bedeutet **nicht**, dass sie erledigt ist;
bei negativen Bruten ist das Alter seit Entdeckung nicht unbedingt das
biologische Alter.

[Fotos und Medien](manual-de.md#section-7)

<a id="core-section-6"></a>

## 6. Fang- und Geolocator-Beschränkungen

**Auch bei Paarvervollständigung gelten sowohl die Sieben-Tage- als auch die
36-Stunden-Beschränkung.** Die Sieben-Tage-Rechnung folgt den Nachweisen zum
Legetag des letzten Eis, nicht der Entdeckung oder dem Tag, an dem das
vollständige Gelege bestätigt wurde. Die 36-Stunden-Beschränkung folgt dem
maßgeblichen Altvogelfang. Das datierte PDF rechnet mit 08:00 am Referenztag;
es ist kein Live-Countdown. Das vollständige Zeitverfahren und die
Wohlfahrtsbeurteilung beachten.

- Eine reine Wiederbeobachtungszeile erlaubt keinen Fang und keine Tag-Anbringung.
- „Band“ bedeutet nicht „tag“. Bei einem bereits getaggten möglichen
  Elternvogel muss die Zuordnung geprüft werden, nicht ein weiterer Tag
  angebracht werden.
- Bedingte Tagging-Hinweise wörtlich nehmen: „tag any, but only if one is
  confirmed X-X“ verlangt die Bestätigung des unberingten Vogels und seiner
  Zuordnung. Ein bereits beringter unbekannter Partner erfüllt diese Bedingung
  für die erste Anbringung nicht.
- Die aktuelle Cass-River-Regel 2026 für die späte Welle gilt für geeignete
  positive B/C-Nester mit Gelegevervollständigung **nach dem 9. Oktober**.
  Entscheidend ist die Gelegevervollständigung, nicht das Datum des Nestbeginns.
  Nur die genehmigte Gebietszuteilung und Paarvervollständigung am selben Nest
  anwenden.

Tatsächliche Tag-Aktion beim Altvogel, alte/neue Tag-IDs, und Spacer-Angaben
eintragen. Bei Küken/Jungvögeln bleiben die Tag-Felder leer. Vor einem Fang
oder einer außergewöhnlichen Anbringung/Entnahme die vollständigen
[Geolocator- und Zeitvorgaben](manual-de.md#section-8) nachlesen.

<a id="core-section-7"></a>

## 7. Nachkontrollen und Tagesabschluss

Ein leeres Nest beweist weder Schlupf noch Prädation. Tatsächliche Nachweise
und Unsicherheit eintragen. Vereinbarte Schicksalskontrollen bis zum
abschließenden `notA` fortsetzen, auch wenn eine Aufgabe verschwindet.
Ein geschlossenes Nest kann weiterhin lebende Küken haben; negative Bruten
erhalten niemals `NESTS`-Abschlusszeilen.

Bruten **im Alter von 21–35 Tagen einschließlich** wieder suchen. Wenn in
diesem festen Fenster keine geeignete Lebendbegegnung vorliegt, kann dies
ab Tag 36 die Brut- und zugehörigen Elternaufgaben unterdrücken. Eine Begegnung
an Tag 25 verhindert diesen bestimmten Auslöser; eine spätere Lebendbegegnung
kann nach der Aktualisierung noch fällige Arbeit zurückbringen. Erneutes
Nisten und wiederholte Elternbeobachtungen ohne Küken haben eigene, strengere
Nachweisregeln. **Vermutet tot ist eine Planungsannahme**, kein beobachteter Tod
und kein Grund für einen D-Fangdatensatz. Ein zuverlässig ursprungsverknüpfter
J-Datensatz beendet nach der Projektregel die Kükenaufgaben; er beweist nicht,
dass jedes Geschwister überlebt hat.

Vor dem Tagesabschluss:

- Prüfen, dass keine Vogelbeobachtung, kein Fang, oder anderer vorgeschriebener
  Vorgang ausschließlich im Kommentar steht. Den passenden Datensatz mit
  wahrheitsgetreuen Angaben speichern; kein Duplikat anlegen, wenn er bereits
  vorhanden ist.
- Gespeicherte Zeilen mit den Notizen vergleichen, einschließlich vorbefüllter
  Daten, Beobachtercodes, IDs, GPS-Paare, und Individuenzahlen. Doppelte
  Übermittlungen vermeiden.
- Originalmedien kopieren, Sicherung prüfen, und vollständige Dateinamen behalten.
- **DATA ENTRY ISSUES** prüfen. Fehler korrigieren; berechtigte Ausnahmen
  erklären und das Reparaturverfahren befolgen. Wahrheitsgetreue Nachweise nie
  ändern, nur damit eine Prüfung bestanden wird.
- Das aktualisierte, richtig datierte To-Do-PDF prüfen. Fehlende Fotos,
  offene Verknüpfungen, widersprechende Lebendnachweise, und offene
  Schicksalskontrollen an die nächste Schicht weitergeben.

[Brutnachkontrolle](manual-de.md#section-9) ·
[Eingabe und Prüfung](manual-de.md#section-10) ·
[Validator-Reparatur](manual-de.md#section-12)

---

Methoden und Entscheidungen bleiben in der Verantwortung von
**Luke Eberhart-Hertel**. Das vollständige Handbuch enthält die vollständigen
[Angaben zu Urheberschaft, KI-Nutzung, Datenschutz, und Sicherheit](manual-de.md#authorship).
