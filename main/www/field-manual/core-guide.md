# Banded Dotterel / Pohowera — Core Team Field Guide

**Core Team Field Guide · Edition 2 · 3 November 2026**

For experienced team members working under the approved permits, training, and
site instructions. This guide summarises the [Full Protocol Manual](manual.md).
For complete requirements and exceptions, follow the linked procedures. If an
entry or situation is unclear, keep the
record truthful and consult the linked procedure or Luke Eberhart-Hertel.

## Contents

- [1. Before leaving](#core-section-1)
- [2. Record the encounter, not the expected result](#core-section-2)
- [3. Keep family records linked](#core-section-3)
- [4. Nest visits and eggs](#core-section-4)
- [5. Handling, marking, and photographs](#core-section-5)
- [6. Capture and geolocator restrictions](#core-section-6)
- [7. Follow-up and end-of-day checks](#core-section-7)

<a id="core-section-1"></a>

## 1. Before leaving

- Check the To-Do PDF's **reference date**, team allocation, and unfinished work
  from the previous day. A missing task does not prove completion.
- Check capture restrictions before planning a trap. Carry the allocated
  rings, bands, and flags; check Garmin/camera IDs, batteries, and NZ clocks.
- Use `BADO` and your approved site code. Cass River nest-ID, marking, and
  geolocator instructions are not automatically applicable at another site.

<a id="core-section-2"></a>

## 2. Record the encounter, not the expected result

| What happened? | Record |
|---|---|
| Nest or scrape visited | One `NESTS` row per actual visit. |
| Eggs measured | One `EGGS` row per egg measured. |
| Bird handled | One `CAPTURES` row per bird per handling event. |
| Bird observed | One `RESIGHTINGS` row per bird per observation. |
| Chick photographed hiding | A separate `RESIGHTINGS` row per chick, `rclass = H`, in addition to any handling record. |

Do not invent a sighting because a bird was captured. A genuine observation
before handling may be recorded separately. Siblings with the same colour band
still need separate records.

**Comments supplement events; they do not replace them.** The To-Do algorithm
does not read free-text comments as substitutes for the required event records.
An observation entered only in comments will therefore be overlooked as evidence
for the corresponding task decision. Missing event records can leave parent
associations unresolved or make the work plan incomplete or misleading.

For example, writing a bird's identity in `NESTS.comments` is not a resighting.
Keep the nest visit in `NESTS` and enter the observed bird separately in
`RESIGHTINGS`, with its actual marks, sex, behaviour, nest ID, and other required
observation details. Use `behav = IN` only if it was actually incubating.
`bird_inc` records attendance/sex, not individual identity, and does not replace
the resighting either. The same principle applies to any event with its own
required record: enter it in the correct form, not only in another row's comments.

**Keep the correct ID.** A known nest's positive ID stays with its mobile brood.
A negative ID means the nest/origin was never found: retain the minus sign and
use it only in bird tables, never `NESTS` or `EGGS`. Uncertain identity does not
justify inventing a negative ID. Clearly unrelated adult captures use a blank
`nest_id` and both GPS fields; never enter `NO_NEST`.

**Keep blanks meaningful.** Zero is an observed count or an applicable “no,” not
unknown. `X` means an observed empty band position; `?` means unreadable marks
in resightings, not an empty position. Capture leg fields must not contain `?`.

[Record and ID rules](manual.md#section-2)

<a id="core-section-3"></a>

## 3. Keep family records linked

Collect a waypoint at the encounter and write down **both** `gps_id` and
`gps_point`. Parent and chick records from that family encounter must agree on
the date, site, and shared GPS pair. Use a new waypoint when the family is
encountered later elsewhere.

- First nest visit: enter GPS. Later stationary nest visits: leave both GPS
  fields blank.
- Negative-ID bird records, every new H-photo row, and age-C recaptures with
  status R or C require both GPS fields, even when a positive ID is known.
- Adult captures with chicks require the GPS pair and the actual `caught_with`
  entry. First chick captures require the actual positive or negative ID.
- Other positive-nest events have specific GPS/blank-field exceptions: use the
  [GPS requirements](manual.md#section-3), not a blanket rule to fill every field.

Record each parent actually observed, including an unbanded parent as **X-X**
(`LL = X`, `LR = X`). Do not invent an absent mate. Use the behaviour seen:
**AT is not AC**. `BC`, `FC`, and `AC` describe chick-tending; `IN`, `NM`, `SC`,
and `BW` can also confirm a nest link, but BW alone does not establish chicks seen.
Other eligible behaviour needs three matching observations to establish the
individual's link. Never split or duplicate one observation to reach three.
Qualifying nest-linked TN, TB, or HA captures can establish association directly;
record the real method and context, not a code chosen to strengthen the result.

MM capture alone does not prove parentage. Earlier eligible evidence can count
for a reliably identified bird; X-X is not a unique identity across dates.
A unique eligible first-banding capture can inherit same-day, same-sex,
same-nest confirming X-X evidence under the approved targeting assumption.
Refer competing identities or changed nest links rather than guessing.

**Submission order:** upload GPS first. If chicks were handled, save their
genuine captures before parent-only resightings or H rows that rely on them.
Submit parent and chick resightings from one encounter together. A prior parent
capture does not replace the accompanying-parent requirement for new chick
resightings. For a genuine no-parent encounter, keep the chick observations,
waypoint, and specific explanation; follow the exception procedure rather than
fabricating a parent.

[Family, parent-association, and exception procedures](manual.md#section-5)

<a id="core-section-4"></a>

## 4. Nest visits and eggs

- A bird observed at the nest needs its own resighting record; its identity
  in the nest-visit comments alone will not supply To-Do association evidence.
- New empty scrape: `S`, zero clutch. New nest with eggs: `F`. Keep the same ID
  for subsequent visits and record actual counts, times, and evidence.
- Rare first discovery of newly hatched chicks **inside an obvious nest**:
  positive ID, F then H at least one minute later, truthful counts, and an
  explanation. Chicks outside a never-found nest use a negative brood ID, not
  invented nest visits. Consult the rare-discovery procedure if validation blocks.
- `clutch_size` means eggs remaining; `brood_size` means chicks observed.
  `hatch_state` describes the eggs: N no sign, S star, C crack, CC multiple/large
  cracks. Do not return H to I because an egg remains.
- Measure only appropriate eggs; **do not float starred or pipping eggs**.
  Keep actual measurement times. Floating fields for submerged eggs must not
  be filled as though they were surface measurements.
- The first H with no eggs remaining and chicks present is the final hatch
  visit. Later mobile-brood encounters go in bird tables. Final `notA` closure
  remains separate.
- If later individually banded chicks fully account for a known complete
  clutch, the To-Do may infer zero remaining eggs and request a `notA nest-check`.
  This does not invent a nest visit or close the nest. Keep every visit's
  actual counts; the conservative inference currently requires a complete
  clutch of at least 3 eggs and trustworthy original-chick links.

[Nest and egg procedure](manual.md#section-4) ·
[Fate and closure](manual.md#section-9)

<a id="core-section-5"></a>

## 5. Handling, marking, and photographs

Read the ring and actual incoming marks before making changes. Record actual
release marks separately: **F** first marking, **R** unchanged recapture,
**C** changed combination, **D** dead recovery. D uses the recovered incoming
marks, with release marks and release time blank. Do not manufacture a release.
Complete the age/status-specific measurements, samples, and applicable flags
in the [capture requirements](manual.md#section-6).

Follow the flagging To-Do and welfare assessment: follow-up begins from day 21,
but **do not flag below 22 g or 27 mm tarsus**. Those thresholds do not replace
the bander's judgement. Flagging an already banded chick changes its combination:
status C. Use only the allocated marking scheme.

**Hiding photograph:** aim before actual age seven days. Each photographed
chick needs its own age-C, sex-U, class-H resighting with an explicit valid
positive/negative ID, known metal ring, actual leg observations, both GPS fields,
camera ID, and full photo endpoints. Save necessary banding records first.
Keep real attending-parent observations with the submission.

A tent photograph belongs to the capture; a hiding photograph belongs to H.
Do not substitute the capture photo flag or tent sequence for the H record.
Keep original filenames and distinguish individuals by metal ring. The photo
task expiring on day seven does **not** mean it was completed; negative-brood
discovery age is not necessarily biological age.

[Photographs and media](manual.md#section-7)

<a id="core-section-6"></a>

## 6. Capture and geolocator restrictions

**Both the seven-day and 36-hour restrictions still apply to pair completion.**
The seven-day calculation follows final-egg laying evidence, not discovery or
the date completion was confirmed. The 36-hour restriction follows relevant
adult capture. The dated PDF assumes 08:00 on its reference date; it is not a
live countdown. Follow the full timing procedure and welfare assessment.

- A resighting-only row is not permission to capture or deploy a tag.
- “Band” does not mean “tag.” An already-tagged possible parent needs its
  association checked, not another tag.
- Follow conditional tagging notes literally: “tag any, but only if one is
  confirmed X-X” requires confirmation of the unbanded bird and its association.
  An already-banded unknown mate does not satisfy that initial-deployment condition.
- The current 2026 Cass River late-wave rule uses eligible B/C positive nests
  with clutch completion **after 9 October**, not initiation. Apply only the
  approved site allocation and same-nest pair-completion rules.

Record actual adult tag action, before/after tag IDs, and spacer information.
Chick/juvenile tag fields stay blank. Consult the complete
[geolocator and timing instructions](manual.md#section-8)
before capture or any exceptional deployment/retrieval.

<a id="core-section-7"></a>

## 7. Follow-up and end-of-day checks

An empty nest is not proof of hatch or predation. Record observed evidence and
uncertainty. Continue agreed fate checks through final `notA`, even if a task
disappears. A closed nest can still have a surviving brood; negative broods
never receive `NESTS` closure rows.

Seek broods during **ages 21–35 inclusive**. From day 36, no qualifying live
encounter in that fixed window can suppress brood and associated parent work.
A day-25 encounter prevents this particular trigger; a later live encounter
can restore work still due after refresh. Renesting and repeated non-brood
parent observations have separate, stricter evidence rules. **Presumed dead is
a planning inference**, not an observed death or a reason to enter a D capture.
A reliably origin-linked J record resolves chick-stage work under the project
rule; it does not prove every sibling survived.

Before finishing:

- Check that no bird observation, capture, or other required event is recorded
  only in comments. Save the appropriate event record with truthful details;
  do not add a duplicate if it is already recorded.
- Check saved rows against notes, including prefilled dates, observer codes,
  IDs, GPS pairs, and individual counts. Avoid duplicate submissions.
- Copy original media, verify the backup, and retain full filenames.
- Review **DATA ENTRY ISSUES**. Correct mistakes; explain legitimate exceptions
  and follow the repair procedure. Never alter truthful evidence to pass a check.
- Review the refreshed, correctly dated To-Do PDF. Hand over missing photos,
  unresolved links, contrary live evidence, and unfinished fate checks.

[Brood follow-up](manual.md#section-9) ·
[Entry and review](manual.md#section-10) ·
[Validator repair](manual.md#section-12)

---

Methods and decisions remain the responsibility of **Luke Eberhart-Hertel**.
The detailed manual retains the full
[authorship, AI-use, privacy, and security disclosure](manual.md#authorship).
