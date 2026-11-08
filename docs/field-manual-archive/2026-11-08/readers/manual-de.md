<!-- English-source-md5: d46b0def8f3dcea6a4e23517ad8d428f -->

# BADO-Feldhandbuch 2026

Protokolle zur Erforschung brütender Banded Dotterel / Pohowera\
**Vollständiges Protokollhandbuch v2.4.22 · Überarbeitet am 3 November 2026**

Dieses Handbuch beschreibt die Verfahren im Feld und die Prüfregeln bei der Dateneingabe
für die Banded-Dotterel-Feldarbeit in ganz Neuseeland während der Brutzeit.
Wenn die App von einer Anweisung abweicht, halten Sie
Ihre Feldaufzeichnungen wahrheitsgetreu und folgen Sie [Abschnitt 12](#section-12).

Die kürzere Fassung für den täglichen Gebrauch finden Sie im [Feldleitfaden für das Kernteam](core-guide-de.md).
Dieses vollständige Handbuch enthält alle Anforderungen, Ausnahmen, und Beispiele.

## Inhalt

- [1. So verwenden Sie dieses Handbuch](#section-1)
- [2. Was habe ich angetroffen?](#section-2)
- [3. Bevor Sie das Feldhaus verlassen](#section-3)
- [4. Nester, Nestmulden, und Eier](#section-4)
- [5. Altvögel, Küken, und Bruten](#section-5)
- [6. Fänge, Farbringe, Metallringe, Fahnen, und Tags](#section-6)
- [7. Fotos und Umgang mit Medien](#section-7)
- [8. Geolokatoren anbringen und abnehmen](#section-8)
- [9. Verbleib, Schlupf, Brutverlust, und notA](#section-9)
- [10. Eingabe und Kontrolle am Tagesende](#section-10)
- [11. Datenwörterbuch vom Feld zur Datenbank](#section-11)
- [12. Prüfmeldungen und Anleitung zur Behebung](#section-12)
- [13. Erforderliche Datenbankereignisse nach Situation](#section-13)
- [14. Durchgearbeitete Beispiele](#section-14)
- [15. Änderungsverzeichnis und Quellenhinweise](#section-15)
- [Anhang A. Vorgegebene Werte](#appendix-a)
- [Anhang B. Checklisten für das Feld und die Einreichung](#appendix-b)
- [Urheberschaft und Einsatz von KI](#authorship)

<a id="section-1"></a>

<details open>
<summary><strong>1. So verwenden Sie dieses Handbuch</strong></summary>

## 1. So verwenden Sie dieses Handbuch

Bitte lesen Sie dieses Handbuch vor dem Feldeinsatz durch, wenn Sie Zeit haben. Bei vorhandenem Datenempfang können Sie es auch im Feld über die FIELDWORKER-App auf Ihrem Telefon aufrufen. Beginnen Sie mit
Abschnitt 2, wenn Sie nicht sicher sind, welche Datensätze eine Beobachtung/Begegnung erfordert. Lesen Sie zuerst die kurze
Verfahrensbeschreibung; verwenden Sie bei der Dateneingabe die zugehörige Hilfstabelle.

Die Verfahren gelten für unsere Arbeit mit Banded Dotterel / Pohowera in ganz Neuseeland.
Verwenden Sie `BADO` für die Art und den freigegebenen Code für Ihr Untersuchungsgebiet. `CR` steht für
Cass River; es ist hier ein Beispiel und nicht der Code für jedes Gebiet. Die nachfolgenden gebietsspezifischen
Nest-ID-Systeme, Beringungsmuster, und Geolokator-Zuteilungen sind als
Beispiele oder Projektanweisungen gekennzeichnet und keine Erlaubnis, sie an einem anderen Ort anzuwenden.
Klären Sie das freigegebene System Ihres Teams und die App-Konfiguration mit der Feldleitung.
Auch Wrybill-Nester können gefunden und
fotografiert werden: Verwenden Sie `WRYB` und die WR-Nest-IDs des Teams. Halten Sie `WRYB`-Einträge
in Ihren Notizen von BADO getrennt. Andere Arten und Gebietscodes in der App unterstützen weitere Projektarbeiten;
die zugehörigen Verfahren werden durch dieses Handbuch nicht zusätzlich abgedeckt.

Mit **Geolokator/Tag** ist hier ein Ortungsgerät gemeint, das an einem Vogel angebracht wird, nicht das Garmin-
GPS oder die Kamera. Abschnitt 8 erläutert das Anbringen, das Abnehmen, und die Tag-Einträge.

### Erfassen Sie, was geschehen ist

Geben Sie jedem Vogel einen eigenen Datensatz, auch wenn Geschwister denselben Farbring tragen.
Ein nur gesichteter Vogel gehört in das Wiederbeobachtungsformular; ein gefangener und in der Hand untersuchter Vogel
gehört in das Fangformular. Fügen Sie nicht allein deshalb eine zweite Sichtung hinzu, weil das Küken
gefangen wurde. Eine tatsächliche Beobachtung vor der Handhabung kann separat erfasst werden.

Versteckfotos sind eine ausdrückliche Ausnahme von der Regel mit einem Datensatz:
Jedes fotografierte Küken benötigt zusätzlich zu einem etwaigen Fangdatensatz eine eigene Wiederbeobachtung der Klasse H
(war das Küken beispielsweise beim Versteckfoto noch unberingt, sollte ein Fangdatensatz die Beringung und ein Wiederbeobachtungsdatensatz das Versteckfoto beschreiben. Ein Versteckfoto eines beringten Kükens erfordert nur den Wiederbeobachtungsdatensatz). Ein Zeltfoto bleibt beim Fang. Abschnitt 7 erläutert die
Trennung.

| Feldaufzeichnung | Datenbanktabelle | Anzahl der Zeilen |
|---|---|---|
| Besuch bei einem Nest oder einer Nestmulde | `NESTS` | Eine neue Zeile pro Besuch. |
| Eimessungen | `EGGS` | Eine Zeile pro Ei, das bei diesem Besuch gemessen wurde. |
| Vogel gefangen oder wiedergefangen | `CAPTURES` | Eine Zeile pro Individuum und Handhabungsereignis. |
| Vogel beobachtet, aber nicht in der Hand untersucht | `RESIGHTINGS` | Eine Zeile pro Individuum und Beobachtung. |
| Küken in seinem Versteck fotografiert | `RESIGHTINGS`, `rclass = H` | Eine Zeile pro fotografiertem Küken. |

Eine Zeile ist eine Zeile im Eingabeformular. Zwei gemeinsam gesichtete beringte Küken benötigen zwei
Kükenzeilen und nicht eine Zeile mit „zwei Küken“ im Kommentar.

**Kommentare ergänzen Ereignisse; sie ersetzen sie nicht.** Der To-Do-Algorithmus
liest Freitextkommentare nicht als Ersatz für erforderliche Ereignisdatensätze.
Wenn Sie beispielsweise die Identität eines Vogels in `NESTS.comments` eintragen oder
`bird_inc` ausfüllen, ersetzt dies kein separates `RESIGHTINGS`-Ereignis mit den tatsächlich
abgelesenen Markierungen, dem Geschlecht, dem Verhalten, der Nest-ID, und den weiteren erforderlichen Beobachtungsangaben. Verwenden Sie IN
nur, wenn der Vogel tatsächlich brütete. Eine nur im Kommentar eingetragene Beobachtung
wird als Beleg für die entsprechende Aufgabenentscheidung übersehen. Tragen Sie jedes
erforderliche Ereignis in das richtige Formular ein, damit Elternzuordnungen und Arbeitspläne
es verwenden können; duplizieren Sie kein bereits gespeichertes Ereignis.

### Erforderlich, bedingt, optional, oder leer?

| Formulierung in diesem Handbuch | Bedeutung |
|---|---|
| Erforderlich | Füllen Sie dieses Feld für das genannte Ereignis aus. |
| Bedingt | Füllen Sie es aus, wenn die genannte Bedingung zutrifft. |
| Optional | Tragen Sie es ein, wenn es erhoben wurde; erfinden Sie nichts. |
| Leer lassen / nicht zutreffend | Das Feld gilt für dieses Ereignis nicht. Füllen Sie es nicht ersatzweise mit null oder `NA`. |

Null ist eine tatsächliche Anzahl oder ein ausdrückliches „nein“ in einem 0/1-Feld. Eine unbekannte Anzahl ist
nicht null. `X` in einem Feld für Beinmarkierungen bedeutet eine beobachtete leere Position; `?` bedeutet,
dass Markierungen gesehen, aber nicht sicher abgelesen wurden. Dies sind unterschiedliche Beobachtungen.

Befolgen Sie die Anweisungen der Feldleitung, die Genehmigungen, und die Grenzen zum Schutz der Tiere. Dieses Handbuch
verbindet die Feldarbeit mit der Datenbank; für Fang,
Handhabung, Messung, Probenahme, und Fototechnik bleibt die praktische Schulung maßgeblich.

</details>

<a id="section-2"></a>

<details>
<summary><strong>2. Was habe ich angetroffen?</strong></summary>

## 2. Was habe ich angetroffen?

Eine Begegnung kann mehrere Datensätze erfordern. Gehen Sie jeden zutreffenden Zweig durch:
Ein Nest zu finden, Eier im Wasser zu testen, und einen Elternvogel zu fangen sind getrennt
zu erfassen, auch wenn alles bei einem Besuch geschieht.

### Übergeordneter Entscheidungsbaum

```text
Was ist bei der Begegnung geschehen? Folgen Sie jedem zutreffenden Zweig.
├─ Nest oder Nestmulde kontrolliert → ein NESTS-Besuch [4, 9]
│  ├─ Eier gemessen/im Wasser getestet → eine EGGS-Zeile pro Ei [4]
│  └─ Gelege fotografiert → Fotofelder bei diesem NESTS-Besuch [7]
├─ Vogel nur gesehen → eine RESIGHTINGS-Zeile pro Vogel [5]
│  └─ Familie anwesend → beobachtete Elternvögel und Küken erfassen, gemeinsamer Wegpunkt [5]
├─ Vogel gefangen/in der Hand untersucht → eine CAPTURES-Zeile pro Vogel [6]
│  ├─ Zeltfoto → Fotofelder bei diesem Fang [7]
│  └─ Geolokator/Tag angebracht/abgenommen/beibehalten → Tag-Felder bei diesem Fang [8]
└─ Küken im Versteck fotografiert → separate RESIGHTINGS-Zeile der Klasse H pro Küken [7]
```

### Derselbe Schlüssel als Text

1. **Haben Sie ein Nest oder eine Nestmulde kontrolliert?** Ja: Tragen Sie einen Nestbesuch ein und gehen Sie dann zu 2.
   Nein: Gehen Sie ohne Nestbesuch zu 2.
2. **Haben Sie Eier gemessen?** Ja: Fügen Sie eine Eizeile pro Ei hinzu. Nein: Legen Sie keine
   Eimesswerte an. Gehen Sie in beiden Fällen zu 3.
3. **Wurde ein Vogel gefangen und in der Hand untersucht?** Ja: Tragen Sie seinen Fang ein; erzeugen Sie keine
   doppelte Sichtung. Nein, er wurde nur gesehen: Tragen Sie seine Wiederbeobachtung ein. Gehen Sie dann zu 4.
4. **Wurden andere Familienmitglieder gesehen?** Ja: Erfassen Sie jeden beobachteten Elternvogel und
   jedes beobachtete Küken nach den Regeln für den Familienwegpunkt. Nein: Fügen Sie keine abwesenden Vögel hinzu. Gehen Sie zu 5.
5. **Wurden Fotos oder Videos aufgenommen?** Ja: Verwenden Sie die Fotofelder des passenden
   Ereignisses; Versteckfotos erfordern immer separate H-Zeilen. Nein: Lassen Sie nicht zutreffende
   Medienfelder leer. Gehen Sie zu 6.
6. **Gab es eine Geolokator-/Tag-Aktion, einen Schlupf, einen Brutverlust, oder einen Abschluss?** Ja: Befolgen Sie auch
   Abschnitt 8 oder 9. Nein: Prüfen Sie vor dem Verlassen die oben ermittelten Datensätze.

### Welche Nest- oder Brut-ID?

1. **Gehört der Vogel zu einem bekannten Nest?** Ja: Behalten Sie diese positive Nest-
   ID bei, auch nachdem die Brut das Nest verlassen hat. Nein: Gehen Sie zu 2.
2. **Ist dies eine mobile Brut, deren Nest und Eier nie gefunden wurden?** Ja:
   Verwenden Sie die zugewiesene negative Brut-ID. Nein: Vergeben Sie nicht allein deshalb eine negative ID,
   weil Sie unsicher sind, zu welchem bekannten Nest der Vogel gehört. Gehen Sie zu 3.
3. **Wird ein Altvogel gefangen, der eindeutig zu keinem Nest und keiner Brut gehört?**
   Ja: Lassen Sie `nest_id` leer und tragen Sie den gps_id/point des Fangs ein. Nein:
   Befolgen Sie die ereignisspezifischen Zuordnungsregeln; erfinden Sie keine Platzhalter-ID.

Der seltene Fund frisch geschlüpfter Küken **in einem eindeutig erkennbaren Nest** belegt
einen positiven Nestursprung. Erfassen Sie den F-Erstfund mit anschließendem H wie in
Abschnitt 4 beschrieben. Küken außerhalb eines Nestes zu finden, belegt diesen Ursprung nicht.

Bei einigen späteren Küken-Wiederbeobachtungen und einer eng definierten Begegnung mit einer Familie
mit negativer Brut-ID kann die ID leer bleiben. Verwenden Sie die Prüfungen in Abschnitt 5; ein leeres Feld
ist keine negative Brut-ID und darf nicht mit einem Platzhalter ausgefüllt werden.

### Welche Wiederbeobachtungsklasse?

1. **Küken in seinem Versteck fotografiert?** Ja: `H`. Nein: Gehen Sie zu 2.
2. **Fehlgeschlagener Fangversuch?** Ja: `C`. Nein: Gehen Sie zu 3.
3. **Videoaufnahme?** Ja: `V`. Nein: Gehen Sie zu 4.
4. **Fotoaufnahme?** Ja: `P`. Nein: `R` für eine gewöhnliche Sichtung.

Derselbe Buchstabe kann in verschiedenen Spalten unterschiedliche Bedeutungen haben:

| Eingabe | Bedeutung |
|---|---|
| `age = C` | Küken. |
| `rclass = C` | Fehlgeschlagener Fangversuch; der Vogel wurde nicht in der Hand untersucht. |
| `capture_status = C` | Wiederfang, bei dem sich die Ringkombination geändert hat. |
| `tag_action = R` | Tag abgenommen, keine gewöhnliche Wiederbeobachtung. |

</details>

<a id="section-3"></a>

<details>
<summary><strong>3. Bevor Sie das Feldhaus verlassen</strong></summary>

## 3. Bevor Sie das Feldhaus verlassen

Prüfen Sie das aktuelle To-Do-PDF und stimmen Sie die Tagesarbeit mit der Feldleitung ab. Nehmen Sie
die Eltern–Nest-Übersicht, die zugeteilten Ringkombinationen, und die für Ihre zugewiesenen Besuche erforderliche
Ausrüstung mit. Lesen Sie alle Hinweise zum Fangzeitpunkt, bevor
Sie planen, einen Elternvogel zu fangen.

### Ausrüstung und Zeiteinstellungen

- Laden Sie das Garmin-GPS und die Kamera auf; vergleichen Sie ihre Geräte-IDs mit Ihren Notizen.
- Nehmen Sie Feldformulare, Ersatzbatterien/-karten, Metallringe, Farbringe, Fahnen, Messgeräte,
  und das für die Tagesarbeit erforderliche beschriftete Probenmaterial mit.
- Verwenden Sie das neuseeländische Ortsdatum und die 24-Stunden-Zeit. Prüfen Sie Kamera- und GPS-Uhr
  gemeinsam, einschließlich der richtigen Sommerzeiteinstellung.
- Lassen Sie das Garmin im Feld eingeschaltet. Löschen Sie seine Punkte nicht und benennen Sie sie nicht manuell um.
  Prüfen Sie bei Bedarf die Aufzeichnungseinstellungen anhand der GPS-Hilfe der App.

### Einen Wegpunkt mit Ihrem Garmin-GPS erfassen

Speichern Sie bei einem neuen Nest, einer Brutbegegnung, einem Fangort, einer gewöhnlichen Wiederbeobachtung, oder einem Versteckfoto-
Ort einen Wegpunkt und notieren Sie sofort die Garmin-Geräte-ID und
die Punktnummer. Punkt 214 auf GPS 4 ist nicht derselbe Datensatz wie Punkt 214 auf GPS 5.

Verwenden Sie bei einer Familienbegegnung denselben Wegpunkt für jedes Familienmitglied, das
bei dieser Gelegenheit erfasst wird. Dies gilt auch, wenn die Küken gefangen und die Elternvögel nur wiederbeobachtet wurden – gleichzeitige Ereignisse, die in zwei
verschiedenen Tabellen eingetragen werden (CAPTURES und RESIGHTINGS). Erfassen Sie bei einer späteren Begegnung einen neuen Punkt, nachdem die Familie
weitergezogen ist; verwenden Sie nicht den gestrigen Punkt, nur weil die Brut-ID unverändert ist.
Tragen Sie `nest_id` immer ein, wenn sie bekannt ist. Prüfen Sie die Familienzuordnung anhand der Eltern–Nest-Übersicht im To-Do-
PDF; andernfalls gelten die Bedingungen für leere IDs in
Abschnitt 5. Das Fehlen in einer To-Do-Tabelle erlaubt für sich allein keine leere ID.

### Hilfstabelle — direkte GPS-Anforderungen

In diesem Handbuch bezeichnet **gps_id/point** beide Datenbankfelder: `gps_id` (die
Garmin-Geräte-ID) und `gps_point` (die gespeicherte Wegpunktnummer). Tragen Sie beide Nummern
zusammen ein, wenn eine direkte Ortsangabe erforderlich ist. „Nestort“ bezeichnet den ortsfesten
Punkt des ersten Nestbesuchs; es ist nicht der Wegpunkt des heutigen Aufenthaltsorts der Brut.

| Situation | Wohin der gps_id/point gehört | Anforderung |
|---|---|---|
| Erster Besuch bei einem positiven Nest/einer Nestmulde | Erste `NESTS`-Zeile | Erforderlich. Bei späteren Nestbesuchen bleiben beide Felder leer. |
| Jede eingetragene negative Brut-ID | Jede `CAPTURES`- / `RESIGHTINGS`-Zeile | Erforderlich; es gibt keinen ortsfesten Nestort. |
| Versteckfoto | Jede `RESIGHTINGS`-Zeile der Klasse H | Erforderlich, auch bei einem bekannten positiven Nest, dessen Küken inzwischen geschlüpft sind. |
| Zulässige Familien-Wiederbeobachtung mit leerer ID | Jede qualifizierende Eltern-/Kükenzeile | Erforderlich, mit dem genauen Begegnungsdatum und dem gemeinsamen gps_id/point; Einzelheiten in Abschnitt 5. |
| Fang mit Alter C, Status `R` oder `C` | `CAPTURES`-Zeile des Kükens | Erforderlich, auch bei einer positiven Nest-ID. |
| Erstfang mit Alter C, Status `F`, positives Nest | `CAPTURES`-Zeile des Kükens | Die Eingaberegel erlaubt beide Felder leer, wenn der Nestort verwendet wird (d. h., wenn das frisch geschlüpfte Küken noch in der Nestmulde gefunden wurde). Erfassen und behalten Sie den Familienwegpunkt; tragen Sie den gps_id/point ein, wenn Sie einen Fang abseits des Nestes erfassen oder die Familienbegegnung verknüpfen. |
| Altvogel mit Küken gefangen | `CAPTURES`-Zeile des Altvogels | Erforderlich, auch bei einem positiven Nest; erfassen Sie den Kükenkontext in `caught_with`, z. B. bedeutet `2C`, dass der Altvogel mit zwei Küken gefangen wurde. |
| Altvogelfang ohne Bezug zu einem Nest oder einer Brut, mit leerer `nest_id` | `CAPTURES`-Zeile | Erforderlich. Lassen Sie die Zuordnung leer; tragen Sie keine Platzhalter-ID ein. |
| Vogel ohne positive Nestzuordnung wiederbeobachtet | `RESIGHTINGS`-Zeile | Erforderlich. |
| Überlebende Brut nach `notA`-Abschluss des positiven Nestes | Wiederbeobachtungen der Küken und der begleitenden Brut-Elternvögel | Erforderlich. |
| Anderer Fang mit positivem Nest | `CAPTURES`-Zeile | Verwenden Sie normalerweise den Nestort und lassen Sie direkte GPS-Felder leer; übertragen Sie die Ausnahmen für Küken/Altvögel mit Küken nicht auf andere Fangkontexte. |
| Gewöhnliche Wiederbeobachtung an einem bekannten positiven Nest | `RESIGHTINGS`-Zeile | Das Nest kann den Ort liefern; behalten Sie bei einer Brutbegegnung den gemeinsamen gps_id/point. |

### Kurzer GPS-Schlüssel

1. **Ist dies der erste Nest-/Nestmuldenbesuch?** Ja: Tragen Sie seinen Fund-gps_id/point ein.
   Nein, ein späterer Besuch bei diesem ortsfesten Nest: Lassen Sie beide Nest-GPS-Felder leer.
   Bei einer Vogelbegegnung gehen Sie zu 2.
2. **Geht es um eine Brut, ein H-Foto, ein Familienereignis mit leerer ID, einen Fang mit Alter C und Status R oder C, oder
   einen Altvogelfang mit Küken?** Ja: Verwenden Sie den gps_id/point der Begegnung
   wie oben vorgegeben. Nein: Gehen Sie zu 3.
3. **Verwendet das zulässige Ereignis den Ort eines positiven Nestes?** Ja: Folgen Sie
   der entsprechenden Tabellenzeile. Nein: Der Zweig für direkte Ortsangaben benötigt beide GPS-Felder.

Laden Sie im Feldhaus die GPS-Daten hoch, bevor Sie biologische Datensätze eingeben. Der eingetragene gps_id/point muss
unter den hochgeladenen Punkten vorhanden sein. Die biologischen Formulare verwenden `gps_id` und
`gps_point`; tragen Sie in diese Felder keine Breiten- und Längengrade ein.

</details>

<a id="section-4"></a>

<details>
<summary><strong>4. Nester, Nestmulden, und Eier</strong></summary>

## 4. Nester, Nestmulden, und Eier

### Ein neues Nest oder eine neue Nestmulde

Halten Sie den ersten Besuch kurz. Bestätigen Sie die Art, erfassen Sie einen Wegpunkt mit Ihrem
Garmin-GPS, und vergeben Sie die nächste freie Nest-ID nach dem Benennungssystem des Teams (siehe unten).
Notieren Sie die tatsächlich gesehenen Eier, Küken, und anwesenden Vögel. Fotografieren und
bearbeiten Sie das Nest nur entsprechend dem Besuchsplan und den Bedingungen zum Schutz der Tiere.

Bei Cass River verwenden BADO-IDs beispielsweise einen A-, B-, oder C-Plot-Präfix und den zugeteilten zweistelligen
Beobachter-/GPS-Code plus eine zweistellige laufende Nummer, zum Beispiel `B0203`. Beginnen Sie
Ihre Zählung in einem anderen Plot nicht neu: B0203 und A0203 dürfen mit
demselben Code/Zählstand nicht für verschiedene Erstfunde vergeben werden. Prüfen Sie das aktuelle Register.
WRYB-Nester verwenden das separate WR-Benennungssystem.

### Neuer Fund oder späterer Besuch?

1. **Hat die Nestmulde/das Nest bereits eine ID?** Ja: Behalten Sie sie bei, wählen Sie den heutigen
   Zustand anhand der Belege nach Abschnitt 9, und gehen Sie zu 4. Nein: Erfassen Sie den
   Fundwegpunkt und gehen Sie zu 2.
2. **Sind Eier im neuen Nest vorhanden?** Ja: Vergeben Sie die ID und tragen Sie den
   ersten `F`-Besuch ein, dann gehen Sie zu 4. Nein: Gehen Sie zu 3.
3. **Ist dies eine Nestmulde ohne Eier und ohne Küken?** Ja: Vergeben Sie die ID und
   tragen Sie `S` mit null Eiern ein. Nein: Wurden frisch geschlüpfte Küken in einem
   eindeutig erkennbaren Nest gefunden? Falls ja, verwenden Sie das nachfolgende Verfahren für diesen seltenen Fund. Falls nein,
   verwenden Sie die Bruthinweise in Abschnitt 5; erfinden Sie keinen Nestursprung.
4. **Wurden Eier gemessen oder im Wasser getestet?** Ja: Fügen Sie eine Eizeile pro gemessenem Ei hinzu.
   Nein: Legen Sie keine Messwerte an. Gehen Sie zu 5.
5. **Sind Küken vorhanden, oder ist der Verbleib unklar?** Ja: Verwenden Sie auch Abschnitt 9.
   Nein: Vervollständigen Sie den aktiven Besuch und seine geplante Nachkontrolle.

Eine bekannte Nestmulde kann später ihren einmaligen F-Erstfund erhalten, wenn Eier gefunden werden;
behalten Sie ihre ID und den ursprünglichen Nestmulden-Wegpunkt bei.

### Seltener Fall: Das Nest wird erstmals mit frisch geschlüpften Küken darin gefunden

Banded-Dotterel-Küken sind Nestflüchter: Sie können sich bald nach
dem Schlupf bewegen und verlassen das Nest kurz darauf. Sie unmittelbar nach dem Schlupf noch in
einem eindeutig erkennbaren Nest zu finden, ist daher sehr selten.

Wenn dies Ihr Fund ist, vergeben Sie eine positive Nest-ID und erfassen Sie den Nest-
Wegpunkt. Tragen Sie zwei NESTS-Ereignisse ein: F für den Erstfund, unmittelbar gefolgt
von H, wobei die H-Zeit mindestens eine Minute nach F liegen muss. Erklären Sie, dass das Nest
erstmals mit frisch geschlüpften Küken darin gefunden wurde. Damit erfassen Sie Erstfund und
Schlupf bei derselben Begegnung; Sie erfinden keinen früheren Eierbesuch.

| Ereignis | Erforderliche Einträge für diese Ausnahme |
|---|---|
| F-Erstfund | Neue positive `nest_id`, tatsächliches Funddatum/Fundzeit, Beobachter/Art/Gebiet, und beide Nest-GPS-Felder. Wenn keine Eier mehr vorhanden sind, `clutch_size = 0`; erfinden Sie keine Eier oder Eimessungen. Erfassen Sie die tatsächlich gesehenen Küken. |
| Unmittelbares H | Dieselbe positive ID und dasselbe Begegnungsdatum; `time_visit` mindestens eine Minute nach F. Erfassen Sie die tatsächlich verbliebenen Eier/Küken; ohne Eier Gelege 0 und die beobachtete positive Kükenanzahl. Lassen Sie direkte Nest-GPS-Felder leer, weil F den Punkt festlegt. |
| Einzelne Vögel | Separate CAPTURES-Zeilen bei Handhabung oder RESIGHTINGS-Zeilen bei Beobachtung; die Familien- und Fotoregeln gelten weiterhin. |

**Wenn die Eingabeprüfung diese Beobachtung beanstandet:** Eine erste F-Zeile mit null Eiern
löst zu Recht die übliche Schutzprüfung aus. Kontrollieren Sie die Eingabe erneut. Wenn die Küken tatsächlich
unmittelbar nach dem Schlupf in einem eindeutig erkennbaren Nest gefunden wurden, behalten Sie die wahren
Anzahlen bei und erklären Sie diesen seltenen Umstand in `comments`. Zum Beispiel:
„Nest erstmals mit frisch geschlüpften Küken noch in einem eindeutig erkennbaren Nest gefunden;
keine Eier mehr vorhanden. F-Erstfund gefolgt von H.“

Wenn das Speichern weiterhin blockiert ist, prüfen Sie die anderen Felder und verwenden Sie die dokumentierte
Umgehung der Eingabeprüfung in Abschnitt 12; behalten Sie die Erklärung bei. Dies ist eine
außergewöhnliche, kommentierte Beobachtung — kein Grund, die Prüfregel abzuschwächen,
Eier zu erfinden, oder eine Ausnahme einzuprogrammieren.

Küken, die erstmals **außerhalb** eines eindeutig erkennbaren Nestes angetroffen werden und deren
Nestursprung zuvor nicht bekannt war, bilden eine Brut unbekannter Herkunft: Verwenden Sie eine negative ID und keine NESTS-
Ereignisse. Legen Sie nicht allein deshalb F/H-Zeilen an, weil Küken frisch geschlüpft aussehen. Eine Brut,
die bereits zuverlässig einem bekannten Nest zugeordnet ist, behält ihre positive ID wie in Abschnitt 5.

### Hilfstabelle — ein Nestbesuch

| Feld(er) | Anforderung | Eingabe |
|---|---|---|
| `species`, `site`, `observer`, `date`, `time_visit` | Erforderlich | Art/Gebiet, registrierter Beobachtercode, und tatsächliches Ortsdatum/Ortszeit. |
| `nest_id`, `nest_state` | Erforderlich | Positive ID und heutiger Zustand. Niemals eine negative ID oder ein Platzhalter für eine unbekannte Zuordnung. |
| `gps_id`, `gps_point` | Nur beim ersten Besuch erforderlich | Beide in der ersten S- oder F-Zeile. Ein späteres F nach S wiederholt sie nicht. |
| `clutch_size`, `brood_size` | Abhängig davon, was sich feststellen lässt | Noch vorhandene Eier und beobachtete Küken sind getrennte Anzahlen. S erfordert `clutch_size = 0` und ein leeres Feld bzw. null für die Kükenanzahl. Verwenden Sie null nicht für eine unbekannte Anzahl. |
| `bird_inc` | Wenn der anwesende Vogel beurteilt wurde | Geschlecht(er), unbekanntes Geschlecht, oder kein Vogel gesehen; Anhang A. Dies erfasst nicht die Identität des Individuums. |
| `hatch_state` | Wenn der Eizustand erfasst wird | Anzahl und Zustand der verbliebenen Eier; Abschnitt 9. |
| `nest_photo`, `tent_photo` | Erfassen, ob das Gelege in der Nestmulde/im Zelt fotografiert wurde | `1` für die zutreffende Serie, `0` für kein Foto. |
| `cam_id`, `photo_start`, `photo_end` | Erforderlich, wenn Fotos erfasst werden | Tatsächliche Kamera und vollständiger Bildbereich bei diesem Besuch. |
| `comments` | Erforderlich bei Zustand `O`; andernfalls Unsicherheit/ungewöhnliche Funde erklären | Beschreiben Sie die Belege und nicht nur den gewählten Code. |

Fügen Sie für den heutigen Besuch eine Zeile hinzu. Überschreiben Sie keinen früheren Besuch mit späteren
Feststellungen. Dieselbe ID bleibt beim Nest, wenn der betreuende Vogel wechselt.

### Eier messen und im Wasser testen

Prüfen Sie die Einummer vor jeder Messung und legen Sie die Eier nach dem
Teamverfahren zügig zurück. Führen Sie bei Eiern mit sternförmigen Anpickspuren oder bereits beginnendem Schlupf keinen Schwimmtest durch. Erfassen Sie ihre Schlupf-
anzeichen stattdessen beim Nestbesuch; wenn eine Eizeile zur Erklärung ausgelassener
Messungen erforderlich ist, lassen Sie ihre Schwimmtestfelder leer und erklären Sie den Grund.

Gelegefotos gehören zum Nestbesuch, nicht in die Eitabelle. Zwei Eier
zu fotografieren, ohne sie zu messen, erfordert für sich allein keine zwei EGGS-Zeilen.

### Hilfstabelle — eine Zeile pro gemessenem Ei

| Feld(er) | Anforderung | Eingabe |
|---|---|---|
| `species`, `observer`, `date`, `time_visit`, `nest_id`, `egg_id` | Erforderlich | Messende Person, tatsächliches örtliches Messdatum/Messzeit, positive Nest-ID, und Einummer 1–4. In `EGGS` gibt es kein `site`-Feld. |
| `float_angle` | Beim Schwimmtest erfassen | Beobachtete ganze Grad, 0–90. Ersetzen Sie einen ungewöhnlichen Messwert nicht durch einen erwarteten. |
| `float_location` | Beim Schwimmtest erfassen | `bottom`, `suspended`, oder `surface`. |
| `float_surface` | Bedingt | `bottom`/`suspended`: leer. `surface`: ganze mm `0`, `1`, `2`, oder `3`. Null bedeutet an der Oberfläche ohne gemessenen Überstand, nicht untergetaucht. |
| `comments` | Wenn eine Messung ausgelassen oder ungewöhnlich ist | Grund für das Auslassen oder die Unsicherheit. |
| Kamera-, Bild-, und Laufwerksfelder | Nicht zutreffend | Solche Felder gibt es in den aktuellen `EGGS` nicht; legen Sie Gelegemedien in `NESTS` ab. |

### Zeit- und Zeilenprüfungen

| Prüfung | Praktische Bedeutung |
|---|---|
| Eizeilen einer Kontrolle | Verwenden Sie das tatsächliche Ereignis am selben Tag. Nach der aktuellen Prüfung dürfen die Messzeiten höchstens fünf Minuten auseinanderliegen. |
| Passender Nestbesuch | Dieselbe positive ID, dasselbe Datum, und derselbe Beobachter; der Nestbesuch darf höchstens 60 Minuten vor oder nach der Eizeit liegen. |
| Einummern | Innerhalb des Messereignisses eindeutig; keine Nummer über der zugeordneten Gelegegröße. Zwei gemessene Eier benötigen zwei Zeilen. |
| Andere messende Person oder tatsächliche Verzögerung | Behalten Sie den wahren Beobachter und die wahren Zeiten bei. Erklären Sie eine fehlgeschlagene Ereigniszuordnung und geben Sie sie zur Prüfung weiter; ändern Sie keine wahrheitsgetreuen Werte, damit die Prüfung bestanden wird. Eine fehlende Zuordnung ist eine Warnung zur Nachprüfung, kein Beweis dafür, dass kein Nestbesuch stattgefunden hat. |

Tragen Sie bei einem Ei an der Oberfläche mit Winkel 90° und gemessenen 1 mm über dem Wasser
`float_location = surface`, `float_angle = 90`, `float_surface = 1` ein.
Lassen Sie bei einem untergetauchten Ei `float_surface` leer, statt `0` einzutragen.

Verwenden Sie die Schlupfprognose zur Planung der Kontrollen, nicht als Beweis für das Schlupfdatum. Behalten Sie die
Besuchsbelege und die beobachteten Schlupfanzeichen neben jeder Schätzung bei.

</details>

<a id="section-5"></a>

<details>
<summary><strong>5. Altvögel, Küken, und Bruten</strong></summary>

## 5. Altvögel, Küken, und Bruten

### Wenn Sie eine Familie finden

Erfassen Sie die tatsächlich angetroffenen Altvögel und jedes Küken. Lesen Sie die sichtbaren Markierungen
ab, notieren Sie das Verhalten der Altvögel, und erfassen Sie einen Wegpunkt mit Ihrem
Garmin-GPS. Halten Sie die Familie in Ihrem Notizbuch zusammen, damit die Einträge später
verknüpft werden können.

Erfassen Sie beide sozialen Elternvögel, wenn beide beobachtet und identifizierbar sind. Wenn nur
einer gesehen wird, erfassen Sie diesen Vogel; fügen Sie den abwesenden Partner nicht hinzu. Ein unberingter Elternvogel
benötigt dennoch eine Zeile mit X-X. Zwei beringte Küken benötigen zwei Zeilen, auch wenn ihre
einzelnen Farbringe gleich sind.

### Welche Familie ist es?

1. **Ist die Brut zuverlässig einem bekannten Nest zugeordnet?** Ja: Behalten Sie diese
   positive ID bei. Nein: Gehen Sie zu 2.
2. **Wurde das Nest nie gefunden?** Ja: Verwenden Sie die zugewiesene negative Brut-ID.
   Nein, die Herkunft ist lediglich unklar: Vergleichen Sie die Elternvögel mit der Eltern–Nest-
   Übersicht im To-Do-PDF; fragen Sie die Feldleitung, wenn die Zuordnung unklar bleibt.

Behalten Sie das führende Minuszeichen einer negativen ID bei. Es kennzeichnet eine mobile Brut
unbekannter Herkunft, kein gescheitertes Nest oder einen unidentifizierten Altvogel. Negative IDs gehören
nur in CAPTURES und RESIGHTINGS, niemals in NESTS oder EGGS.

Lassen Sie bei einem Altvogelfang, der eindeutig zu keinem Nest und keiner Brut gehört, `nest_id`
leer und tragen Sie den gps_id/point des Fangs ein. Dies ist keine Möglichkeit, eine
unbekannte Familienzuordnung zu erfassen: Eine Brut benötigt weiterhin ihre tatsächliche Zuordnung oder einen zulässigen
Weg mit leerer ID wie nachfolgend beschrieben.

### Geben Sie der Familie einen gemeinsamen Wegpunkt

Jeder Familiendatensatz dieser Begegnung muss dieselbe GPS-Geräte- und Punkt-
nummer tragen, mit demselben Datum und Gebiet. Dies gilt tabellenübergreifend: Wenn Küken
gefangen, die Eltern aber nur wiederbeobachtet wurden, benötigen ihre Datensätze dennoch
denselben Wegpunkt. Diese Einträge sind entscheidend, wenn eine fehlende
Nest-/Brutzuordnung rekonstruiert wird.

Beispielsweise verwenden zwei Kükenfänge und eine Eltern-Wiederbeobachtung bei GPS 4 / Punkt 214
alle `gps_id = 4` und `gps_point = 214`. Eine Punktnummer allein, ein Punkt von
einem anderen GPS, oder das gestrige Datum kann diese gemeinsame Begegnung nicht identifizieren.

Alle Datensätze dieser Familienbegegnung müssen bei der Nest- oder Brut-ID übereinstimmen,
wo eine eingetragen ist. Unterschiedliche nicht leere IDs am selben Datum, im selben Gebiet, und beim selben
gps_id/point lösen einen Eingabefehler aus, auch wenn die Küken-ID ebenfalls
eingetragen ist. Prüfen Sie das Notizbuch und die Familienidentität; erfinden Sie keinen zweiten
Wegpunkt, damit die Eingabe akzeptiert wird. Dies verhindert nicht, dass sich die Zuordnung eines Kükens
zwischen getrennten Begegnungen ändert, beispielsweise nach einer Vermischung von Bruten.

### Erfassen Sie das Verhalten des Altvogels

| Altvogelbeobachtung | `behav` |
|---|---|
| Küken hudern | `BC` |
| Mit Küken Nahrung suchen | `FC` |
| Mit Küken wachsam sein | `AC` |
| Verleiten mit scheinbar gebrochenem Flügel | `BW` |

`BC`, `FC`, und `AC` beschreiben einen Elternvogel mit Küken. `BW` allein besagt nicht, dass
einzelne Küken gesehen wurden: Ein Vogel kann bei Eiern oder Küken verleiten. Unterscheiden Sie
allgemeine Wachsamkeit `AT` von Wachsamkeit mit Küken `AC`.

### Wann bestätigt eine Beobachtung die Eltern–Nest-Zuordnung?

Wenn das To-Do-PDF Sie auffordert, die Nestzuordnung eines Elternvogels zu bestätigen, erfassen Sie, was
dieser Vogel am Nest oder bei der Brut tatsächlich tut. **Scharren (`SC`) kann die
Zuordnung nach einer klaren, nestbezogenen Beobachtung bestätigen.** Dafür müssen keine Küken
anwesend sein. Fügen Sie keine Kükenzeilen hinzu, wenn tatsächlich keine Küken angetroffen wurden.

Die Prüfung gilt für jeden Elternvogel separat. Einen Vogel zu bestätigen, bestätigt nicht
seinen Partner; die Familie kann daher weiterhin unter **Parents to resight
for nest association** erscheinen.

| Beobachtung des identifizierten Elternvogels | Erforderlicher Beleg für seine Nestzuordnung |
|---|---|
| Brüten `IN` | Eine passende nestbezogene Wiederbeobachtung: Der identifizierte Altvogel brütet auf diesem Nest. |
| Nestpflege `NM` | Eine passende nestbezogene Wiederbeobachtung: Der Altvogel pflegt dieses Nest. |
| Scharren `SC` | Eine passende nestbezogene Wiederbeobachtung: Der Altvogel scharrt am erfassten Nest/an der erfassten Nestmulde. Küken müssen nicht anwesend sein. |
| Verleiten mit scheinbar gebrochenem Flügel `BW` | Eine passende nestbezogene Wiederbeobachtung kann die Zuordnung bestätigen. Das Verleiten allein belegt nicht, dass Küken gesehen wurden. |
| Küken hudern `BC`, mit Küken Nahrung suchen `FC`, mit Küken wachsam sein `AC` | Eine passende brutbezogene Wiederbeobachtung. Erfassen Sie die begleitenden Küken so, wie sie tatsächlich angetroffen wurden, nach den nachfolgenden Regeln. |
| Anderes Verhalten | Drei passende nestbezogene Wiederbeobachtungen sind erforderlich; die erste Beobachtung zählt zu den dreien dazu. |
| Ein `?` in einem beliebigen Beinsegment | Das Ereignis liefert keinen Eltern–Nest-Beleg, außer ein bekannter Metallring identifiziert den Vogel zuverlässig über die Fanghistorie. Behalten Sie die beobachteten Fragezeichen bei. |
| Elternvogel mit Küken: `BC`, `FC`, oder `AC` | Befolgen Sie auch die nachfolgenden Regeln für begleitende Küken. `SC` und die anderen bestätigenden Verhaltensweisen lösen diese Anforderung allein nicht aus. |

Dies sind Codes für das Formularfeld `behav`. Verwenden Sie das tatsächlich beobachtete Verhalten,
nicht den Code, der am ehesten einen To-Do-Eintrag entfernt. Ein in der Nähe wachsamer Altvogel ist `AT`;
verwenden Sie `AC` nur für einen Altvogel, der mit Küken wachsam ist. Wenn mehrere Verhaltensweisen
beobachtet wurden, tragen Sie die zutreffenden Codes durch Kommas getrennt ein, beispielsweise `AT, IN`.

### Wie die Datenbank zwischen möglichen Elternvögeln auswählt

Die Datenbank beurteilt Männchen und Weibchen getrennt. Sie identifiziert zuerst den
Vogel und gewichtet dann die Belege, die diesen Vogel genau diesem Nest oder
dieser Brut zuordnen. Eine aus einer früheren Saison erkannte Farbkombination belegt
die Identität, nicht die Zugehörigkeit zu einem aktuellen Nest.

| Belege, stärkste zuerst | Wirkung auf die Eltern–Nest-Zuordnung |
|---|---|
| Ein qualifizierender direkter Fang | Ein nestbezogener Altvogel, der mit TN, TB, oder HA gefangen wurde oder mit Küken in `caught_with` erfasst ist, liefert einen direkten Zuordnungsbeleg. Auch ein zulässiger Altvogelfang, der über die genaue Familienbegegnung mit einem beringten Küken verknüpft ist, kann die Zuordnung belegen. Erfassen Sie die tatsächliche Methode/den tatsächlichen Kontext; wählen Sie niemals einen Fangcode, um das Ergebnis zu verstärken. |
| Eine bestätigende Wiederbeobachtung | Eine der oben genannten IN, NM, SC, BW, BC, FC, oder AC. Dies hat Vorrang vor einer anderen Identität, die nur durch wiederholtes anderes Verhalten gestützt ist. |
| Drei andere passende Wiederbeobachtungen | Drei tatsächliche, zulässige nestbezogene Beobachtungen derselben Identität, einschließlich der ersten. Dies sind Beobachtungsdatensätze, nicht die zwei getrennten Tage pro Elternvogel für Brutverlustbelege in Abschnitt 9. Teilen Sie keine einzelne Beobachtung auf und duplizieren Sie keine Zeilen, um drei zu erreichen. |
| Unzureichende oder widersprüchliche Belege | Die Zuordnung bleibt offen, wenn keine Identität ein qualifizierendes Niveau erreicht, oder mehrdeutig, wenn mehrere Identitäten das stärkste Niveau teilen. Die Datenbank wählt keinen Vogel allein deshalb aus, weil er in der Nähe gesehen wurde. |

Auch eine mehrdeutige Markierungszuordnung verhindert, dass dieser Kandidat als
geklärt gilt, selbst wenn einige seiner anderen Belege stark erscheinen. Lesen Sie die Markierungen besser ab
und geben Sie den Widerspruch zur Prüfung weiter; entfernen Sie die ursprüngliche Beobachtung nicht.

**Ein zunächst unbestätigter Vogel, der später an einem anderen Nest bestätigt wird.** Ein zuverlässig identifizierter
Altvogel kann zuerst bei einem Nest gesehen werden, ohne ausreichende Belege für
die Elternschaft, und anschließend an einem anderen Nest bestätigt werden. Wenn das spätere Nest einen
eindeutigen ausgewählten Elternvogel hat, der durch bestätigendes Verhalten oder einen qualifizierenden
direkten Fang gestützt ist, wird ein älterer, weiterhin unbestätigter Kandidat für denselben Vogel und dasselbe Geschlecht
aus der aktuellen Elternanzeige des früheren Nestes entfernt. Der spätere Beleg
muss an einem strikt späteren Feldtag liegen als alle Begegnungen dieses Kandidaten am früheren Nest.
Das frühere Nest bleibt in seinen normalen Aufgaben, wobei sein Elternvogel weiterhin
unbekannt ist oder geprüft werden muss; die Beobachtung selbst bleibt in der Datenbank.

Dies löscht keine unabhängig geklärte frühere Zuordnung, überträgt keine
Belege zwischen Nestern, und entscheidet nicht zwischen konkurrierenden starken Ansprüchen. Eine Begegnung am selben Tag
oder eine weitere Begegnung am früheren Nest nach der neuen Bestätigung
verhindert diese eng begrenzte Vorrangregel. X-X, gemeinsam verwendete Einzelfarbmarkierungen von Rekruten, und
mehrdeutige Identitätszuordnungen können diese nestübergreifende Verknüpfung nicht belegen. Männchen und
Weibchen werden unabhängig beurteilt, anhand der Belege bis zum Bezugsdatum.

Ein Fang mit mobilem Japannetz (`capture_method = MM`) beweist für sich allein nicht,
zu welchem Nest dieser Altvogel gehört. Bei einem zuverlässig identifizierten Vogel am selben
Nest können zulässige Beobachtungen vor und nach MM gemeinsam zählen: Ein
bestätigendes Verhalten oder drei passende Beobachtungen können die Zuordnung klären. Ein
späterer MM-Fang löscht keine unabhängig belegte Zuordnung.

Bei X-X ist dies anders: Es kennzeichnet einen unberingten Vogel des erfassten Geschlechts an diesem
Nest, kein über Begegnungen hinweg eindeutig identifizierbares Individuum. Beispielsweise ist ein
adultes Männchen, das an Tag 1 mit MM gefangen wird, nicht allein
durch diesen Fang als Elternvogel belegt. Ein männlicher X-X-Vogel, der dort an Tag 2 beim Brüten beobachtet wird, bestätigt stattdessen
einen unberingten männlichen Elternvogel. Wird ein anderes Männchen an Tag 3 erstmals mit
MM gefangen und markiert, nehmen Sie nicht an, dass es der Vogel von Tag 2 war. Das neu markierte
Männchen benötigt eine eigene bestätigende Beobachtung oder drei getrennte qualifizierende
Beobachtungen nach dem Fang. Diese X-X-Belege von einem anderen Tag werden nicht
auf ihn übertragen. Wenden Sie dieselbe Regel unabhängig auf Weibchen an.

**Freigegebene Entscheidung — Luke Eberhart-Hertel, 1 November 2026:** Bei einer eindeutigen bestätigenden
X-X-Wiederbeobachtung und einem einzigen zulässigen Fang mit `capture_status = F` (Erstberingung)
desselben Geschlechts, am selben Nest, und am selben Datum wird angenommen,
dass es sich um dasselbe anvisierte Individuum handelt. Diese Bestätigung vom selben Tag wird auf die
neu markierte Identität übertragen, auch bei einem MM-Fang, ohne dass spätere Sichtungen erforderlich sind.
Behalten Sie das tatsächliche Beobachtungsdatum bei. RESIGHTINGS hat kein Feld für die Beobachtungszeit;
erfinden Sie keine genaue Sichtungszeit oder Reihenfolge davor/danach. Die SQL-Berechnung
setzt den Zeitpunkt dieses verknüpften Belegs vorsichtig auf Datum und Uhrzeit des Fangs an diesem Tag.
Dieser abgeleitete Zeitstempel ist keine beobachtete Wiederbeobachtungszeit.

In einem erfundenen Beispiel bedeutet `sameDayXXIN + firstMM` einen beim
Brüten beobachteten X-X-Altvogel und einen zulässigen gleichgeschlechtlichen MM-Erstberingungsfang am selben Nest
an Tag 1. Ohne spätere Sichtungen wird die markierte Identität unter
dieser Annahme an Tag 1 geklärt. Dagegen bleibt bei X-X IN an Tag 1, gefolgt nur von einem ersten MM-Fang
an Tag 2, die neu markierte Identität offen. Hat dieser Vogel seine eigene
zulässige bestätigende X-X-Verknüpfung am selben Tag 2, liefert dies den Beleg für Tag 2
und erlaubt, einen älteren Platzhalter außer Gebrauch zu nehmen, ohne den Beleg von Tag 1 zu übertragen.

Es gibt keine eindeutige Verknüpfung bei mehreren konkurrierenden gefangenen Identitäten,
mehrdeutigen oder anderweitig unzulässigen Belegen, einem anderen Geschlecht oder Nest, bloßem Wiederfang,
oder Belegen nach dem Bezugsdatum. Für die Eindeutigkeitsprüfung der Erstmarkierung werden
alle zulässigen F-Identitätsschlüssel für dieses Geschlecht, dieses Nest, und dieses Datum gezählt, bevor Filter für spätere Belege
oder Mehrdeutigkeit angewendet werden. Ein konkurrierender Kandidat darf nicht ausgefiltert werden, um
eine eindeutige Verknüpfung herzustellen, nur weil ihm spätere Belege fehlen oder er eine spätere Mehrdeutigkeits-
prüfung nicht besteht. Doppelte Zeilen derselben Identität ergeben keine weitere Identität.
Ein späteres X-X bleibt separat.
Teilen Sie keine Datensätze auf und duplizieren Sie keine, um drei zu erreichen. Behalten Sie die ursprüngliche X-X/MM-
Verdrängungshistorie bei und geben Sie widersprüchliche starke Belege zur Prüfung weiter;
löschen Sie keine Beobachtungen und wählen Sie nicht stillschweigend zwischen konkurrierenden Vögeln aus.
Die Beleghierarchie, die Sieben-Tage-/36-Stunden-Fanggrenzen, und die Tag-Regeln bleiben
unverändert, ebenso die davon unabhängigen Schutzregeln für Ereignisse am selben Tag bei der Herkunft von Jungvögeln und beim Brut-
abschluss. Diese freigegebene Methode ersetzt die frühere pauschale Formulierung, dass am selben Tag keine Verknüpfung möglich sei.
Der Umfang der Überprüfung ist separat in den datierten Quellenhinweisen dokumentiert.

Die To-Do-Nachbeobachtung kann zwei Kalender-
tage nach dem Fang beginnen; dies ist getrennt von der 36-Stunden-Regel zur Fangstörung
in Abschnitt 8. Eine wegen der Zeitgrenze gesperrte Fanganweisung kann auch als
Wiederbeobachtungsarbeit erscheinen. Lesen Sie deshalb den To-Do-Hinweis, statt anzunehmen, dass jede Wiederbeobachtungs-
zeile eine unsichere Elternidentität bedeutet.

Lesen Sie so viel wie möglich von der Markierung ab. Die meisten vollständig farbberingten Altvögel lassen sich
an ihrer Unterbein-Kombination zuordnen; bei Vögeln, die sich durch einen Abstandshalter am oberen Bein unterscheiden,
muss auch dieser Teil abgelesen werden. Ein verifizierter Metallring kann einen Vogel identifizieren, wenn
seine beobachteten Farbmarkierungen unsicher sind. Andernfalls schließt ein `?` irgendwo in den vier
Beinfeldern dieses Ereignis als Beleg für die Elternzuordnung aus; es ist kein
Platzhalter, der zu jeder möglichen Farbe passt. Behalten Sie die ursprüngliche Beobachtung bei.
Ein X-X-Altvogel kann als aktueller Elternvogel erfasst werden, aber X-X kann nicht belegen,
dass es an einem anderen Nest oder an einem anderen Datum dasselbe unberingte Individuum ist.

Ein späterer Fang/eine spätere Beringung oder überzeugende Belege für einen anderen Elternvogel können
die ausgewählte Identität ändern. Ältere Beobachtungen dürfen nicht als neue
Sichtungen nach vorne kopiert werden. Prüfen Sie die aktualisierte Eltern–Nest-Übersicht und geben Sie widersprüchliche Markierungen,
Geschlechter, oder Daten zur Prüfung weiter, statt Beobachtungen passend zu ändern.

Die Anforderung im Feld ist eine tatsächliche gemeinsame Familienbegegnung: dasselbe Datum,
Gebiet, und derselbe gps_id/point. Die geprüften lokalen Zuordnungsregeln erzwingen diese gemeinsame
Begegnung und lehnen widersprüchliche Familien-IDs ab. Prüfen Sie die tatsächlichen Feldaufzeichnungen,
wenn die Eltern–Nest-Übersicht falsch erscheint; ein automatisches Ergebnis erlaubt nicht,
ein falsches Datum, einen falschen Wegpunkt, oder eine falsche Identität zu übergehen.

**Ein geklärter Elternvogel bedeutet keine tote Brut.** Eine Zeile kann aus **Parents
to resight for nest association** verschwinden, weil die Zuordnung jetzt belegt ist, während
die Brut auf Beringungs- oder Fahnenlisten bleibt. Die getrennten Prüfungen für vermuteten Tod
und den Abschluss der Kükenphase durch das Jugendstadium sind in [Abschnitt 9](#section-9) erläutert.

### Sichtungen und Handhabungen so eingeben, wie sie stattgefunden haben

Verwenden Sie die folgende Reihenfolge, damit keine Beobachtungen erfunden werden, um eine Meldung zu erfüllen.

| Begegnung | Datensätze und Reihenfolge der Einreichung |
|---|---|
| Elternvögel und Küken nur gesehen | Eine RESIGHTINGS-Zeile pro Vogel. Reichen Sie die Eltern- und Kükenzeilen gemeinsam ein. |
| Küken gefangen, Elternvögel nur gesehen | Speichern Sie zuerst die tatsächlichen CAPTURES-Zeilen mit Alter C. Reichen Sie danach die Eltern-RESIGHTINGS-Zeilen mit übereinstimmendem Datum, Gebiet, und vollständigem gps_id/point ein. Die gespeicherten Fänge erfüllen die Prüfung auf begleitende Küken beim Elternvogel. |
| Küken nur wiederbeobachtet; Elternvogel in der Hand untersucht, aber nicht bei der Betreuung von Küken beobachtet | Der Fang allein erfüllt nicht die Prüfung auf einen begleitenden Elternvogel bei der Küken-Wiederbeobachtung. Erfassen Sie den tatsächlichen Ablauf und geben Sie eine wahrheitsgetreue außergewöhnliche Begegnung zur Prüfung weiter; erfinden Sie kein Betreuungsverhalten. |
| Küken nach der Handhabung im Versteck fotografiert | Zuerst der Fang, dann eine separate H-Zeile mit den tatsächlichen Eltern-Wiederbeobachtungen; Abschnitt 7. |

Wenn Sie einen Verhaltenscode eingeben, der eine Beobachtung eines Elternvogels mit Küken bedeutet, aber
keinen begleitenden Kükendatensatz haben, prüfen Sie Ihre Notizen. Ergänzen Sie die tatsächlichen Küken-
Wiederbeobachtungen oder speichern Sie zuerst die tatsächlichen Kükenfänge, wenn dies der Ablauf war.
Erfinden Sie neben gefangenen Küken keine zusätzlichen Kükensichtungen.

Diese Unterscheidung gilt nur in einer Richtung: Ein **gespeicherter Kükenfang** kann
die Prüfung auf der Elternseite erfüllen. Eine Küken-**Wiederbeobachtung** benötigt weiterhin den beobachteten Elternvogel
in derselben RESIGHTINGS-Einreichung. Ein gestern eingetragener Elternvogel — oder einer, der heute in einer
früheren Einreichung gespeichert wurde — ist nicht automatisch in den gerade
geprüften Zeilen enthalten. Teilen Sie eine Familiensichtung nicht auf getrennte Einreichungen auf.

### Hilfstabelle — Verknüpfungen zwischen Eltern- und Küken-Wiederbeobachtungen

| Prüfung | Anforderung |
|---|---|
| Elternvogel | `age = A`; das tatsächliche Verhalten enthält `BC`, `FC`, oder `AC`. |
| Unsichere Elternmarkierungen | Erfassen Sie das Abgelesene. Enthält ein beliebiges Beinsegment `?`, kann das Ereignis keinen Eltern–Nest-Beleg liefern, außer sein bekannter Metallring lässt sich zuverlässig zur Fanghistorie zurückverfolgen. Tragen Sie diesen bekannten Code in `ring` ein; ersetzen Sie beobachtete Fragezeichen nicht durch abgeleitete Farben. Alte Fanghistorie belegt die Identität, nicht die Nestzuordnung einer früheren Saison. |
| Küken | Eine separate Zeile mit `age = C` für jedes wiederbeobachtete Küken, einschließlich H-Zeilen. |
| Übereinstimmende Begegnung | Dasselbe Datum und entweder dieselbe gültige ID oder derselbe vollständige gps_id/point. Behalten Sie für die Feldaufzeichnung das gemeinsame Familiendatum, das Gebiet, und den gps_id/point auch dann bei, wenn die ID bekannt ist. |
| Elternseite | Verknüpfte Kükenzeile in der Einreichung oder ein bereits gespeicherter Fang mit Alter C mit genau demselben Datum, Gebiet, und vollständigem gps_id/point. Ein ungespeicherter Fang in einem anderen Formular kann nicht geprüft werden. |
| Seite der Küken-Wiederbeobachtung | Verknüpfte Elternzeile in der aktuellen Einreichung; frühere Elternhistorie liefert Identitätsbelege, keine neue Beobachtung. |
| Historie des positiven Nestes | Beobachtungen von Elternvögeln mit Küken benötigen den letzten relevanten Nestzustand `H` oder `notA` am oder vor dem Begegnungsdatum. Erfinden Sie keine Schlupfbelege, um dies zu erfüllen. |
| Außergewöhnliche Begegnung | Erklären Sie eine tatsächlich fehlende Eltern-/Begleiterbeobachtung; Abschnitt 12. |

### Wann die Nest- oder Brut-ID leer bleiben kann

Tragen Sie sie immer ein, wenn sie bekannt ist. Ermitteln Sie die ID anhand der Elternkombinationen
mithilfe der Eltern–Nest-Übersicht im To-Do-PDF. Die folgenden Ausnahmen gelten für
bestehende, zuverlässige Familienzuordnungen und erlauben nicht, ein nahe gelegenes Nest auszuwählen.

| Situation der Wiederbeobachtung | Bedingungen vor dem Weglassen von `nest_id` |
|---|---|
| Gewöhnliches Küken, Klasse `R`, `P`, `V`, oder `C` | Beide GPS-Felder und mindestens ein Elternvogel mit Alter A und `BC`, `FC`, oder `AC` in derselben Einreichung an genau diesem Datum und gps_id/point. Jeder qualifizierende Elternvogel benötigt eine gültige aktuelle oder auflösbare frühere Zuordnung; die Familie muss ein eindeutiges Nest-/Brutergebnis liefern. Wiederbeobachtungen der Klasse P oder V behalten ihre Kamera-/Bildbereichsanforderungen; `ring` bleibt optional. |
| Ein oder beide Elternvögel erfasst | Einer oder beide können die Zuordnung liefern; zwei demselben Nest zugeordnete Elternvögel ergeben weiterhin eine einzige eindeutige ID. Widersprüchliche oder ungeklärte Identitäten liefern keine abgeleitete Zuordnung. |
| Familie mit negativer Brut-ID, mit leeren IDs in Eltern- und Kükenzeilen | Die bestätigten Elterndatensätze in der Datenbank müssen bereits beide sozialen Elternvögel eindeutig für eine negative Brut identifizieren; keiner darf ungeklärt sein. Jeder tatsächlich gesehene Elternvogel muss seiner ausgewählten Identität entsprechen und `BC`, `FC`, oder `AC` aufweisen; alle Zeilen teilen Datum, Gebiet, und vollständigen gps_id/point. Ein beobachteter Elternvogel genügt; fügen Sie seinen abwesenden Partner nicht hinzu. |
| Küken mit Versteckfoto | Bei neuen H-Zeilen ist kein Weglassen zulässig. Tragen Sie neben Ring, beiden GPS-Feldern, und vollständigen Fotofeldern auch die ausdrückliche positive/negative ID ein; Abschnitt 7. |
| Erster Kükenfang | Es gilt keine Wiederbeobachtungsausnahme. Eine CAPTURES-Zeile mit Alter C und Status F benötigt die tatsächliche positive Nest- oder negative Brut-ID. |

Die Suche der Software nach gespeicherten Familien ist keine rein ortsbezogene Vermutung. Fehlende,
noch unbestätigte, oder mehrdeutige Elternidentitäten können eine ausgelassene ID nicht ersetzen. Tragen Sie die
bekannte ID ausdrücklich ein oder geben Sie die ungeklärte Zuordnung zur Prüfung weiter, statt
die Mehrdeutigkeit zu umgehen. Abgeleitete Zuordnungen füllen das ursprünglich leere Feld nachträglich nicht aus.
Ein Elternvogel eines positiven Nestes benötigt weiterhin seine erforderliche ID; die Ausnahme, bei der
sowohl Eltern- als auch Küken-IDs leer sein dürfen, ist der oben beschriebene Fall einer Familie mit negativer Brut-ID.

### Ein unberingter Elternvogel oder kein Elternvogel gesehen

Betreut ein unberingter Elternvogel Küken, erfassen Sie ihn als X-X: mindestens
`LL = X`, `LR = X`. Ergänzen Sie sein tatsächliches Verhalten, Alter, Geschlecht, Beobachter, Datum, Gebiet,
die erforderliche ID, und den gemeinsamen gps_id/point. X-X erfasst einen unberingten Vogel bei dieser Begegnung;
es identifiziert dieses Individuum nicht über mehrere Tage hinweg und kann für sich allein
die obige Ausnahme zur Elternidentität nicht begründen.

Wenn kein Elternvogel gesehen wurde, erfassen Sie jedes Küken und den Begegnungswegpunkt. Ergänzen Sie einen
konkreten Kommentar, etwa „Zwei beringte Küken wiederbeobachtet; während dieser Begegnung kein betreuender
Altvogel gesehen.“ Dies ist eine berechtigte Ausnahme wegen eines fehlenden Elternvogels. Verwenden Sie
die dokumentierte Umgehung nur, wenn die wahrheitsgetreue Eingabe nach Prüfung der übrigen Felder weiterhin blockiert ist.
Eine unbekannte ID benötigt eine eigene Erklärung; ein abwesender
Elternvogel kann keine fehlende Familienzuordnung liefern.

Vergleichen Sie vor dem Speichern die Vogelanzahl, den gemeinsamen Wegpunkt, und die IDs mit Ihrem
Notizbuch. Ist die Familienzuordnung unsicher, nehmen Sie dies in die Übergabe auf.

</details>

<a id="section-6"></a>

<details>
<summary><strong>6. Fänge, Farbringe, Metallringe, Fahnen, und Tags</strong></summary>

## 6. Fänge, Farbringe, Metallringe, Fahnen, und Tags

### Erfassen Sie den Vogel vor und nach der Handhabung

Geben Sie jedem gefangenen Vogel einen neuen Fangdatensatz. Lesen Sie vor Änderungen seinen Metallring und alle
Beinmarkierungen ab. Erfassen Sie die Markierungen beim Fang getrennt von
jenen bei der Freilassung. Vergleichen Sie Probenbeschriftungen und Tag-Nummern mit dem Ring,
solange die Identität des Vogels eindeutig ist.

### Welcher Fangstatus?

1. **War der Vogel beim Auffinden tot?** Ja: `D`, mit den Umständen im
   Kommentar. Nein: Gehen Sie zu 2.
2. **War dies seine erste Markierung?** Ja: `F`. Nein: Gehen Sie zu 3.
3. **Hat sich die Kombination geändert?** Ja: `C`. Nein: `R`.

| Status | Eingangsfelder `UL_in`, `LL_in`, `UR_in`, `LR_in` | Freilassungsfelder `UL`, `LL`, `UR`, `LR` |
|---|---|---|
| `F` | `X` in allen vier Feldern gemäß der geprüften Eingaberegel. | Tatsächliche neue Markierungen; nicht überall X. |
| `R` | Vollständige vorhandene Markierungen. | Dieselbe Kombination wie beim Eingang. |
| `C` | Vollständige vorherige Markierungen mit mindestens einer markierten Position. | Tatsächlich geänderte Kombination; mindestens eine Position unterscheidet sich. |
| `D`, in jedem Alter | Tatsächlich beim Totfund vorhandene Markierungen an allen vier Positionen; X verwenden, wo keine Markierung vorhanden ist. Ein Küken oder Jungvogel kann eine Fahne tragen oder nicht. | Alle vier Felder leer lassen; keine Freilassungszeit. Tragen Sie bei einem toten Vogel keine Fahne als Freilassungsmarkierung ein. |

Verwenden Sie in keinem Beinfeld eines Fangs `?`, auch nicht in Eingangsfeldern.
Der Vogel wird unmittelbar untersucht. Ersetzen Sie eine unlesbare Markierung nicht durch
`X`; erklären Sie eine außergewöhnliche beschädigte/unlesbare Markierung und geben Sie sie zur Prüfung weiter.

### Hilfstabelle — Fangangaben

| Feld(er) | Anforderung | Eingabe |
|---|---|---|
| `date`, `caught`, `species`, `site`, `observer`, `capture_status`, `capture_method`, `field_sex`, `age`, `ring` | Erforderlich | Tatsächliche Identität des gefangenen Vogels, örtliches Datum/Uhrzeit, und CP-Metallringcode. |
| `released` | Lebende Freilassung | Tatsächliche Freilassungszeit nach dem Fang. Bei Totfund leer. |
| `nest_id` | Abhängig von der Zuordnung | Tragen Sie die bekannte positive oder negative ID ein. Ein erster Kükenfang muss eine haben. Bei einem ansonsten gültigen späteren Kükenfang mit leerer ID kann der Snapshot die Brutzuordnung aus eindeutiger früherer Ringhistorie wiederherstellen; ereignisspezifische Eingabeprüfungen gelten weiterhin. Behalten Sie den tatsächlichen Ring und beide GPS-Felder bei. Geben Sie widersprüchliche Historie zur Prüfung weiter, statt zu raten. Bei einem Altvogelfang ohne Nest-/Brutbezug lassen Sie dieses Feld leer und tragen Sie gps_id/point ein. Verwenden Sie keinen Platzhalter. |
| `gps_id`, `gps_point` | Bedingt | Verwenden Sie die genaue Status-/Ortstabelle in Abschnitt 3. Alter C mit Status R oder C erfordert immer beide Felder. |
| Eingangs- und Freilassungsfelder der Beine | Statusabhängig | Verwenden Sie die obige Tabelle und die tatsächliche Reihenfolge der Markierungen. Keine Fragezeichen. |
| `caught_with` | Wenn Begleiter mit dem betrachteten Vogel gefangen wurden | Codes/Anzahlen wie `M` oder `2C`. Ein mit Küken gefangener Altvogel benötigt den direkten gps_id/point. Dies ersetzt keine individuellen Vogeldatensätze. |
| `parents` | Küken-/Jungvogelkontext, wenn beurteilt | Geschlechterzusammensetzung der anwesenden Eltern aus Anhang A; nicht die Identitäten der Eltern. Bei Altvögeln leer. |
| `eggs_handled` | Wenn die Handhabung von Eiern während des Fangs erfasst wird | `0` nein / `1` ja. Nur CAPTURES. |
| `book_id`, `form_id` | Bei Verwendung von Fangbuch/-formularen | Buch- und Seitenkennungen aus der Papieraufzeichnung. |
| `observer_upload` | Person, die den Fang hochlädt | Registrierter Beobachtercode der Person, die den Datensatz eingibt. |
| Fotofelder und Kennzeichen | Ereignisabhängig | Abschnitt 7. Tags: Abschnitt 8. |

### Messungen, Proben, und Fotos nach Alter

Verwenden Sie mm für Längen und g für die Masse. Befolgen Sie die Messtechnik des Teams;
ersetzen Sie die Tarsus- oder Flügelmethode nicht durch eine andere, nur weil die Einheiten übereinstimmen.

| Vogel | Erforderliche Messungen/Einträge in der geprüften Prüfliste | Bedingt, optional, oder leer |
|---|---|---|
| Altvogel, `age = A` | `tarsus`, `culmen`, `total_head`, `head_white`, `head_black`, `rufous_band`, `wing`, `weight`; `brood_patch` 0/1; mindestens ein Mauserwert; `fat` 1–8; `feather_wear` 0–3; `breast_samp`, `primary_samp`, `mugshot_photo`, `wing_photo` 0/1. | `parents` leer. Kükenfoto-Kennzeichen leer/0. Blut-/andere Proben nur, wenn entnommen. Erklären Sie eine Messung, die nicht sicher erhoben werden konnte; erfinden Sie sie nicht. |
| Küken, Status F oder R | `tarsus`, `culmen`, `weight`; Geschlecht `U`. Erstes F benötigt zusätzlich `chick_tent_photo` und `chick_hide_photo` 0/1; verwenden Sie `chick_hide_photo = 0` für dieses Verfahren mit separatem H. | Keine Einträge für `total_head`, `head_white`, `head_black`, `rufous_band`, `wing`, `brood_patch`, Mauser, Fett, oder Federabnutzung. `breast_samp`/`primary_samp` leer oder 0; Porträt-/Flügelkennzeichen leer. Kükenfoto-Kennzeichen bei R dürfen leer oder 0/1 sein. |
| Älteres Küken, geänderte Kombination C | `tarsus`, `culmen`, `weight`; Geschlecht `U`; vollständige Markierungen vorher/nachher und beide GPS-Felder. | Zusätzliche Messungen bei älteren Küken, Proben, und unterstützte Fotokennzeichen dürfen eingetragen werden, wenn sie erhoben wurden; sie werden nicht allein durch Status C sämtlich verpflichtend. |
| Küken tot aufgefunden, Status D | `tarsus`, `culmen`, `weight`; Geschlecht `U`; tatsächlich beim Totfund vorhandene Markierungen an allen vier Eingangspositionen. | Die Einschränkungen für Alter C bei anderen Messungen/Proben gelten weiterhin. Freilassungs-Beinfelder und Freilassungszeit leer; keine Erstmarkierungs-Fotopflicht allein aufgrund des Fundes. Erklären Sie alles, was nicht wahrheitsgetreu gemessen werden konnte. |
| Jungvogel, `age = J` | `tarsus`, `culmen`, `weight`; Geschlecht `U`. | `total_head`, Kopfband-/rostfarbene Bandbreiten, und `brood_patch` leer. Flügel darf erfasst werden. `breast_samp`/`primary_samp` leer oder 0; Kükenfoto-Kennzeichen leer/0. |
| Küken oder Jungvogel | Keine Tag-Einträge. | `tag_action`, `tag_type`, `tag_id`, `tag_id_in` leer lassen — nicht O. |

Verwenden Sie für Blut `BQ` (Queens-Puffer), `BF` (Filterpapier), oder `BE` (EDTA);
lassen Sie das Feld leer, wenn kein Blut entnommen wurde. Federproben-Kennzeichen verwenden 0/1, nicht die Blut-
codes. Beschriften Sie jede Probe so, dass sie dem Ring des Vogels und dem Ereignis zugeordnet werden kann.

Bei den Messungen ist der äußere Tarsus das Diagonalmaß von der hinteren
Kerbe am oberen Ende bis zur letzten vorderen Hornschuppe am Fuß; die sichtbare Schnabelfirstlänge reicht
vom Stirngefieder bis zur Schnabelspitze. Die Gesamtkopflänge reicht von der Schnabelspitze bis zum Hinterkopf;
die Flügellänge ist die maximale Länge des abgeflachten und gestreckten Flügels. Verwenden Sie die erlernte Technik,
nicht diese Kurzbeschreibungen allein.

### Markierungen an der linken und rechten Seite des Vogels ablesen

Lesen Sie übereinanderliegende Ringe von oben nach unten ab. `BG` und `GB` bezeichnen unterschiedliche Reihenfolgen.

| Position | Beobachtungs-/Freilassungsfeld | Eingangsfeld beim Fang |
|---|---|---|
| Linkes oberes Bein / Tibia | `UL` | `UL_in` |
| Linkes unteres Bein / Tarsus | `LL` | `LL_in` |
| Rechtes oberes Bein / Tibia | `UR` | `UR_in` |
| Rechtes unteres Bein / Tarsus | `LR` | `LR_in` |

| Abgelesene Markierung | Einzutragender Wert |
|---|---|
| Zwei rote Ringe | `RR`, nicht R,R. Farben: Anhang A. |
| Metallring | `M` im Beinfeld; individuelle Metallringnummer in `ring`. |
| Vollständige gravierte Fahne | F + Farbe + Gravur im oberen Beinfeld, z. B. `FWAB`. |
| Wiederbeobachtung: Rot über einem nicht abgelesenen Ring | `R?` im passenden Segment, z. B. `LL = R?`. |
| Wiederbeobachtung: Nicht abgelesener Ring über Rot | `?R` im passenden Segment. |
| Wiederbeobachtung: Ringe gesehen, aber keinen sicher abgelesen | `?` in diesem Segment. Tragen Sie nicht X ein und lassen Sie es nicht leer, als wären keine Markierungen gesehen worden. |
| Wiederbeobachtung: Tag mit gelbem Abstandshalter | `UR = TY`. |
| Wiederbeobachtung: Tag mit unlesbarer Abstandshalterfarbe | `UR = T?`. T allein ist nicht zulässig. |
| Unberingter Vogel wiederbeobachtet | X-X: mindestens `LL = X`, `LR = X`; weitere Ereignisfelder ausfüllen. |

Die Unsicherheitsnotation gilt für alle vier Beinsegmente in RESIGHTINGS. Sie gilt
nicht für CAPTURES und schafft kein neues Format für unvollständige Fahnencodes. Erklären Sie eine
teilweise abgelesene Gravur im Kommentar; raten Sie nicht. Eine unvollständige Markierung erfasst,
was Sie gesehen haben, identifiziert einen Elternvogel aber möglicherweise nicht zuverlässig genug, um seine ID wegzulassen.

### Kükenringe und spätere Fahnen

Im Beringungssystem von Cass River tragen Küken mit Status F oder R eine Farbe in LL und Metall M in UR; leere UL/LR-
Positionen werden im Fangdatensatz als X dargestellt. Geschwister können dieselbe Farbe tragen;
nur ihre Metallringe unterscheiden sie individuell.

Befolgen Sie die To-Do-Liste **Broods to recapture for flagging** und die Beurteilung
der Feldleitung. Die aufgeführte Nachkontrolle beginnt ab 21 Tagen; dies ist kein Beweis
dafür, dass ein Küken bereit ist. **Bringen Sie bei einem Küken unter 22 g oder unter 27 mm Tarsuslänge keine Fahne an.**
Das Erreichen dieser Grenzwerte ersetzt nicht die tierschutzbezogene Beurteilung der beringenden Person.

Einem bereits beringten Küken eine gravierte Fahne anzulegen, ändert seine Kombination:
Verwenden Sie Fangstatus C, behalten Sie die Eingangsmarkierungen bei, und erfassen Sie die tatsächlichen Freilassungs-
markierungen. Das Markierungssystem für Jungvögel verwendet eine gravierte UL-Fahne, UR-Metall, und
leere untere Positionen; ändern Sie das Alter nicht allein, damit eine Anordnung akzeptiert wird.

### Warum Aufgaben zum Anlegen von Fahnen erscheinen oder verschwinden

Der aktualisierte Snapshot verwendet die letzte qualifizierende Kükenbegegnung am oder vor
dem Bezugsdatum des PDFs, nicht einfach die größte frühere Kükenanzahl. Die
Aufgabenentscheidung und **N chicks / N seen** im PDF verwenden dasselbe SQL-Ergebnis.
Direkte Nest-IDs, eindeutige frühere Ringhistorie, und zulässige GPS-verknüpfte Familien-
datensätze können die Brutzuordnung liefern. Ein späterer Fang mit leerer Nest-ID kann
daher seine Fahne über den früheren Fang desselben Rings einbringen.

Verschiedene bekannte Küken zählen jeweils einmal; wiederholte Zeilen für denselben Ring erhöhen
die Kükenanzahl nicht. Die Fahnenanzahl betrifft genau diese Individuen der letzten Begegnung,
nicht ein anderes, früher mit einer Fahne versehenes Geschwister. Beispielsweise wurden ursprünglich drei Küken
gefangen, die letzte qualifizierende Begegnung enthält jedoch nur ein
identifiziertes Küken, und dieses trägt bereits eine Fahne: Es bleibt keine Aufgabe zum Anlegen von Fahnen.
Zwei zuletzt angetroffene Küken, von denen nur eines eine Fahne trägt, oder ein zuletzt angetroffenes Küken ohne Fahne lassen weiterhin
Arbeit offen. Diese Verringerung der operativen Aufgaben erklärt vermisste Geschwister nicht
für tot und klärt ihren individuellen Verbleib nicht.

Unberingte, mehrdeutige, oder anderweitig ungeklärte Belege dürfen die
Aufgabe nicht fälschlich abschließen. Bestätigt tote Küken sind keine lebenden Zieltiere; ihre überlebenden Geschwister
bleiben getrennte Arbeit. Wenn es keine verwendbare letzte Begegnung gibt, greift der Snapshot
auf seine Kükenanzahl aus Fanghistorie/operativer Planung zurück und behält seine
bestehenden Schutzregeln für ungeklärte Belege bei. Eine fehlende Anzahl beweist nicht,
dass null Küken übrig sind. Melden Sie eine Abweichung, statt Beobachtungen zu ändern,
um eine Aufgabe zu entfernen.

Verwenden Sie nur die vom Team zugeteilten Kombinationen aus dem aktuellen To-Do-PDF und
von der Feldleitung. Verwenden Sie eine Kombination niemals erneut, nur weil ihr bisheriger Vogel
in letzter Zeit nicht gesehen wurde. Die Anzeige einer scheinbar verfügbaren Markierung ersetzt
nicht die Zuteilung durch das Team.

</details>

<a id="section-7"></a>

<details>
<summary><strong>7. Fotos und Umgang mit Medien</strong></summary>

## 7. Fotos und Umgang mit Medien

### Den Bildbereich unmittelbar bei der Begegnung notieren

Notieren Sie für jede Bildserie das Motiv, die Kamera-ID, und den ersten/letzten Dateinamen.
Notieren Sie bei Kükenfotos auch den individuellen Ring. Prüfen Sie die Notizen,
solange Sie die Bilder noch den Vögeln und dem Ort zuordnen können.

Ein Zeltfoto dokumentiert das Handling; ein Versteckfoto zeigt das Küken an
seinem Versteck. Halten Sie ihre Bildbereiche getrennt, auch bei derselben Gelegenheit.
Ein Kontrollkästchen im Fangformular allein dokumentiert kein anrechenbares Versteckfoto.

### In welchen Datensatz gehören die Fotos?

1. **Zeigt das Foto ein Küken an seinem Versteck?** Ja: eine eigene H-Wiedersichtung für
   jedes fotografierte Küken. Nein: weiter zu 2.
2. **Zeigt das Foto ein Küken beim Handling im Zelt?** Ja: seine
   Fangzeile, mit `chick_tent_photo = 1`. Nein: weiter zu 3.
3. **Zeigt das Foto ein Gelege in der Nestmulde oder im Zelt?** Ja: der NESTS-
   Besuch mit den zutreffenden Fotokennzeichen. Nein: weiter zu 4.
4. **Ist es ein Foto vom Handling eines Altvogels?** Ja: die Fotokennzeichen
   und der Bildbereich beim Fang. Nein: P für eine Foto-Wiedersichtung oder V für eine Videositzung verwenden.

| Foto/Sitzung | Tabelle und Felder | Getrennt halten von |
|---|---|---|
| Gelege in der Nestmulde / im Zelt | `NESTS`: `nest_photo` / `tent_photo`, dazu `cam_id`, `photo_start`, `photo_end`. | Schwimmproben-Messwerten in EGGS. |
| Küken beim Handling/im Zelt | `CAPTURES`: `chick_tent_photo = 1`, Kamera/Bildbereich. | Bildern vom Versteck. |
| Altvogelporträt / Flügel | `CAPTURES`: `mugshot_photo` / `wing_photo`, Kamera/Bildbereich. | Einer eigenen Wiedersichtung im Feld. |
| Versteck eines Kükens | `RESIGHTINGS`: `rclass = H`, ausdrücklich eingetragene positive/negative `nest_id`, individueller Ring, direktes GPS, und Kamera/Bildbereich. | Allen CAPTURES-Fotobereichen. |
| Sonstige Fotos / Videos | `RESIGHTINGS`: `rclass = P` / `V`, Kamera/Bildbereich, und die normalen Ereignisangaben. | Einer normalen R-Zeile ohne Medien. |

### Ein Küken am Versteck fotografieren

Halten Sie genügend Angaben fest, damit jedes fotografierte Küken seinem Ring, Versteck,
und seinen Bildern zugeordnet werden kann. Geben Sie jedem Küken eine eigene Zeile im
Notizbuch. „Zwei Küken fotografiert“ sagt nicht, welche zwei Individuen erledigt sind.

Wenn das Küken beim Versteckfoto noch unberingt ist, muss es auch nach dem
normalen Kükenprotokoll gefangen und beringt werden. Tragen Sie die Beringung
in CAPTURES ein und das Versteckfoto in eine eigene H-Zeile in RESIGHTINGS.
Verfolgen Sie das einzelne Küken durch die gesamte Foto- und Handling-Abfolge,
damit die H-Zeile den richtigen, neu vergebenen Ring dieses Kükens enthält.

Wenn das Küken bereits beringt ist und ohne Fang fotografiert wird,
tragen Sie nur die H-Wiedersichtung ein; legen Sie keinen neuen Fangdatensatz an. Sein früherer
Fang muss bereits gespeichert sein, damit der Ring geprüft werden kann. Wenn das Küken
tatsächlich erneut gefangen wird, tragen Sie diesen echten Wiederfang in CAPTURES ein,
zusätzlich zur eigenen H-Wiedersichtung. Ein Zeltfoto bleibt, falls aufgenommen, beim Fang.

Nehmen Sie den Familien-Wegpunkt mit Ihrem Garmin-GPS auf, auch wenn das positive Nest
bekannt ist. Tragen Sie den oder die Elternvögel und die anderen Familienmitglieder ein,
die bei dieser Gelegenheit tatsächlich wiedergesehen wurden, alle mit demselben
Datum, Gebiet, und vollständigen gps_id/point. Ein beobachteter Elternvogel reicht;
für einen abwesenden Partner ist keine Zeile erforderlich. Ein unberingter Elternvogel
wird als X-X eingetragen und nicht weggelassen.

### Ergänzende Tabelle — eine H-Zeile pro fotografiertem Küken

| Feld(er) | Anforderung | Eintrag |
|---|---|---|
| `species`, `site`, `date`, `observer` | Erforderlich | Tatsächliche Begegnung im Feld: BADO und Ihr freigegebener Gebietscode, zum Beispiel CR für Cass River. |
| `age`, `sex`, `rclass` | Erforderlich | `C`, `U`, `H`. |
| `ring` | Erforderlich | CP-Metallring des fotografierten Kükens, z. B. `CP12345` oder `CP-12345`. Sein Fang muss bereits in CAPTURES der aktuellen Saison gespeichert sein. |
| `UL`, `LL`, `UR`, `LR` | Beobachtete Markierungen zusätzlich zum Ring erforderlich | Tragen Sie die gesehene Anordnung ein, einschließlich der unterstützten Unsicherheitsnotation. Der Ring ersetzt die Beinfelder nicht. Raten Sie bei einer unlesbaren Farbe oder Metallringposition nicht. |
| `nest_id` | Für jede neue H-Zeile erforderlich | Ausdrücklich eingetragene gültige positive Nest- oder negative Brut-ID. Ring- oder Elternhistorie hebt diese Eingabepflicht nicht auf. |
| `gps_id`, `gps_point` | Erforderlich | Beide für diese Versteckfoto-Begegnung, auch bei Küken eines positiven Nests. |
| `cam_id`, `photo_start`, `photo_end` | Erforderlich | Tatsächliche Kamera und vollständiger Bildbereich der Versteckfotos. Das Ende darf nicht vor dem Anfang liegen. |
| `behav` | Bei H optional | Leer lassen, wenn nicht gesondert notiert; jeder eingetragene Code muss zu einem Küken passen. |
| Eltern-Wiedersichtung | Erforderlich, außer bei einer tatsächlichen Begegnung ohne Elternvogel | Beobachteter Elternvogel mit Alter A und `BC`, `FC`, oder `AC` in derselben Übermittlung; Abschnitt 5. |

Speichern Sie den Fang des Kükens, bevor Sie die H-Zeile übermitteln, damit sein Ring
geprüft werden kann. Belassen Sie den Zelt-Bildbereich bei diesem Fang. Setzen Sie in diesem Ablauf
`chick_hide_photo` beim Erstfang des Kükens auf 0; wo dieses Kennzeichen optional ist,
kann es leer/0 bleiben. Tragen Sie die tatsächlichen Versteckfotos in H-Zeilen ein,
statt das Fangkennzeichen auf 1 zu setzen.

Normale Wiedersichtungen mit R/Klasse P oder V/C dürfen `ring` leer lassen. Bei einem H-Foto ist das nicht zulässig:
Die Farbringe von Geschwistern allein unterscheiden das fotografierte Küken nicht.

<details>
<summary><strong>Die Nest- oder Brut-ID für die H-Zeile finden</strong></summary>

### Die gesicherte Familienzuordnung nutzen, nicht GPS allein

Jede neue H-Zeile mit Alter C benötigt eine ausdrücklich eingetragene ID. Nutzen Sie die
Parent–Nest-Übersicht im To-Do-PDF und die gespeicherte Ring-/Fanghistorie des Kükens,
um die Familie zu prüfen. Eine teilweise abgelesene Markierung oder ein Wegpunkt
allein reicht nicht, um zwischen Familien zu wählen. Wenn die ID nicht zuverlässig
festgestellt werden kann, bewahren Sie das Foto, den Ring, und die Begegnungsnotizen auf,
und bitten Sie Luke Eberhart-Hertel, die Zuordnung zu klären; raten Sie nicht und nutzen Sie nicht die normale
Ausnahme für eine leere ID, um eine H-Zeile zu übermitteln.

| Familiensituation | Erforderliche Zuordnung |
|---|---|
| Die aktuelle positive/negative ID des Elternvogels ist bekannt | Tragen Sie diese ID in die H-Zeile ein und prüfen Sie sie anhand der verlässlichen Küken-/Familienhistorie. Tragen Sie den oder die tatsächlich gesehenen Elternvögel ein; erfinden Sie keinen abwesenden Partner. |
| Eine normale Familien-Wiedersichtung erfüllt die Ausnahme für eine leere ID nach Abschnitt 5 | Diese Ausnahme gilt nicht für eine H-Zeile. Tragen Sie beim H-Küken die ausdrückliche Nest-/Brut-ID ein. |
| Die frühere Ring-/Familienzuordnung ist mehrdeutig | Bewahren Sie die Belege auf und bitten Sie Luke Eberhart-Hertel um Klärung, bevor Sie den H-Datensatz eingeben; wählen Sie keine ID nur deshalb, weil sie gerade passt. |

Ring, Beinbeobachtungen, gps_id/point, und Fotofelder bleiben Pflicht. Eine gültige
H-Zeile und erledigte Arbeit unter **Broods to photograph** sind unterschiedliche
Prüfungen. Die Software behält eindeutige Zuordnungen über die Ringhistorie für ältere
H-Datensätze bei, die nach dem früheren Verfahren mit leerer ID gespeichert wurden.
Das ist Kompatibilität mit historischen Einträgen und keine Erlaubnis, bei einer neuen
H-Zeile die ID leer zu lassen; historische Rohzeilen werden nicht stillschweigend umgeschrieben.

</details>

### Den Fortschritt anhand der einzelnen Ringe prüfen

Der To-Do-Vergleich zählt unterschiedliche gefangene Kükenringe und unterschiedliche
anrechenbare H-Foto-Ringe für dieses Nest/diese Brut. Wiederholte H-Zeilen für denselben
Ring zählen einmal. `CP12345` und `CP-12345` werden als derselbe Ring erkannt;
schreiben Sie den Ring einheitlich wie in den Fangnotizen, um die manuelle Prüfung zu erleichtern.

Drei gefangene Küken und nur zwei anrechenbare H-Foto-Identitäten lassen ein
Foto offen. Eine Brut ohne Belege für gefangene Kükenringe gilt nicht allein deshalb
als erledigt, weil beide Zahlen null sind. Eine ungeklärte H-Zuordnung kann die Arbeit
auf der Liste lassen, obwohl die Fotos aufgenommen wurden.

### Zwei unterschiedliche Zeitrechnungen

Nehmen Sie Versteckfotos auf, **bevor die Küken sieben Tage alt sind**. Das ist die biologische
Frist. Die To-Do-Anzeige nutzt einen datierten Eintrag, der nicht immer dem tatsächlichen
Alter des Kükens entspricht.

| Umstand | To-Do-Anzeigefenster | Was der Feldmitarbeiter beachten muss |
|---|---|---|
| Brut aus einem positiven Nest | Tage 1–6 nach dem Datum des Schlupfbelegs. | Tag 0 liegt nicht in diesem Anzeigefenster; nehmen Sie geeignete Fotos bei der Begegnung auf, statt auf die Liste zu warten. |
| Negative Brut unbekannter Herkunft | Tage 1–6 nach der Entdeckung. | Die Küken können beim Fund bereits älter sein. Die Entdeckung ist nicht das Schlupfdatum; Alter einschätzen und mit der Feldleitung priorisieren. |
| Tag 7 nach dem maßgeblichen Datum | Die To-Do-Aufgabe läuft aus. | Auslaufen ist keine Erledigung und verlängert das biologische Ziel unter sieben Tagen nicht. |

Nehmen Sie fehlende Fotos, unsicheres Alter, und ungeklärte Familienzuordnungen in die
Übergabe auf. Nutzen Sie das Verschwinden aus dem PDF nicht als Beweis, dass jedes Küken
fotografiert wurde.

### Medien kopieren und prüfen

Kopieren Sie die Originalbilder auf das zugewiesene Laufwerk und lassen Sie ihre Dateinamen
unverändert. Notieren Sie Laufwerk/Ordner im Medienregister des Teams; in den aktuellen
Tabellen NESTS, EGGS, CAPTURES, oder RESIGHTINGS gibt es kein Feld `harddrive_id`.
Löschen Sie die Kameraoriginale nicht vor der Sicherungsprüfung des Teams.

Prüfen Sie die Kamera und die vollständigen Bildkennungen, einschließlich etwaiger
Präfixe für Bildserie/Einzelbild. Beispielsweise sind `101-4122` und `102-4122` verschiedene
Bilder; die letzten vier Ziffern allein identifizieren sie nicht. Behalten Sie die vollständige
Bildkennung aus den Feldnotizen bei und nutzen Sie im Formular die bestehende
Dateinamenkonvention des Teams. Benennen Sie Originale nicht um, damit ein Bereich die Validierung besteht.

Mehrere H-Zeilen mit Alter C aus derselben Fotositzung dürfen denselben Bildbereich
haben, wenn Kamera und Datum gleich sind und entweder die gültige Nest-/Brut-ID oder
der vollständige gps_id/point übereinstimmt. Jedes Küken benötigt weiterhin seinen
eigenen Ring und seine eigene Zeile. Diese Ausnahme erlaubt nicht, einen CAPTURES-
Zeltbereich als H-Versteckbereich wiederzuverwenden.

Prüfen Sie vor dem Abschluss jede notierte Bildserie anhand der Dateien und des
aktualisierten To-Do-PDFs. Führen Sie eine Liste der offenen Arbeit pro Küken, nicht nur eine Brutsumme.

</details>

<a id="section-8"></a>

<details>
<summary><strong>8. Geolokatoren anbringen und zurückholen</strong></summary>

## 8. Geolokatoren anbringen und zurückholen

### Luke Eberhart-Hertels Anweisungen zum Anbringen befolgen

Die Geolokatoren werden über den Verlauf der Brutzeit verteilt angebracht, um
Stand- und Zugvögel gleichmäßig zu beproben. Bei frühen Nestern werden mehr
Standvögel erwartet, bei späteren mehr Zugvögel; der Nestzeitpunkt allein bestimmt
nicht, zu welcher Gruppe ein einzelner Vogel gehört.

Für das Anbringen 2026 am Cass River sind ungefähr 50 der 100 Geolokatoren in der ersten Brutwelle und 50
in der zweiten geplant. In einer möglichen dritten Welle werden Eltern mit
erneutem Brutversuch und Zweitbrut erwartet, eher als erstmals brütende Vögel.
Luke Eberhart-Hertel überwacht die Wellen und weist das Team an, das Anbringen
zu pausieren oder fortzusetzen.

Ziel ist, beide Partner ausgewählter aktiver Paare zu beproben und dadurch die
Geschlechter ausgewogen zu erfassen. Das ist ein Ziel auf Paarebene über die Zeit,
**keine Erlaubnis, beide Eltern bei einem Besuch zu fangen**. Jeder Vogel muss
unabhängig berechtigt sein. Wenn der Partner warten muss, lassen Sie ihn unbehandelt
und prüfen Sie später seine aktuellen To-Do-Anweisungen erneut.

### Vor einem Fangversuch

| Prüfung | Erforderliche Entscheidung im Feld |
|---|---|
| Aktuelles To-Do-PDF | Eine Anweisung **Parents to capture** für den vorgesehenen Vogel und Zweck. Ein reiner Wiedersichtungshinweis ist keine Anweisung zum Anbringen. |
| Identität und Tag-Status | Verlässliche Vogelidentität und aktueller Tag-Status. Unsichere Identität zuerst klären, außer die aktuelle To-Do-Anweisung erlaubt ausdrücklich die Bestätigung beim Fang. |
| Nest/Brut und Welle | Geeignete aktive Einheit, aktuelle Bearbeitungsanforderungen erfüllt, und Luke Eberhart-Hertels Wellenanweisungen erlauben das Anbringen. |
| Sieben-Tage-Abstand | Die geltende Freigabe ab Gelegevollständigkeit ist offen; nutzen Sie die aktuelle To-Do-Anweisung, nicht eine Zählung ab Nestentdeckung. |
| Sechsunddreißig-Stunden-Abstand | Die Störungssperre nach einem Elternfang ist abgelaufen. Die Paarvervollständigung hebt sie nicht auf. |
| Vogel und Bedingungen | Genehmigungen, Tierwohl, Wetter, Zustand, Handling-Grenzen, und das Urteil des Beringers erlauben die Maßnahme. |
| Bestand und Nachverfolgung | Bestätigen Sie den zugewiesenen Tag und den aktuellen Bestand; halten Sie einen noch nicht berechtigten Partner als offene Arbeit fest. |

### Ergänzende Tabelle — Hinweise zur Fangzeit

| To-Do-Hinweis | Bedeutung |
|---|---|
| `7d rule` | Mit dem Fang warten, bis mindestens sieben Tage seit dem bekannten oder begründbar geschätzten Legedatum des letzten Eis vergangen sind. Am Datum der bestätigten Vollständigkeit nicht erneut sieben Tage beginnen. |
| Zwei Eier, gültige Legeschätzung | Wenn eine Beobachtung bestätigt, dass das Gelege mindestens drei Tage nach dem geschätzten Legedatum von Ei 2 noch zwei Eier hat, gilt es mit zwei Eiern als vollständig. Die sieben Tage ab dieser Legeschätzung zählen, nicht ab dem Bestätigungsbesuch. Ein laut Schwimmprobe bereits altes Gelege kann bei der Entdeckung die Bedingung erfüllen. |
| Zwei Eier, keine Schwimmprobendaten | Nutzen Sie bis zu besseren Belegen das erste notierte Zwei-Eier-Datum als vorsichtigen Ersatzwert; eine frühere Entdeckung mit einem Ei ist nicht das Datum des zweiten Eis. Eine spätere Beobachtung muss bestätigen, dass das Gelege nach dem Drei-Tage-Abstand noch zwei Eier hat. Eine Besuchslücke allein belegt keine Vollständigkeit. |
| Später erscheint ein drittes Ei | Setzen Sie die Grundlage der Vollständigkeit auf die Legeschätzung des dritten/letzten Eis zurück, anhand der beobachteten Legegeschichte oder einer gültigen Schwimmprobenschätzung; andernfalls das erste Drei-Eier-Datum als vorsichtigen Ersatzwert verwenden. Behalten Sie die frühere Zwei-Eier-Zeitrechnung nicht bei. |
| Schwimmprobe nach der Entdeckung | Die spätere gültige Schwimmprobe kann die Schätzung für das letzte Ei verfeinern. Sie muss nicht künstlich auf das Entdeckungsdatum begrenzt werden; die tatsächlichen Besuche und Messwerte beibehalten. |
| `36hr rule` | Ein weiterer Elternvogel ist erst nach Ablauf des Störungsabstands berechtigt. Die PDF-Berechnung vergleicht 08:00 am Referenzdatum mit der vorherigen maßgeblichen Altvogel-Fangzeit; eine veraltete Morgenliste ist kein laufender Countdown. |
| Beide Regeln | Beide Freigaben müssen erfüllt sein; eine hebt die andere nicht auf. |
| Zeit oder Zuordnung ungeklärt | Wie angewiesen wiedersichten oder warten. Im Feld keine Ausnahme neu ausrechnen, um aus Wiedersichtungsarbeit Fangarbeit zu machen. |

Drei Eier sind das übliche vollständige Gelege, aber zwei Eier, oder selten eines,
können das tatsächliche Endgelege sein. Tragen Sie tatsächliche Zahlen und Folgebesuche ein;
erfinden Sie kein drittes Ei. Ein stabiles Ein-Ei-Gelege folgt seiner gesondert geprüften
Vollständigkeitsregel und der aktuellen To-Do-Anweisung.

Die projektinterne Brutdauer ab Gelegevollständigkeit beträgt 26 Tage. Wo die
Schlupfschätzung dieselbe Grundlage der Vollständigkeit nutzt, entsprechen
**19 Tage bis zum Schlupf sieben Tagen seit der Vollständigkeit**. Der angezeigte
Schlupf-Countdown ist eine hilfreiche Gegenprüfung, aber keine eigenständige Fangfreigabe,
wenn Legegeschichte oder Vollständigkeit ungeklärt sind. Schlupfzeichen, bestätigter
Schlupf, und eine bekannte negative Brut können die Sieben-Tage-Freigabe nach ihren
bestehenden Regeln erfüllen; die separate 36-Stunden-Sperre und alle anderen
Fang-/GEO-Prüfungen gelten weiterhin.

### Wenn ein Elternvogel bereits einen GEO trägt

Paarvervollständigung betrifft den zuverlässig zugeordneten Partner eines
aktuell mit Tag versehenen Elternvogels mit anrechenbarer Anbringungshistorie an
genau diesem Nest. Ein Tag an einem anderen Nest, ein reiner Rückholungsdatensatz,
oder eine unsichere Elternidentität reicht nicht. Die aktuelle To-Do-Entscheidung
muss weiterhin die geltenden Nest-/Plot-, Zuordnungs-, Tierwohl-, und Zeitregeln erfüllen.

Wenn der Partner bestätigt unberingt ist, kann eine berechtigte Anweisung
`tag X-X M (pair completion)` oder die weibliche Entsprechung lauten, statt lediglich
`band X-X`. Wenn sein Status noch geprüft werden muss, fordert
`resight/tag M (status ?; pair completion)` oder die weibliche Entsprechung das
Team auf, diesen Status festzustellen und nur bei Berechtigung einen Tag anzubringen.
Ein `resight/tag`-Hinweis ist keine Erlaubnis, eine geschlossene Sieben-Tage- oder
36-Stunden-Sperre zu umgehen. Ohne anrechenbare GEO-Paarvervollständigungsbelege
bleibt eine normale `band X-X`-Anweisung Beringungsarbeit und keine Tag-Anbringung.

Bei einem Vogel mit Tag muss die Nestzuordnung möglicherweise noch bestätigt werden.
Behalten Sie seine Wiedersichtungs-Nachverfolgung bei, aber bringen Sie keinen weiteren Tag an.
Eine offene Zuordnung löscht seinen bestehenden Tag nicht. Die Bestätigung der
Zuordnung macht ihn nicht zu einem Ziel ohne Tag; jeder später festgestellte
andere Elternvogel muss anhand seiner eigenen Belege beurteilt werden.

### Wenn ein beringter Elternvogel einen unbekannten Partner hat

Bei den aktuellen Spätwellen-Anweisungen 2026 am Cass River kann der Hinweis
`tag any, but only if one is confirmed X-X` auch dann erscheinen, wenn ein zuverlässig
zugeordneter Elternvogel beringt und ohne Tag ist und die Identität oder der
Beringungsstatus des anderen unbekannt ist. Der bekannte beringte Elternvogel kann
jedes der beiden Geschlechter haben. Der bestehende Fall mit zwei unbekannten
Eltern nutzt dieselbe bedingte Formulierung.

Diese Anweisung gilt nur für berechtigte positive Nester auf den Plots B und C,
deren Grundlage der Gelegevollständigkeit **nach dem 9. Oktober 2026** liegt.
Vollständigkeit am 9. Oktober reicht nicht; Nestbeginn oder Entdeckung allein legt
diesen Stichtag nicht fest. Die separaten Sieben-Tage- und 36-Stunden-Freigaben müssen
auch offen sein. Bestehende Tag-Belege, Tod, mehrdeutige Identitäten, und ungeklärte
MM-Nachverfolgung schränken die Anweisung weiterhin ein. Der bekannte beringte
Elternvogel benötigt eine bestätigte Zuordnung; beim unbekannten Partner kann noch
Zuordnungsarbeit erforderlich sein.

1. Bestätigen Sie vor dem ersten Anbringen, dass der unbekannte Vogel X-X ist und
   dass er zu diesem Nest gehört.
2. Wenn dieser Vogel bereits beringt ist, erlaubt dieser Hinweis kein erstmaliges
   Anbringen bei einem der beiden Elternvögel.
3. Nach einem berechtigten Anbringen beim bestätigten X-X-Elternvogel kann
   der beringte Partner über die üblichen Paarvervollständigungsregeln am selben
   Nest berechtigt werden, einschließlich des unabhängigen 36-Stunden-Abstands.

Der Hinweis gibt eine bedingte Anweisung zu einer bestehenden Fangaufgabe.
Er bestätigt selbst keine Elternzuordnung und hebt keine Zeitsperre auf.

### Welche Geolokator-/Tag-Maßnahme hat stattgefunden?

1. **Wurde der Altvogel in der Hand untersucht?** Nein: tragen Sie das Sichtbare in RESIGHTINGS ein;
   Anbringen/Rückholen wird nicht behauptet. Ja: weiter zu 2.
2. **Vorher und nachher kein Tag?** Ja: O. Nein: weiter zu 3.
3. **Vorher kein Tag, dann Tag angebracht?** Ja: D. Nein: weiter zu 4.
4. **Tag entfernt und keinen angebracht?** Ja: R. Nein: weiter zu 5.
5. **Derselbe Tag behalten?** Ja: S. Nein, ein alter Tag wurde durch
   einen anderen ersetzt: N.

### Ergänzende Tabelle — nur GEO-Fänge von Altvögeln

`TY` unten zeigt beispielhaft einen gelben Abstandshalter. Tragen Sie die tatsächliche
vollständige Abstandshalterfarbe in die passende Vorher-/Nachher-Markierung ein;
`T?` ist in CAPTURES nicht erlaubt. Markierungen ohne Tag bleiben die tatsächlich
beobachteten Ringe und werden nicht automatisch X.

| `tag_action` | `tag_id_in` vorher | `tag_id` nachher | `tag_type` | `UR_in` → `UR` |
|---|---|---|---|---|
| `O` kein Tag | Leer | Leer | Leer | Tatsächliche Markierung ohne Tag → tatsächliche Markierung ohne Tag. |
| `D` Anbringen | Leer | Neuer Tag beim Freilassen | `GEO` | Tatsächliche Markierung ohne Tag → Tag mit bekannter Abstandshalterfarbe, z. B. TY. |
| `R` Rückholen | Entfernter Tag | Leer | `GEO` | Tag mit bekannter Abstandshalterfarbe → tatsächliche Markierung ohne Tag beim Freilassen. |
| `S` behalten | Bestehender Tag | Derselbe Tag | `GEO` | Tatsächlicher Tag/Abstandshalter vorher → tatsächlicher Tag/Abstandshalter nachher. |
| `N` Ersatz | Alter Tag | Anderer neuer Tag | `GEO` | Tatsächlicher alter Tag/Abstandshalter → tatsächlicher neuer Tag/Abstandshalter. |

Tragen Sie bei diesen Altvogel-Einträgen `wt_w_tag = 0` oder `1` ein, um anzugeben,
ob die notierte Masse einen Tag einschloss. Verwenden Sie bei O den Wert 0. Ergänzen Sie auch
Fangstatus, Ring, Vorher-/Nachher-Ringe, und die anderen Pflichtfelder des Fangs.
`tag_action` und `capture_status` beschreiben unterschiedliche Dinge: Das Entfernen
eines Tags bedeutet nicht automatisch, dass die Ringkombination unverändert blieb.

Die Tag-Historie muss zur Maßnahme passen: Rückholen/Behalten beziehen sich auf den
aktiven Tag an diesem Vogel; beim Ersatz gibt es unterschiedliche alte/neue IDs. Prüfen Sie einen
Historienfehler anhand des Notizbuchs und geben Sie ihn zur Klärung weiter, statt die Tag-Nummer zu ändern.

Küken und Jungvögel lassen alle vier Tag-Felder leer — nicht O. Ein Altvogel mit Tag,
der nur gesehen wird, kommt mit sichtbarem Tag/Abstandshalter und Kommentaren in
RESIGHTINGS. `UR = T?` bedeutet eine ungelesene Abstandshalterfarbe, nicht eine ungelesene
Tag-ID. Ein nicht gesehener Tag ist kein Beweis für eine Rückholung.

Vergleichen Sie vor dem Freilassen und der Eingabe die Ring- und Tag-Beschriftungen mit
dem schriftlichen Eintrag. Ein zurückgeholtes Gerät steht nicht automatisch zum erneuten
Anbringen bereit; Luke Eberhart-Hertel muss seinen physischen Zustand und die Zuweisung bestätigen.

</details>

<a id="section-9"></a>

<details>
<summary><strong>9. Ausgang, Schlupf, Verlust, und notA</strong></summary>

## 9. Ausgang, Schlupf, Verlust, und notA

### Die Belege dieses Besuchs beschreiben

Betrachten Sie die übrigen Eier, Küken, und anwesenden Altvögel, bevor Sie den Zustand
bestimmen. Ein leeres Nest allein unterscheidet Schlupf nicht von Verlust. Halten Sie
einen möglichen Ausgang von einem bestätigten getrennt und erläutern Sie die Belege.

| Befund | `nest_state` | Zugehöriger Eintrag |
|---|---|---|
| Nestmulde, keine Eier | `S` | Gelegegröße null; erster Besuch mit Entdeckungs-GPS. |
| Nestentdeckung | `F` | Normalerweise mit Eiern; kann auf ein früheres S folgen. Beim seltenen Fund frisch geschlüpfter Küken in einem eindeutigen Nest gilt F und unmittelbar danach H; Abschnitt 4. |
| Aktives, bebrütetes Nest | `I` | Tatsächliche Eier und anwesender Altvogel. |
| Küken beim Schlupf gesehen | `H` | Übrige Eier und Küken getrennt zählen. |
| Mögliche Prädation / mögliches Verlassen | `pP` / `pD` | Belege und Unsicherheit in die Kommentare; vereinbarte Ausgangskontrollen bis notA offen halten. |
| Bestätigte Prädation / bestätigtes Verlassen | `P` / `D` | Belege für die Bestätigung; weitere Ausgangskontrollen bleiben bis notA erlaubt. |
| Endgültiger Abschluss des inaktiven Nests, Markierungen entfernt | `notA` | Letzter Besuch; Bedingungen unten. |
| Anderer Befund | `O` | Erklärender Kommentar erforderlich; setzt die Historie nicht zurück. |

### Schlupf, Verlust, oder Abschluss?

1. **Sind Küken vorhanden?** Ja: H und die tatsächlichen Ei-/Kükenzahlen notieren;
   die einzelnen Vögel getrennt eintragen. Nein: weiter zu 2.
2. **Sind die Eier noch aktiv?** Ja: den aktiven Besuch und den Eizustand notieren.
   Nein: weiter zu 3.
3. **Ist Verlust/Verlassen gesichert?** Ja: P/D mit Belegen. Nur vermutet:
   pP/pD mit Kommentaren und vereinbarter Nachprüfung. Unklar: die Unsicherheit
   beibehalten; weder Schlupf noch Verlust erfinden. Weiter zu 4.
4. **Ist das positive Nest für den endgültigen Abschluss bereit und sind die Markierungen entfernt?** Ja:
   notA eintragen. Nein: die vereinbarte Nachverfolgung beibehalten.

### Ausgangskontrollen bleiben bis notA offen

Weder mögliche Prädation pP noch bestätigte Prädation P oder Verlassen D ist der
endgültige Abschlussbesuch. Führen Sie die nötigen Ausgangskontrollen fort und legen Sie für
jeden Besuch eine neue NESTS-Zeile mit seinen Belegen an, bis zum endgültigen notA-Abschluss.
Überschreiben Sie den früheren Befund nicht, wenn spätere Belege ihn klären.
Mögliches Verlassen pD bleibt ebenfalls ein Prüfzustand und kein endgültiger Abschluss.

Wenn das To-Do-PDF das Nest vor dem Abschluss nicht mehr auflistet, halten Sie die
vereinbarte Kontrolle in der Teamübergabe fest. Fehlen im PDF bedeutet nicht, dass
bereits der letzte notA-Besuch stattgefunden hat. Prüfen Sie Referenzdatum und
Aktualisierungsstatus des PDFs, und melden Sie fehlende Abschlussarbeit, statt sie als erledigt anzusehen.

### Eier und Küken getrennt halten

`clutch_size` sind die noch vorhandenen Eier; `brood_size` sind die beobachteten Küken.
`hatch_state` beschreibt übrige Eier, nicht Küken: Anzahl gefolgt von N (kein
Zeichen), S (Stern), C (Riss), oder CC (mehrere/große Risse).

Ein Ei ohne Anpickzeichen und zwei Küken ergeben `clutch_size = 1`, `hatch_state = 1N`,
`brood_size = 2`. Tragen Sie die Küken bei Handling in CAPTURES ein, bei bloßer Sichtung
in RESIGHTINGS. H-Nestbesuche können wiederholt werden, solange Eier übrig sind.
Setzen Sie den Zustand nach H nicht wieder auf I, nur weil ein Ei noch nicht geschlüpft ist.

Der erste H-Besuch ohne übrige Eier und mit anwesenden Küken ist der letzte
Schlupfbesuch. Spätere Begegnungen mit mobilen Küken gehören in die Vogeltabellen,
nicht in zusätzliche H-Nestbesuche. Ein letzter notA-Abschluss kann folgen.

### Wenn spätere Kükenfänge das vollständige Gelege abdecken

Ein wahrheitsgetreuer Schlupfbesuch kann ein Ei und zwei Küken erfassen; später
wird das dritte Küken abseits des Nests gefangen. Den Besuch nicht umschreiben
und keinen weiteren Besuch erfinden. Nach einer erfolgreichen Aktualisierung
kann das To-Do null verbleibende Eier ableiten, wenn unterschiedliche,
verlässlich dem Ursprungsnest zugeordnete, erstmals beringte Küken jedes Ei
eines bekannten vollständigen Geleges abdecken. Die operative Eierzahl wird
dann null und die Folgeaufgabe `notA nest-check`, nicht eine Eierkontrolle.
Das ist weder ein beobachtetes leeres Nest noch ein abgeschlossener Abschlussbesuch.

Die derzeitige vorsichtige Ableitung erfordert ein H-Nest, ein vor dem Schlupf
dokumentiertes vollständiges Gelege mit mindestens 3 Eiern, und zeitlich
erfasste Erstberingungen seiner ursprünglichen Küken bis zum Referenzdatum.
Doppelte Fänge zählen einmal; Wiederfänge verschieben den Abschlusszeitpunkt
nicht. Unbekannte Ursprünge, gemischte oder widersprüchliche Zuordnungen,
ungeklärte zusätzliche Küken, und spätere Eibeobachtungen verhindern die
Ableitung. Kleinere Gelege werden durch diese Regel nicht als vollständig
geschlüpft abgeleitet. Bekannte Kükenverluste können belegen, dass ein Ei
geschlüpft ist, zählen aber nicht als lebende Küken in der Brutgröße.
Bestehende Fangbeschränkungen und Brutabschlussregeln bleiben unverändert.
Beim späteren notA-Besuch die tatsächlich beobachteten Anzahlen eintragen.

### Ergänzende Tabelle — endgültiger Abschluss

| Situation | Eintrag |
|---|---|
| Normales `notA` | Letzte NESTS-Zeile; `clutch_size = 0`, `hatch_state` leer. |
| Überlebende Brut nach dem letzten H | Ein notA darf direkt auf die letzte H-Zeile folgen, mit null Eiern und der beibehaltenen beobachteten Zahl überlebender Küken. Dazwischen ist keine D-Zeile nötig. |
| Verlassene Eier bleiben liegen | Die freigegebene D → notA-Abfolge in derselben Übermittlung darf die beobachtete Gelegezahl der D-Zeile beibehalten. Bei gleichen Zeitstempeln wird D vor notA bewertet; der Abschluss darf nicht vor D liegen. Die Abfolge erklären. |
| Ausgang nach pP, P, oder D wird noch geprüft | Jeden tatsächlichen Folgebesuch ergänzen; diese Einträge bleiben bis zum letzten notA offen. Keinen Abschluss herstellen, nur weil eine To-Do-Aufgabe verschwindet. |
| Negative Brut | Keine NESTS-Zeile und kein notA-Abschluss. Die Einzeleinträge zur Brut fortführen. |
| Ein neuer Versuch in der Nähe | Eine neue Nest-ID nach der Teamkonvention vergeben; keine abgeschlossene ID für ein anderes Nest wieder öffnen. |

Ein abgeschlossenes positives Nest kann weiterhin eine überlebende Brut haben, die
beringt, am Versteck fotografiert, oder mit Flaggen markiert werden muss. Behalten Sie
ihre positive ID bei verknüpften Vogeleinträgen bei und notieren Sie den aktuellen
Familien-Wegpunkt. Eine spätere Kükenbegegnung kann Last Visit im To-Do-PDF auf
ein neueres Datum setzen, ohne den Zeitpunkt des ersten Schlupfeintrags zu ändern.

### Eine Brut weiterverfolgen, wenn keine Küken mehr gesehen werden

Küken können sich verstecken; eine erfolglose Suche oder ein Altvogel allein ist
deshalb kein Beweis, dass eine Brut gestorben ist. Die bekannten Elternvögel
wiederzusehen bleibt wertvoll: notieren Sie ihre Identität, ihren Aufenthaltsort, und
was sie tatsächlich tun. Die Datenbank kann dann ungeklärte Familienarbeit von
Belegen für vermuteten Brutverlust oder einen späteren Brutversuch unterscheiden.

Nutzen Sie vor dem Aufbruch die Parent–Nest-Übersicht, um die früheren Eltern zu bestimmen.
Planen Sie nach Möglichkeit echte Folgebeobachtungen von **beiden** Eltern an verschiedenen
Tagen. Nehmen Sie bei jeder Begegnung mit Ihrem Garmin-GPS einen Wegpunkt auf.
Wenn die Küken erneut gesehen werden, tragen Sie sie einzeln ein, mit ihren Elternvögeln
und dem gemeinsamen Familien-gps_id/point nach Abschnitt 5. Lassen Sie überlebende Küken
oder kükenbetreuendes Verhalten nicht weg, nur weil der Brutverlust erwartet wird.

**Vermutlich tot ist eine Schlussfolgerung für die Planung, kein beobachteter Tod.**
Sie entfernt nach einer Aktualisierung die To-Do-Arbeit der Brut; sie schreibt die
Feldbeobachtungen nicht um, beweist nicht den Tod jedes Kükens, und ersetzt den letzten
notA-Besuch bei einem positiven Nest nicht. Es gibt keinen `behav`-Code für „vermutlich tot“
zum Eintragen. Nutzen Sie keinen Totfund-Fangstatus für einen erschlossenen Verlust.

### Zuordnung, Verlust, und Erledigung im Jungvogelstadium nicht verwechseln

| Ergebnis nach Aktualisierung | Belege | Bedeutung für die Nachverfolgung |
|---|---|---|
| Elternzuordnung bestätigt | Die zulässigen Identitäts- und nestverknüpften Beobachtungen aus Abschnitt 5. | Die Zuordnung dieses Elternvogels benötigt keine Bestätigung mehr. Beringung, Fotos, oder Flaggenmarkierung der Brut können noch fällig sein. |
| Brut vermutlich tot | Weg 1, 2, oder 3 unten, ohne widersprechende Lebendbelege. | Weitere brutbezogene Arbeit, einschließlich zugehöriger Elternfang-/Wiedersichtungsaufgaben und des Bruteintrags in der Parent–Nest-Übersicht, wird ausgeblendet. Das ist kein beobachteter Tod und kein Grund, einen D-Fang zu erfinden. |
| Brut im Jungvogelstadium erledigt | Ein zuverlässig zur Herkunftsbrut zugeordneter Fang oder eine solche Wiedersichtung mit Alter J, einschließlich eines bestätigten Totfunds mit Alter J. | Nach Luke Eberhart-Hertels Projektregel wird angenommen, dass die Geschwister ebenfalls J erreicht haben; deshalb endet die Nachverfolgung im Kükenstadium. Das beweist nicht, dass jedes Geschwister überlebt hat. |

Keines dieser Ergebnisse schreibt die Beobachtungen um. Ein positives Nest kann
seinen letzten notA-Besuch noch benötigen; eine negative Brut erhält niemals NESTS-Zeilen.

### Welches Verhalten trägt zu welcher Entscheidung bei?

| Was tatsächlich beobachtet wurde | `behav`-Eintrag | Verwendung bei den Prüfungen |
|---|---|---|
| Elternvogel hudert Küken, sucht mit ihnen Nahrung, oder ist mit ihnen wachsam | BC, FC, oder AC | Positiver Beleg für Brutbetreuung. Zählt nicht als Beobachtung ohne Brutbetreuung; jedes angetroffene Küken ebenfalls eintragen. |
| Brüten, Nestpflege, oder Scharren | IN, NM, oder SC | Bestätigt eine Nestzuordnung bei zulässiger Identität/Verknüpfung. Das ist Nest-/Neubeginn-Verhalten und keine Beobachtung ohne Brutbetreuung. Bei einem anderen Versuch dessen eigene Nest-ID verwenden. |
| Flügellahm-Verleiten | BW | Kann die Zuordnung bestätigen und eines der anrechenbaren Beobachtungsdaten ohne Brutbetreuung liefern, wenn in dieser Zeile kein BC/FC/AC oder IN/NM/SC vorkommt. BW allein kann die Brutverlust-Anforderung für keinen der beiden Elternvögel erfüllen. |
| Nahrungssuche allein / mit vermutetem Partner / im Trupp | FA / FM / FF | Zählt zu den stärkeren Belegen ohne Brutbetreuung, wenn zuverlässig identifiziert und ausdrücklich mit der alten Brut verknüpft, ohne positives Brut- oder Nest-/Neubeginn-Verhalten in dieser Zeile. |
| Ruhen / Verweilen / Wachsamkeit / Kämpfen | RS / LF / AT / FT | Zählt nach derselben Grundlage wie FA/FM/FF. Allgemeine Wachsamkeit AT ist nicht Wachsamkeit mit Küken AC. |
| Anderes Verhalten | OB | Zählt in der aktuellen Berechnung nach derselben Grundlage. Erklären Sie in `comments` genau, was geschah; OB ist kein Code für „Brut verschwunden“. |
| Nur Gefiederpflege oder Balz | PR oder CO | Nützliche Feldbeobachtungen, zählen aber nicht zur Schwelle wiederholter Beobachtungen ohne Brutbetreuung für vermuteten Brutverlust. Sie bestätigen auch nicht selbstständig die Nestzuordnung. |

Eine Beobachtung kann unterschiedlichen Zwecken dienen. Beispielsweise können drei
echte AT-Wiedersichtungen die Nestzuordnung eines Elternvogels begründen; AT-Beobachtungen
**vor** dem Schlupfbeleg der Brut können aber keinen späteren Brutverlust begründen.
Eine Zeile mit `AT, BC` ist ein positiver Brutbeleg und kein negativer Beleg.

### Weg 1 — wiederholte Beobachtungen beider Eltern ohne Brutbetreuung

Für diesen Weg müssen alle folgenden Bedingungen erfüllt sein. Eine negative Brut
nutzt ihr Entdeckungsdatum, weil ihr tatsächliches Schlupfdatum unbekannt sein kann.
Bei einem positiven Nest ist das Startdatum der früheste notierte H-Besuch oder
die früheste positive Kükenzahl; wenn beides fehlt, liefert der erste verknüpfte
Kükenfang den Schlupfbeleg. Das ist das Belegdatum der Datenbank und keine Behauptung,
den genauen Schlupfzeitpunkt zu kennen.

| Anforderung | Was zu erheben oder zu prüfen ist |
|---|---|
| Die Brut ist zulässig | Ein positives Nest mit Schlupfbeleg oder eine negative Brut unbekannter Herkunft. Ein Verlust im Eistadium wird über Nestbesuche bewertet, nicht über diese Regel für mobile Bruten. |
| Mindestens 21 Tage sind vergangen | Das Referenzdatum des PDFs liegt mindestens 21 Tage nach diesem Startdatum. Die Beobachtungen selbst dürfen innerhalb dieses Zeitraums nach dem Start früher gemacht worden sein. |
| Beide Eltern zuverlässig festgestellt | Männchen und Weibchen haben jeweils eine eindeutige ausgewählte Zuordnung zur alten Brut. Lediglich mögliche Identitäten, unbekanntes Geschlecht, und X-X liefern diese Zwei-Eltern-Historie nicht. |
| Zwei getrennte Daten pro Elternvogel | Jeder Elternvogel hat an mindestens zwei verschiedenen Tagen anrechenbare Beobachtungen ohne Brutbetreuung, strikt nach dem Startdatum und spätestens am Referenzdatum. Die Eltern müssen nicht an denselben Tagen gesehen werden. Wiederholte Zeilen an einem Tag zählen für diesen Elternvogel als ein Datum. |
| Alte Brut-ID ausdrücklich eingetragen | Diese anrechenbaren Elternzeilen tragen die alte positive oder negative `nest_id`. Eine bekannte Identität oder ein Wegpunkt allein ordnet eine Zeile mit leerer ID für genau diese Berechnung nicht der alten Brut zu. Verknüpfen Sie niemals eine unsichere Beobachtung mit einer ID, nur damit sie zählt. |
| Mehr als BW allein | Jeder Elternvogel hat mindestens eine anrechenbare Zeile mit FA, FM, FF, RS, LF, AT, FT, oder OB. BW kann ein weiteres Datum beitragen, aber zwei reine BW-Daten pro Elternvogel reichen nicht. |
| Kein widersprechendes Verhalten in der gezählten Zeile | Eine Zeile mit BC/FC/AC oder IN/NM/SC zählt nicht als Beleg ohne Brutbetreuung, auch wenn sie zusätzlich AT oder einen anderen aufgelisteten Code enthält. |
| Zeitfolge der Brutbetreuung geprüft | Die letzte verknüpfte BC/FC/AC-Beobachtung muss vor den letzten anrechenbaren Daten ohne Brutbetreuung von **beiden** Eltern liegen. Eine positive Beobachtung am selben Tag oder später erfüllt diese Bedingung nicht. |

Das mögliche Verlustdatum ist das spätere der letzten anrechenbaren Daten ohne
Brutbetreuung beider Eltern. Anschließend greift die Lebendbeleg-Prüfung unten.
Lediglich 21 Tage zu erreichen oder die Küken 21 Tage nicht zu finden reicht für
diesen Weg nicht. Die separate Regel mit festem Zeitfenster in Weg 3 beginnt erst ab Tag 36.

### Weg 2 — frühere Eltern einem anderen Nest zugeordnet (Belege für erneutes Brüten)

Erneutes Brüten bedeutet, einen weiteren Brutversuch zu beginnen. Eine zugeordnete
Nestmulde reicht: Es muss nicht auf Eier gewartet werden. Tragen Sie den neuen Versuch
unter seiner eigenen positiven nest_id ein und danach die tatsächliche Zuordnung
des Altvogels. Eine zulässige SC-Beobachtung kann die Zuordnung des scharrenden
Elternvogels bestätigen; IN oder NM können ebenfalls eine Zuordnung bestätigen,
wenn diese Verhaltensweisen tatsächlich beobachtet werden. Fügen Sie kein Verhalten
hinzu, nur um die alte Brut aus dem To-Do-PDF zu entfernen.

Luke Eberhart-Hertels Projektregel behandelt anrechenbares erneutes Brüten automatisch
als vermuteten Verlust der früheren abhängigen Brut: BADO-Eltern beginnen keinen
weiteren Versuch, solange sie diese Brut noch betreuen. Dieser Weg hat keine 21-Tage-Wartefrist.
Tragen Sie alle widersprechenden Kükenbelege wahrheitsgemäß ein und geben Sie einen scheinbaren
Widerspruch an Luke Eberhart-Hertel weiter. Wenn die alte Brut durch zuverlässige
Alter-J-Belege bereits erledigt ist, macht ein neuer Versuch aus dieser entwicklungsbedingten
Erledigung keinen vermuteten Tod.

| Anforderung in der aktuellen Berechnung | Bedeutung im Feld |
|---|---|
| Ein eigener nachfolgender Versuch | In der aktuellen Cass River-To-Do-Umsetzung ein anderes positives CR-Nest, das nach dem Startdatum der alten Brut erstmals notiert wurde, mit einem zulässigen S-, F-, oder I-Besuch bis zum Referenzdatum. Der erneute Besuch eines älteren oder abgeschlossenen Nests belegt keinen neuen Versuch. |
| Ein stark abgesicherter früherer Elternvogel | Ein Altvogel hat eine eindeutige ausgewählte Zuordnung sowohl zur alten Brut als auch zu diesem anderen Nest. Das reicht für den Weg über ein späteres Nest. Ein abwesender Partner muss nicht beobachtet werden und es muss nicht 21 Tage gewartet werden. |
| Alternative: zwei zugeordnete frühere Elternidentitäten | Zwei unterschiedliche frühere Elternidentitäten, ein Männchen und ein Weibchen, sind zuverlässig demselben neuen Versuch zugeordnet. Eine einzelne vorläufige Identität oder zwei gleichgeschlechtliche Kandidaten begründen diesen Paar-Weg nicht. |
| Tatsächliche Elternbelege | Die Elternzuordnungs-Hierarchie aus Abschnitt 5 gilt. IN/NM/SC sind nützliche direkte Verhaltensbeobachtungen; die Berechnung verlangt aber keinen dieser drei Codes, wenn ein anderer zulässiger Zuordnungsweg die Verknüpfung bereits gesichert hat. |
| Entfernung ist nur eine Zusatzinformation | Ein späteres Nest innerhalb von 100 m kann den angezeigten Grund stützen, aber Nähe allein belegt niemals gemeinsame Eltern und schließt keine Brut ab. Ein verknüpftes Nest weiter entfernt kann zählen; eine negative Brut benötigt keinen erfundenen Ursprungspunkt. |

Das mögliche Verlustdatum darf nicht vor den nötigen Nest- und Identitätsbelegen
für die alte Brut oder den neuen Versuch liegen. Eine spätere Bestätigung darf
nicht genutzt werden, um das Ergebnis zurückzudatieren. Nähe allein, eine mögliche
Identität, oder eine zukünftige Beobachtung liefert die Zuordnung nicht. Melden Sie
eine falsche Zuordnung an Luke Eberhart-Hertel.

### Weg 3 — keine lebende Brutbegegnung im Alter von 21–35 Tagen

Planen Sie, die Bruten im Alter von **21 bis einschließlich 35 Tagen** wiederzufinden.
Ab Tag 36 gilt eine Brut ohne anrechenbare Lebendbegegnung an irgendeinem Tag in
diesem Fenster für die Planung als vermutlich tot. Ihre Brutarbeit und die
zugehörigen Elternfang- und Wiedersichtungsaufgaben werden nach der Aktualisierung
entfernt, zusammen mit ihrem Bruteintrag in der Parent–Nest-Übersicht. Diese Regel
benötigt weder die Zwei-Eltern-Beobachtungen aus Weg 1 noch die Belege für erneutes Brüten aus Weg 2.

| Prüfung | So funktioniert diese Regel |
|---|---|
| Welches Alter wird genutzt? | Bei einem positiven Nest ab dem notierten Schlupfbeleg zählen, nicht ab der Entdeckung im Eistadium. Bei einer negativen Brut den bestehenden Arbeitsersatz für Alter/Entdeckungsdatum verwenden: Das behauptet nicht, dass die Entdeckung ihr tatsächliches Schlupfdatum war. Ohne brauchbaren Altersbezug kann diese Regel keinen vermuteten Verlust begründen. |
| Wann endet das Fenster? | Tag 35 liegt noch im Beobachtungsfenster. Der erste mögliche Tag für das Ausblenden ist Tag 36. Alle Prüfungen nutzen das Referenzdatum des PDFs und die für dieses Datum verfügbaren Einträge. |
| Was zählt als Begegnung? | Die unten beschriebenen zuverlässig verknüpften lebenden Küken oder positiven Brutbetreuungsbelege. Direkte Nest-/Brut-IDs und freigegebene eindeutige Zuordnungen über Ringhistorie oder Familien-gps_id/point zählen. Ein unidentifizierter Altvogel allein, eine mehrdeutige Zuordnung, oder ein totes gefundenes Küken allein zählt nicht. |
| Was, wenn die Brut an Tag 25 gesehen wurde? | Eine anrechenbare Lebendbegegnung an irgendeinem Tag von 21 bis 35 verhindert genau diesen Auslöser, auch bei späteren Referenzdaten. Das ist ein festes Fenster und kein gleitender Abwesenheitszeitraum. Wege 1 und 2 und die Erledigung im Jungvogelstadium gelten weiterhin unabhängig. |
| Was, wenn Küken nach Tag 35 wieder gefunden werden? | Die tatsächliche Begegnung eintragen. Eine anrechenbare Lebendbegegnung an Tag 36 oder später verhindert dieses Ergebnis „vermutlich tot“ bei der nächsten Aktualisierung und bringt Arbeit zurück, die nach den normalen Aufgabenregeln noch fällig ist. Die Beobachtung nicht an die frühere Erwartung anpassen. |

Nichts an dieser Berechnung beweist, dass die Küken gestorben sind. Tragen Sie keinen
Totfund, Verlustbesuch, Brutgröße null, oder erfundene erfolglose Suche ein,
nur um das Ergebnis zu erreichen. Laden Sie echte Beobachtungen zeitnah hoch und bitten Sie
um eine Aktualisierung, bevor Sie sich auf den datierten Arbeitsplan verlassen.
Ein nötiger notA-Besuch beim positiven Nest bleibt getrennt; negative Bruten
erhalten niemals NESTS-Abschlusszeilen.

Ein später bestätigter Tod löscht keine frühere Lebendbegegnung innerhalb des Fensters.
Wenn eine Wiedersichtung einem Tod am selben oder einem früheren Datum widerspricht,
geben Sie Identität und Zeitfolge zur Prüfung weiter, statt sie automatisch als
Überlebensbeleg zu verwenden.

### Lebendbelege können die Brut offen halten oder zurückbringen

Bevor die Datenbank To-Do-Arbeit ausblendet, prüft sie auf folgende Einträge mit
Datum **am oder nach dem möglichen Verlustdatum**, bis zum Referenzdatum:

- Eine CAPTURES-Zeile mit Alter C und lebendem capture_status F, R, oder C,
  zuverlässig mit der alten Brut verknüpft.
- Eine RESIGHTINGS-Zeile mit Alter C, zuverlässig mit der alten Brut verknüpft.
- Eine BC-, FC-, oder AC-Wiedersichtung eines zuverlässig festgestellten früheren
  Elternvogels, ausdrücklich mit der alten Brut verknüpft, direkt oder über eine
  freigegebene eindeutige Zuordnung.

Jeder solche Eintrag verhindert das Ergebnis „vermutlich tot“ bei dieser Aktualisierung.
Brutarbeit kann erneut erscheinen, wo sie ihre normalen Alters-, Zeit-, und
Erledigungsregeln noch erfüllt. Das garantiert nicht, dass jeder frühere To-Do-Eintrag
zurückkommt; beispielsweise kann das Anzeigefenster für Versteckfotos bereits abgelaufen sein.

Bei Weg 3 ist das mögliche Verlustdatum Tag 36. Dieselben anrechenbaren Lebendbelege
verhindern diesen Weg auch, wenn sie innerhalb der Tage 21–35 liegen. Ein verspätetes
Hochladen einer echten Begegnung von Tag 25 korrigiert deshalb das Ergebnis nach
der Aktualisierung; ändern Sie ihr Felddatum nicht auf das Upload-Datum.

Eine freigegebene eindeutige erschlossene Zuordnung zählt ebenfalls; eine leere rohe
nest_id bedeutet nicht, dass das Ereignis keine Familienzuordnung hat. Tragen Sie die
bekannte ID ein, wann immer sie verfügbar ist. Befolgen Sie andernfalls Abschnitt 5 und
behalten Sie gemeinsames Datum, Gebiet, und gps_id/point bei. Widersprechende ausdrückliche
IDs, mehrdeutige Eltern, oder unsichere Markierungen ohne verifizierten bekannten
Ring liefern keine erschlossene Zuordnung. Ändern Sie kein wahrheitsgemäßes Datum und
keinen Wegpunkt, damit ein Ereignis zählt.

Ein Fang mit Status D ist ein Totfund und kein Überlebensbeleg. Ein unbekannter
Fangstatus ist ebenfalls kein verlässlicher Lebendbeleg. Ein totes Küken belegt
nicht, dass die gesamte Brut gestorben ist: Ein Geschwister kann noch leben.
Tragen Sie den gefundenen Vogel als eigene CAPTURES-Zeile ein und notieren Sie weiterhin alle
tatsächlich angetroffenen lebenden Geschwister und betreuenden Elternvögel.

### Ein herkunftsverknüpfter Jungvogel erledigt die Arbeit im Kükenstadium

Tragen Sie das tatsächliche Alter des Vogels ein. Eine gravierte Flagge identifiziert
einen Vogel; sie belegt allein nicht Alter J. Ein tatsächlich mit Alter J gefangener
oder wiedergesehener Vogel, der zuverlässig zu seiner ursprünglichen Brut
zurückverfolgt werden kann, erledigt deren Arbeit im Kükenstadium. Nach Luke Eberhart-Hertels
Projektregel entwickeln sich Geschwister gleich schnell, und es wird angenommen,
dass sie ebenfalls J erreicht haben. Warten Sie nicht auf einen eigenen J-Eintrag für
jedes Geschwister, nur um die To-Do-Arbeit der Brut zu entfernen.

Eine lesbare Flagge kann über den Fang, der sie mit einem Metallring verknüpft hat,
zum ursprünglichen Kükenfang zurückverfolgt werden. Spätere Brutmischung ersetzt
diese ursprüngliche Herkunft nicht. Widersprüchliche Ring-/Flaggenidentitäten oder
eine mehrdeutige Herkunftsbrut benötigen Prüfung; sie dürfen nicht irgendeine ID
erledigen, die zufällig in der neuen Zeile steht.

| Herkunftsprüfung | Zeitliche Anforderung |
|---|---|
| Jungvogel-Ereignis in CAPTURES | Die Herkunfts- und Flagge-zu-Ring-Belege müssen zum tatsächlichen Fangereignis bereits vorliegen. Wahrheitsgemäßes Datum und Fangzeit eintragen. |
| Jungvogel-Ereignis in RESIGHTINGS | Weil diese Tabelle kein Begegnungszeitfeld hat, nutzt die automatische Rückverfolgung Herkunfts-/Flagge-zu-Ring-Fänge von einem früheren Felddatum, nicht vom selben Datum. Es geht um Felddaten, nicht um den Zeitpunkt des Hochladens. |
| Identität kann noch nicht sicher zurückverfolgt werden | Die tatsächliche Beobachtung beibehalten und das ungeklärte Ergebnis an Luke Eberhart-Hertel weitergeben. Keine Daten verschieben und keine früheren Fänge erfinden. |

Ein zuverlässig zur Herkunftsbrut verknüpfter Totfund mit bestätigtem Alter J
erledigt ebenfalls die Arbeit im Kükenstadium. Er belegt das Erreichen von J,
nicht das Überleben. Tragen Sie D ein, die tatsächlich gefundenen Markierungen in die
Eingangsfelder, und lassen Sie Freilassungsfelder/-zeit leer. Halten Sie alle bekannten
Geschwistertode im Datensatz fest: Erledigt bedeutet nicht, dass jedes Geschwister
überlebt hat. Ein Totfund mit Alter C liefert diesen Beleg für das Jungvogelstadium nicht.

Weder Erledigung im Jungvogelstadium noch vermuteter Verlust ersetzt einen unabhängig
nötigen notA-Besuch beim positiven Nest. Tragen Sie keinen NESTS-Verlust ein und ändern Sie
keine Rohdaten, um eines dieser Ergebnisse zu erreichen.

### Entscheidungshilfe im Feld — welche Belege sollten als Nächstes gesammelt werden?

1. **Ist ein Vogel mit tatsächlichem Alter J zuverlässig seiner ursprünglichen Brut zugeordnet?**
   Ja: dieses Individuum eintragen, einschließlich eines Totfunds, wenn dies der
   Befund war, und die Erledigung im Jungvogelstadium nach der Aktualisierung prüfen. Nein: weiter zu 2.
2. **Wurden Küken oder kükenbetreuende Eltern gesehen?** Ja: die tatsächliche
   Familie eintragen, jeden Vogel einzeln, mit gemeinsamem Datum, Gebiet, und gps_id/point;
   die Brut nicht für tot erklären. Nein: weiter zu 3.
3. **Sind die früheren Eltern zuverlässig identifiziert?** Nein: Markierung und tatsächliches
   Zuordnungsverhalten nach Abschnitt 5 erheben; ungeklärte Identität liefert keine
   Zwei-Eltern-Verlustschlussfolgerung. Ja: weiter zu 4.
4. **Ist ein früherer Elternvogel tatsächlich einem neuen Versuch zugeordnet, einschließlich
   einer Nestmulde?** Ja: dieses Nest unter seiner eigenen ID und das tatsächliche
   Elternverhalten eintragen; Weg 2 prüfen
   und widersprechende Kükenbelege melden. Nein: weiter zu 5.
5. **Wurden beide früheren Eltern jeweils an zwei getrennten Tagen ohne Brutbetreuung
   beobachtet?** Nein: geeignete Wiederholungsbeobachtungen planen, ohne
   Störung oder erfundene Einträge. Ja: alle Bedingungen von Weg 1 prüfen,
   einschließlich der 21-Tage-Schwelle, ausdrücklicher alter Brutzuordnungen, und der BW-Begrenzung.
6. **Hat die Brut Tag 36 ohne irgendeine anrechenbare Lebendbegegnung im Alter von
   21–35 Tagen erreicht?** Ja: Weg 3 kann ihre Arbeit nach der Aktualisierung ausblenden.
   Jede spätere Lebendbegegnung wahrheitsgemäß eintragen, damit zulässige Arbeit
   zurückkommen kann. Eine Begegnung an Tag 25 verhindert diesen Weg; ein Altvogel
   allein tut dies nicht.
7. **Fehlt die Brut in einem frisch aktualisierten PDF?** Den Grund mit dem zuständigen
   Bediener prüfen. Erledigte Elternzuordnung, normale Erledigung,
   Ablauf, vermuteter Brutverlust, und Erledigung im Jungvogelstadium sind unterschiedliche
   Gründe für das Verschwinden.
   Fehlende Arbeit oder widersprechende Überlebensbelege benötigen weiterhin eine Übergabe.

Ereignistabellen und Beispiele stehen in den Abschnitten 13 und 14. Kein Feldmitarbeiter
muss eine Statustabelle ändern oder eine Brut manuell „abhaken“: echte Belege eintragen,
dann den zuständigen Bediener den datierten Arbeitsplan aktualisieren und prüfen lassen.

</details>

<a id="section-10"></a>

<details>
<summary><strong>10. Dateneingabe und Prüfung am Tagesende</strong></summary>

## 10. Dateneingabe und Prüfung am Tagesende

### Notizbuch, GPS, und Medien zusammenführen

1. Laden Sie zuerst die Garmin-Aufzeichnungen herunter und anschließend hoch. Prüfen
   Sie Geräte-IDs und Wegpunktnummern anhand Ihres Notizbuchs.
2. Kopieren Sie die Originalmedien auf das zugewiesene Laufwerk. Prüfen Sie für jede
   Bildserie Motiv, Ring, Kamera, und vollständigen ersten/letzten Dateinamen.
3. Tragen Sie Nestbesuche vor den zugehörigen Eimessungen und den Vogelbeobachtungen
   mit positivem Nestbezug ein, die auf dieser Historie beruhen.
4. Speichern Sie echte Kükenfänge vor reinen Eltern-Wiedersichtungsübermittlungen oder
   H-Zeilen, die diese Fänge finden müssen. Ergänzen Sie keine doppelten Küken-Wiedersichtungen.
5. Übermitteln Sie Eltern- und Küken-Wiedersichtungen einer Begegnung gemeinsam. Vergleichen
   Sie ihr gemeinsames Datum, Gebiet, und gps_id/point mit allen Fängen dieser Begegnung.
6. Öffnen Sie **DATA ENTRY ISSUES**, korrigieren Sie Fehler, und prüfen Sie erneut. Nutzen Sie
   Abschnitt 12 für eine gültige Ausnahme oder eine Meldung, die dem vereinbarten Vorgehen widerspricht.
7. Speichern Sie, prüfen Sie den übermittelten Datensatz, und sehen Sie ein aktualisiertes
   To-Do-PDF durch. Nehmen Sie unvollständige Einträge, Familienzuordnungen, und Fotos in die Teamübergabe auf.

Das Formular kann das heutige Datum, BADO, oder CR vorbelegen. Prüfen Sie diese
Angaben bei der Eingabe älterer Notizen oder von WRYB-Datensätzen. Hinweise werden
beim Bewegen des Mauszeigers über Spaltenüberschriften angezeigt; ändern Sie jedoch
keinen wahrheitsgemäßen Eintrag aufgrund eines Hinweises, der dem aktuellen Verfahren
widerspricht. Mehrere Personen können gleichzeitig Daten eingeben; stimmen Sie ab,
wer welche Begegnung eingibt, um doppelte Übermittlungen zu vermeiden.

### Das Popup der Nest Map lesen

Klicken Sie auf einen Punkt, um Nest-/Brut-ID, Zustand, Eltern, Schlupfstatus, und
Gelege-/Brutgrößen zu sehen, soweit verfügbar. **Last encounter** zählt Tage rückwärts
ab dem Referenzdatum der App: Verwendet wird die letzte anrechenbare Brutbegegnung
bei einem Brutpunkt oder der letzte Nestbesuch bei einem noch nicht geschlüpften
Nest. Ein unbekannter Zeitpunkt wird als Unknown angezeigt. Last observer wird nur
angezeigt, wenn die Quelle diese Angabe liefert; ein früherer Nestbesucher wird
nicht als Beobachter einer späteren Brutsichtung dargestellt.

**Hatch timing (days)** folgt der Anzeige **Est. Hatch** im PDF. Positive Werte
sind Tage bis zum geschätzten Schlupf. Bei einem noch nicht geschlüpften Nest bedeuten
negative Werte überfällige Tage; bei einer Brut bedeuten sie Tage seit dem Schlupf,
anhand des bestehenden Schlupfbelegs oder des Alters-/Entdeckungsersatzwerts für
Bruten unbekannter Herkunft. Null ist die Schätzung des Schlupftags, kein Schlupfbeweis.
Alle Werte nutzen das Referenzdatum der App. Fehlende Schätzungen, einschließlich
bis zur Schwimmprobe zurückgehaltener Schätzungen, zeigen Unknown statt einer
irreführenden Zahl. Die Karte verwendet denselben Formatierer wie das PDF;
sie führt keine weitere Schlupfberechnung ein und ändert keine Aufgabenberechtigung.

Eltern-Zusatzangaben beschreiben die Nestzuordnung, nicht die Berechtigung für einen
Tag. Beispielsweise bedeutet `MOCK-F (IN)` eine Zuordnung durch bestätigendes
IN-Verhalten; `MOCK-M (2)` bedeutet zwei anrechenbare nichtbestätigende Wiedersichtungen
und erfordert ohne andere Belege eine dritte oder bestätigende Belege. Eindeutige
Fangbelege können stattdessen `TN`, `TB`, oder `HA` anzeigen; Fang mit Küken oder
GPS-verknüpften Küken wird gesondert gekennzeichnet. `MM, 2` bedeutet einen MM-Fang
und zwei anrechenbare Wiedersichtungen an diesem Nest. Konkurrierende oder unsichere
Zuordnungen werden als mehrdeutig gekennzeichnet; behandeln Sie sie nicht als
gesicherte Eltern. Die stärkeren Belege eines geklärten Elternvogels haben Vorrang
vor einer geringeren Wiedersichtungszahl oder einem anderen noch offenen Kandidaten.

Diese Eltern-Zusatzangaben stammen aus dem letzten erfolgreichen To-Do-Snapshot,
nicht aus einer neuen Zuordnungsberechnung bei jedem Öffnen der Karte. Aktualisieren
Sie den Snapshot nach neuen Beobachtungen, um die Zählwerte zu aktualisieren. Wenn
passende veröffentlichte Belege fehlen oder die Live-Karte einen anderen Vogel
zeigt, bleibt dessen reine Identität ohne Zuordnungszusatz stehen.

### Das To-Do-PDF als datierten Arbeitsplan lesen

Das PDF liest den veröffentlichten To-Do-Snapshot für sein Referenzdatum. Das
Speichern eines Datensatzes oder erneute Herunterladen des PDFs baut diesen Snapshot
nicht zwangsläufig neu auf. Prüfen Sie das Datum und bitten Sie den zuständigen
Bediener um eine Aktualisierung, wenn neue Einträge fehlen. Ändern Sie das appweite
Referenzdatum nicht unbedacht; andere Ausgaben verwenden es ebenfalls.

**Build To-do snapshot** kann bis zu 20 Minuten dauern; bei ausgelastetem Server
kann es länger dauern. Die Wartemeldung zeigt die gemeldete Erstellungsphase und
die verstrichene Zeit und bietet währenddessen das Spiel Dotterel Finder in einem
neuen Browser-Tab an. Starten Sie keinen weiteren Aufbau, während einer läuft.
Warten Sie auf ein erfolgreiches Ergebnis, bevor Sie ein neu heruntergeladenes
PDF als aktuellen Arbeitsplan verwenden.

| PDF-Überschrift | Was zu tun/prüfen ist |
|---|---|
| Parents to capture | Vorgesehener Vogel, Zweck, und Zeithinweise; Abschnitt 8. |
| Parents to resight for nest association | Tatsächliche Verhaltens-/Identitätsbelege erheben; reine Wiedersichtungsarbeit nicht in Fangarbeit umwandeln. |
| Nests to process / re-process | Fehlende Schwimmproben oder Gelege-/Nestmulden-/Zeltfotos, unter Beachtung von Schlupfzeichen und Besuchsplan. |
| Nests to check for additional eggs | Tatsächliche Zunahme oder Stabilität der Gelegegröße. |
| Nests to check for potential hatch | Übrige Eier, Schlupfzeichen, und gesehene Küken — nicht nur das vorhergesagte Datum. |
| Broods to band | Eigene Fänge und Metallring-Identitäten für Küken, die in der Hand waren. |
| Broods to photograph | H-Foto-Fortschritt pro Küken. Biologische Frist vor dem Alter von sieben Tagen; Anzeigezeitrechnungen in Abschnitt 7. |
| Broods to recapture for flagging | Aktuelle Altersschätzung, Identität, Messwerte, und Tierwohl; Abschnitt 6. |
| Nests requiring a notA closure visit | Endgültiger Abschluss eines positiven Nests, kein Eintrag für eine negative Brut. |

Vergleichen Sie bei Kükenarbeit **N chicks / N seen** mit der letzten anrechenbaren
Begegnung aus Abschnitt 6, nicht automatisch mit dem ursprünglichen Gelege oder
der historischen maximalen Brutgröße. Sowohl die Aufgabenfreigabe als auch die
PDF-Anzeige verwenden dieselben veröffentlichten SQL-Zählwerte. Laden Sie das PDF
nach der Snapshot-Aktualisierung durch den Bediener erneut herunter, wenn ein
neuer ringverknüpfter Fang zur Flaggenmarkierung noch nicht berücksichtigt ist.

Nutzen Sie die Parent–Nest-Übersicht, um eine Familie anhand der Elternkombination(en)
nachzuschlagen. Kartenpunkte für Nester sind ortsfest; Brutpunkte zeigen den letzten
durch Belege gestützten Begegnungsort und garantieren nicht, dass die Familie noch
dort ist. Overview-Panels helfen bei der Beurteilung von Fortschritt und
Schlupfvorhersagen; sie sind keine Fangfreigaben und kein Ersatz für die aktuellen To-Do-Anweisungen.

Jeder Parent capture-Hinweis mit `tag`, einschließlich einer bedingten
`resight/tag`-Anweisung, erhält eine weiße Umrandung an seinem Kartenpunkt. Die
Umrandung lenkt die Aufmerksamkeit auf die Anweisungen der Zeile; alle Identitäts-,
Zuordnungs-, und Zeitbedingungen dieser Zeile gelten weiterhin.

### Historische notA-Nester nachschlagen

Unter **Show Views** ersetzt `notA_summary` den früheren View2-Tab. Angezeigt wird
eine Zeile pro Nest, dessen letzter veröffentlichter Besuch notA ist, mit beiden
Eltern, gesonderten offenen oder mehrdeutigen Identitätsangaben, dem notA-Besuchsdatum,
und einem gegebenenfalls beobachteten Schlupfdatum. Der aktuelle Geltungsbereich
ist BADO am Cass River, entsprechend der Elternlogik. Zu einem notA-Neststandort
können weiterhin eine lebende Brut und offene Brutaufgaben gehören.

Verknüpfungen zu späteren Nestern erfordern dasselbe zuverlässig bestätigte
Individuum und Geschlecht an beiden Nestern. X-X oder eine gemeinsame Küken-/Rekrutenfarbe
belegt keine Verknüpfung. Mehrere später bestätigte Nester können angezeigt werden.
Später bedeutet hier ein späteres notiertes Erstfunddatum; es beweist weder ein
späteres Legedatum noch, dass das alte Nest vor dem nächsten Versuch formal abgeschlossen wurde.

Der Bericht nutzt den letzten erfolgreichen veröffentlichten Snapshot am gewählten
Referenzdatum. Aktualisieren Sie ihn über den normalen Snapshot-Aufbau, wenn neue
Einträge aufgenommen werden müssen. Ein geändertes Datum oder ein unvollständiger/
fehlgeschlagener letzter Aufbau kann den Bericht leer lassen, bis ein erfolgreicher
passender Snapshot veröffentlicht ist; ein leerer Bericht allein bedeutet nicht,
dass keine historischen notA-Nester vorhanden sind. Der Bediener installiert das
kleine Ansichtsskript einmal nach dem ersten erfolgreichen Snapshot; es muss nicht
für jedes Datum oder jeden Aufbau neu installiert werden.

Wenn eine Elternzuordnungszeile verschwindet, prüfen Sie zuerst, ob ihre Zuordnung
nach Abschnitt 5 geklärt wurde. Wenn Brutarbeit verschwindet, prüfen Sie auch normale
Aufgabenerledigung/Ablauf, vermuteten Verlust, und Erledigung im Jungvogelstadium
nach Abschnitt 9. Das feste Begegnungsfenster von Tag 21 bis 35 kann zugehörige
Elternarbeit ebenfalls ab Tag 36 entfernen; spätere anrechenbare Lebendbelege können
zulässige Arbeit nach einer Aktualisierung zurückbringen. Prüfen Sie den notierten
Abschlussgrund, statt anzunehmen, dass jede fehlende Zeile eine geklärte Elternzuordnung bedeutet.
Der Bediener kann den notierten Grund, das Datum, und die stützenden Belege prüfen;
Fehlen allein sagt dem Feldmitarbeiter nicht, welche Regel angewendet wurde.

Ein positives Nest kann allein deshalb in der Übersicht oder auf der Karte bleiben,
weil sein notA-Besuch noch fällig ist, selbst nach dem Ende der Brutnachverfolgung.
Das ist keine Anweisung, weiter zu versuchen, die erledigte Brut zu beringen oder zu fotografieren.

### Vor dem Abschluss

Vergleichen Sie die Zahlen im Notizbuch mit den gespeicherten Zeilen. Prüfen Sie
jeden neuen Ring, jede negative ID, und jeden Familien-Wegpunkt; vergleichen Sie
anschließend die Mediennotizen mit den kopierten Dateien. Bestätigen Sie, dass kein
Formular versehentlich zweimal gespeichert wurde. Fehlende Arbeit benötigt eine
klare Übergabe, selbst wenn sie aus der To-Do-Anzeige bereits abgelaufen ist.

</details>

<a id="section-11"></a>

<details>
<summary><strong>11. Datenwörterbuch vom Feld zur Datenbank</strong></summary>

## 11. Datenwörterbuch vom Feld zur Datenbank

Dies sind die Feldnamen auf den Formularen. Das Vorhandensein einer Spalte bedeutet
nicht, dass jedes Ereignis einen Wert benötigt; maßgeblich ist die Anforderungstabelle des Verfahrens.

### Identität, Datum, und Ort

| Feld | Bedeutung und Verwendung |
|---|---|
| `species` | BADO für dieses Handbuch; WRYB für einen Schiefschnabel-Datensatz. |
| `site` | Freigegebener Code für das Untersuchungsgebiet, beispielsweise CR für Cass River. In NESTS/CAPTURES/RESIGHTINGS unterstützt, nicht in EGGS. Die Gebietsauswahlliste prüfen, statt überall CR zu verwenden. |
| `observer` | Registrierter Code der beobachtenden/messenden/beringenden Person, nicht automatisch der hochladenden Person. Zwei oder drei Großbuchstaben oder Ziffern verwenden, beispielsweise `AB` oder `P3`, genau wie in OBSERVERS registriert. |
| `date` | Tatsächliches Felddatum, Ortszeit NZ, `YYYY-MM-DD`. |
| `time_visit` | Tatsächliche Zeit des Nestbesuchs oder der Eimessung, `HH:MM`; ein solches Feld gibt es in RESIGHTINGS nicht. |
| `caught`, `released` | Tatsächliche Fang-/Freilassungszeiten, nur CAPTURES. |
| `nest_id` | Positive Verknüpfung zu einem bekannten Nest oder negative Verknüpfung zu einer Brut unbekannter Herkunft. Ein nicht damit zusammenhängender Altvogelfang lässt sie leer und erfordert gps_id/point. Leere IDs bei Familienereignissen müssen die Abschnitte 5 und 7 erfüllen. |
| `gps_id`, `gps_point` | Garmin-Gerät und gespeicherte Wegpunktnummer. Gemeinsam identifizieren sie den hochgeladenen Punkt; keines ist eine Koordinate. |
| `comments` | Belege, Unsicherheit, ausgelassene Beobachtungen, und Gründe für eine gerechtfertigte Ausnahme. |

### Vögel und Markierungen

| Feld | Bedeutung und Verwendung |
|---|---|
| `age` | A Altvogel, J Jungvogel, C Küken; dasselbe Altersfeld gibt es in beiden Vogeltabellen. |
| `sex` / `field_sex` | Geschlecht bei Wiedersichtung / Fang. M/MU männlich/wahrscheinlich männlich; F/FU weiblich/wahrscheinlich weiblich; U unbekannt. Küken/Jungvögel verwenden U. |
| `ring` | Individueller Metallringcode. Erforderlich in CAPTURES und H-RESIGHTINGS; in anderen Wiedersichtungsklassen optional. Ergänzt die Beinmarkierungen. |
| `UL`, `LL`, `UR`, `LR` | Markierungen am linken/rechten oberen/unteren Bein des Vogels. Beobachtete Markierungen in RESIGHTINGS; Markierungen beim Freilassen in CAPTURES. |
| `UL_in`, `LL_in`, `UR_in`, `LR_in` | Markierungen vor dem Handling, nur CAPTURES. Keine Fragezeichen in irgendeinem Fang-Beinfeld. |
| `rclass` | R regulär, P Fotografie, V Video, C erfolgloser Fangversuch, H Versteckfoto. |
| `behav` | Beobachtetes Verhalten. Mehrere zutreffende Kürzel mit Kommas trennen; BC, FC, oder AC lösen die Familienprüfungen aus. Übereinanderliegende Ringfarben nicht durch Kommas trennen. |
| `capture_status` | F erste Markierung, R unveränderter Wiederfang, C geänderte Kombination, D Totfund. |
| `capture_method` | HA Handfang, TB Klappfalle an der Brut, TN Klappfalle am Nest, SM stationäres Japannetz, MM mobiles Japannetz, O sonstiges mit Kommentar. |
| `parents` | Geschlechterzusammensetzung der betreuenden Vögel bei einem Küken-/Jungvogelfang; speichert keine Elternidentitäten. |
| `caught_with` | Zusammen mit dem Zielvogel gefangene Begleiter: M Partner, M? wahrscheinlicher Partner, S gleichgeschlechtlicher Artgenosse, C Küken/Anzahl wie 2C. Die Fragezeichenkonvention ist von den Beinfeldern getrennt. |
| `book_id`, `form_id` | Kennungen von Fangnotizbuch und Seite. |

### Nester und Eier

| Feld | Bedeutung und Verwendung |
|---|---|
| `nest_state` | Nestzustand bei diesem Besuch; Abschnitt 9. |
| `bird_inc` | Geschlecht(er) des anwesenden/brütenden Vogels oder E kein Vogel gesehen. Keine Elternidentität und kein Beweis für ein leeres Gelege. |
| `clutch_size`, `brood_size` | Übrige Eier / beobachtete Küken. Leer ist nicht null. |
| `hatch_state` | Zahlen der übrigen Eier und N/S/C/CC-Zeichen; z. B. 2N1S. |
| `egg_id` | Einummer 1–4 innerhalb des Nests, bei späteren Messungen einheitlich wiederverwendet. |
| `float_angle` | Ganze Grad, 0–90. |
| `float_location` | bottom, suspended, oder surface. |
| `float_surface` | Ganze mm 0–3 bei einem Ei an der Oberfläche; leer bei bottom/suspended. |

### Messwerte, Medien, und Tags

| Feld(er) | Bedeutung und Verwendung |
|---|---|
| `tarsus`, `culmen`, `total_head`, `wing` | Längen in mm nach den festgelegten Methoden des Teams. |
| `head_white`, `head_black`, `rufous_band` | Bandbreiten in mm; altersabhängige Anforderungen in Abschnitt 6. |
| `weight`, `wt_w_tag` | Masse in g; 0/1 gibt an, ob diese Masse einen Tag einschloss. |
| `brood_patch`, `moult_left`, `moult_right`, `fat`, `feather_wear` | Beurteilungen von Zustand/Mauser, kein Ersatz für Kommentare. Die erlernte Bewertung verwenden; Anhang A. |
| `breast_samp`, `primary_samp` | Kennzeichen für Federproben 0/1, soweit zutreffend. |
| `blood_samp`, `other_sample` | Code der Blutkonservierung oder Beschreibung einer anderen tatsächlichen Probe. Kein Blut: leer. |
| `cam_id`, `photo_start`, `photo_end` | Kamera und vollständige erste/letzte Bildkennung. Vorhanden in NESTS/CAPTURES/RESIGHTINGS, nicht in EGGS. |
| `nest_photo`, `tent_photo` | Gelegefoto-Kennzeichen in NESTS. |
| `mugshot_photo`, `wing_photo`, `chick_tent_photo` | Handling-Fotokennzeichen in CAPTURES. |
| `chick_hide_photo` | Im Formular beibehaltenes CAPTURES-Feld; je nach Gültigkeit 0/leer verwenden. Tatsächliche Versteckbilder erfordern eigene H-Zeilen. |
| `tag_action`, `tag_type`, `tag_id_in`, `tag_id` | Tag-Maßnahme/-Typ beim Altvogel und Vorher-/Nachher-IDs; Abschnitt 8. Bei Küken-/Jungvogelfängen leer. |
| `eggs_handled` | Nur CAPTURES, 0/1: Eier während des Fangs vorübergehend entfernt. |
| `observer_upload` | Nur CAPTURES: registrierter Code der eingebenden Person; dasselbe Format mit zwei oder drei Zeichen aus Großbuchstaben/Ziffern gilt. |
| `falcon_upload` | Verwaltung des DOC/FALCON-Uploads, keine Erledigung der Feldarbeit. Formularvorgabe/Handhabung der zuständigen hochladenden Person überlassen. |
| `nov`, `pk` | Von der App verwaltete Validierungs-/Datensatzkennungen. Nicht ändern, um einen Fehler zu beseitigen. |

Der Medienspeicherort gehört in das Medienregister des Teams, nicht in eine erfundene
Spalte `harddrive_id`. Meldungen aus der Öffentlichkeit werden gesondert vom
zuständigen Teammitglied betreut; verschieben Sie keine regulären Feldbeobachtungen
aus RESIGHTINGS, um deren Eingabeprüfungen zu umgehen.

</details>

<a id="section-12"></a>

<details>
<summary><strong>12. Validatormeldungen und Korrekturhilfe</strong></summary>

## 12. Validatormeldungen und Korrekturhilfe

### Die Meldung mit dem Notizbuch abgleichen

Öffnen Sie **DATA ENTRY ISSUES** und lesen Sie die benannte Zeile und Spalte.
Korrigieren Sie einen Tippfehler, einen falschen Vorgabewert, oder eine ausgelassene
Beobachtung, und prüfen Sie erneut. Ein speicherblockierender Fehler erfordert vor
der Übermittlung Aufmerksamkeit; eine Warnung fordert zur Prüfung auf, beweist aber
nicht, dass die Beobachtung falsch ist.

| Meldung/Problem | Prüfung und Reaktion |
|---|---|
| Pflichtfeld fehlt | Notizbuch und ereignisspezifische Tabelle verwenden; unbekannt nicht durch null ersetzen. |
| GPS fehlt/nicht gefunden | GPS zuerst hochladen. Beide tatsächlichen Nummern und das Begegnungsdatum prüfen; niemals einen lediglich bequemen hochgeladenen Punkt auswählen. |
| Fang mit Alter C und Status R oder C ohne gps_id/point | Beide Felder auch bei positiver ID eintragen. Die Status-F-Ausnahme gilt nicht für Fänge mit Status R oder C. |
| Elternvogel mit Küken ohne Kükenzeile | Wenn Küken gefangen wurden, zuerst die echten CAPTURES-Zeilen mit Alter C und passendem Datum, Gebiet, und gps_id/point speichern. Andernfalls die tatsächlichen Kükensichtungen ergänzen. Keine erfundenen zusätzlichen Wiedersichtungen. |
| Küken-Wiedersichtung ohne Elternvogel | Die tatsächliche Beobachtung des betreuenden Elternvogels in dieselbe Übermittlung aufnehmen; ein unberingter Elternvogel ist X-X. Wenn kein Elternvogel gesehen wurde, die Ausnahme unten verwenden. |
| Leere ID bei gewöhnlicher Kükensichtung | Datum/GPS, elterliches BC, FC, oder AC, und eine verlässliche Familienzuordnung prüfen. Bei leeren Eltern-IDs einer negativen Familie müssen beide sozialen Eltern bereits geklärt sein. |
| Mehrdeutige Familie/Eltern | Identitäten und bekannte ID mit der Feldleitung erneut prüfen. Nicht die erste Übereinstimmung wählen oder eine ungeklärte Zuordnung übersteuern, als wäre sie gesichert. |
| H-Ring fehlt/nicht gefunden | Tatsächlicher CP-Ring, bereits in CAPTURES der aktuellen Saison gespeichert. Die optionale Ringregel einer gewöhnlichen Sichtung gilt nicht. |
| Medien bei H/Klasse P oder V unvollständig | Kamera und beide Bereichsgrenzen. H benötigt auch beide GPS-Felder, einschließlich bei positiver ID. |
| Unbekannte Wiedersichtungsmarkierung abgewiesen | Unterstützte Notation ?, ?R, R?, oder UR T? bestätigen. Ein Live-Inspektor kann noch vor der Korrektur liegen: die wahre Ablesung beibehalten und die Abweichung weitergeben. |
| Fragezeichen in Fangmarkierungen | Tatsächliche Markierungen des Vogels in der Hand ablesen. Keine unsichere Wiedersichtung in Fangfelder kopieren und Unsicherheit nicht durch X ersetzen. Eine beschädigte/unlesbare Markierung zur Klärung weitergeben. |
| T allein | Jeder Tag hat einen Abstandshalter: tatsächliche bekannte Farbe beim Fang oder T? bei einer Wiedersichtung, wenn unlesbar. |
| Fotobereich überlappt ein anderes Ereignis | Kamera, vollständiges Präfix, und Zuordnung der Bildserie prüfen. Nur die Regel für gemeinsam genutzte H-Bereiche derselben Sitzung erlaubt gemeinsame Bereiche. |
| Status R, aber Markierungen geändert | Vorher-/Nachher-Ringe prüfen; eine tatsächlich geänderte Kombination verwendet Status C. |
| Tag-Historie stimmt nicht überein | Ring, alte/neue Tag-IDs, und vorherige Maßnahme prüfen. Keine ID ändern, um eine Historie herzustellen. |
| Messwertwarnung | Einheiten, Übertragung, Alter/Status, und tatsächlichen Messwert prüfen. Einen gültigen ungewöhnlichen Wert mit Erklärung beibehalten; gegebenenfalls die Bereitschaft zur Flaggenmarkierung prüfen. |
| Nestchronologie oder Eibesuch passt nicht | Tatsächliche Besuchsfolge, Beobachter, und Zeiten prüfen. Niemals Schlupfbelege erfinden oder eine Messzeit ändern, damit eine Verknüpfung die Prüfung besteht. |
| Erstes F mit null Eiern nach Fund von Küken im Nest abgewiesen | Erwartete Schutzprüfung. Beobachtung erneut prüfen; falls korrekt, tatsächliche Zahlen beibehalten und den seltenen Fund im Nest in den Kommentaren erklären. Die dokumentierte Übersteuerung verwenden, falls nach Prüfung aller anderen Felder weiterhin blockiert. Keine programmierte Validatorausnahme erforderlich. |
| Weiterer pP-, P-, oder D-Besuch abgewiesen | Ausgangskontrollen bleiben nach der freigegebenen Methode bis zum letzten notA erlaubt. Tatsächliche Folge prüfen und die Endzustandsmeldung eines älteren Validators weitergeben. |
| Validator fehlgeschlagen / keine sinnvolle Zeile oder Variable | Möglicher Inspektorfehler. Meldung aufbewahren und um technische Prüfung bitten; dies ist kein biologischer Befund. |

### Küken ohne Elternvogel gesehen

Tragen Sie Küken und Wegpunkt so ein, wie sie angetroffen wurden. Ergänzen Sie
einen konkreten Kommentar, beispielsweise „Zwei beringte Küken wiedergesehen;
bei dieser Begegnung kein betreuender Altvogel gesehen.“ Dies ist eine berechtigte
Ausnahme von der normalen Begleiteltern-Prüfung und kein Grund, einen Altvogel zu erfinden.

Prüfen Sie jedes andere Feld. Wenn der wahrheitsgemäße Eintrag weiterhin blockiert
wird, nutzen Sie die dokumentierte Steuerung des Portals: **VALIDATION** auf **OFF**
setzen, den erklärenden Kommentar am betroffenen Datensatz beibehalten und ihn in
der Übergabe kennzeichnen. Stellen Sie die Validierung für folgende gewöhnliche
Einträge wieder auf ON. Wenn auch die Nest-/Brut-ID unbekannt ist, erklären Sie
dies gesondert; der fehlende Elternvogel liefert keine Verknüpfung bei leerer ID.

Ein beobachteter unberingter Elternvogel ist nicht abwesend: Tragen Sie seine X-X-
Zeile ein. Eine vergessene Elternzeile, ein unvollständiger gps_id/point, oder ein
fehlender H-Ring ist nicht dieselbe Ausnahmesituation. Die Übersteuerung selbst
beweist weder Elternschaft noch erledigte To-Do-Arbeit und hebt H-Ring-/GPS-/Medienanforderungen nicht auf.

### Seltener Fund von Küken im Nest ohne Eier

Die normale Abweisung eines ersten F mit Gelegegröße null ist beabsichtigt. Prüfen
Sie bei der sehr seltenen F → H-Entdeckung aus Abschnitt 4 erneut, dass die Küken
tatsächlich in einem eindeutigen Nest waren, behalten Sie die tatsächlichen Zahlen
bei, und kommentieren Sie die Umstände. Die geprüfte Meldung fordert bereits dazu
auf, erneut zu prüfen und bei korrektem Eintrag einen Kommentar zur Umgehung der Validierung hinzuzufügen.

Wenn nach Prüfung der anderen Felder weiterhin eine Blockierung besteht, setzen
Sie **VALIDATION** für den gerechtfertigten Eintrag auf **OFF**, behalten Sie den
erklärenden Kommentar bei, und stellen Sie anschließend wieder auf ON. Ändern Sie
nicht den Inspektor und tragen Sie keine erfundene Eizahl ein.

### Wenn die Live-App von diesem Entwurf abweicht

Bewahren Sie die genaue Feldbeobachtung und Meldung auf. Geben Sie die Abweichung
an die Feldleitung weiter, bevor Sie eine Umgehungslösung übernehmen. Schalten Sie
die Validierung nicht routinemäßig aus, um einen noch nicht installierten korrigierten
Inspektor nachzuahmen. Aktuelle lokale Prüfungen sind keine Verifizierung des Live-Portals;
Angaben zu Quelle/Version stehen in Abschnitt 15.

</details>

<a id="section-13"></a>

<details>
<summary><strong>13. Erforderliche Datenbankereignisse je nach Situation</strong></summary>

## 13. Erforderliche Datenbankereignisse je nach Situation

Mit diesen Tabellen prüfen Sie, welche Einträge für eine Begegnung nötig sind. „Angaben zur Wiedersichtung“ meint `species`, `site`, `observer`, `date`, `rclass`, `age`, `sex`, die beobachteten Beinmarkierungen, und das zutreffende `behav`. „Fangangaben“ meint die erforderliche Identität, den Status, die Zeiten, die Markierungen, und die altersspezifischen Felder aus Abschnitt 6. Für GPS- und Familienausnahmen gelten weiterhin die Bedingungen aus den Abschnitten 3 und 5.

<details>
<summary><strong>Neues Nest oder neue Nestmulde</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Neu vergebene positive ID: `NESTS`, ein erster Besuch. |
| Erforderlich | `species`, `site`, `observer`, `date`, `time_visit`, `nest_id`, `nest_state`, beide GPS-Felder. |
| Bedingt | Bei S ist die Gelegegröße null; Ei-/Kükenzahlen, anwesender Vogel, und Schlupfzeichen so, wie beobachtet. |
| Fotos | `nest_photo`/`tent_photo`, tatsächliche Kamera/Bildbereich in NESTS. |
| Nicht eintragen | Negative ID oder Platzhalter-ID, wiederverwendete Entdeckungs-Laufnummer, oder erfundene Eimaße. |
| Wahrscheinliche To-Do-Folgearbeit | Muldenfotos, Bearbeitung, weitere Eier, oder Schlupfkontrollen. |

</details>

<details>
<summary><strong>Frisch geschlüpfte Küken in einem eindeutig erkennbaren Nest gefunden</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Sehr seltene Erstentdeckung mit Küken, die noch in ihrem Nest sind: zwei NESTS-Zeilen, F und unmittelbar danach H. |
| Erforderlich | Dieselbe neue positive ID; Entdeckungs-gps_id/point bei F; H-Zeit mindestens eine Minute später; tatsächliche Ei-/Kükenzahlen und normale Besuchsangaben. |
| Bedingt | Wenn keine Eier mehr da sind, ist die Gelegegröße 0; kein früheres Gelege erfinden. Einzelne Vögel erhalten ihre eigenen Fang-/Wiedersichtungsereignisse. |
| Fotos | Tatsächliche Nest-Bildfolge beim zugehörigen Besuch; Medien vom Versteck/von der Handhabung der Küken bleiben getrennt. |
| Nicht eintragen | Negative ID für den belegten Nestursprung; erfundene Eier/Eizeilen; F/H-Nestereignisse für eine Brut unbekannter Herkunft, die außerhalb des Nests gefunden worden ist. |
| Wahrscheinliche To-Do-Folgearbeit | Beringung, H-Fotos, und abschließendes notA. Die normale F-Schutzprüfung bei null Eiern bleibt bestehen; eine korrekte seltene Beobachtung erklären und bei Bedarf die dokumentierte Übersteuerung verwenden. |

</details>

<details>
<summary><strong>Bereits bekanntes Nest</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Neuer Besuch bei bestehender ID: `NESTS`, eine neue Zeile. |
| Erforderlich | Bestehende `nest_id`, heutige Besuchsangaben/Zustand, und tatsächliche Befunde. |
| Bedingt | Ei-/Kükenzahlen, Schlupf-/Schicksalsbelege; Bedingungen für den endgültigen Abschluss in Abschnitt 9. |
| Fotos | Heutige Bildfolge, falls aufgenommen. Direkte Nest-GPS-Felder bleiben nach dem ersten Besuch leer. |
| Nicht eintragen | Heutige Befunde anstelle eines früheren Besuchs eintragen; eine zweite F-Entdeckung für dieselbe ID. |
| Wahrscheinliche To-Do-Folgearbeit | Bearbeitung, Gelege-/Schlupfprüfung, oder Abschluss. |

</details>

<details>
<summary><strong>Eier vermessen, im Wasser geprüft, oder fotografiert</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Nestbesuch: eine NESTS-Zeile. Messungen: eine EGGS-Zeile je vermessenem Ei. Reines Fotografieren fügt keine EGGS-Zeilen dazu. |
| Erforderlich | EGGS: `species`, `observer`, `date`, `time_visit`, positive `nest_id`, eindeutige `egg_id`. Tatsächliche Flotationswerte erfassen, wenn welche erhoben worden sind. |
| Bedingt | `float_surface` untergetaucht leer, an der Oberfläche 0–3; Zeitvorgaben und Zuordnung zum Nestbesuch in Abschnitt 4. |
| Fotos | NESTS-Fotofelder, `cam_id`, `photo_start`, `photo_end`. |
| Nicht eintragen | Negative IDs, `site`-/Kamera-/Laufwerksfelder in EGGS, oder Flotationswerte für Eier mit Sternrissen/Schlupfanzeichen. |
| Wahrscheinliche To-Do-Folgearbeit | Nestbearbeitung, Schlupfprognose/-kontrollen; fehlende Messungs-/Besuchszuordnung prüfen. |

</details>

<details>
<summary><strong>Altvogel oder Küken nur gesehen</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Vogel nicht in der Hand: `RESIGHTINGS`, eine Zeile je Individuum. |
| Erforderlich | Angaben zur Wiedersichtung; direktes GPS, wo vorgeschrieben. |
| Bedingt | Nest-/Brutverknüpfung, Prüfung auf begleitenden Elternvogel bei Alter C, belegte Teilablesungen der Markierungen. |
| Fotos | Klasse P oder V/H braucht Kamera und vollständigen Bildbereich; für H gelten zusätzliche Ring-/GPS-Regeln. |
| Nicht eintragen | Fang, Proben, oder Geräteaktion für einen Vogel, der nicht in der Hand war. |
| Wahrscheinliche To-Do-Folgearbeit | Elternzuordnung, Brutarbeit, oder Beobachtung des besenderten Vogels. |

</details>

<details>
<summary><strong>Unberingter Vogel, auch ein betreuender Elternvogel</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Vogel unberingt gesehen: `RESIGHTINGS`, eine Zeile je Individuum. |
| Erforderlich | Angaben zur Wiedersichtung; mindestens `LL = X`, `LR = X`; tatsächliches Alter/Geschlecht/Verhalten und Standort. |
| Bedingt | Elternzeile mit BC, FC, oder AC begleitet Kükensichtungen; ausdrückliche ID, wenn nötig. |
| Fotos | Tatsächliche klassenabhängige Felder. |
| Nicht eintragen | Elternvogel nur wegen fehlender Beringung weglassen; X für unlesbare Ringe verwenden; X-X als weltweit eindeutigen Vogel behandeln. |
| Wahrscheinliche To-Do-Folgearbeit | Elternidentität/-beringung oder Prüfung der Familienverknüpfung. |

</details>

<details>
<summary><strong>Brut mit positivem Nest verknüpft</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `CAPTURES` für Vögel in der Hand, `RESIGHTINGS` für Sichtungen; eine Zeile je individuellem Ereignis. |
| Erforderlich | Ereignisangaben, gemeinsames Familiendatum, site, und gps_id/point; bekannte positive ID, wo vorgeschrieben. |
| Bedingt | Bei geeigneten späteren Wiedersichtungen darf die ID nur nach Abschnitt 5 fehlen; die Vorgeschichte von Eltern mit Küken am positiven Nest muss H/notA stützen. |
| Fotos | Handhabung in CAPTURES; Versteck auf eigenen H-Zeilen. |
| Nicht eintragen | Mehrere Küken in einer Zeile, neue negative ID nur weil die Brut weitergezogen ist, fortgesetzte H-Nestbesuche nach dem letzten Schlupf. |
| Wahrscheinliche To-Do-Folgearbeit | Beringung, Versteckfotos je Küken, Flaggenmarkierung, und Abschluss des positiven Nests. |

</details>

<details>
<summary><strong>Mobile Brut, deren Nest nie gefunden worden ist</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Nur `CAPTURES` / `RESIGHTINGS`, eine Zeile je individuellem Ereignis. |
| Erforderlich | Vergebene negative `nest_id`, wo vorgeschrieben; beide GPS-Felder und gemeinsames Familiendatum/site. |
| Bedingt | Spätere Familienwiedersichtungen mit leerer ID erst nach der bestätigten Verknüpfung beider Eltern aus Abschnitt 5; keine Zeile für einen abwesenden Elternvogel erfinden. Erste Kükenfänge behalten die ausdrückliche ID. |
| Fotos | Getrennte Zelt-/H-Ereignisse; bei H sind Ring und Kamera/Bildbereich Pflicht. |
| Nicht eintragen | NESTS- oder EGGS-Zeile, weggelassenes Minuszeichen, oder ein Platzhalter statt der Brut-ID. |
| Wahrscheinliche To-Do-Folgearbeit | Elternzuordnung, Beringung, Fotos, und spätere Flaggenmarkierung; die Fotoanzeige verwendet Entdeckungstage 1–6. |

</details>

<details>
<summary><strong>Altvogel oder Küken gefangen/wiedergefangen</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `CAPTURES`, eine neue Zeile je Handhabungsereignis. |
| Erforderlich | Fangangaben, Metall-`ring`, passende alters-/statusabhängige Messungen, und Markierungen vorher/nachher. |
| Bedingt | Bei Alter C und Status R oder C immer direktes GPS; erster Kükenfang F braucht eine echte positive/negative ID. Bei Altvogel mit Küken in `caught_with` ist direktes GPS Pflicht. Geräte/Proben so, wie tatsächlich angebracht/genommen. |
| Fotos | Handhabungs-Fotofelder und tatsächliche Kamera/Bildbereich; eigene H-Zeilen für Versteckfotos. |
| Nicht eintragen | Fragezeichen in irgendeinem Beinfeld; einen früheren Fang überschreiben; erfundene doppelte Sichtung. |
| Wahrscheinliche To-Do-Folgearbeit | Beringung, Eltern-/Gerätearbeit, Fotos je Küken, oder Flaggenmarkierung. |

</details>

<details>
<summary><strong>Küken gefangen, Eltern nur wiedergesehen</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Eine CAPTURES-Zeile je Küken in der Hand; eine RESIGHTINGS-Zeile je beobachtetem Elternvogel. |
| Erforderlich | Kükenfänge zuerst speichern. `date`, `site`, `gps_id`, `gps_point` über die Tabellen hinweg gleich halten; tatsächliches elterliches BC, FC, oder AC. |
| Bedingt | Normale Nest-/Brut- und Fangfelder; wenn auch H-Fotos gemacht worden sind, eigene H-Zeilen. |
| Fotos | Zelt-Bildfolge beim Fang, Versteck-Bildfolge bei H. |
| Nicht eintragen | Zusätzliche Kükensichtungen nur, damit die elternseitige Prüfung passt; erfundener Elternvogel. |
| Wahrscheinliche To-Do-Folgearbeit | Familienzuordnung, Kükenfotos, oder Flaggenmarkierung. |

</details>

<details>
<summary><strong>Küken ohne Elternvogel gesehen</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `RESIGHTINGS`, eine Zeile je tatsächlich gesehenem Küken. |
| Erforderlich | Angaben zur Wiedersichtung, tatsächlicher Wegpunkt, konkrete Erklärung für den fehlenden Elternvogel. |
| Bedingt | Bekannte ID; begründete Übersteuerung wegen fehlendem Elternvogel, falls blockiert. Unbekannte ID braucht eine eigene Erklärung. |
| Fotos | H-Vorgaben zu Ring/GPS/Foto bleiben gleich. |
| Nicht eintragen | Einen erfundenen betreuenden Elternvogel oder eine behauptete abgeleitete Familienverknüpfung ohne Belege. |
| Wahrscheinliche To-Do-Folgearbeit | Prüfung der Familienverknüpfung und Übergabe des wahrheitsgemäßen Ausnahmeeintrags. |

</details>

<details>
<summary><strong>Kükenfoto im Zelt</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Auf der bestehenden Handhabungszeile in `CAPTURES`; keine zweite Fangzeile. |
| Erforderlich | `chick_tent_photo = 1`, `cam_id`, `photo_start`, `photo_end`, normale Fangangaben. |
| Bedingt | Weitere Handhabungsmessungen/Proben, soweit zutreffend. |
| Fotos | Nur die Zelt-Bildfolge. |
| Nicht eintragen | Dieselbe Bildfolge als eigenes H-Versteckfoto. |
| Wahrscheinliche To-Do-Folgearbeit | Versteckfotos bleiben nötig, wenn noch nicht erledigt. |

</details>

<details>
<summary><strong>Versteckfoto von einem Küken</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Eigenes `RESIGHTINGS` H, eines je fotografiertem Küken. |
| Erforderlich | Alter C, Geschlecht U, ausdrückliche gültige positive/negative `nest_id`, individueller `ring`, beobachtete Markierungen, beide GPS-Felder, vollständige Kamera/Bildbereich, und Begegnungsangaben. |
| Bedingt | Tatsächliche Elternwiedersichtung in derselben Übermittlung, außer beim begründeten Fall ohne Elternvogel. Fangring zuerst speichern. Keine Ausnahme mit leerer ID für eine neue H-Zeile. |
| Fotos | Versteck-Bildfolge; gemeinsamer H-Bildbereich nur nach der Regel für dieselbe Fotositzung aus Abschnitt 7. |
| Nicht eintragen | Versteckbeleg nur in `chick_hide_photo`; zusammengefasster Handhabungs-/H-Eintrag; doppelter Ring als weiteres fertig fotografiertes Küken. |
| Wahrscheinliche To-Do-Folgearbeit | Broods to photograph: individueller Fortschritt, biologische Frist vor Erreichen eines Alters von sieben Tagen, getrennte Anzeige-Zeitrechnung. |

</details>

<details>
<summary><strong>Normale oder spezielle Wiedersichtung</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `RESIGHTINGS`, eine Zeile je Vogel und tatsächlichem Ereignis. R/Klasse P oder V/C/H nach Abschnitt 2 auswählen. |
| Erforderlich | Angaben zur Wiedersichtung; Verhalten außer bei den optionalen Fällen für normale R-Küken/H. |
| Bedingt | Klasse P oder V/H mit Kamera/Bildbereich. Die alters-C-bezogenen Familien- und GPS-Prüfungen gelten für jede Klasse weiter. |
| Fotos | H ausdrücklich fürs Kükenversteck, nicht allgemeines P. |
| Nicht eintragen | Veraltete Klassenwerte, Fangzeile für einen gescheiterten Versuch, oder R mit Medien, um die Vorgaben für Klasse P oder V/H zu umgehen. |
| Wahrscheinliche To-Do-Folgearbeit | Hängt von den tatsächlichen Eltern-/Brut-/Gerätebelegen ab, nicht nur vom Buchstaben. |

</details>

<details>
<summary><strong>Geolokator beim Altvogel anbringen, abnehmen, belassen, oder ersetzen</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `CAPTURES`, eine Zeile je Altvogel in der Hand. |
| Erforderlich | Normale Fangangaben und die genauen O/D/R/S/N-Zellen für vorher/nachher aus Abschnitt 8. |
| Bedingt | Gerätegeschichte, bekannte Abstandshalterfarben, `wt_w_tag`, und aktionsspezifische IDs. Eignung/Zeitvorgaben vor dem Fang prüfen. |
| Fotos | Tatsächliche Handhabungs-Bildfolge, falls aufgenommen. |
| Nicht eintragen | Geräteaktion bei einem nur gesichteten Vogel; O bei einem Küken; T? bei einem Fang; Partnerfang beim selben Besuch nur zur Paarvervollständigung. |
| Wahrscheinliche To-Do-Folgearbeit | Luke Eberhart-Hertels Anweisungen zu Ausbringungswelle/Bestand, Partnereignung, und spätere Abnahme. |

</details>

<details>
<summary><strong>Besenderten Altvogel nur beobachtet</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `RESIGHTINGS`, eine Zeile je beobachtetem Altvogel. |
| Erforderlich | Angaben zur Wiedersichtung und tatsächlich gesehene Markierungen. |
| Bedingt | UR TY, oder T? bei unlesbarem Abstandshalter; Verhalten, Familie/Standort, und Klasse-P- oder -V-Felder, soweit zutreffend. |
| Fotos | Klasse P oder V, wenn eine entsprechende Aufnahme stattgefunden hat. |
| Nicht eintragen | Reines T; geratene Geräte-ID; Abnahme daraus ableiten, dass man ein Gerät nicht gesehen hat. |
| Wahrscheinliche To-Do-Folgearbeit | Geschichte des besenderten Vogels, Status-/Identitätsprüfung bei Unsicherheit. |

</details>

<details>
<summary><strong>Schlupf beobachtet</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | Ein `NESTS`-Besuch, dazu individuelle Vogelereignisse so, wie angetroffen. |
| Erforderlich | Zustand H, wahre Zahlen der verbliebenen Eier/Küken, und Besuchsangaben. |
| Bedingt | `hatch_state` für verbliebene Eier; später ein endgültiges notA. |
| Fotos | Tatsächliche passende Nest-Bildfolge; Kükenmedien bleiben bei ihren eigenen Ereignissen. |
| Nicht eintragen | Küken als Eier; spätere H-Nestbesuche nach dem letzten Schlupfbesuch mit null Eiern. |
| Wahrscheinliche To-Do-Folgearbeit | Beringung, H-Fotos, und Abschluss, während die Brutarbeit weitergeht. |

</details>

<details>
<summary><strong>Brutverlust oder endgültiger Abschluss</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | `NESTS`, eine Zeile je tatsächlichem Besuch am positiven Nest. |
| Erforderlich | Bestehende ID, Datum/Zeit, Belege, und passender möglicher/bestätigter Zustand oder endgültiges notA. |
| Bedingt | Weitere Schicksalskontrollen mit pP, P, oder D bleiben bis zum endgültigen notA erlaubt; Zählwerte und Bedingungen für D → notA / Abschluss nach H in Abschnitt 9. |
| Fotos | Beleg-Bildfolge, wenn aufgenommen. |
| Nicht eintragen | Gewissheit nur aus einem leeren Nest; Abschluss für eine negative Brut; notA für einen weiteren Versuch wieder öffnen. |
| Wahrscheinliche To-Do-Folgearbeit | Vereinbarte Schicksalsprüfung/Abschluss; Nachverfolgung der überlebenden Brut bleibt getrennt. |

</details>

<details>
<summary><strong>GPS, Medien, und Übergabe am Tagesende</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | GPS-Upload liefert GPS_POINTS/GPS_TRACKS; biologische Einträge behalten ihre individuellen Ereignisse. |
| Erforderlich | Richtige gps_id/point-Werte, tatsächliche Felddaten, und Medienkennungen; Einträge vor der Übergabe speichern/prüfen. |
| Bedingt | Zuständige Bedienperson um Aktualisierung der veröffentlichten To-Do-Ergebnisse bitten; Übersteuerungen und ungeklärte Verknüpfungen prüfen. |
| Fotos | Originale kopieren, Sicherungen/Bildbereiche prüfen; Speicherort im Medienregister. |
| Nicht eintragen | GPS-Zeilen/Koordinaten von Hand erfinden, übermittelte Ereignisse verdoppeln, oder `nov`/`pk` als Reparatur verwenden. |
| Wahrscheinliche To-Do-Folgearbeit | Aktualisiertes datiertes PDF und klare Liste der unerledigten Feldarbeit. |

</details>

<details>
<summary><strong>Frühere Eltern ohne Küken oder an einem anderen Nest gesehen</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | RESIGHTINGS: eine Zeile je tatsächlich beobachtetem Altvogel bei jeder echten Gelegenheit. Ein anderes Nest braucht auch seine echten NESTS-Besuche, keine NESTS-Zeile für Brutverlust. |
| Erforderlich | Normale Altvogelangaben zu observer/date/site/age/sex, beobachtete Beinmarkierungen, `rclass`, und tatsächliches `behav`. Begegnungs-gps_id/point aufnehmen. Für Weg 1 in Abschnitt 9 die verlässliche alte Brut-ID ausdrücklich eintragen. |
| Bedingt | An einem anderen Nest dessen eigene positive ID und tatsächliche Zuordnungsbelege eintragen. Alle tatsächlich angetroffenen Küken erfassen; normale Familien-/Übermittlungsregeln verwenden, wenn BC/FC/AC zutrifft. OB und unsicheres Schicksal in Kommentaren erklären. |
| Fotos | Normales R braucht keine erfundenen Fotofelder. P oder V mit ihren Pflichtmedien verwenden, wenn so eine Aufnahme stattgefunden hat. H bleibt speziell für Küken-Versteckfotos. |
| Nicht eintragen | Einen erfundenen Partner/ein erfundenes Küken, falsche Abwesenheitszahl, erfundenes IN/AC, doppelte Sichtung, verschobenes Datum, oder eine CAPTURES-Totfundzeile, um vermuteten Verlust zu erzwingen. Keine NESTS-Zeilen für eine negative Brut. |
| Wahrscheinliche To-Do-Folgearbeit | Elternzuordnung kann unabhängig vom Brutschicksal geklärt werden. Geeignetes erneutes Nisten, wiederholte Belege ohne Brutbetreuung, oder die feste Regel ohne Begegnung an Tagen 21–35 können Brut- und zugehörige Elternarbeit unterdrücken. Geeignete Lebendbelege können vermuteten Verlust verhindern oder Arbeit wieder öffnen. Abschnitt 9. |

</details>

<details>
<summary><strong>Totfund oder Jungvogel mit Ursprungsverknüpfung</strong></summary>

| Erforderliche Datenbankereignisse | Eintrag |
|---|---|
| Situation / Tabelle / Zeilen | CAPTURES: eine Zeile je tot gefundenem oder tatsächlich in der Hand gehaltenem Vogel. RESIGHTINGS: eine Zeile je nur gesehenem Jungvogel. Handhabung oder Sichtung niemals erfinden. |
| Erforderlich | Normale Ereignisfelder aus Abschnitt 6. Für D: tatsächliches Alter, Ring, alle vier beim Fund vorhandenen _in-Positionen, leere Freilassungs-Beinfelder, und leere Freilassungszeit. Die Fundmarkierungen von einem Jungvogel müssen keine Flagge enthalten. |
| Bedingt | Bekannte Ursprungs-/Brut-ID und tatsächliche gps_id/point nach den Standortregeln. Für automatische J-Auflösung muss die ursprüngliche Brut aus Eintrag/Vorgeschichte verlässlich und ohne widersprüchliche Identitäten erkennbar sein. Eine spätere soziale Brutverknüpfung bewahren, statt frühere Einträge umzuschreiben. |
| Fotos | Nur tatsächliche Fotos, mit ihren eigenen Kamera-/Bildbereichsmetadaten, wenn eingetragen. Keine Fotos oder Flaggenmarkierungen für eine Lebendfreilassung erfinden. |
| Nicht eintragen | Fragezeichen in Fang-Beinfeldern, erfundene Freilassungsmarkierungen/-zeit, eine D-Zeile für vermuteten Verlust, oder J nur zum Leeren der To-Do-Liste. |
| Wahrscheinliche To-Do-Folgearbeit | Alter C mit D allein schließt die Brut nicht. Ein verlässlich ursprungsverknüpftes J-Ereignis, auch D, erledigt die Kükenphasenarbeit; unabhängig erforderliche positive notA-Arbeit bleibt. |

</details>

</details>

<a id="section-14"></a>

<details>
<summary><strong>14. Durchgearbeitete Beispiele</strong></summary>

## 14. Durchgearbeitete Beispiele

### Ein neues Nest mit zwei Eiern und sein brütender Elternvogel

Sie finden B0203, nehmen Punkt 214 auf Garmin 4 auf, prüfen beide Eier mit Flotation, und identifizieren den brütenden Elternvogel.

| Eintrag | Tabelle/Zeilen | Wichtigste Angaben |
|---|---|---|
| Entdeckung | NESTS, 1 | Positive ID B0203; F; tatsächliche Besuchsangaben; Gelege 2; GPS 4 / 214. |
| Eimessungen | EGGS, 2 | B0203, Ei 1 und 2, tatsächliche messende Person/Zeiten, und jeder Flotationswert. |
| Gelegefotos | Auf der NESTS-Zeile | Zutreffende Fotofelder, Kamera, und Bildbereich. |
| Brütender Elternvogel | RESIGHTINGS, 1 | A, R, IN, tatsächliche Markierungen/Geschlecht, und B0203. |

Wenn B0203 als bekannte Nestmulde angefangen hat, behalten Sie seine ID; die frühere S-Zeile enthält bereits die Nest-gps_id/point, deshalb bleiben die GPS-Felder beim heutigen F leer.

### Ein Elternvogel und zwei beringte Küken

Am 25. Oktober ist ein verlässlich mit B0203 verknüpfter Altvogel mit zwei Küken wachsam. Der Begegnungswegpunkt ist GPS 4 / Punkt 216.

| Vogel | Tabelle | Alter / Klasse / Verhalten | `nest_id` | GPS |
|---|---|---|---|---|
| Elternvogel | RESIGHTINGS | A / R / AC | B0203 | 4 / 216 |
| Küken 1 | RESIGHTINGS | C / R / leer, wenn kein Verhalten erfasst | B0203, oder zulässig leer | 4 / 216 |
| Küken 2 | RESIGHTINGS | C / R / leer, wenn kein Verhalten erfasst | B0203, oder zulässig leer | 4 / 216 |

Übermitteln Sie die drei Zeilen gemeinsam, mit demselben Datum/site und den normalen Pflichtangaben. Bei normalen Kükensichtungen darf der Ring leer bleiben. Wenn beide Eltern gesehen werden und beide zu B0203 gehören, tragen Sie beide ein: Es gibt weiterhin nur eine eindeutige Familien-ID.

### Küken gefangen, Eltern wiedergesehen

Zwei Küken werden gefangen, während beide Eltern in der Nähe betreuen. Speichern Sie zuerst die zwei Kükenzeilen in CAPTURES, dann tragen Sie die zwei echten Elternzeilen in RESIGHTINGS ein. Alle vier Einträge verwenden dasselbe Datum, site, und gps_id/point.

Die gespeicherten Fänge erfüllen die Prüfung auf begleitende Küken bei den Eltern. Kükenzeilen in RESIGHTINGS sind nicht allein deshalb nötig, weil die Küken in der Hand waren. Wenn Sie auch Versteckfotos machen, übermitteln Sie die tatsächlichen Elternbeobachtungen und H-Zeilen gemeinsam nach dem Speichern der Fänge; eine vorherige eigene Übermittlung nur für die Eltern ist nicht nötig.

| Vogel / Ereignis | Tabelle / Zeilen | Wichtigste Angaben |
|---|---|---|
| Küken 1 in der Hand | CAPTURES, 1 | Alter C; sein eigener Ring, tatsächlicher Fangstatus, Markierungen, und Pflichtmessungen; Nest-/Brutverknüpfung nach Abschnitt 6. Vor den Elternwiedersichtungen speichern. |
| Küken 2 in der Hand | CAPTURES, 1 | Alter C; sein eigener Ring und seine Fangangaben, wie bei Küken 1. Der Eintrag des Geschwisters deckt das Küken nicht ab. |
| Elternvogel 1 bei der Kükenbetreuung beobachtet | RESIGHTINGS, 1 | Alter A; normales `rclass = R`; tatsächliches BC-, FC-, oder AC-Verhalten, Identität, und Nest-/Brutverknüpfung nach Abschnitt 5. |
| Elternvogel 2 bei der Kükenbetreuung beobachtet | RESIGHTINGS, 1 | Alter A; seine eigene Identität und sein beobachtetes Verhalten, wie bei Elternvogel 1. Keiner von beiden erhält eine CAPTURES-Zeile, weil keiner in der Hand war. |
| Küken 1 im Versteck fotografiert, falls gemacht | RESIGHTINGS, 1 zusätzliche H-Zeile | Alter C; `rclass = H`; Ring von Küken 1; Nest-/Brutverknüpfung nach Abschnitt 7; beide GPS-Felder und die eigenen `cam_id`, `photo_start`, und `photo_end` von dem Foto. Mit den tatsächlichen Elternbeobachtungen übermitteln. |
| Küken 2 im Versteck fotografiert, falls gemacht | RESIGHTINGS, 1 zusätzliche H-Zeile | Alter C; `rclass = H`; Ring von Küken 2 und seine eigenen Versteckfotoangaben, wie bei Küken 1. In derselben Familienwiedersichtungs-Übermittlung abgeben. |

Verwenden Sie auf jeder Zeile der Begegnung dasselbe Datum, site, und gps_id/point, und füllen Sie die normalen Pflichtfelder für jedes Ereignis aus. Ohne Versteckfotos sind das **vier Zeilen**: zwei Fänge und zwei Elternwiedersichtungen. Wenn beide Küken im Versteck fotografiert werden, sind das **sechs Zeilen**: dieselben vier plus zwei H-Zeilen. Ein Zeltfoto bleibt auf der CAPTURES-Zeile des betreffenden Kükens; es fügt keine weitere Zeile dazu und ersetzt keinen Versteckfotoeintrag.

### Eine negative Brut, zuerst erfasst und später wiedererkannt

Das Nest von Brut -C0402 ist nie gefunden worden. Bei ihrer ersten Fangbegegnung speichern Sie jedes Küken, das in der Hand war, unter -C0402, mit seinem eigenen Ring und dem gemeinsamen Familienwegpunkt. Erfassen Sie die beobachteten Eltern getrennt. Fügen Sie keine NESTS- oder EGGS-Zeilen dazu.

Später sind durch die bestätigten Elterneinträge beide sozialen Eltern für -C0402 eindeutig geklärt. Sie sehen nur einen von ihnen mit zwei Küken an einem neuen Wegpunkt. Der genehmigte Wiedersichtungsweg mit leerer ID kann gelten, aber nur wegen der vorherigen Begegnung, bei der die nest_id -C0402 angelegt worden ist:

| Zeile | Erforderlicher aktueller Beleg | `nest_id` |
|---|---|---|
| Beobachteter Elternvogel | A; tatsächliches BC, FC, oder AC; verlässliche ausgewählte Identität | Darf nach der bestätigten Ausnahme für negative Familien leer sein. |
| Küken 1 | C; tatsächliche Sichtung; dasselbe Datum, site, und gps_id/point wie beim Elternvogel | Darf nach derselben Ausnahme leer sein. |
| Küken 2 | C; tatsächliche Sichtung; dasselbe Datum, site, und gps_id/point wie beim Elternvogel | Darf nach derselben Ausnahme leer sein. |
| Abwesender zweiter Elternvogel | Keine Beobachtung | Keine Zeile. Seine bereits geklärte Vorgeschichte ist keine neue Sichtung. |

Tragen Sie -C0402 direkt ein, wenn bekannt. Die Ausnahme gilt nicht für den ersten Kükenfang bei einer neuen Familie, für ein ungeklärtes Paar, oder für einen teilweise abgelesenen Elternvogel, der nicht verlässlich identifiziert werden kann.

### Wann eine weggelassene Küken-ID nicht abgeleitet werden kann

| Unterschied | Ergebnis / richtige Reaktion |
|---|---|
| Elternvogel nur AT, nicht mit Küken beobachtet | AT liefert keinen BC-, FC-, oder AC-Beleg. Das wahre Verhalten beibehalten. |
| Elterndatum 24. Oktober, Küken 25. Oktober | Verschiedene Begegnungen; Daten nicht passend machen. |
| Eltern-GPS 4 / 216, Küken-GPS 5 / 216 | Verschiedene Garmin-Geräte. Tatsächliche gps_id/point prüfen. |
| Eltern-IDs B0203 und B0204 an einem Punkt | Widersprüchliche Verknüpfungen. Klären, bevor auf eine leere ID vertraut wird. |
| Beim negativen Brutpaar ist ein sozialer Elternvogel ungeklärt | Die historische Bedingung für beide Eltern ist nicht erfüllt; bekannte negative ID eintragen oder Unsicherheit weitergeben. |
| Elternmarkierung enthält nur unlesbare Belege | Das Fragezeichen ist kein Platzhalter für irgendeine Identität. Verlässliche Verknüpfung beschaffen; fehlende Farbe nicht raten. |
| Elternvogel bereits in einer früheren Wiedersichtungs-Übermittlung gespeichert | Eine Übermittlung von Kükensichtungen braucht weiterhin ihre tatsächliche begleitende Elternzeile. Keine zweite Beobachtung erfinden; eine Familienübermittlung nicht aufteilen. |
| Kükensichtung, Klasse P oder V ohne Kamera/Bildbereich | Familienableitung liefert keine fehlenden Medienangaben. |
| H-Küken ohne Ring | H braucht seinen individuellen Ring, egal wie die Brut verknüpft ist. |

### Was bei einer unlesbaren Markierung einzutragen ist

| Beobachtung | Eintrag |
|---|---|
| Linker Tarsus: rot über einem unlesbaren Ring | `LL = R?` in RESIGHTINGS. |
| Linker oberer Beinabschnitt: unlesbarer Ring über rot | `UL = ?R` in RESIGHTINGS. |
| Rechter unterer Beinabschnitt: Ringe gesehen, keine Farbe sicher abgelesen | `LR = ?` in RESIGHTINGS. |
| Rechts oben Gerät vorhanden, Abstandshalterfarbe unlesbar | `UR = T?` in RESIGHTINGS, nicht T. |
| Derselbe Vogel später in der Hand | Tatsächliche Markierungen ablesen und in CAPTURES eintragen; keine ? in Freilassungs- oder Eingangs-Beinfeldern. |

Nützliche Unsicherheit in Kommentaren bewahren. Keine von diesen Ablesungen in X umwandeln; das würde eine leere Position beschreiben.

### Drei gefangene Küken, zwei Versteckfotos

Drei verschiedene Ringe sind in CAPTURES erfasst. Später werden zwei Küken im Versteck fotografiert. Jedes erhält eine H-Zeile mit seinem eigenen Ring, direktem GPS, und Versteck-Bildbereich, gemeinsam mit den Zeilen der beobachteten Eltern.

Der aktualisierte To-Do-Fortschritt **Broods to photograph** bleibt bei zwei von drei, solange das To-Do-Anzeigefenster offen ist. Ein Küken zweimal einzutragen erledigt das dritte nicht. Bei einer negativen Brut, die vor sechs Tagen entdeckt worden ist, kann die Liste morgen ablaufen, obwohl ein Foto fehlt — und die Küken können bereits älter als sechs Tage sein. Melden Sie die fehlende Arbeit; aus dem Ablauf keine Erledigung ableiten.

### Familien-ID vor dem Eintragen von einem Versteckfoto finden

Ein früherer Fang hat einen Kükenring mit seiner sozialen Familie verknüpft. Jetzt fotografieren Sie das Küken im Versteck und sehen einen bekannten Elternvogel am selben Wegpunkt wieder; sein Partner ist abwesend. Tragen Sie das tatsächliche Elternverhalten und das gemeinsame Datum, site, und gps_id/point ein, mit dem Kükenring und vollständigen H-Fotofeldern. Prüfen Sie die Ringgeschichte und die Parent–Nest-Zusammenfassung, dann tragen Sie die feststehende positive/negative ID ausdrücklich auf der H-Zeile ein. Keine Zeile für den abwesenden Partner ist nötig. Wenn die Familie nicht verlässlich identifiziert werden kann, behalten Sie die Feldnotizen und Fotos und bitten Sie Luke Eberhart-Hertel um Klärung; übermitteln Sie keine neue H-Zeile mit leerer ID. Den aktualisierten To-Do-Fortschritt je Ring nach der Snapshot-Aktualisierung getrennt prüfen.

### Unberingter Elternvogel oder kein Elternvogel gesehen

Ein unberingter Elternvogel, der zwei beringte Küken betreut, erhält seine eigene RESIGHTINGS-Zeile mit Alter A, `LL = X`, `LR = X`, beobachtetem BC, FC, oder AC, erforderlicher ID, und gemeinsamem Wegpunkt. Die zwei Küken erhalten auch jeweils eine Zeile.

Wenn kein Altvogel gesehen worden ist, tragen Sie nur die Küken, den Wegpunkt, und einen konkreten Kommentar zum fehlenden Elternvogel ein. Verwenden Sie bei Blockierung die begründete Ausnahme aus Abschnitt 12; fügen Sie keinen X-X-Altvogel nur zum Erfüllen der Prüfung dazu.

### Ein älteres Küken erhält seine Flagge

Ein Küken wird nach dem aktuellen Flaggenplan wiedergefangen und besteht die Zustands-/Messwertbeurteilung durch die beringende Person. Seine alte Kombination wird in den vier Eingangsfeldern erfasst; seine tatsächliche neue Flaggenkombination kommt in die Freilassungsfelder. Verwenden Sie `capture_status = C`, nicht R, und erfassen Sie beide GPS-Felder auch bei einem bekannten positiven Nest. Tarsus, Culmen, und Gewicht bleiben Pflicht. Für das Küken wird keine Geräteaktion eingetragen.

### Einen Geolokator ersetzen

Ein geeigneter Altvogel kommt mit GEO-017 und geht mit GEO-044. Auf seiner einzigen CAPTURES-Zeile tragen Sie `tag_action = N`, `tag_type = GEO`, `tag_id_in = GEO-017`, `tag_id = GEO-044`, die tatsächlichen Abstandshaltermarkierungen vorher/nachher, und `wt_w_tag` zur Beschreibung des erfassten Gewichts ein. Ring und normale Fangfelder vervollständigen.

Eine spätere Wiedersichtung beschreibt, was damals sichtbar war. Das ist kein weiterer Gerätewechsel, und ein später nicht gesehenes Gerät ist nicht automatisch eine Abnahme.

### Letzter Schlupf und Abschluss

Ein Besuch stellt fest, dass keine Eier mehr da sind und zwei Küken anwesend sind: den letzten H-Nestbesuch mit Gelege 0 und Brut 2 erfassen. Individuelle Fänge/Wiedersichtungen erfassen die Küken getrennt. Ein späterer einzelner notA-Abschluss kann Brut 2 bei null Eiern und leerem Schlupfzustand behalten. Brutbegegnungen in den Vogeltabellen unter derselben positiven ID fortsetzen, mit ihren neuen Familienwegpunkten.

### Erstentdeckung unmittelbar nach dem Schlupf, im Nest

Um 10:00 finden Sie ein eindeutig erkennbares Nest mit zwei frisch geschlüpften Küken und ohne verbliebene Eier. Vergeben Sie seine positive ID und nehmen Sie den Nestwegpunkt auf.

| NESTS-Zeile | `time_visit` | `nest_state` | `clutch_size` / `brood_size` | GPS |
|---|---|---|---|---|
| Entdeckung | 10:00 | F | 0 / 2 | Beide Felder fürs neue Nest. |
| Unmittelbarer Schlupfeintrag | 10:01 | H | 0 / 2 | Leer; Entdeckungspunkt bereits erfasst. |

Beide Zeilen beschreiben dieselbe Entdeckungsbegegnung. Erklären Sie, dass die Küken unmittelbar nach dem Schlupf im Nest gefunden worden sind. Keine Eimessungen oder früheren Eibesuch erfinden. Die erste-F-Prüfung bei null Eiern sollte den seltenen Eintrag beanstanden. Prüfen Sie ihn noch einmal, kommentieren Sie die korrekte Entdeckung im Nest, und verwenden Sie die dokumentierte Übersteuerung, wenn weiterhin blockiert. Behalten Sie die wahren Zahlen; eine Validatoränderung ist nicht nötig.

Wenn die Küken außerhalb eines Nests gefunden worden wären und ihre Herkunft unbekannt wäre, verwenden Sie eine negative Brut-ID und keine NESTS-Ereignisse. Ihr junges Aussehen allein reicht nicht, um einen positiven Nestursprung festzustellen.

### Ein möglicher Verlust mit weiteren Schicksalskontrollen danach

Sie erfassen pP mit den Belegen für möglichen Prädationsverlust. Eine spätere Kontrolle bestätigt P; ein weiterer Besuch darf verbleibende Belege klären, bevor die Markierungen entfernt werden und das endgültige notA eingetragen wird. Jede tatsächliche Kontrolle erhält eine neue NESTS-Zeile. Das gleiche Prinzip gilt für D: Bestätigte Aufgabe schließt den Eintrag nicht von selbst ab. Keine zusätzlichen Besuche erfinden und das Verschwinden aus dem To-Do-PDF nicht als endgültigen Abschluss behandeln.

### Eine Elternzuordnung bestätigen ist nicht dasselbe wie eine Brut verlieren

Ein identifiziertes Männchen bei B0210 wird bei drei echten Gelegenheiten mit AT gesehen. Die drei geeigneten nestverknüpften Wiedersichtungen können seine Zuordnung feststellen. Alternativ kann eine klare IN-Beobachtung bei B0210 die Verknüpfung feststellen. Das Weibchen braucht weiterhin seine eigenen Belege.

| Eingetragene Belege | Was sich nach der Aktualisierung ändern kann | Was daraus nicht folgt |
|---|---|---|
| Drei passende männliche AT-Wiedersichtungen, oder eine männliche IN-Wiedersichtung | Der Zuordnungs-Wiedersichtungsbedarf fürs Männchen kann erledigt sein. | Die Identität des Weibchens ist damit nicht festgestellt; die Brut wird nicht nur deswegen für tot gehalten, weil die To-Do-Zeile verschwindet. |
| Zwei plausible Männchen mit jeweils gleich starken Zuordnungsbelegen | Die Zuordnung bleibt mehrdeutig. | Nicht die bevorzugte Markierung auswählen oder eine wahrheitsgemäße Beobachtung verwerfen. |

### Beide früheren Eltern wiederholt ohne Brutbetreuung gesehen

B0211 hat Schlupfbelege vom 1. Oktober. Beide Elternidentitäten sind bereits eindeutig festgestellt. Die folgenden Wiedersichtungen sind ausdrücklich mit B0211 verknüpft und haben ihre tatsächlichen Begegnungswegpunkte.

| Datum | Vogel / Zeilen in RESIGHTINGS | `behav` | Beitrag |
|---|---|---|---|
| 12. Oktober | Männchen, 1 | FA | Erstes geeignetes Datum des Männchens und stärkeres Verhalten ohne Brutbetreuung. |
| 15. Oktober | Weibchen, 1 | AT | Erstes geeignetes Datum des Weibchens und stärkeres Verhalten ohne Brutbetreuung. |
| 18. Oktober | Männchen, 1 | BW | Zweites geeignetes Datum des Männchens; BW kann FA ergänzen. |
| 20. Oktober | Weibchen, 1 | RS | Zweites geeignetes Datum des Weibchens. |

Mit Referenzdatum 22. Oktober hat die Brut die 21-Tage-Schwelle erreicht. Wenn keine widersprüchliche Brutbetreuungs-Chronologie oder spätere Reaktivierungsbelege vorliegen, erfüllen die Beobachtungen Weg 1. Das mögliche Verlustdatum ist der 20. Oktober, das spätere der letzten geeigneten Daten von beiden Eltern. Vor der 21-Tage-Schwelle erfüllen dieselben Einträge den Weg noch nicht.

Wenn beide Eltern nur am 18. Oktober wiederholt gesehen worden wären, wäre das weiterhin jeweils ein Datum, nicht zwei. Wenn das Männchen an beiden Tagen BW und kein stärkeres aufgeführtes Verhalten ohne Brutbetreuung hätte, würde es die Vorgabe nicht erfüllen. Wenn bei einem der Eltern am 20. Oktober BC erfasst wäre, wäre die Chronologiebedingung nicht erfüllt; erfassen Sie die tatsächliche Kükenbegegnung, statt sie wegzulassen.

### Ein früherer Elternvogel brütet an einem anderen Nest

B0212 hat Schlupfbelege vom 1. Oktober und ein verlässlich festgestelltes Weibchen. Am 14. Oktober wird ein anderes Nest, B0213, mit Eiern entdeckt, und das Weibchen wird dort beim Brüten beobachtet.

| Begegnungsbestandteil | Erwartetes Ereignis | Zentrale Angaben |
|---|---|---|
| Neue Nestentdeckung | NESTS, 1 | B0213; F, tatsächliches Datum/Zeit/Zählwerte, und Entdeckungs-gps_id/point. |
| Brütendas Weibchen | RESIGHTINGS, 1 | Alter A, tatsächliche Markierungen/Geschlecht, `behav = IN`, `nest_id = B0213`; normale Wiedersichtungsangaben. |
| Alte Brut | Kein erfundenes Ereignis | Keinen B0212-Nestverlust, kein totes Küken, und keine Beobachtung eines abwesenden Partners hinzufügen. |

Sobald dasselbe Weibchen für beide Versuche eindeutig ausgewählt ist, nimmt der Weg über das spätere Nest Verlust von B0212 an, ohne 21 Tage zu warten, sobald die nötigen Nest- und Identitätsbelege vorliegen. Die To-Do-Arbeit der alten Brut wird nach der Aktualisierung unterdrückt, aber ihr erforderlicher notA-Besuch bleibt.

Wenn ein lebendes Küken von B0212 tatsächlich am 14. Oktober selbst oder später angetroffen wird, erfassen Sie es und seine Familie wahrheitsgemäß. Eine direkte Verknüpfung oder eine genehmigte eindeutige Verknüpfung bei leerer ID verhindert vermuteten Verlust bei der nächsten Aktualisierung. Das gemeinsame Datum, site, und gps_id/point beibehalten. Ein nahes Nest mit unbeteiligten Eltern würde die Regel fürs erneute Nisten nicht auslösen.

### Ein früherer Elternvogel scharrt bei einem neuen Versuch

Das gleiche Prinzip gilt, wenn der neue Versuch B0213 noch eine Nestmulde ist.

| Begegnungsbestandteil | Erwartetes Ereignis | Zentrale Angaben |
|---|---|---|
| Neue ortsfeste Nestmulde | NESTS, 1 | B0213, S, tatsächliches Datum/Zeit, null Eier, und Entdeckungs-gps_id/point. Keine erfundenen EGGS-Zeilen. |
| Früherer Elternvogel tatsächlich beim Scharren | RESIGHTINGS, 1 | Alter A, seine tatsächlichen Markierungen/Geschlecht, SC, und B0213, mit den Begegnungsangaben. |
| Alte Brut | Kein erfundenes Ereignis | Kein erfundenes totes Küken, kein erfundener Verlustbesuch, und kein erfundener abwesender Partner. |

Eine geeignete SC-Beobachtung kann die Zuordnung von dem Elternvogel feststellen. Sobald die alte und die neue Zuordnung die Vorgaben aus Abschnitt 9 erfüllen, kann die Mulde vermuteten Verlust auslösen; aufs erste Ei muss man nicht warten.

### Ein totes Küken ist keine tote Brut

Ein beringtes Küken von B0214 wird tot gefunden. Ein Geschwister lebt noch in der Nähe.

| Vogel | Erwartetes Ereignis | Zentrale Angaben |
|---|---|---|
| Tot gefundenes Küken | CAPTURES, 1 | Alter C, Status D, sein Ring, und alle vier tatsächlichen Fundmarkierungen in den _in-Feldern; Freilassungsfelder/-zeit leer. Tatsächlichen Wegpunkt und bekannte Brutverknüpfung erfassen. |
| Lebendes Geschwister beobachtet, nicht in der Hand | RESIGHTINGS, 1 | Alter C, beobachtete Markierungen, tatsächliche Familien-gps_id/point, und normale Verknüpfungsangaben. |
| Tatsächlich beobachtete Eltern | RESIGHTINGS, jeweils eine | Tatsächliches BC, FC, oder AC bei der Betreuung des lebenden Kükens, mit demselben Datum/site/gps_id/point. Keine Zeile für einen abwesenden Elternvogel. |

Der Totfund beweist kein Überleben und stellt keinen Verlust der ganzen Brut fest. Die lebenden Familienbelege halten die Brutarbeit nach den üblichen Zeit-/Erledigungsregeln offen. Alter J nicht vergeben, um die Liste zu leeren.

### Eine Brut verschwindet aus dem Arbeitsplan und wird später wieder angetroffen

Eine positive Brut hat erfasste Schlupfbelege vom 1. Oktober. Ihr Beobachtungsfenster geht vom 22. Oktober bis zum 5. November: Alter 21–35 einschließlich. In dem Fenster gibt es keine geeigneten Lebendbegegnungen.

| Referenzdatum / tatsächliche Begegnung | Erwartetes Arbeitsplanergebnis nach der Aktualisierung |
|---|---|
| 5. November, Tag 35 | Das Fenster ist noch nicht vorbei. Die Abwesenheitsregel unterdrückt die Brut nicht. Andere feststehende Erledigungs- oder Abschlussregeln können trotzdem gelten. |
| 6. November, Tag 36, weiterhin keine Lebendbegegnung | Nach Weg 3 vermutlich tot. Brutarbeit, zugehörige Elternaufgaben, und den Zusammenfassungseintrag der Brut entfernen. Ein unabhängig fälliger notA-Besuch am positiven Nest bleibt. |
| Ein lebendes Küken wird tatsächlich am 6. November gesehen | Das Küken und alle tatsächlich beobachteten Eltern eintragen, nach den normalen Familienverknüpfungs- und gps_id/point-Regeln. Nach der Aktualisierung gilt das Ergebnis „vermutlich tot“ nicht mehr; offene Flaggen- oder Elternarbeit kann zurückkommen. |
| Stattdessen wird eine echte Begegnung vom 26. Oktober spät hochgeladen | Den 26. Oktober als Felddatum behalten: Das war Tag 25. Sobald die Begegnung in einer Aktualisierung eingeht, verhindert sie Weg 3, weil sie ins Beobachtungsfenster fällt. |

Für eine negative Brut, die am 1. Oktober erstmals gefunden worden ist und kein verlässliches Schlupfdatum hat, gelten dieselben Daten, wobei die Entdeckung als betrieblicher Altersersatz dient. Keinen Schlupfbesuch erfinden. Weder Verschwinden noch Wiederauftauchen rechtfertigt erfundene Feldereignisse oder das Löschen früherer Beobachtungen.

### Ein Jungvogel löst die ursprüngliche Brut auf, auch nach Brutvermischung

CP99001 ist zuerst als Küken von B0214 beringt worden. Später hat er sich B0215 angeschlossen und ist dort wiedergefangen worden; dabei ist sein Ring gemeinsam mit Flagge FWAB erfasst worden. An einem späteren Feldtag wird FWAB tatsächlich mit Alter J beobachtet.

| Begegnung | Erwartetes Ereignis | Was der Eintrag feststellt |
|---|---|---|
| Erste Kükenmarkierung bei B0214 | CAPTURES, 1 | Alter C, F, CP99001, B0214, und die tatsächlichen Anfangsmarkierungen. |
| Späterer Wiederfang bei B0215 | CAPTURES, 1 | Tatsächliches Alter, Status C bei geänderter Kombination, CP99001, Eingangs-/Freilassungsmarkierungen einschließlich FWAB, und B0215. Das erfasst die spätere soziale Zuordnung, ohne den ursprünglichen Ursprung zu löschen. |
| FWAB danach als Jungvogel gesehen | RESIGHTINGS, 1 | Alter J, FWAB in UL, weitere Markierungen wie beobachtet, und normale Angaben zu Datum/site/observer/Standort. Die Rückverfolgung nutzt den früheren Flaggen-Ring-Fang und den ursprünglichen Kükeneintrag. |

Die ursprüngliche Brut B0214 wird in der Jungvogelphase aufgelöst. Das erledigt nicht die anderen Küken von B0215 nur, weil CP99001 sich ihnen später angeschlossen hat. Die Flagge allein stellt Alter J nicht fest; die beobachtende Person muss den Vogel tatsächlich als J beurteilen.

Wenn CP99001 stattdessen tot gefunden und als J bestätigt wird, tragen Sie eine CAPTURES-Zeile mit D, seinen Fundmarkierungen in den Eingangsfeldern, und ohne Freilassungsmarkierungen oder Freilassungszeit ein. Der verlässliche ursprungsverknüpfte J-Eintrag erledigt trotzdem die Kükenphasenarbeit von B0214. Seinen Tod und alle bekannten Geschwistertode bewahren: Das ist entwicklungsbedingte Auflösung, keine Aussage, dass alle Geschwister überlebt haben.

</details>

<a id="section-15"></a>

<details>
<summary><strong>15. Überarbeitungsverzeichnis und Quellenhinweise</strong></summary>

## 15. Überarbeitungsverzeichnis und Quellenhinweise

### Überarbeitungsverzeichnis

| Version | Änderung |
|---|---|
| v2.2 Arbeitshandbuch | Eigener Cass River/BADO-Entwurf in Word/PDF; ursprüngliche Referenz behalten. |
| v2.2 Markdown-Vorschau | Inhaltslinks und aufklappbare Abschnitte für die lokale Prüfung. |
| v2.3, 26. Oktober 2026 | Frühere vollständige Textneufassung, unter dem Dateinamen der v2.2-Vorschau behalten. |
| v2.4 Prüfentwurf, 26. Oktober 2026 | Alle Abschnitte geprüft/neu gefasst; tabellenübergreifende Familieneingabe, Fang-GPS-/Statustabelle, leere IDs bei negativen Familien, Unsicherheitsnotation, H-Fortschritt/zwei Zeitrechnungen, Eizeitvorgaben, Altvogel-Gerätezellen, und Bedingungen vor dem Fang korrigiert. Zusammengefasste Situationen/Beispiele/Checklisten und ausdrückliche Hinweise zum Quellenstand ergänzt. |
| v2.4.1, 26. Oktober 2026 | Luke Eberhart-Hertel hat bestätigt, dass Schicksalskontrollen mit pP, P, oder D bis notA offen bleiben, und dass bei der sehr seltenen Entdeckung eines positiven Nests mit frisch geschlüpften Küken darin F und danach H mindestens eine Minute später verwendet wird. Schlüssel, Verfahren, Situationen, Beispiele, und Checklisten aktualisiert; verbleibende Validator-/Aufgabenabstimmung ausdrücklich unterschieden. |
| v2.4.2, 26. Oktober 2026 | Klargestellt, dass die normale Ablehnung des ersten F bei null Eiern beabsichtigt ist. Die korrekte seltene Beobachtung braucht einen erklärenden Kommentar und eine dokumentierte Übersteuerung bei Blockierung, keine programmierte Ausnahme. Die irrtümliche Behauptung einer Validatorlücke aus Verfahren, Situationen, Beispielen, und Quellenhinweisen entfernt. |
| v2.4.3, 26. Oktober 2026 | Luke Eberhart-Hertels direkte Änderungen bewahrt; vage GPS-Formulierungen durch gps_id/point ersetzt, Bezeichnung fürs Feldhaus vereinheitlicht, und Fang-/Wiedersichtungskürzel ausgeschrieben. Die abgeschaffte Eingabekonvention für Vögel ohne Nest überall entfernt; unabhängige Altvogelfänge verwenden leere nest_id und gps_id/point. Ausnahme mit bekanntem Ring bei unsicheren Elternmarkierungen und Regel für widersprüchliche IDs innerhalb derselben Begegnung ergänzt. Vollständige Software-Integrationsprüfung steht weiterhin aus. |
| v2.4.4, 26. Oktober 2026 | Geprüfte Protokollmetadaten auf v1.3.14 aktualisiert und erklärt, dass eine geeignete nestverknüpfte SC-Beobachtung die Zuordnung von dem Elternvogel bestätigen kann, ohne Kükeneinträge zu verlangen oder den Partner zu bestätigen. Abgeschlossene begrenzte Prüfungen von der ausstehenden vollständigen Probe am 27. Oktober und der ungeprüften Live-Installation unterschieden. |
| v2.4.5, 26. Oktober 2026 | Ereignistabelle je Vogel zum tabellenübergreifenden Fang-/Wiedersichtungsbeispiel ergänzt, mit Übermittlungsreihenfolge, optionalen eigenen Versteckfotozeilen, und Gesamtzahlen von vier oder sechs Zeilen. Keine Protokolländerung. |
| v2.4.6, 27. Oktober 2026 | Offenlegung zu Urheberschaft/KI und Luke Eberhart-Hertels Kontaktadresse vor dem Inhalt ergänzt. Lokale App-Leseseite mit aufklappbaren Abschnitten, Inhaltsnavigation, und Suche ergänzt; keine Änderung an Feldmethoden oder Datenbankregeln. |
| v2.4.7, 27. Oktober 2026 | Verhaltenscodes für Elternzuordnung, Belegreihung, und MM-Nachverfolgung erweitert. Die zwei Wege für vermuteten Brutverlust, Schutzbedingungen für Zeit/Identität/Verhalten, Belege am späteren Nest, und Reaktivierungsgrenzen, Feldentscheidungsschlüssel, Ereignistabelle, durchgearbeitete Beispiele, und Prüfcheckliste ergänzt. Stand der begrenzten lokalen Probe aktualisiert; keine Änderung an SQL, Validatoren, oder Live-Zustand. |
| v2.4.8, 27. Oktober 2026 | Handbuch an Luke Eberhart-Hertels genehmigte automatische Verlustregel bei erneutem Nisten angepasst, einschließlich zugeordneter Nestmulden; Schutzregeln für gleichentägige und eindeutig abgeleitete Lebendbelege; getrennte Auflösung der ganzen Brut in der Jungvogelphase, einschließlich bestätigter J-Totfunde; und wahrheitsgemäße D-Einträge für Küken/Jungvögel. Schritte im Entscheidungsschlüssel, unterstützende Tabellen, und durchgearbeitete Beispiele ergänzt. Quellenstand auf lokales Protokoll v1.3.17 aktualisiert; Live-Installation bleibt ungeprüft. |
| v2.4.9, 28. Oktober 2026 | Neue H-Einträge brauchen eine ausdrückliche Nest-/Brut-ID; ältere H-Verknüpfung bei leerer ID dient nur der Kompatibilität. Zeitvorgaben fürs letzte Ei, Bestätigung bei zwei Eiern/Ersatz ohne Flotation/Neustart beim dritten Ei, unabhängige 36-Stunden-Schwelle, Flaggenzählungen aus der letzten Begegnung, spätere ringverknüpfte Fänge, und Anleitung zur GEO-Paarvervollständigung ergänzt. Protokoll-/Quellenstand aktualisiert; abschließende gemeinsame SQL-/PDF-Probe und Live-Bereitstellung bleiben eigene Prüfungen. |
| v2.4.10, 29. Oktober 2026 | Festes Lebendbegegnungsfenster von Alter 21 bis 35 einschließlich, erste Unterdrückung an Tag 36, Altersersatz bei negativen Bruten, und Reaktivierung durch spätere Lebendbelege ergänzt. Unterdrückung zugehöriger Elternaufgaben/Zusammenfassung, Korrektur durch späten Upload, und unabhängige notA-/Jungvogelauflösung erklärt; datiertes durchgearbeitetes Beispiel ergänzt. |
| v2.4.11, 29. Oktober 2026 | Neuseelandweiten Geltungsbereich klargestellt und gebietsspezifische Beispiele gekennzeichnet; Urheberschafts-/KI-Erklärung hinter Anhang B mit Inhaltslink verschoben; Geolokator-/Gerätebegriffe geklärt und Rechtschreibung korrigiert. Keine biologische Regel oder SQL geändert. |
| v2.4.12, 31. Oktober 2026 | Stichtag für Gelegevervollständigung nach dem 9. Oktober und bedingte Geräteanweisung für B/unbekannt, Nachverfolgung zur Paarvervollständigung am selben Nest, Schutz für bereits besenderte noch ungeklärte Eltern, einheitliche Formulierung zur Paarvervollständigung, und weiße Kartenumrisse dokumentiert. Wartehinweise zum Snapshot und historischen notA_summary-Bericht ergänzt. Quellenstand mit lokalem Validatorprotokoll v1.3.20 und abgeschlossener lokaler Prüfung abgeglichen. |
| v2.4.13, 31. Oktober 2026 | Luke Eberhart-Hertels MM-Chronologieentscheidung klargestellt: Geeignete Belege vor MM zählen für einen verlässlich identifizierten Vogel; X-X-Belege können nicht auf einen später erstmals markierten Vogel übertragen werden, der seine eigenen nachfolgenden Belege braucht. Geschlechtsspezifische Chronologie-, Konflikt-, und Gleichentags-Reihenfolgeschutzregeln ergänzt. Anpassung der Fangfeldhinweise bewahrt den bestehenden F/R/C/D-Validatorvertrag; das ist keine Aussage über eine Live-Installation. |
| v2.4.14, 1. November 2026 | Luke Eberhart-Hertel hat genehmigt, eindeutig bestätigendes X-X mit einer einzigen geeigneten Status-F-Erstberingungsidentität desselben Geschlechts/am selben Nest/am selben Datum zu verknüpfen, auch bei MM ohne spätere Sichtungen. Gleichentägige Belege werden übertragen, mit Datierung des Belegs nach Fangdatum/-zeit und ohne abgeleitete genaue Beobachtungszeit/-reihenfolge. Alle verschiedenen geeigneten F-Identitäten vor Filtern für spätere Belege/Mehrdeutigkeit zählen. Ältere Belege von anderen Tagen können nicht übertragen werden; eine eigene gültige gleichentägige Bestätigung kann einen älteren Platzhalter ablösen. Alle Schutzregeln für Mehrdeutigkeit, Verdrängung, Zeit/Gerät, und unbeteiligte gleichentägige Ereignisse bleiben. Ersetzt die pauschale Formulierung aus v2.4.13, dass am selben Tag keine Verknüpfung möglich ist. |
| v2.4.15, 1. November 2026 | Offenlegung zur KI-Nutzung um öffentliche Regeln zur Projektsteuerung, bereinigte Anfragezusammenfassungen, Fachübergaben, Validatoren, und Links zum synthetischen Arbeitsablauf erweitert. Menschliche Prüfung/händische Installation am Feldserver, Vertraulichkeitsausschlüsse, anfängliche Tests mit erfundenen Daten, und den eigenen Umfang der späteren genehmigten lokalen/Feldbeispiel-Fehlersuche klargestellt. Keine Änderung an Wissenschaft, Validatoren, SQL, oder App-Bedienung. |
| v2.4.16, 1. November 2026 | Hinweis ergänzt, das Feldhandbuch in einem eigenen Fenster zu öffnen, wenn GitHub-Links in der FIELDWORKER-App nicht aufgehen. Keine Änderung an Protokoll, Datenbank, oder Linkbehandlung. |
| v2.4.17, 1. November 2026 | Vereinfachtes Nest Map-Popup, referenzdatumsbezogene Anzeige Last encounter, und zwischengespeicherte Zuordnungsbelege je Elternvogel erklärt. Bloße Snapshot-Anzeigemetadaten ändern keine Zuordnungs-, Zeit-, oder Aufgabenregeln. |
| v2.4.18, 1. November 2026 | Hatch timing (days) zum Nest Map-Popup ergänzt, mit dem bestehenden PDF-Formatierer Est. Hatch, einschließlich seiner Flotationsschutzregeln, veröffentlichten Aufgabenwerte, und Brutalterskonvention. Keine Änderung an SQL, Schema, oder Aufgabenregeln. |
| v2.4.19, 2. November 2026 | Oxford-Komma durchgehend in Prosaaufzählungen angewandt. Keine Änderungen an Feldprotokoll, Validatorregeln, oder Aufgabenlogik. |
| v2.4.20, 3. November 2026 | Erklärt, wie eine spätere bestätigte Zuordnung für einen verlässlich identifizierten Altvogel einen früheren noch ungeklärten Kandidaten an einem anderen Nest ablöst, ohne Beobachtungen oder unabhängig festgestellte Zuordnungen zu löschen. Schutzregeln für Zeit, Identität, und Mehrdeutigkeit bleiben. |
| v2.4.21, 3. November 2026 | Den Core Team Field Guide als Startansicht der App ergänzt, mit Zugang zu der vollständigen Referenz. Ausdrücklich erklärt, dass Kommentare keine Ereigniseinträge ersetzen können, die der To-Do-Algorithmus verwendet. Keine biologische oder Datenbankregel geändert. |
| v2.4.22, 3. November 2026 | Standarddeutsche Ansichten beider Handbücher ergänzt und die vorsichtige Schlupfableitung aus vollständig abgedeckten Gelegen, operativ null Eier, und notA-Nachkontrolle dokumentiert, ohne Besuche oder Abschluss zu erfinden. |

Die Veröffentlichungskopie für die App ist getrennt von Luke Eberhart-Hertels bearbeitbarem privatem Prüfentwurf und den behaltenen Word-/PDF-Referenzen; die Dateien sind nicht überschrieben worden. Abschnittsnummern und Inhaltslinks bleiben zur Navigation erhalten.

### Quellengrundlage und Grenze zur Bereitstellung

Luke Eberhart-Hertels neueste ausdrückliche Entscheidungen bestimmen die Methodik. Feldnamen und verfügbare Werte sind gegen aktuelles SQL und DataEntry-Formulare geprüft worden; die jüngsten genehmigten Korrekturen sind gegen die geprüften Inspektoren, den lokalen Protokollspiegel, Fachübergaben, und Mock-Testbelege geprüft worden. Ältere historische Formulierungen setzen diese nicht außer Kraft.

| Quelle/Stand | Stand bei der Überarbeitung |
|---|---|
| Repository-Quelltext | Der durch PR #163 integrierte Quelltext enthält die bedingte Geräteanweisung, Schutz für noch ungeklärte besenderte Eltern, historischen Bericht, und Wartemeldung. Die nachfolgende Formulierungskorrektur zur Paarvervollständigung und die Dokumentationsaktualisierung brauchen ihre eigene Veröffentlichung. |
| Geprüfter lokaler Protokollspiegel | Lokal v1.3.20, einschließlich registrierter Beobachtercodes aus zwei oder drei Großbuchstaben/Ziffern, ausdrücklicher Pflicht-IDs für neue H-Zeilen, Familien-/Unsicherheits- und SC-Korrekturen, und wahrheitsgemäßer Totfundregeln für Küken/Jungvögel. Änderungen an betrieblichen Aufgabenhinweisen fügen keine Validatorregeln beim Speichern dazu. |
| Externes Validatorprotokoll | Bei der Prüfung ist keine externe YAML-Synchronisierung durchgeführt worden. Für die aktuelle geprüfte Version den versionierten lokalen Spiegel lesen. |
| Lokale Prüfung | Eine abgeschlossene isolierte MariaDB-11.8.9-Installation/-Aktualisierung und Prüfung des vierseitigen PDFs stützen die jüngsten Aufgabenänderungen. Der historische Bericht hat getrennt gezielte Prüfungen mit erfundenen Daten bestanden. Das sind verschiedene Prüfumfänge. |
| Genehmigte gleichentägige Verknüpfung vom 1. November | Genehmigte Gleichentagsregel; der Prüfumfang ist getrennt im [datierten Prüfverzeichnis](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/docs/reconstruction/MM_FOLLOWUP_VERIFICATION_2026-10-31.md#approved-decision-addendum--1-november-2026) erfasst. Keine Aussage über Live-Bereitstellung. Das Neuerzeugen des HTML des Handbuchs ist nur Dokumentationserzeugung. |
| Live-Datenbank, Inspektoren, und Shiny-Prozess | Die Dokumentationsprüfung hat die Live-Installation nicht untersucht. Eine Quelltextintegration oder ein lokaler Erfolg stellt nicht fest, welche Versionen am Feldserver installiert sind. |

Manche älteren Protokoll-/Übergabelisten erwähnen noch EGGS-Medienspalten, die im aktuellen SQL fehlen, abgeschaffte Anweisungen für Vögel ohne Nest, ältere Zeitbeschreibungen, oder ersetzte Familienregeln. Datierte Übergaben bewahren die Vorgeschichte; ihre aktuellen Ergänzungen und das Handbuch verwenden die geprüften Tabellendefinitionen und Luke Eberhart-Hertels ausdrückliche Entscheidungen.

Luke Eberhart-Hertel hat beide Feldmethodenfragen am 26. Oktober geklärt: Besuche mit pP, P, oder D bleiben bis zum endgültigen notA für weitere Schicksalskontrollen offen, und frisch geschlüpfte Küken, die noch in einem eindeutig erkennbaren Nest sind, belegen einen positiven Ursprung mit F und unmittelbar folgendem H mindestens eine Minute später. Küken, die außerhalb eines Nests ohne bekannten Ursprung gefunden werden, verwenden den Weg für negative Bruten, ohne NESTS-Ereignisse. Banded Dotterels verlassen das Nest kurz nach dem Schlupf; deshalb ist die Ausnahme im Nest sehr selten.

Die Ablehnung des ersten F bei null Eiern ist eine beabsichtigte Schutzprüfung, keine Umsetzungslücke. Luke Eberhart-Hertel hat bestätigt, dass die äußerst seltene korrekte Beobachtung bei Blockierung über einen erklärenden Kommentar und die dokumentierte Übersteuerung behandelt werden soll; der Validator darf nicht so programmiert werden, dass er sie automatisch annimmt. Wahrheitsgemäße Zahlen und die Reihenfolge F → H bewahren.

Frühere Prüfungen mit erfundenen Daten haben Snapshot-Upgrades, wiederholte Aktualisierungen, Referenzdatumsänderungen, und Familien-/Identitätsgrenzfälle abgedeckt. Eine spätere genehmigte lokale Wiederholung hat das ausgewählte SQL mit einem eingefrorenen lokalen Eingangsdatenstand ausgeführt und den Arbeitsplan vom 31. Oktober erzeugt; ihre erforderlichen Veröffentlichungs-/Aufgabenprüfungen sind bestanden worden, und alle vier PDF-Seiten sind geprüft worden. Ein vollständiger Vergleich mit älteren behaltenen goldenen Aufgaben-/Kontext-Referenzzeilen war nicht verfügbar und wird nicht behauptet. Der historische Bericht ist getrennt mit erfundenen Einträgen geprüft worden; seine Verknüpfungen zu späteren Nestern sind nicht gegen aktuelle Feldeinträge geprüft worden. Die Formulierungskorrektur ändert nur die zwei Gerätehinweis-Zeichenketten und hat ihre gezielte Prüfung bestanden. Die Prüfung belegt weder Live-Adminer-Laufzeitverhalten noch Live-Bereitstellung.

Die Erklärung der Elternzuordnung folgt den geprüften Abgleich- und ausgewählten Zuordnungsregeln in `DATABASE/views.SQL`; die oben erfasste genehmigte Entscheidung vom 1. November zur gleichentägigen Verknüpfung wartet auf eine eigene Umsetzungsprüfung. Die Brutableitung folgt der Abschlussstufe und den Aufgabenausschlüssen in `DATABASE/refresh_todo_list_snapshot.SQL`. Die geprüften Regeln verlangen gemeinsames Datum/site/gps_id/point, lehnen widersprüchliche abgeleitete Familienziele ab, behalten die Ausnahme mit verifiziertem Ring für unsichere Elternmarkierungen bei, akzeptieren geeignete gleichentägige oder spätere Lebendbelege, und unterscheiden Todesfälle im Alter C von entwicklungsbedingter Auflösung im Alter J. Sie schreiben keine Rohzeilen um.

Ein gemeldeter Fehler bei normalen Familien hat sich als fehlendes Konfliktereignis in den erfundenen Testdaten erwiesen. Die ursprünglichen Testdaten mit einer ID sind korrekt aufgelöst worden; nach dem Hinzufügen des tatsächlich widersprüchlichen Vogelereignisses hat dasselbe unveränderte SQL die Verknüpfung abgelehnt. Beide Fälle sind als Kontrollen behalten worden und haben keine unnötige Änderung am Produktionsquelltext ausgelöst. Ausführliche Testverläufe bleiben im lokalen Prüfverzeichnis, nicht in Feldbeispielen.

Das ausführliche Quelleninventar, die Änderungsabdeckung, und das Prüfverzeichnis werden getrennt bei der lokalen Autorenprüfung aufbewahrt. Beispiele enthalten keine kopierten Feldeinträge oder echten Koordinaten. Das historische Handbuch liefert Belege für Schreib- und Bildstil, keine aktuellen Codes oder biologische Autorität.

### Wenn App und Handbuch nicht übereinstimmen

Behalten Sie die tatsächliche Beobachtung. Erfassen Sie die genaue Meldung und geben Sie sie an die Feldleitung weiter. Verwenden Sie nur die begründete Ausnahme aus Abschnitt 12; ändern Sie keine Markierungen, Daten, Zählwerte, oder Familienidentität, um durch die Prüfung zu kommen.

Die Freigabe der Markdown-Formulierungen ist keine Freigabe, das Schema zu ändern, Inspektoren zu installieren, die App bereitzustellen, oder das Handbuch zu veröffentlichen. Das bleiben getrennte Schritte.

</details>

<a id="appendix-a"></a>

<details>
<summary><strong>Anhang A. Vorgegebene Werte</strong></summary>

## Anhang A. Vorgegebene Werte

### Vogelangaben und Wiedersichtungsklassen

| Feld | Werte |
|---|---|
| `species` | BADO; WRYB, wenn ein Schiefschnabelnest/eine Schiefschnabelbeobachtung erfasst wird. Andere App-Codes liegen außerhalb dieses Verfahrens. |
| `site` | Den genehmigten Untersuchungsgebietscode verwenden; CR ist das Cass-River-Beispiel. Im Auswahlmenü den für das eigene Gebiet verwendeten Code prüfen. |
| `age` | A Altvogel; J Jungvogel; C Küken. |
| `sex`, `field_sex` | M männlich; MU wahrscheinlich männlich; F weiblich; FU wahrscheinlich weiblich; U unbekannt. C/J verwenden U. |
| `rclass` | R regulär; P Fotografie; V Video; C gescheiterter Fang; H Küken-Versteckfoto. |

| `behav` | Bedeutung |
|---|---|
| IN / NM | Brüten / Nestpflege. |
| BC / FC / AC | Küken hudern / Nahrungssuche mit Küken / wachsam mit Küken. |
| BW | Verleiten mit vorgetäuschtem Flügelbruch; kann in der Nähe von Eiern oder Küken auftreten. |
| CO | Balz. |
| SC | Mulde scharren. Eine geeignete nestverknüpfte Beobachtung kann die Zuordnung dieses Elternvogels bestätigen; begleitende Kükenzeilen sind dafür nicht erforderlich. |
| FA / FM / FF | Nahrungssuche allein / mit vermutetem Partner / im Trupp. |
| PR / RS / LF | Gefiederpflege / Ruhen am Ruheplatz / untätiges Verweilen. |
| AT / FT | Wachsam / Kämpfen. |
| OB | Anderes Verhalten; in Kommentaren erklären. |

Mehrere zutreffende Verhaltenstokens durch Kommas trennen. Bei einem regulären R-Küken oder einem H-Küken darf das Verhalten leer bleiben, wenn keines erfasst wurde; bei anderen Zeilen bleibt das Verhalten Pflicht. AT nicht anstelle von AC verwenden und BW allein nicht als Beleg dafür behandeln, dass einzelne Küken gesehen wurden.

### Nest- und Eiwerte

| Feld | Werte |
|---|---|
| `nest_state` | S Nestmulde; F Entdeckung; I aktiv/bebrütet; H Küken gesehen; pP mögliche Prädation; pD mögliche Aufgabe; P bestätigte Prädation; D bestätigte Aufgabe; notA endgültiger inaktiver Abschluss; O anderes mit Kommentar. pP, P, oder D erlauben weitere Schicksalskontrollen bis notA. Die seltene Schlupfentdeckung im Nest verwendet F und danach H, keinen erfundenen Eibesuch. |
| `bird_inc` | M männlich; F weiblich; MF/FM beide; U unbekanntes Geschlecht; E kein Vogel gesehen. |
| `hatch_state` | Eizahl plus N kein Anzeichen, S Sternriss, C Riss, CC mehrere/große Risse; z. B. 2N1S. |
| `egg_id` | 1, 2, 3, 4 innerhalb des Nests. |
| `float_location` | bottom, suspended, surface. |
| `float_angle`, `float_surface` | Ganze Grad 0–90; Höhe über der Wasseroberfläche in ganzen mm 0–3 nur an der Oberfläche, sonst leer. |

### Fang-, Proben-, und Gerätewerte

| Feld | Werte |
|---|---|
| `capture_status` | F Erstmarkierung; R unveränderter Wiederfang; C geänderte Kombination; D Totfund. |
| `capture_method` | HA Hand; TB Klappfalle an der Brut; TN Klappfalle am Nest; SM stationäres Japannetz; MM mobiles Japannetz; O anderes, mit Kommentar. |
| `parents` | MF beide Geschlechter; F weiblich; M männlich; U1 ein Elternvogel unbekannten Geschlechts; U2 zwei Elternvögel unbekannten Geschlechts; O anderes mit Kommentar. |
| `caught_with` | M Partner; M? wahrscheinlicher Partner; S gleichgeschlechtlicher Artgenosse; C Küken/Anzahl wie 2C. Bei Bedarf durch Kommas trennen. |
| `blood_samp` | BQ Queens-Puffer; BF Filterpapier; BE EDTA; leer, wenn keine Probe. |
| `breast_samp`, `primary_samp`, `brood_patch`, `wt_w_tag`, `eggs_handled`, zutreffende Fotofelder | 0 nein / 1 ja, nur wenn laut Alters-/Ereignistabelle zutreffend. |
| `fat` | 1–8, nach der geschulten Bewertungsmethode. |
| `feather_wear` | 0 frisch; 1 leicht abgenutzt; 2 mäßig abgenutzt; 3 stark abgenutzt. |
| `moult_left`, `moult_right` | Stadien-/Zählnotation des Teams, z. B. 0(10) für zehn alte Handschwingen ohne Mauser. Bei Asymmetrie rechts getrennt erfassen. |
| `tag_action` | Nur Altvögel: O keine; D Anbringung; R Abnahme; S gleiches Gerät beibehalten; N neues Ersatzgerät. |
| `tag_type` | GEO Geolokator; GPS/PTT für andere Gerätearbeiten unterstützt. Gerätefelder bei Küken/Jungvögeln bleiben leer. |

### Markierungsnotation

| Code/Eintrag | Bedeutung |
|---|---|
| B, G, R, O, W, L, Y | Blau, grün, rot, orange, weiß, limettengrün, und gelb. |
| M | Metallring; nicht seine individuelle Ringnummer. |
| X | Beobachtete leere Beinposition; nicht unlesbar. |
| X-X | Kurznotation für unberingte Wiedersichtung: mindestens LL X und LR X. |
| F + Farbe + Gravur | Vollständige Flagge in einem oberen Beinfeld, z. B. FWAB. |
| R? / ?R | Nur Wiedersichtung: sicher rot oberhalb / unterhalb des unlesbaren Rings. Gilt für UL, LL, UR, LR. |
| ? | Nur Wiedersichtung: Markierungen auf diesem Abschnitt gesehen, keine sicher abgelesen. |
| TY / T? | Wiedersichtung UR: Gerät mit gelber / unlesbarer Abstandshalterfarbe. T allein ist ungültig; bei Fängen ist der tatsächliche bekannte Abstandshalter erforderlich. |

In keinem Eingangs-/Freilassungs-Beinfeld von CAPTURES darf `?` stehen. Die eigene Konvention `caught_with = M?` ist kein Beinmarkierungseintrag.

### IDs und leere Felder

| Eintrag | Verwendung |
|---|---|
| Positive ID | Bekanntes Nest und seine verlässlich verknüpfte Brut. |
| Negative ID | Brut unbekannter Herkunft; Minuszeichen beibehalten; nur Vogeltabellen. |
| Leere ID | Ein unabhängiger Altvogelfang verwendet leere `nest_id` und gps_id/point. Leere IDs bei Familienereignissen müssen die Abschnitte 5 und 7 erfüllen; ein Küken beim Erstfang braucht weiterhin seine tatsächliche positive oder negative ID. |

</details>

<a id="appendix-b"></a>

<details>
<summary><strong>Anhang B. Checklisten für Feldarbeit und Übermittlung</strong></summary>

## Anhang B. Checklisten für Feldarbeit und Übermittlung

### Vor dem Verlassen des Feldhauses

- [ ] Aktuelles To-Do-PDF, Referenzdatum, und Teamaufteilung geprüft.
- [ ] Garmin/Kamera geladen, IDs, und lokale neuseeländische Uhrzeiten geprüft.
- [ ] Notizbuch, Metallringe/Farbringe/Flaggen, Messausrüstung, und Probenausrüstung bereit.
- [ ] Fang- und GEO-Zeitvorgaben/Eignung vor der Fallenplanung geprüft.

### Vor dem Verlassen der Begegnung

- [ ] Jeder Vogel und jede Eimessung haben eine eigene Notizbuchzeile.
- [ ] Tatsächliche Nest-/Brut-ID beibehalten; negatives Minuszeichen erhalten.
- [ ] Garmin-Wegpunkt aufgenommen, wo nötig; Geräte-ID und Punkt aufgeschrieben.
- [ ] Familiendatum, site, und gps_id/point stimmen bei Sichtungen und Fängen überein.
- [ ] Altvogelverhalten so erfasst, wie beobachtet; AT von AC unterschieden und IN/NM/SC mit dem tatsächlich betroffenen Nest verknüpft.
- [ ] Alle beobachteten Eltern erfasst; keinen abwesenden Elternvogel erfunden.
- [ ] Unberingter betreuender Elternvogel als X-X erfasst; unlesbare Wiedersichtungsmarkierungen verwenden ?.
- [ ] Eingangs-/Freilassungsmarkierungen beim Fang direkt abgelesen; kein ? in irgendeinem Beinfeld.
- [ ] Jede Bildfolge identifiziert Motiv/Ring, Kamera, und vollständige Anfangs-/Endwerte.
- [ ] Zelt- und Versteck-Bildfolgen getrennt; Proben-/Geräteetiketten geprüft.

### Vor dem Speichern

- [ ] Felddatum/-zeit und Beobachter gegen vorausgefüllte Standardwerte geprüft.
- [ ] GPS hochgeladen; beide Zahlen gültig und passend zur Begegnung.
- [ ] Erster NESTS-Besuch hat GPS; spätere Besuche wiederholen es nicht.
- [ ] Seltene Entdeckung von Küken innerhalb des Nests verwendet positive ID, F und danach H mindestens eine Minute später, mit wahren Zahlen; Brut unbekannter Herkunft außerhalb des Nests hat keine NESTS-Zeilen.
- [ ] Falls das seltene korrekte F mit null Eiern die Validierung auslöst, wurde die Beobachtung erneut geprüft und in Kommentaren erklärt; jede Übersteuerung ist dokumentiert, keine Aufforderung zur Abschwächung des Inspektors.
- [ ] Ei-Nummern/-zahlen, leere Flotationsfelder gegenüber null, und tatsächliche Zeiten geprüft.
- [ ] Echte Kükenfänge vor reinen Eltern-/H-Einträgen gespeichert, die diese verwenden.
- [ ] Eltern- und Kükenwiedersichtungen aus einer Begegnung gemeinsam übermittelt.
- [ ] Keine zusätzlichen Kükensichtungen neben Fängen erfunden.
- [ ] Jede leere ID bei normalen Familien oder späteren Fängen erfüllt ihre spezifischen Bedingungen; die Ausnahme gilt nicht für eine neue H-Zeile.
- [ ] Widersprüchliche Familienidentitäten weitergegeben, nicht stillschweigend ausgewählt.
- [ ] Ausnahme wegen fehlendem Elternvogel hat bei Bedarf einen konkreten wahrheitsgemäßen Kommentar.
- [ ] Fänge mit Alter C und Status R oder C haben beide GPS-Felder auch bei einer positiven ID.
- [ ] Jede neue H-Zeile hat eine ausdrückliche gültige positive/negative nest_id, Ring, Beinbeobachtungen, gps_id/point, und Kamera/Bildbereich.
- [ ] Medienfelder für Klasse P oder V vollständig; normale Ringoptionalität nicht auf H angewandt.
- [ ] Geräteaktion, tatsächliche alte/neue IDs, und reine Altvogelfelder geprüft.
- [ ] Fangstatus stimmt mit Vorher-/Nachherkombination überein; Proben verwenden ihre eigenen Codes.
- [ ] Ein D-Totfund hat tatsächliche Eingangsmarkierungen und leere Freilassungsfelder/-zeit, bei Alter C ebenso wie J; keine Flagge oder Sichtung erfunden.
- [ ] Unabhängige Altvogelfänge haben leere `nest_id` und gps_id/point; keine Platzhalter-IDs eingegeben. Negative IDs erscheinen nur in Vogeltabellen.
- [ ] Validierung geprüft; `nov`/`pk` nicht bearbeitet; jede begründete Übersteuerung dokumentiert.

### Vor dem Tagesabschluss

- [ ] Gespeicherte Zeilen stimmen mit den Notizbuchzahlen überein; keine doppelten Übermittlungen.
- [ ] Keine Beobachtung oder anderes erforderliches Ereignis nur in Kommentaren erfasst; ein am Nest gesehener Vogel hat seinen eigenen RESIGHTINGS-Eintrag, nicht nur eine Identität in NESTS-Kommentaren.
- [ ] Originalmedien kopiert und Sicherung geprüft, ohne Dateien umzubenennen.
- [ ] Aktualisiertes To-Do-PDF geprüft, einschließlich Referenzdatum und Aktualisierungsstatus.
- [ ] Fehlende Eltern-/Brutarbeit auf geklärte Zuordnung, Erledigung, Ablauf, vermuteten Verlust, oder Auflösung in der Jungvogelphase geprüft — nicht als Beweis für tote Küken betrachtet.
- [ ] Bruten im Alter 21–35 erneut gesucht; jede spätere Lebendbegegnung oder spät hochgeladene Begegnung aus dem Zeitfenster zur erneuten Aktualisierung übergeben, ohne ihr Felddatum zu ändern.
- [ ] Bestätigter ursprungsverknüpfter J-Eintrag, einschließlich D, auf Auflösung der Brutphase geprüft; bekannte Geschwistertode beibehalten und positive notA-Arbeit weiterhin geprüft.
- [ ] Frühere Eltern, Beobachtungen ohne Brutbetreuung an getrennten Tagen, neue Nestversuche, und alle entgegenstehenden Kükenbelege mit ihren richtigen IDs übergeben; Abschnitt 9.
- [ ] Versteckfotos vor dem tatsächlichen Alter von sieben Tagen geplant, nicht nach Entdeckungsalter.
- [ ] Fehlende Fotos je Ring geprüft; Ablauf nicht mit Erledigung verwechselt.
- [ ] Ungeklärte Familienverknüpfungen, Validierungsabweichungen, und unerledigte Arbeit übergeben.
- [ ] Schicksalskontrollen mit pP, P, oder D bleiben bis zum endgültigen notA in der Übergabe, auch wenn sie im To-Do-PDF fehlen.

</details>

<a id="authorship"></a>

<details>
<summary><strong>Urheberschaft und Einsatz von KI</strong></summary>

## Urheberschaft und Einsatz von KI

Luke Eberhart-Hertel hat die in diesem Handbuch beschriebenen Feldmethoden, Protokolle, und wissenschaftlichen Begründungen entwickelt. Er hat auch die Gestaltung der Datenbank und ihrer Eingaberegeln geleitet und bleibt für die Methoden und endgültigen Entscheidungen verantwortlich.

Unter seiner Leitung half KI dabei, diese Methoden in ein lesbares Handbuch zu übertragen, und unterstützte das Schreiben, Prüfen, und Testen von Teilen der zugehörigen Software. Dazu gehörten die Regeln zur Prüfung der Dateneingabe, die To-Do-Listen, und weitere Datenbankwerkzeuge. Die KI-Unterstützung ersetzte weder sein wissenschaftliches Urteil noch seine Verantwortung.

Wenn sich die folgenden GitHub-Links in der FIELDWORKER-App nicht öffnen lassen, wählen Sie oberhalb des Handbuchs **Handbuch in einem separaten Fenster öffnen** (im englischen Handbuch: **Open Field Manual in a separate window**) und versuchen Sie die Links anschließend erneut.

Für alle, die sich für die Entstehung dieser Arbeit interessieren, macht das Projekt seinen Entwicklungsprozess auf GitHub einsehbar:

- [Überblick über den Einsatz von KI](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/CODEX_USAGE_TRANSPARENCY.md).
- [Anweisungen und Sicherheitsregeln für die KI-Assistenten](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/AGENTS.md).
- [Zusammenfassungen von Anfragen, Diskussionen, und Entscheidungen](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/codex_logs/INDEX.md).
- [Arbeitsnotizen für die verschiedenen Fachaufgaben](https://github.com/ornitho-logics/NZ_FIELDWORKER/tree/main/notes/codex_proposals).
- [Entwicklung und Prüfung der Dateneingabeprüfungen](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/codex_proposals/THREAD3_VALIDATION_ARCHITECTURE.md#mock-data-and-tests), zusammen mit den [Prüfungen selbst](https://github.com/ornitho-logics/NZ_FIELDWORKER/tree/main/notes/codex_proposals/validator_sandbox/inspector_lists_by_table).
- [Entwicklung der To-Do-Listen, Karten, und PDFs](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/main/notes/codex_proposals/THREAD4_TODO_MAP_LIST_DEBUG_PLAN.md).
- [Anleitung zur Reproduktion des Entwicklungs- und Testprozesses](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/1559b166e77d177fe01e278e1b112d912f032b1a/docs/reconstruction/README.md), mit [erfundenen Beispieldaten](https://github.com/ornitho-logics/NZ_FIELDWORKER/blob/1559b166e77d177fe01e278e1b112d912f032b1a/tools/reconstruction/fixtures.sql).

Diese Ressourcen erläutern die Arbeit und ihre Grenzen. Sie enthalten geprüfte Notizen und Zusammenfassungen, nicht jedes Gespräch oder jede private Arbeitsdatei.

Sicherheit und menschliche Aufsicht standen im Mittelpunkt des Prozesses. Luke Eberhart-Hertel prüfte Änderungen und installierte Aktualisierungen persönlich auf dem Feldserver. KI-Assistenten griffen nicht eigenständig auf diesen Server zu und änderten ihn nicht eigenständig. Private Datenbankkopien, Passwörter, und sensible Feldinformationen werden in diesen Transparenzressourcen nicht veröffentlicht.

Die ersten Dateneingabeprüfungen wurden anhand erfundener Einträge entwickelt, einschließlich absichtlich falscher Beispiele, um zu testen, ob Probleme erkannt werden. Bei späterer Entwicklung und Fehlersuche wurden auch ausgewählte echte Einträge und Datenbank-Snapshots verwendet, die einen Teil der Feldsaison abdeckten. Ausgewählte Beispiele und Zusammenfassungen wurden mit der KI besprochen; der vollständige Saisondatensatz war nicht in den Prompts enthalten. Größere Datenbankprüfungen wurden lokal auf Luke Eberhart-Hertels Computer durchgeführt. Diese Unterscheidung ist wichtig: Die Arbeit bestand nicht ausschließlich aus Tests mit künstlichen Daten, aber die vollständige Saisondatenbank wurde auch nicht als KI-Prompt bereitgestellt.

Bei Fragen oder Klärungsbedarf wenden Sie sich an Luke Eberhart-Hertel unter
[luke.eberhart@bi.mpg.de](mailto:luke.eberhart@bi.mpg.de).

</details>
