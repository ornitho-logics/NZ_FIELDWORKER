# BADO Field Manual 2026

Cass River · Banded Dotterel / Pohowera\
**Markdown review draft v2.4.10 · Revised 29 October 2026**

This draft aims to describe the field procedures and the data-entry
validation logic for Banded Dotterel fieldwork during the breeding season.
If the app disagrees with an instruction, keep
the field record truthful and follow [Section 12](#section-12).

## Authorship and use of AI

Luke Eberhart-Hertel developed, described, and reasoned through the fieldwork methods,
protocols and underlying logic presented in this manual, including the
relational data structure and the rules connecting field observations to
database records. He retains full accountability for these
methods, decisions, and their scientific reasoning.

A GPT AI model was used under Luke Eberhart-Hertel's direction to translate the code-based
logic and protocols into a human-friendly Markdown manual, and to help organise
and refine its wording and presentation. AI assistance does not transfer
authorship of the methods or responsibility for their accuracy away from Luke Eberhart-Hertel.

For questions or clarification, contact Luke Eberhart-Hertel at
[luke.eberhart@bi.mpg.de](mailto:luke.eberhart@bi.mpg.de).

## Contents

- [1. How to use this manual](#section-1)
- [2. What have I encountered?](#section-2)
- [3. Before leaving the field house](#section-3)
- [4. Nests, scrapes and eggs](#section-4)
- [5. Adults, chicks and broods](#section-5)
- [6. Captures, bands, rings, flags and tags](#section-6)
- [7. Photographs and media handling](#section-7)
- [8. Geolocator deployment and retrieval](#section-8)
- [9. Fate, hatching, failure and notA](#section-9)
- [10. End-of-day entry and review](#section-10)
- [11. Field-to-database data dictionary](#section-11)
- [12. Validator messages and repair guide](#section-12)
- [13. Required database events by scenario](#section-13)
- [14. Worked examples](#section-14)
- [15. Revision record and source notes](#section-15)
- [Appendix A. Controlled values](#appendix-a)
- [Appendix B. Field and submission checklists](#appendix-b)

<a id="section-1"></a>

<details open>
<summary><strong>1. How to use this manual</strong></summary>

## 1. How to use this manual

If you have time, please browse this manual before going to the field. You may also consult it from the FIELDWORKER app on your phone in the field if you have data coverage. Start with
Section 2 if you are unsure which data records an observation/encounter needs. Read the short
procedure first; use its supporting table when entering the data.

The procedures apply to all our Banded Dotterel / Pohowera throghout New Zealand. Use `BADO` for
the species and `CR` for the Cass River site or check the site list if working elsewhere in New Zealand. Wrybill nests may also be found and
photographed: use `WRYB` and the team's WR nest IDs. Keep `WRYB` records separate
from BADO in your notes. Other species and site codes in the app support wider project work;
they are not additional procedures covered by this manual.

### Record what happened

Give each bird its own record, even when siblings have the same colour band.
A bird only seen goes in the resighting form; a bird caught and handled goes
in the capture form. Do not add a second sighting simply because the chick was
captured. A genuine observation before handling can be recorded separately.

Hiding-spot photographs are a specific exception to the single record:
each photographed chick needs its own H-class resighting as well as any capture
record (e.g., if the chick was unbanded when the hiding spot photo was taken, there should be a capture record to describe the banding plus a resighting record to describe the hiding spot photo. A hiding spot photo of a banded chick requires only the resighting record). A tent photograph stays with the capture. Section 7 explains the
separation.

| Field record | Database table | Number of rows |
|---|---|---|
| Nest or scrape visit | `NESTS` | One new row per visit. |
| Egg measurements | `EGGS` | One row per egg measured on that visit. |
| Bird caught or recaptured | `CAPTURES` | One row per individual per handling event. |
| Bird observed but not handled | `RESIGHTINGS` | One row per individual per observation. |
| Chick photographed in its hiding place | `RESIGHTINGS`, `rclass = H` | One row per photographed chick. |

A row is one line in the entry form. Two banded chicks seen together need two
chick rows, not one row with “two chicks” in the comments.

### Required, conditional, optional or blank?

| Wording in this manual | Meaning |
|---|---|
| Required | Complete this field for the stated event. |
| Conditional | Complete it when the stated condition applies. |
| Optional | Enter it if obtained; do not invent it. |
| Leave blank / not applicable | The field does not apply to that event. Do not fill it with zero or `NA` as a substitute. |

Zero is a real count or an explicit “no” in a 0/1 field. An unknown count is
not zero. `X` in a leg-mark field means an observed empty position; `?` means
marks were seen but not confidently read. These are different observations.

Follow the field lead's directions, permits and welfare limits. This manual
connects fieldwork to the database; practical training still governs trapping,
handling, measuring, sampling and photographic technique.

</details>

<a id="section-2"></a>

<details>
<summary><strong>2. What have I encountered?</strong></summary>

## 2. What have I encountered?

An encounter may need several records. Work through every applicable branch:
finding a nest, floating eggs and catching a parent are separate things to
record, even when they happen on one visit.

### Master decision tree

```text
What happened during the encounter? Follow every applicable branch.
├─ Nest or scrape checked → one NESTS visit [4, 9]
│  ├─ Eggs measured/floated → one EGGS row per egg [4]
│  └─ Clutch photographed → photo fields on that NESTS visit [7]
├─ Bird only seen → one RESIGHTINGS row per bird [5]
│  └─ Family present → record observed parent(s) and chick(s), shared waypoint [5]
├─ Bird caught/handled → one CAPTURES row per bird [6]
│  ├─ Tent photograph → photo fields on that capture [7]
│  └─ Device fitted/removed/retained → device fields on that capture [8]
└─ Chick photographed hiding → separate H-class RESIGHTINGS row per chick [7]
```

### Equivalent text key

1. **Did you check a nest or scrape?** Yes: enter a nest visit, then go to 2.
   No: go to 2 without a nest visit.
2. **Did you measure eggs?** Yes: add one egg row per egg. No: do not create
   egg readings. In either case, go to 3.
3. **Was a bird caught and handled?** Yes: enter its capture; do not manufacture
   a duplicate sighting. No, it was only seen: enter its resighting. Then go to 4.
4. **Were other family members seen?** Yes: record each observed parent and
   chick, using the family waypoint rules. No: do not add absent birds. Go to 5.
5. **Were photographs or videos taken?** Yes: use the appropriate event's photo
   fields; hiding photographs always need separate H rows. No: leave unrelated
   media fields blank. Go to 6.
6. **Was there a device action, hatch, failure or closure?** Yes: also follow
   Section 8 or 9. No: check the records identified above before leaving.

### Which nest or brood ID?

1. **Does the bird belong to a known nest?** Yes: retain that positive nest
   ID, including after the brood leaves the nest. No: go to 2.
2. **Is this a mobile brood whose nest and eggs were never found?** Yes:
   use its assigned negative brood ID. No: do not assign a negative ID merely
   because you are unsure which known nest the bird belongs to. Go to 3.
3. **Is an adult being captured when clearly unrelated to any nest or brood?**
   Yes: leave `nest_id` blank and enter the capture's gps_id/point. No:
   follow the event-specific association rules; do not invent a placeholder ID.

The rare discovery of newly hatched chicks **inside an obvious nest** establishes
a positive nest origin. Record its F discovery followed by H as described in
Section 4. Finding chicks outside a nest does not establish that origin.

Some later chick resightings, and a narrowly defined negative-brood family
encounter, can leave the ID blank. Use the checks in Section 5; a blank field
is not a negative brood ID and must not be filled with a placeholder.

### Which resighting class?

1. **Chick photographed in its hiding place?** Yes: `H`. No: go to 2.
2. **Failed capture attempt?** Yes: `C`. No: go to 3.
3. **Video session?** Yes: `V`. No: go to 4.
4. **Photography session?** Yes: `P`. No: `R` for a regular sighting.

The same letter can have different meanings in different columns:

| Entry | Meaning |
|---|---|
| `age = C` | Chick. |
| `rclass = C` | Failed capture attempt; the bird was not handled. |
| `capture_status = C` | Recapture in which the band combination changed. |
| `tag_action = R` | Device retrieved, not a regular resighting. |

</details>

<a id="section-3"></a>

<details>
<summary><strong>3. Before leaving the field house</strong></summary>

## 3. Before leaving the field house

Check the current To-Do PDF and agree the day's work with the field lead. Take
the Parent–Nest summary, allocated band combinations and the equipment needed
for the visits you have been assigned. Read any capture timing notes before
planning to trap a parent.

### Equipment and time settings

- Charge the Garmin GPS and camera; check their unit IDs against your notes.
- Take field forms, spare batteries/cards, rings, bands, flags, measuring
  equipment and the labelled sample materials needed for the day's work.
- Use local New Zealand date and 24-hour time. Check the camera and GPS clocks
  together, including the correct daylight-saving setting.
- Keep the Garmin switched on in the field. Do not delete or manually rename
  its points. Check recording settings against the app's GPS help if needed.

### Collect a waypoint with your Garmin GPS

At a new nest, brood encounter, capture location, regular resighting, or hiding-photo
location, save a waypoint and immediately write down the Garmin unit ID and
point number. Point 214 on GPS 4 is not the same record as point 214 on GPS 5.

For a family encounter, use the same waypoint for every family member recorded
on that occasion. This includes a situation in which the chick(s) were captures and the parent(s) were only resightings – simultaneous events that are entered into two
different tables (CAPTURES and RESIGHTINGS). Collect a new point for a later encounter after the family
moves; do not reuse yesterday's point because the brood ID is unchanged.
Enter `nest_id` whenever it is known. Use the Parent–Nest summary on the To-Do
PDF to check the family link; otherwise follow the blank-ID conditions in
Section 5. Absence from a To-Do table does not by itself permit a blank ID.

### Supporting table — direct GPS requirements

In this manual, **gps_id/point** means both database fields: `gps_id` (the
Garmin unit ID) and `gps_point` (the saved waypoint number). Enter both numbers
together whenever a direct location is required. “Nest location” means the stationary
point established by the nest's first visit; it is not the waypoint of today's brood location.

| Circumstance | Where the gps_id/point belongs | Requirement |
|---|---|---|
| First positive nest/scrape visit | First `NESTS` row | Required. Later nest visits leave both fields blank. |
| Any entered negative brood ID | Each `CAPTURES` / `RESIGHTINGS` row | Required; no stationary nest location exists. |
| Hiding photograph | Every H-class `RESIGHTINGS` row | Required, including a known positive nest that has since hatched. |
| Eligible blank-ID family resighting | Each qualifying parent/chick row | Required, with the exact encounter date and shared gps_id/point; see Section 5 for more details. |
| Age-C capture, status `R` or `C` | The chick's `CAPTURES` row | Required even with a positive nest ID. |
| Age-C first capture, status `F`, positive nest | The chick's `CAPTURES` row | The entry rule permits both blank when using the nest location (i.e., the fresh chick was still found in the nest scrape). Collect and retain the family waypoint; enter the gps_id/point when recording a capture away from the nest or linking the family encounter. |
| Adult captured with chicks | Adult `CAPTURES` row | Required, including a positive nest; record the chick context in `caught_with`, e.g. `2C` means that the adult was captured with two chicks. |
| Adult capture unrelated to a nest or brood, with `nest_id` blank | `CAPTURES` row | Required. Leave the association blank; do not enter a placeholder ID. |
| Bird resighted without a positive nest link | `RESIGHTINGS` row | Required. |
| Surviving brood after positive-nest `notA` closure | Chick and accompanying brood-parent resightings | Required. |
| Other positive-nest capture | `CAPTURES` row | Normally use the nest location and leave direct GPS blank; do not apply the chick/adult-with-chicks exceptions to unrelated capture contexts. |
| Ordinary resighting at a known positive nest | `RESIGHTINGS` row | The nest can supply the location; retain the shared gps_id/point for a brood encounter. |

### Quick GPS key

1. **Is this the first nest/scrape visit?** Yes: enter its discovery gps_id/point.
   No, a later visit to that stationary nest: leave both nest GPS fields blank.
   For a bird encounter, go to 2.
2. **Is it a brood, H photograph, blank-ID family event, age-C status R or C capture or
   adult capture with chicks?** Yes: use the encounter's gps_id/point as
   specified above. No: go to 3.
3. **Does the permitted event use a positive nest's location?** Yes: follow
   its row in the table. No: the direct-location branch needs both GPS fields.

Upload the GPS before entering biological records at the field house. The entered gps_id/point must
exist among the uploaded points. The biological forms use `gps_id` and
`gps_point`; do not type latitude and longitude into those fields.

</details>

<a id="section-4"></a>

<details>
<summary><strong>4. Nests, scrapes and eggs</strong></summary>

## 4. Nests, scrapes and eggs

### A new nest or scrape

Keep the first visit short. Confirm the species, collect a waypoint with your
Garmin GPS and assign the next unused nest ID under the team's naming system (see below).
Write down the eggs, chicks and attending bird actually seen. Photograph and
process the nest only as directed by the visit plan and welfare conditions.

Cass River BADO IDs use an A, B or C plot prefix and the assigned two-digit
observer/GPS code plus two-digit running tally, for example `B0203`. Do not
restart your tally in another plot: B0203 and A0203 must not be assigned as
different discoveries using the same code/tally. Check the current register.
WRYB nests use the separate WR naming system.

### New discovery or later visit?

1. **Does the scrape/nest already have an ID?** Yes: keep it, choose today's
   state from the evidence using Section 9, and go to 4. No: record the
   discovery waypoint and go to 2.
2. **Are eggs present at the new nest?** Yes: assign its ID and enter the
   opening `F` visit, then go to 4. No: go to 3.
3. **Is this a scrape with neither eggs nor chicks?** Yes: assign its ID and
   enter `S` with zero eggs. No: were newly hatched chicks found inside an
   obvious nest? If yes, use the rare discovery procedure below. If no,
   use the brood guidance in Section 5; do not invent a nest origin.
4. **Were eggs measured or floated?** Yes: add an egg row per egg measured.
   No: do not create readings. Go to 5.
5. **Are chicks present, or is fate uncertain?** Yes: also use Section 9.
   No: complete the active visit and its planned follow-up.

A known scrape can later have its single F discovery when eggs are found;
retain its ID and the original scrape waypoint.

### Rare case: the nest is first found with newly hatched chicks inside

Banded Dotterel chicks are precocial and nidifugous: they can move soon after
hatching and leave the nest shortly afterwards. Finding them still inside an
obvious nest immediately after hatch is therefore very rare.

If that is what you find, assign a positive nest ID and collect the nest
waypoint. Enter two NESTS events: F to record discovery, followed immediately
by H, with the H time at least one minute after F. Explain that the nest was
first found with newly hatched chicks inside it. This records discovery and
hatch at the same encounter; it does not invent an earlier egg visit.

| Event | Required entries for this exception |
|---|---|
| F discovery | New positive `nest_id`, actual discovery date/time, observer/species/site and both nest GPS fields. If no eggs remain, `clutch_size = 0`; do not invent eggs or egg measurements. Record the chicks actually seen. |
| Immediate H | Same positive ID and encounter date; `time_visit` at least one minute after F. Record actual remaining eggs/chicks; with no eggs, clutch 0 and the observed positive brood count. Leave direct nest GPS blank because F establishes the point. |
| Individual birds | Separate CAPTURES rows if handled or RESIGHTINGS rows if observed; family and photograph rules still apply. |

**When validation flags this observation:** a first F row with zero eggs
correctly triggers the usual safeguard. Recheck the entry. If chicks really
were found inside an obvious nest immediately after hatch, keep the true
counts and explain this rare circumstance in `comments`. For example:
“Nest first found with newly hatched chicks still inside an obvious nest;
no eggs remained. F discovery followed by H.”

If saving remains blocked, check the other fields and use the documented
validation override in Section 12, retaining the explanation. This is an
exceptional, commented observation—not a reason to weaken the inspector,
invent eggs or add a programmed exception.

Chicks first encountered **outside** an obvious nest, with no previously known
nest origin, form an unknown-origin brood: use a negative ID and no NESTS
events. Do not make F/H rows merely because chicks look newly hatched. A brood
already reliably linked to a known nest retains its positive ID, as in Section 5.

### Supporting table — one nest visit

| Field(s) | Requirement | Entry |
|---|---|---|
| `species`, `site`, `observer`, `date`, `time_visit` | Required | Species/site, registered initials and actual local date/time. |
| `nest_id`, `nest_state` | Required | Positive ID and today's state. Never a negative ID or a placeholder for an unknown association. |
| `gps_id`, `gps_point` | Required on first visit only | Both on the opening S or F row. A later F after S does not repeat them. |
| `clutch_size`, `brood_size` | Conditional on what can be established | Eggs still present and chicks observed are separate counts. S requires `clutch_size = 0` and blank/zero brood. Do not use zero for an unknown count. |
| `bird_inc` | When attending bird assessed | Sex(es), unknown sex or no bird seen; Appendix A. This does not record the individual's identity. |
| `hatch_state` | When egg condition recorded | Count and condition of remaining eggs; Section 9. |
| `nest_photo`, `tent_photo` | Record whether clutch photographed in scrape/tent | `1` for the applicable sequence, `0` for no photograph. |
| `cam_id`, `photo_start`, `photo_end` | Required when photographs recorded | Actual camera and complete image range on this visit. |
| `comments` | Required for state `O`; otherwise explain uncertainty/unusual findings | Describe the evidence, not just the chosen code. |

Add a row for today's visit. Do not overwrite an earlier visit with later
findings. The same ID stays with the nest when its attending bird changes.

### Measuring and floating eggs

Check the egg's number before each reading and return eggs promptly under the
team's procedure. Do not float starred or pipping eggs. Record their hatch
signs on the nest visit instead; if an egg row is needed to explain omitted
measurements, leave its float fields blank and explain why.

Clutch photographs belong on the nest visit, not in the egg table. Photographing
two eggs without measuring them does not, by itself, require two EGGS rows.

### Supporting table — one row per egg measured

| Field(s) | Requirement | Entry |
|---|---|---|
| `species`, `observer`, `date`, `time_visit`, `nest_id`, `egg_id` | Required | Measurer, actual local measurement date/time, positive nest ID and egg number 1–4. No `site` field exists in `EGGS`. |
| `float_angle` | Record when floated | Observed whole degrees, 0–90. Do not replace an unusual reading with an expected one. |
| `float_location` | Record when floated | `bottom`, `suspended` or `surface`. |
| `float_surface` | Conditional | `bottom`/`suspended`: blank. `surface`: whole mm `0`, `1`, `2` or `3`. Zero means at the surface with no measured projection, not submerged. |
| `comments` | When reading omitted or unusual | Reason for omission or uncertainty. |
| Camera, image and drive fields | Not applicable | No such fields in current `EGGS`; put clutch media in `NESTS`. |

### Timing and row checks

| Check | What it means in practice |
|---|---|
| Egg rows from one check | Use the actual same-day event. Their measurement times must span no more than five minutes under the current check. |
| Matching nest visit | Same positive ID, date and observer, with the nest visit no more than 60 minutes before or after the egg time. |
| Egg numbers | Unique within the measurement event; no number above the matched clutch size. Two measured eggs need two rows. |
| Different measurer or genuine delay | Keep the true observer and times. Explain and refer a failed event match; do not change truthful values to make it pass. A missing match is a review warning, not proof that no nest visit occurred. |

For a surface egg with angle 90° and a measured 1 mm above water, enter
`float_location = surface`, `float_angle = 90`, `float_surface = 1`.
For a submerged egg, leave `float_surface` blank rather than entering `0`.

Use the hatching forecast to plan checks, not as proof of hatch date. Keep the
visit evidence and observed hatch signs alongside any estimate.

</details>

<a id="section-5"></a>

<details>
<summary><strong>5. Adults, chicks and broods</strong></summary>

## 5. Adults, chicks and broods

### When you find a family

Record the adult(s) and each chick you actually encounter. Read the marks you
can see, note what the adults are doing and collect a waypoint with your
Garmin GPS. Keep the family together in your notebook so the entries can be
linked later.

Record both social parents when both are observed and identifiable. If only
one is seen, record that bird; do not add the absent mate. An unbanded parent
still needs a row, using X-X. Two banded chicks need two rows even if their
single colour bands are the same.

### Which family is it?

1. **Is the brood reliably linked to a known nest?** Yes: retain that
   positive ID. No: go to 2.
2. **Was the nest never found?** Yes: use the assigned negative brood ID.
   No, the origin is merely uncertain: check the parents against the Parent–Nest
   summary on the To-Do PDF; ask the field lead if the match remains unclear.

Keep the leading minus sign on a negative ID. It denotes a mobile brood of
unknown origin, not a failed nest or an unidentified adult. Negative IDs belong
only in CAPTURES and RESIGHTINGS, never NESTS or EGGS.

For an adult capture clearly unrelated to any nest or brood, leave `nest_id`
blank and enter the capture's gps_id/point. This is not a way to record an
unknown family association: a brood still needs its actual link or an eligible
blank-ID route described below.

### Give the family one shared waypoint

Every family record from this encounter must carry the same GPS unit and point
number, with the same date and site. This applies across tables: if chicks
were captured but the parents only resighted, their records still need the
same waypoint. These entries are crucial when reconstructing a missing
nest/brood link.

For example, two chick captures and one parent resighting at GPS 4 / point 214
all use `gps_id = 4` and `gps_point = 214`. A point number alone, a point from
another GPS, or yesterday's date cannot identify that shared encounter.

All records from this family encounter must agree on the nest or brood ID
where one is entered. Different nonblank IDs at the same date, site and
gps_id/point trigger a data-entry error, even when the chick's ID is also
entered. Check the notebook and family identity; do not invent a second
waypoint to make the entry pass. This does not prevent a chick's association
changing between separate encounters, for example after brood mixing.

### Record the adult's behaviour

| Adult observation | `behav` |
|---|---|
| Brooding chicks | `BC` |
| Foraging with chicks | `FC` |
| Alert with chick(s) | `AC` |
| Broken-wing display | `BW` |

`BC`, `FC` and `AC` describe a parent with chicks. `BW` alone does not say that
individual chicks were seen: a bird can display near eggs or chicks. Keep
general alert `AT` distinct from alert with chicks `AC`.

### When does an observation confirm the parent–nest link?

When the To-Do PDF asks you to confirm a parent's nest association, record what
that bird actually does at the nest or brood. **Scraping (`SC`) can confirm the
link after one clear, nest-linked observation.** It does not require chicks to
be present. Do not add chick rows unless chicks were actually encountered.

The check applies to each parent separately. Confirming one bird does not
confirm its mate, so the family may still appear under **Parents to resight
for nest association**.

| Observation of the identified parent | Evidence needed for its nest link |
|---|---|
| Incubating `IN` | One matching nest-linked resighting: the identified adult is incubating this nest. |
| Nest maintenance `NM` | One matching nest-linked resighting: the adult is maintaining this nest. |
| Scraping `SC` | One matching nest-linked resighting: the adult is scraping at the recorded nest/scrape. Chicks need not be present. |
| Broken-wing display `BW` | One matching nest-linked resighting can confirm association. The display alone does not establish that chicks were seen. |
| Brooding chicks `BC`, foraging with chicks `FC`, alert with chick(s) `AC` | One matching brood-linked resighting. Record the accompanying chicks as actually encountered, using the rules below. |
| Other behaviour | Three matching nest-linked resightings are needed; the first observation counts towards the three. |
| A `?` in any leg segment | The event does not supply parent–nest evidence unless a known metal ring reliably identifies the bird from capture history. Keep the observed question marks. |
| Parent with chicks: `BC`, `FC` or `AC` | Also follow the accompanying-chick rules below. `SC` and the other confirming behaviours do not trigger that requirement on their own. |

These are codes for the form's `behav` field. Use the behaviour actually seen,
not the code most likely to remove a To-Do entry. An adult alert nearby is `AT`;
use `AC` only for an adult alert with chicks. If several behaviours were
observed, enter the applicable codes separated by commas, for example `AT, IN`.

### How the database chooses between possible parents

The database assesses males and females separately. It first identifies the
bird, then weighs the evidence linking that bird to this particular nest or
brood. A colour combination recognised from an earlier season establishes
identity, not ownership of a current nest.

| Evidence, strongest first | How it affects the parent–nest link |
|---|---|
| A qualifying direct capture | A nest-linked adult caught by TN, TB or HA, or with chicks recorded in `caught_with`, supplies direct association evidence. An eligible adult capture linked to a banded chick through the exact family encounter can also establish the link. Record the actual method/context; never choose a capture code to strengthen the result. |
| One confirming resighting | One of IN, NM, SC, BW, BC, FC or AC above. This takes precedence over an alternative identity supported only by repeated other behaviour. |
| Three other matching resightings | Three genuine, eligible nest-linked observations of the same identity, including the first. These are observation records, not the two separate dates per parent used for brood-loss evidence in Section 9. Do not split one observation or duplicate rows to reach three. |
| Insufficient or conflicting evidence | The link remains pending if no identity reaches a qualifying level, or ambiguous if more than one identity shares the strongest level. The database does not choose a bird merely because it was seen nearby. |

An ambiguous mark match also prevents that candidate from being treated as
resolved, even when some of its other evidence appears strong. Obtain a better
reading and refer the conflict; do not remove the original observation.

A mobile-mistnet capture (`capture_method = MM`) does not, by itself, prove
which nest that adult belongs to. Obtain genuine matching follow-up sightings.
For an MM follow-up, one confirming behaviour or three matching post-capture
resightings can resolve the link. The To-Do follow-up can begin two calendar
days after capture; this is separate from the 36-hour capture-disturbance rule
in Section 8. A timing-blocked capture instruction can also appear as
resighting work, so read the To-Do note rather than assuming every resighting
row means uncertain parent identity.

Read as much of the mark as possible. Most fully colour-banded adults can be
matched by their lower-leg combination; birds distinguished by an upper-leg
spacer need that part read too. A verified metal ring can identify a bird when
its observed colour marks are uncertain. Otherwise, `?` anywhere in the four
leg fields excludes that event from parent-association evidence; it is not a
wildcard matching every possible colour. Keep the original observation.
An X-X adult can be recorded as a current parent, but X-X cannot establish
that it is the same unbanded individual at another nest or on another date.

Later capture/banding or convincing evidence of a different parent can change
the selected identity. Older observations must not be copied forward as new
sightings. Check the refreshed Parent–Nest summary and refer conflicting marks,
sexes or dates rather than editing observations to make them agree.

The field requirement is a genuine shared family encounter: the same date,
site and gps_id/point. The reviewed local matching rules enforce that shared
encounter and reject conflicting family IDs. Check the actual field records
if the Parent–Nest summary looks wrong; an automatic result is not permission
to ignore a mistaken date, waypoint or identity.

**A resolved parent is not a dead brood.** A row can disappear from **Parents
to resight for nest association** because the link is now established, while
the brood remains on banding or flagging lists. The separate presumed-dead
and juvenile-stage resolution checks are explained in [Section 9](#section-9).

### Enter sightings and handling as encountered

Use the following order to avoid inventing observations to satisfy a message.

| Encounter | Records and submission order |
|---|---|
| Parent(s) and chicks only seen | One RESIGHTINGS row per bird. Submit the parent and chick rows together. |
| Chicks captured, parent(s) only seen | Save the genuine age-C CAPTURES rows first. Then submit the parent RESIGHTINGS rows, matching date, site and complete gps_id/point. The saved captures satisfy the parent's accompanying-chick check. |
| Chick only resighted; parent handled but not observed tending chicks | The capture alone does not satisfy the chick resighting's accompanying-parent check. Record what occurred and refer a truthful exceptional encounter; do not invent tending behaviour. |
| Chick photographed hiding after handling | Capture first, then a separate H row with the actual parent resighting(s); Section 7. |

If you enter a behaviour code implying a parent-with-chicks observation but
have no accompanying chick record, check your notes. Add the actual chick
resightings, or save the genuine chick captures first if that is what happened.
Do not make up additional chick sightings alongside captured chicks.

The distinction works in one direction: a **saved chick capture** can satisfy
the parent-side check. A chick **resighting** still needs the observed parent
in the same RESIGHTINGS submission. A parent entered yesterday—or saved in an
earlier submission today—is not automatically included in the rows now being
checked. Avoid splitting one family sighting across separate submissions.

### Supporting table — parent and chick resighting links

| Check | Requirement |
|---|---|
| Parent | `age = A`; actual behaviour includes `BC`, `FC` or `AC`. |
| Uncertain parent marks | Record what was read. If any leg segment contains `?`, the event cannot supply parent–nest evidence unless its known metal ring can be reliably traced to capture history. Enter that known code in `ring`; do not replace observed question marks with inferred colours. Old capture history establishes identity, not a previous season's nest link. |
| Chick | A separate `age = C` row for each chick resighted, including H rows. |
| Matching encounter | Same date and either the same valid ID or the same complete gps_id/point. For field recording, retain the shared family date, site and gps_id/point even when the ID is known. |
| Parent side | Linked chick row in the submission, or an already-saved age-C capture with the exact same date, site and complete gps_id/point. An unsaved capture in another form cannot be checked. |
| Chick resighting side | Linked parent row in the current submission; prior parent history supplies identity evidence, not a new observation. |
| Positive nest history | Parent-with-chicks observations need latest relevant nest state `H` or `notA`, on or before the encounter date. Do not invent hatch evidence to satisfy this. |
| Exceptional encounter | Explain a genuinely missing parent/companion observation; Section 12. |

### When the nest or brood ID can be blank

Enter it whenever known. Use the Parent–Nest summary on the To-Do PDF to work
out the ID from the parent combination(s). The following exceptions are for
existing, reliable family links, not permission to choose a nearby nest.

| Resighting circumstance | Conditions before omitting `nest_id` |
|---|---|
| Ordinary chick, class `R`, `P`, `V` or `C` | Both GPS fields and at least one same-submission age-A `BC`, `FC` or `AC` parent at that exact date and gps_id/point. Each qualifying parent needs a valid current or resolvable prior association; the family must give one unambiguous nest/brood result. Class P or V resightings retain their camera/range requirements; `ring` remains optional. |
| One or both parents recorded | One or both may supply the link; two parents linked to the same nest are still one unique ID. Conflicting or unresolved identities do not supply an inferred link. |
| Negative-brood family, with blank IDs on parent and chick rows | The confirmed parent records in the database must already identify both social parents unambiguously for one negative brood, with neither unresolved. Each parent actually seen must match its selected identity and have `BC`, `FC` or `AC`; all rows share date, site and complete gps_id/point. One observed parent is sufficient; do not add its absent mate. |
| Hiding-photo chick | No omission permitted for new H rows. Enter the explicit positive/negative ID as well as ring, both GPS fields and complete photo fields; Section 7. |
| First chick capture | No resighting exception applies. An age-C status-F CAPTURES row needs the actual positive nest or negative brood ID. |

The software's saved-family lookup is not a location-only guess. Missing,
pending or ambiguous parent identities cannot supply an omitted ID. Enter the
known ID explicitly or refer the unresolved association rather than bypassing
the ambiguity. Inferred links do not fill the original blank field afterwards.
A positive-nest parent still carries its required ID; the exception allowing
both parent and chick IDs to be blank is the negative-family case above.

### An unbanded parent, or no parent seen

If an unbanded parent is tending chicks, record it as X-X: at minimum
`LL = X`, `LR = X`. Add its actual behaviour, age, sex, observer, date, site,
required ID and shared gps_id/point. X-X records an unbanded bird at this encounter;
it does not identify that individual across days and cannot by itself supply
the parent-identity exception above.

If no parent was seen, record each chick and the encounter waypoint. Add a
specific comment, such as “Two banded chicks resighted; no tending adult seen
during this encounter.” This is a legitimate missing-parent exception. Use
the documented override only if the truthful entry remains blocked after
checking the other fields. An unknown ID needs its own explanation; an absent
parent cannot supply a missing family link.

Before saving, compare the bird count, shared waypoint and IDs with your
notebook. If the family link is uncertain, put it in the handover.

</details>

<a id="section-6"></a>

<details>
<summary><strong>6. Captures, bands, rings, flags and tags</strong></summary>

## 6. Captures, bands, rings, flags and tags

### Record the bird before and after handling

Give each captured bird a new capture record. Read its metal ring and all leg
marks before making changes. Record the marks at capture separately from
those at release. Check sample labels and device numbers against the ring
while the bird's identity is clear.

### Which capture status?

1. **Was the bird dead when recovered?** Yes: `D`, with the circumstances in
   comments. No: go to 2.
2. **Was this its first marking?** Yes: `F`. No: go to 3.
3. **Did the combination change?** Yes: `C`. No: `R`.

| Status | Incoming fields `UL_in`, `LL_in`, `UR_in`, `LR_in` | Release fields `UL`, `LL`, `UR`, `LR` |
|---|---|---|
| `F` | `X` in all four under the reviewed entry rule. | Actual new marks; not all X. |
| `R` | Complete existing marks. | Same combination as incoming. |
| `C` | Complete previous marks, with at least one marked position. | Actual changed combination; at least one position differs. |
| `D`, at any age | Actual recovered marks in all four positions, using X where no mark is present. A chick or juvenile may be flagged or unflagged. | Leave all four blank; no release time. Do not add a release flag to a dead bird. |

Do not use `?` anywhere in a capture leg field, including incoming fields.
The bird is being examined directly. Do not replace an unreadable mark with
`X`; explain an exceptional damaged/unreadable mark and refer it for review.

### Supporting table — capture details

| Field(s) | Requirement | Entry |
|---|---|---|
| `date`, `caught`, `species`, `site`, `observer`, `capture_status`, `capture_method`, `field_sex`, `age`, `ring` | Required | Actual capture identity, local date/time and CP metal-ring code. |
| `released` | Live release | Actual release time, after capture. Blank for dead recovery. |
| `nest_id` | Association-dependent | Enter the known positive or negative ID. A first chick capture must have one. For an otherwise valid later chick capture with a blank ID, the snapshot can recover the brood link through unambiguous earlier ring history; event-specific entry checks still apply. Keep the actual ring and both GPS fields. Refer conflicting history rather than guessing. For an unrelated adult capture, leave this blank and enter gps_id/point. Do not use a placeholder. |
| `gps_id`, `gps_point` | Conditional | Use the exact status/location table in Section 3. Age-C status R or C always need both. |
| Incoming and release leg fields | Status-dependent | Use the table above and actual ordered marks. No question marks. |
| `caught_with` | When companions caught with focal bird | Codes/counts such as `M` or `2C`. An adult caught with chicks needs the direct gps_id/point. This does not replace individual bird records. |
| `parents` | Chick/juvenile context, when assessed | Attending sex composition from Appendix A; not the parents' identities. Blank for adults. |
| `eggs_handled` | When recording egg handling during capture | `0` no / `1` yes. CAPTURES only. |
| `book_id`, `form_id` | When using capture book/forms | The book and page identifiers from the paper record. |
| `observer_upload` | Capture uploader | Registered initials of the person entering the record. |
| Photo fields and flags | Event-dependent | Section 7. Devices: Section 8. |

### Measurements, samples and photographs by age

Use mm for lengths and g for mass. Follow the team's measurement technique;
do not substitute a different tarsus or wing method because the units agree.

| Bird | Required measurements/entries in the reviewed inspector | Conditional, optional or blank |
|---|---|---|
| Adult, `age = A` | `tarsus`, `culmen`, `total_head`, `head_white`, `head_black`, `rufous_band`, `wing`, `weight`; `brood_patch` 0/1; at least one moult score; `fat` 1–8; `feather_wear` 0–3; `breast_samp`, `primary_samp`, `mugshot_photo`, `wing_photo` 0/1. | `parents` blank. Chick-photo flags blank/0. Blood/other samples only if taken. Explain a measurement that could not safely be obtained; do not invent it. |
| Chick, status F or R | `tarsus`, `culmen`, `weight`; sex `U`. Initial F also needs `chick_tent_photo` and `chick_hide_photo` 0/1; use `chick_hide_photo = 0` for this separate-H workflow. | No `total_head`, `head_white`, `head_black`, `rufous_band`, `wing`, `brood_patch`, moult, fat or feather-wear entries. `breast_samp`/`primary_samp` blank or 0; mugshot/wing flags blank. R chick-photo flags may be blank or 0/1. |
| Older chick, changed combination C | `tarsus`, `culmen`, `weight`; sex `U`; complete before/after marks and both GPS fields. | Additional older-chick measurements, samples and supported photo flags may be entered when obtained; they are not all made mandatory merely by status C. |
| Chick recovered dead, status D | `tarsus`, `culmen`, `weight`; sex `U`; actual recovered marks in all four incoming positions. | Age-C restrictions on other measurements/samples still apply. Release leg fields and released time blank; no first-marking photo requirement merely because the bird was recovered. Explain anything that could not truthfully be measured. |
| Juvenile, `age = J` | `tarsus`, `culmen`, `weight`; sex `U`. | `total_head`, head-band/rufous widths and `brood_patch` blank. Wing may be recorded. `breast_samp`/`primary_samp` blank or 0; chick-photo flags blank/0. |
| Chick or juvenile | No device entries. | Leave `tag_action`, `tag_type`, `tag_id`, `tag_id_in` blank—not O. |

For blood, use `BQ` (Queens buffer), `BF` (filter paper) or `BE` (EDTA);
leave blank if none was collected. Feather-sample flags use 0/1, not the blood
codes. Label every sample so it can be matched to the bird's ring and event.

For measurements, outside tarsus is the diagonal measurement from the rear
notch at the upper end to the last front scute at the foot; exposed culmen is
from forehead feathering to bill tip. Total head is bill tip to back of skull;
wing is the maximum flattened and straightened wing. Use trained technique,
not these brief descriptions alone.

### Read marks from the bird's left and right

Read stacked bands top to bottom. `BG` and `GB` identify different orders.

| Position | Observed/release field | Incoming capture field |
|---|---|---|
| Left upper leg / tibia | `UL` | `UL_in` |
| Left lower leg / tarsus | `LL` | `LL_in` |
| Right upper leg / tibia | `UR` | `UR_in` |
| Right lower leg / tarsus | `LR` | `LR_in` |

| What was read | What to enter |
|---|---|
| Two red bands | `RR`, not R,R. Colours: Appendix A. |
| Metal band | `M` in the leg field; individual metal number in `ring`. |
| Complete engraved flag | F + colour + engraving in the upper-leg field, e.g. `FWAB`. |
| Resighting: red above an unread band | `R?` in the appropriate segment, e.g. `LL = R?`. |
| Resighting: unread band above red | `?R` in the appropriate segment. |
| Resighting: bands seen but none confidently read | `?` in that segment. Do not enter X or leave it blank as though no marks were seen. |
| Resighting: tag with yellow spacer | `UR = TY`. |
| Resighting: tag with spacer colour unreadable | `UR = T?`. Bare T is not allowed. |
| Unbanded bird resighted | X-X: at minimum `LL = X`, `LR = X`; complete other event fields. |

The uncertainty notation applies to all four RESIGHTINGS leg segments. It does
not extend to CAPTURES or create a new partial flag-code format. Explain a
partly read engraving in comments; do not guess it. A partial mark records
what you saw but may not identify a parent reliably enough to omit its ID.

### Chick bands and later flags

Cass River status F or R chicks use one colour in LL and metal M in UR, with empty UL/LR
positions represented as X in the capture record. Siblings may share the colour;
only their metal rings distinguish them individually.

Follow the **Broods to recapture for flagging** To-Do list and the field lead's
assessment. The listed follow-up begins at 21 days or more; it is not proof
that a chick is ready. **Do not flag a chick below 22 g or below 27 mm tarsus.**
Meeting those cutoffs does not replace the bander's welfare judgement.

Giving a previously banded chick an engraved flag changes its combination:
use capture status C, preserve the incoming marks and record the actual release
marks. The juvenile marking scheme uses an engraved UL flag, UR metal and
empty lower positions; do not change age solely to make a layout pass.

### Why flagging work appears or disappears

The updated snapshot uses the latest qualifying chick encounter on or before
the PDF's reference date, not simply the largest earlier brood count. The
task decision and the PDF's **N chicks / N seen** use the same SQL result.
Direct nest IDs, unambiguous prior ring history and eligible GPS-linked family
records can supply the brood link. A later capture with a blank nest ID can
therefore contribute its flag through the same ring's earlier capture.

Distinct known chicks count once; repeated rows for one ring do not add
chicks. The flagged count concerns those same latest-encounter individuals,
not a different sibling flagged earlier. For example, three chicks were
captured originally, but the latest qualifying encounter contains just one
identified chick and that chick is already flagged: no flagging task remains.
Two latest chicks with only one flagged, or one latest unflagged chick, still
leave work to do. This operational reduction does not declare missing siblings
dead or resolve their individual fate.

Unringed, ambiguous or otherwise unresolved evidence must not falsely close
the task. Confirmed-dead chicks are not live targets; their surviving siblings
remain separate work. If there is no usable latest encounter, the snapshot
falls back to its capture-history/operational brood count and retains its
existing unresolved-evidence safeguards. A missing count is not proof that
zero chicks remain. Report a mismatch rather than changing observations to
remove a task.

Use only the team's allocated combinations from the current To-Do PDF and
the field lead. Never reuse a combination because its previous bird has not
recently been seen. A display of an apparently available mark is not a
replacement for the team's allocation.

</details>

<a id="section-7"></a>

<details>
<summary><strong>7. Photographs and media handling</strong></summary>

## 7. Photographs and media handling

### Write the image range down at the encounter

For each sequence, record the subject, camera ID and first/last filenames.
For chick photographs, write the individual ring as well. Check the notes
while you can still match the images to the birds and location.

A tent photograph records handling; a hiding photograph records the chick in
its hiding place. Keep their image ranges distinct, even on the same occasion.
A capture-form checkbox alone does not record a qualifying hiding photograph.

### Which record receives the photographs?

1. **Is it a chick in its hiding place?** Yes: a separate H resighting for
   each photographed chick. No: go to 2.
2. **Is it a chick photographed during handling in the tent?** Yes: its
   capture row, with `chick_tent_photo = 1`. No: go to 3.
3. **Is it a clutch photographed in the scrape or tent?** Yes: the NESTS
   visit and its applicable photo flag(s). No: go to 4.
4. **Is it an adult handling photograph?** Yes: the capture photo flag(s)
   and range. No: use P for a photography resighting or V for a video session.

| Photograph/session | Table and fields | Keep separate from |
|---|---|---|
| Clutch in scrape / tent | `NESTS`: `nest_photo` / `tent_photo`, plus `cam_id`, `photo_start`, `photo_end`. | EGGS float readings. |
| Chick handling/tent | `CAPTURES`: `chick_tent_photo = 1`, camera/range. | Hiding-place images. |
| Adult mugshot / wing | `CAPTURES`: `mugshot_photo` / `wing_photo`, camera/range. | A separate field resighting session. |
| Chick hiding place | `RESIGHTINGS`: `rclass = H`, explicit positive/negative `nest_id`, individual ring, direct GPS and camera/range. | All CAPTURES photo ranges. |
| Other photography / video | `RESIGHTINGS`: `rclass = P` / `V`, camera/range and normal event details. | A regular R row without media. |

### A chick photographed hiding

Keep enough information to match every photographed chick to its ring, hiding
place and images. Give each chick a line in your notebook. “Two chicks
photographed” does not identify which two individuals were completed.

If the chick is unbanded when the hiding photograph is taken, it also needs
to be captured and banded under the normal chick protocol. Enter the banding
in CAPTURES and the hiding photograph in a separate H-class RESIGHTINGS row.
Keep track of the individual throughout the photograph and handling sequence
so the H row contains the correct chick's newly assigned ring.

If the chick is already banded and is photographed without being caught,
enter only the H resighting; do not add a new capture record. Its earlier
capture must already be saved so the ring can be checked. If the chick is
actually caught again, record that genuine recapture in CAPTURES as well as
the separate H resighting. A tent photograph, if taken, stays on the capture.

Collect the family waypoint with your Garmin GPS, even if the positive nest
is known. Record the parent(s) and other family members actually resighted
on that occasion, all with the same date, site and complete gps_id/point. One
observed parent is sufficient; an absent mate does not need a row. An unbanded
parent is entered as X-X, not omitted.

### Supporting table — one H row per photographed chick

| Field(s) | Requirement | Entry |
|---|---|---|
| `species`, `site`, `date`, `observer` | Required | Actual field encounter, normally BADO / CR. |
| `age`, `sex`, `rclass` | Required | `C`, `U`, `H`. |
| `ring` | Required | Photographed chick's CP metal ring, e.g. `CP12345` or `CP-12345`. Its capture must already be saved in current-season CAPTURES. |
| `UL`, `LL`, `UR`, `LR` | Observed marks required alongside ring | Record the layout seen, including supported uncertainty notation. Ring does not replace leg fields. Do not guess an unreadable colour or metal position. |
| `nest_id` | Required for every new H row | Explicit valid positive nest or negative brood ID. Ring or parent history does not waive this entry. |
| `gps_id`, `gps_point` | Required | Both for this hiding-photo encounter, including positive-nest chicks. |
| `cam_id`, `photo_start`, `photo_end` | Required | Actual camera and complete hiding-image range. End must not precede start. |
| `behav` | Optional for H | Leave blank if not separately recorded; any entered code must be appropriate for a chick. |
| Parent resighting | Required except genuine no-parent encounter | Observed age-A parent with `BC`, `FC` or `AC` in the same submission; Section 5. |

Save the chick's capture before submitting the H row, so its ring can be
checked. Keep the tent range on that capture. In this workflow, set the initial
chick capture's `chick_hide_photo` to 0; where that flag is optional it can
remain blank/0. Enter the actual hiding photographs in H rows, not by setting
the capture flag to 1.

Ordinary R/class P or V/C resightings may leave `ring` blank. An H photograph cannot:
sibling colour bands alone do not distinguish the photographed chick.

<details>
<summary><strong>Finding the H row's nest or brood ID</strong></summary>

### Use the established family link, not GPS alone

Every new age-C H row needs its ID entered explicitly. Use the Parent–Nest
summary on the To-Do PDF and the chick's saved ring/capture history to check
the family. A partly read mark or a waypoint alone is not enough to choose
between families. If the ID cannot be established reliably, preserve the
photograph, ring and encounter notes and ask Luke Eberhart-Hertel to resolve the link; do not
guess or use the ordinary blank-ID exception to submit an H row.

| Family situation | Required link |
|---|---|
| Parent's current positive/negative ID is known | Enter that ID on the H row and check it against reliable chick/family history. Record the parent(s) actually seen; do not invent an absent mate. |
| An ordinary family resighting qualifies for a blank ID under Section 5 | That exception does not extend to an H row. Enter the H chick's explicit nest/brood ID. |
| Prior ring/family association is ambiguous | Retain the evidence and ask Luke Eberhart-Hertel to resolve it before entering the H record; do not select a convenient ID. |

Ring, leg observations, gps_id/point and photo fields remain compulsory. A
valid H row and completed **Broods to photograph** work are different checks.
The software retains deterministic ring-history links for older H records
saved under the previous blank-ID procedure. That is historical compatibility,
not permission to leave a new H row's ID blank; raw historical rows are not
silently rewritten.

</details>

### Check progress against individual rings

The To-Do comparison counts distinct captured chick rings and distinct qualifying
H-photo rings for that nest/brood. Repeat H rows for the same ring count once.
`CP12345` and `CP-12345` are recognised as the same ring; use consistent spelling
with the capture notes to make manual checking easier.

Three captured chicks and only two qualifying H-photo identities leave one
photograph outstanding. A brood with no captured-ring evidence is not treated
as completed simply because both counts are zero. An unresolved H association
may leave work listed despite the photographs having been taken.

### Two different clocks

Take hiding photographs **before the chicks are seven days old**. This is the
biological deadline. The To-Do display uses a dated record, which is not always
the chick's true age.

| Circumstance | To-Do display window | What the fieldworker must remember |
|---|---|---|
| Brood from a positive nest | Days 1–6 after the hatch-evidence date. | Day 0 is not in this display window; take suitable photographs when encountered rather than waiting for the list. |
| Negative brood of unknown origin | Days 1–6 after discovery. | Chicks may already be older when found. Discovery is not hatch date; assess age and prioritise with the field lead. |
| Day 7 after the relevant date | The To-Do task expires. | Expiry is not completion and does not extend the under-seven-day biological aim. |

Put missing photographs, uncertain age and unresolved family links in the
handover. Do not use disappearance from the PDF as proof that every chick was
photographed.

### Copying and checking media

Copy the original images to the assigned drive and keep their filenames
unchanged. Record the drive/folder in the team's media register; there is no
`harddrive_id` field in the current NESTS, EGGS, CAPTURES or RESIGHTINGS tables.
Do not delete camera originals before the team's backup check.

Check the camera and full image identifiers, including any roll/frame prefix.
For example, `101-4122` and `102-4122` are different images; the last four
digits alone do not identify them. Retain the full image identifier recorded
in the field and use the team's established filename convention in the form.
Do not rename originals to make a range pass validation.

Several age-C H rows from the same photo session may share an image range when
they have the same camera and date and share either the valid nest/brood ID or
complete gps_id/point. Each chick still needs its own ring and row. This exception
does not permit a CAPTURES tent range to be reused as an H hiding range.

Before finishing, check every recorded sequence against the files and the
updated To-Do PDF. Keep a per-chick list of what remains, not just a brood total.

</details>

<a id="section-8"></a>

<details>
<summary><strong>8. Geolocator deployment and retrieval</strong></summary>

## 8. Geolocator deployment and retrieval

### Follow Luke Eberhart-Hertel's deployment directions

Deployments are spread across nesting phenology to sample residents and migrants
evenly. Early nests are predicted to contain more residents and later nests
more migrants; nest timing alone does not identify an individual as either.

The plan is roughly 50 of the 100 geolocators in the first nesting wave and 50
in the second. A possible third wave is expected to contain renesters and
double-brooding parents, rather than first-time nesters. Luke Eberhart-Hertel monitors the
waves and directs the team to pause or continue deployment.

Aim to sample both members of selected active pairs, helping balance the sexes.
This is a pair-level aim over time, **not permission to catch both parents on
one visit**. Each bird must be independently eligible. If the mate must wait,
leave it unhandled and recheck its current To-Do instructions later.

### Before attempting a capture

| Check | Required field decision |
|---|---|
| Current To-Do PDF | A **Parents to capture** instruction for the intended bird and purpose. A resighting-only note is not a deployment instruction. |
| Identity and device status | Reliable bird identity and current tag status. Resolve uncertain identity first unless the current To-Do instruction explicitly allows confirmation at capture. |
| Nest/brood and wave | Suitable active unit, current processing requirements met and Luke Eberhart-Hertel's wave directions permit deployment. |
| Seven-day interval | The applicable clutch-completion gate is open; use the current To-Do instruction, not a count from nest discovery. |
| Thirty-six-hour interval | The post-parent-capture disturbance gate is open. Pair completion does not waive it. |
| Bird and conditions | Permits, welfare, weather, condition, handling limits and bander judgement allow the action. |
| Stock and follow-up | Confirm the assigned device and current stock; keep an ineligible mate as pending work. |

### Supporting table — capture timing notes

| To-Do note | Meaning |
|---|---|
| `7d rule` | Capture waits until at least seven days after the final egg's known or defensibly estimated laying date. Do not start another seven days at the date completion is confirmed. |
| Two eggs, valid laying estimate | If an observation confirms that the clutch still has two eggs at least three days after egg 2's estimated laying date, treat it as complete at two eggs. Count the seven days from that laying estimate, not the confirmation visit. An already-old floated clutch can qualify on discovery. |
| Two eggs, no float data | Use the first recorded two-egg date as a conservative proxy until better evidence is available; an earlier one-egg discovery is not the second egg's date. A later observation must confirm the clutch is still two eggs after the three-day interval. A gap in visits alone does not establish completion. |
| A third egg appears later | Reset the completion basis to the third/final egg's laying estimate, using the observed laying history or valid float estimate; otherwise use the first three-egg observation as the conservative proxy. Do not retain the earlier two-egg clock. |
| Floated after discovery | The later valid float can refine the final-egg estimate. It need not be artificially limited to the discovery date; retain the actual visits and measurements. |
| `36hr rule` | Another parent is not eligible until the disturbance interval has elapsed. The PDF calculation uses 08:00 on its reference date against the previous relevant adult capture time; do not treat a stale morning list as a live countdown. |
| Both rules | Both gates must be satisfied; one does not cancel the other. |
| Timing or association unresolved | Resight or wait as directed. Do not recalculate an exception in the field to turn resighting work into capture work. |

Three eggs are the usual completed clutch, but two eggs, or rarely one, can
be the true final clutch. Record actual counts and follow-up visits; do not
invent a third egg. A stable one-egg clutch follows its separately checked
completion rule and the current To-Do instruction.

The project's completion-based incubation interval is 26 days. Where the
hatch estimate uses that same completion basis, **19 days to hatch corresponds
to seven days since completion**. The displayed hatch countdown is a useful
cross-check, not an independent capture permit when laying history or
completion is unresolved. Hatch signs, confirmed hatch and a known negative
brood can satisfy the seven-day gate under their existing rules; the separate
36-hour restriction and all other capture/GEO checks still apply.

### When one parent already has a GEO

Pair completion concerns the reliably associated mate of a currently tagged
parent with qualifying deployment history at this same nest. A tag at an
unrelated nest, a retrieval-only record or an uncertain parent identity is not
enough. The current To-Do decision must still meet the applicable nest/plot,
association, welfare and timing rules.

If the mate is confirmed unbanded, an eligible instruction can read
`tag X-X M (pair completion)` or its female equivalent, rather than simply
`band X-X`. If the mate's status still needs checking, `resight/tag M (status ?)`
or its female equivalent asks the team to establish that status and tag only
when eligible. A `resight/tag` note is not permission to bypass a closed
seven-day or 36-hour gate. Without qualifying GEO pair-completion evidence,
an ordinary `band X-X` instruction remains banding work, not a deployment.

### Which device action occurred?

1. **Was the adult handled?** No: record what was visible in RESIGHTINGS;
   no deployment/retrieval is claimed. Yes: go to 2.
2. **No device before or after?** Yes: O. No: go to 3.
3. **No device before, device fitted?** Yes: D. No: go to 4.
4. **Device removed with none fitted?** Yes: R. No: go to 5.
5. **Same device retained?** Yes: S. No, an old device was replaced by a
   different one: N.

### Supporting table — adult GEO captures only

`TY` below illustrates a yellow spacer. Enter the actual complete spacer
colour in the appropriate before/after mark; no `T?` is allowed in CAPTURES.
Non-tag marks remain the actual observed bands, not automatically X.

| `tag_action` | `tag_id_in` before | `tag_id` after | `tag_type` | `UR_in` → `UR` |
|---|---|---|---|---|
| `O` no tag | Blank | Blank | Blank | Actual no-tag mark → actual no-tag mark. |
| `D` deployment | Blank | New outgoing device | `GEO` | Actual no-tag mark → tag plus known spacer, e.g. TY. |
| `R` retrieval | Removed device | Blank | `GEO` | Tag plus known spacer → actual no-tag release mark. |
| `S` retained | Existing device | Same device | `GEO` | Actual tag/spacer before → actual tag/spacer after. |
| `N` replacement | Old device | Different new device | `GEO` | Actual old tag/spacer → actual new tag/spacer. |

For these adult entries, record `wt_w_tag = 0` or `1` to say whether the
recorded mass included a tag. For O, use 0. Complete the bird's capture status,
ring, before/after bands and the other required capture fields as well.
`tag_action` and `capture_status` describe different things: removing a device
does not automatically mean the band combination was unchanged.

Device history must support the action: retrieval/retention refer to the device
active on that bird; a replacement has distinct old/new IDs. Check a history
error against the notebook and refer it rather than changing the device number.

Chicks and juveniles leave all four device fields blank—not O. A tagged adult
only seen is recorded in RESIGHTINGS with the visible tag/spacer and comments.
`UR = T?` records an unread spacer colour, not an unread device ID. Failure to
see a tag is not proof of retrieval.

Before release and entry, compare ring and device labels with the written
record. A retrieved unit is not automatically available for redeployment;
Luke Eberhart-Hertel must confirm its physical condition and allocation.

</details>

<a id="section-9"></a>

<details>
<summary><strong>9. Fate, hatching, failure and notA</strong></summary>

## 9. Fate, hatching, failure and notA

### Describe the evidence from this visit

Look at the remaining eggs, chicks and attending birds before deciding the
state. An empty nest does not by itself distinguish hatch from loss. Keep a
possible outcome separate from a confirmed one and explain the evidence.

| Finding | `nest_state` | Supporting record |
|---|---|---|
| Scrape, no eggs | `S` | Zero clutch; first visit has discovery GPS. |
| Nest discovery | `F` | Normally with eggs; may follow an earlier S. The rare newly hatched chicks inside an obvious nest use F then immediate H; Section 4. |
| Active, incubated nest | `I` | Actual eggs and attending bird. |
| Chicks seen at hatching | `H` | Separate remaining-egg and chick counts. |
| Possible predation / desertion | `pP` / `pD` | Evidence and uncertainty in comments; keep agreed fate checks open until notA. |
| Confirmed predation / desertion | `P` / `D` | Evidence supporting confirmation; further fate checks remain allowed until notA. |
| Final inactive-nest closure, marks removed | `notA` | Final visit; conditions below. |
| Other finding | `O` | Required explanatory comment; not a reset of the history. |

### Hatch, failure or closure?

1. **Are chicks present?** Yes: record H and actual egg/chick counts; enter
   individual birds separately. No: go to 2.
2. **Are eggs still active?** Yes: record the active visit and egg condition.
   No: go to 3.
3. **Is loss/desertion established?** Yes: P/D with evidence. Only suspected:
   pP/pD with comments and agreed review. Unclear: retain the uncertainty;
   do not invent either hatch or failure. Go to 4.
4. **Is the positive nest ready for final closure and marks removed?** Yes:
   enter notA. No: retain the agreed follow-up.

### Fate checks remain open until notA

Neither possible predation pP nor confirmed predation P or desertion D is the
final closure visit. Continue the necessary fate-check visits, adding a new
NESTS row with the evidence from each visit, until the final notA closure.
Do not overwrite the earlier finding when later evidence clarifies it.
Possible desertion pD likewise remains a review state, not final closure.

If the To-Do PDF stops listing the nest before closure, keep the agreed check
in the team handover. Absence from the PDF does not mean the nest has received
its final notA visit. Check the PDF's reference date and refresh status, and
report missing closure work rather than assuming it is complete.

### Keep eggs and chicks separate

`clutch_size` is eggs still present; `brood_size` is chicks observed.
`hatch_state` describes remaining eggs, not chicks: count followed by N (no
sign), S (star), C (crack) or CC (multiple/large cracks).

One unpipped egg and two chicks give `clutch_size = 1`, `hatch_state = 1N`,
`brood_size = 2`. Record the chicks in CAPTURES if handled or RESIGHTINGS if
only seen. H nest visits can repeat while eggs remain. Do not return the state
to I after H merely because an egg remains unhatched.

The first H visit with no eggs left and chicks present is the final hatch
visit. Later mobile-chick encounters belong in the bird tables, not additional
H nest visits. One final notA closure may follow.

### Supporting table — final closure

| Situation | Entry |
|---|---|
| Normal `notA` | Final NESTS row; `clutch_size = 0`, `hatch_state` blank. |
| Surviving brood after final H | One notA may directly follow the final H row, with zero eggs and the observed surviving brood count retained. No intervening D row is needed. |
| Deserted eggs retained | The approved same-submission D → notA sequence may retain the D row's observed clutch count. D is assessed before notA if timestamps are identical; closure cannot precede D. Explain the sequence. |
| pP, P or D fate still being checked | Add each actual follow-up visit; these records remain open until final notA. Do not manufacture closure because a To-Do task disappears. |
| Negative brood | No NESTS row and no notA closure. Continue individual brood records. |
| A new attempt nearby | Assign a new nest ID under the team's convention; do not reopen a closed ID for another nest. |

A closed positive nest can still have a surviving brood needing banding,
hiding photographs or flagging. Keep its positive ID on linked bird records
and record the current family waypoint. A later chick encounter can advance
the To-Do PDF's Last Visit without changing when hatch was first recorded.

### Following a brood when chicks are no longer seen

Chicks can hide, so one unsuccessful search or one adult seen alone is not
proof that a brood has died. Resighting the known parent(s) remains valuable:
record their identity, where they are and what they are actually doing. The
database can then distinguish unresolved family work from evidence supporting
presumed brood loss or a subsequent nesting attempt.

Use the Parent–Nest summary to identify the former parents before setting out.
When possible, plan genuine follow-up observations of **both** parents on
different dates. Collect a waypoint with your Garmin GPS at each encounter.
If the chicks are seen again, record them individually, with their parent(s)
and the shared family gps_id/point under Section 5. Do not omit surviving chicks
or chick-tending behaviour merely because the brood is expected to have failed.

**Presumed dead is a planning inference, not an observed death.** It removes
the brood's To-Do work after a refresh; it does not rewrite the field records,
prove that every chick died, or replace a positive nest's final notA visit.
There is no presumed-dead `behav` code to enter. Do not use a dead-recovery
capture status for an inferred loss.

### Do not confuse association, loss and juvenile-stage resolution

| Result after refresh | Evidence | Meaning for follow-up |
|---|---|---|
| Parent association confirmed | The eligible identity and nest-linked observations in Section 5. | That parent's link no longer needs confirmation. Brood banding, photographs or flagging may still be due. |
| Brood presumed dead | Route 1, 2 or 3 below, without contrary live evidence. | Further brood-related work, including associated parent capture/resighting tasks and the brood's Parent–Nest summary entry, is suppressed. This is not an observed death or a reason to invent a D capture. |
| Brood resolved at the juvenile stage | One reliably origin-linked age-J capture or resighting, including a confirmed age-J dead recovery. | Under Luke Eberhart-Hertel's project rule, siblings are presumed to have reached J too, so chick-stage follow-up stops. This is not proof that every sibling survived. |

None of these results rewrites the observations. A positive nest may still
need its final notA visit; a negative brood never receives NESTS rows.

### Which behaviours contribute to which decision?

| What was actually observed | `behav` entry | Use in the checks |
|---|---|---|
| Parent brooding, foraging with, or alert with chicks | BC, FC or AC | Positive brood-tending evidence. It does not count as a non-brood observation; enter each encountered chick too. |
| Incubating, maintaining a nest, or scraping | IN, NM or SC | Confirms a nest association when the identity/link is eligible. It is nesting/restart behaviour, not a non-brood observation. For another attempt, use that nest's own ID. |
| Broken-wing display | BW | Can confirm association and can supply one of the qualifying non-brood observation dates when no BC/FC/AC or IN/NM/SC occurs on that row. BW alone cannot meet the brood-loss requirement for either parent. |
| Foraging alone / with presumed mate / in flock | FA / FM / FF | Counts towards the stronger non-brood evidence when properly identified and explicitly linked to the old brood, without positive brood or nesting/restart behaviour on that row. |
| Roosting / loafing / alert / fighting | RS / LF / AT / FT | Counts on the same basis as FA/FM/FF. General alert AT is not alert with chicks AC. |
| Other behaviour | OB | Counts on that same basis in the current calculation. Explain exactly what occurred in `comments`; OB is not a code for “brood gone”. |
| Preening or courtship only | PR or CO | Useful field observations, but do not count towards the repeated non-brood-loss threshold. They do not independently confirm nest association either. |

An observation can serve different purposes. For example, three genuine AT
resightings may establish a parent's nest association, but AT observations
made **before** the brood's hatch evidence cannot establish subsequent brood
loss. A row containing `AT, BC` is positive brood evidence, not negative evidence.

### Route 1 — repeated non-brood observations of both parents

All the following conditions must be met for this route. A negative brood uses
its discovery date, because its true hatch date may be unknown. For a positive
nest, the starting date is the earliest recorded H visit or positive brood
count; if neither exists, the first linked chick capture supplies hatch
evidence. This is the database's evidence date, not a claim to know the exact
hatching time.

| Requirement | What to obtain or check |
|---|---|
| Brood is eligible | A positive nest with hatch evidence, or an unknown-origin negative brood. An egg-stage failure is assessed through nest visits, not this mobile-brood rule. |
| At least 21 days have elapsed | The PDF's reference date is at least 21 days after that starting date. The observations themselves may have been made earlier within this post-start period. |
| Both parents reliably established | The male and female each have an unambiguous selected association with the old brood. Merely possible identities, unknown sex and X-X cannot supply this two-parent history. |
| Two separate dates for each parent | Each parent has qualifying non-brood observations on at least two different dates, strictly after the starting date and no later than the reference date. The parents need not be seen on the same dates. Repeated rows on one day count as one date for that parent. |
| Old brood ID recorded explicitly | These qualifying parent rows carry the old positive or negative `nest_id`. A known identity or waypoint alone does not assign a blank-ID row to the old brood for this particular calculation. Never attach an uncertain observation to an ID just to make it count. |
| More than BW alone | Each parent has at least one qualifying row with FA, FM, FF, RS, LF, AT, FT or OB. BW can contribute another date, but two BW-only dates per parent are insufficient. |
| No conflicting behaviour on the counted row | A row with BC/FC/AC or IN/NM/SC is not counted as non-brood evidence, even if it also includes AT or another listed code. |
| Brood-tending chronology checked | The latest linked BC/FC/AC observation must be earlier than **both** parents' last qualifying non-brood dates. A same-day or later positive observation fails this condition. |

The candidate loss date is the later of the two parents' last qualifying
non-brood dates. The live-evidence check below is then applied. Simply reaching
21 days, or failing to find the chicks for 21 days, is not sufficient for this
route. The separate fixed-window rule in Route 3 starts only from day 36.

### Route 2 — former parent(s) associated with another nest (renesting evidence)

Renesting means starting another nesting attempt. An associated scrape is
enough: there is no need to wait for eggs. Record the new attempt under its
own positive nest_id, then record the adult's actual association with it.
One eligible SC observation can confirm the scraping parent's link; IN or NM
can also confirm a link when those behaviours are genuinely observed.
Do not add a behaviour merely to remove the old brood from the To-Do PDF.

Luke Eberhart-Hertel's project rule treats qualifying renesting as automatic presumed loss
of the earlier dependent brood: BADO parents do not begin another attempt
while still tending that brood. This route has no 21-day wait. Record any
contrary chick evidence truthfully and refer an apparent contradiction to Luke Eberhart-Hertel.
If the old brood has already resolved through reliable age-J evidence, a new
attempt does not turn that developmental resolution into presumed death.

| Requirement in the current calculation | Field meaning |
|---|---|
| A distinct subsequent attempt | A different positive CR nest first recorded after the old brood's starting date, with an eligible S, F or I visit by the reference date. Revisiting an older or closed nest does not establish a new attempt. |
| One strongly established former parent | One adult has an unambiguous selected association with both the old brood and this other nest. This is sufficient for the later-nest route. It is not necessary to observe an absent mate or wait 21 days. |
| Alternative: two matched former-parent identities | Two distinct former-parent identities, one male and one female, are reliably matched to the same new attempt. A lone tentative identity or two same-sex candidates do not establish this pair route. |
| Actual parent evidence | The parent-association hierarchy in Section 5 applies. IN/NM/SC are useful direct behavioural observations, but the calculation does not demand one of these three codes when another eligible association route has already established the link. |
| Distance is supporting information only | A later nest within 100 m can strengthen the displayed reason, but proximity alone never establishes common parents or closes a brood. A linked nest farther away can qualify; a negative brood needs no invented origin point. |

The candidate loss date cannot precede the required nest and identity evidence
for either the old brood or the new attempt. A later confirmation must not be
used to backdate the result. Proximity alone, a possible identity or a future
observation cannot supply the link. Report a mistaken link to Luke Eberhart-Hertel.

### Route 3 — no live brood encounter during ages 21–35 days

Plan to locate broods again between ages **21 and 35 days, inclusive**. From
day 36, a brood with no qualifying live encounter anywhere in that window is
presumed dead for planning. Its brood work and associated parent capture and
resighting tasks are removed after refresh, along with its brood entry in the
Parent–Nest summary. This rule does not require the two-parent observations
in Route 1 or renesting evidence in Route 2.

| Check | How this rule works |
|---|---|
| Which age is used? | For a positive nest, count from its recorded hatch evidence, not its egg-stage discovery. For a negative brood, use the existing operational age/discovery-date proxy: this is not a claim that discovery was its true hatch date. Without a usable age anchor, this rule cannot establish presumed loss. |
| When does the window end? | Day 35 is still within the observation window. The first possible suppression date is day 36. All checks use the PDF's reference date and records available for that date. |
| What counts as an encounter? | The reliably linked live chick or positive brood-tending evidence described below. Direct nest/brood IDs and approved unambiguous ring-history or family gps_id/point links count. An unidentified adult alone, an ambiguous link or a dead chick recovery alone does not count. |
| What if the brood was seen on day 25? | One qualifying live encounter on any day from 21 through 35 prevents this particular trigger, even at later reference dates. This is a fixed window, not a rolling absence period. Routes 1 and 2 and juvenile-stage resolution still apply independently. |
| What if chicks are found again after day 35? | Enter the actual encounter. A qualifying live encounter on day 36 or later prevents this presumed-dead result at the next refresh and restores any work still due under the normal task rules. Do not change the observation to fit the earlier expectation. |

Nothing in this calculation proves that the chicks died. Do not enter a dead
recovery, failure visit, zero brood count or invented unsuccessful search just
to obtain the result. Upload genuine observations promptly, and ask for a
refresh before relying on the dated work plan. A required positive-nest notA
visit remains separate; negative broods never receive NESTS closure rows.

A later confirmed death does not erase an earlier live encounter within the
window. If a resighting conflicts with a death recorded on the same or an
earlier date, refer the identity and chronology for review rather than using
it automatically to establish survival.

### Live evidence can keep the brood open or bring it back

Before suppressing To-Do work, the database checks for any of the following
dated **on or after the candidate loss date**, up to the reference date:

- An age-C CAPTURES row with live capture_status F, R or C, reliably linked
  to the old brood.
- An age-C RESIGHTINGS row reliably linked to the old brood.
- A reliably established former parent's BC, FC or AC resighting explicitly
  linked to the old brood, directly or through an approved unambiguous link.

Any such record prevents the presumed-dead result at that refresh. Brood work
can reappear where it still meets its normal age, timing and completion rules.
It does not guarantee that every previous To-Do entry returns; for example,
the hiding-photo display window may already have expired.

For Route 3, the candidate loss date is day 36. The same qualifying live
evidence also prevents that route when dated within days 21–35. A late upload
of a genuine day-25 encounter therefore corrects the result after refresh;
do not alter its field date to the upload date.

An approved unambiguous inferred link counts too; a blank raw nest_id does not
mean that the event has no family association. Enter the known ID whenever
available. Otherwise follow Section 5, retaining the shared date, site and
gps_id/point. Conflicting explicit IDs, ambiguous parents or uncertain marks
without a verified known ring cannot supply an inferred association. Do not
change a truthful date or waypoint to make an event count.

A capture with status D is a dead recovery, not evidence of survival. An
unknown capture status is not reliable live evidence either. One dead chick
does not establish that the entire brood died: a sibling may remain alive.
Record the recovered bird as its own CAPTURES row and continue recording any
living siblings and tending parents actually encountered.

### One origin-linked juvenile resolves chick-stage work

Record the bird's actual age. An engraved flag identifies a bird; it does not
by itself establish age J. One genuinely age-J capture or resighting that can
be reliably traced to its original brood resolves that brood's chick-stage
work. Under Luke Eberhart-Hertel's project rule, siblings develop at the same rate and are
presumed to have reached J too. Do not wait for a separate J record for each
sibling simply to clear the brood's To-Do work.

A readable flag may be traced through the capture that linked it to a metal
ring, then back to the original chick capture. Later brood mixing does not
replace that original origin. Contradictory ring/flag identities or an ambiguous
original brood need review; they must not resolve whichever ID happens to be
entered on the new row.

| Origin check | Timing requirement |
|---|---|
| Juvenile CAPTURES event | The origin and flag-to-ring evidence must already exist by the actual capture event. Enter the truthful date and caught time. |
| Juvenile RESIGHTINGS event | Because this table has no encounter-time field, the automatic trace uses origin/flag-to-ring captures from an earlier field date, not the same date. This concerns field dates, not when the rows were uploaded. |
| Identity cannot yet be traced safely | Keep the actual observation and refer the unresolved result to Luke Eberhart-Hertel. Do not move dates or invent earlier captures. |

A reliably origin-linked dead recovery confirmed as age J also resolves
chick-stage work. It establishes reaching J, not survival. Enter D, the actual
recovered marks in the incoming fields and blank release fields/time. Keep all
known sibling deaths in the record: resolved does not mean every sibling lived.
An age-C dead recovery does not supply this juvenile-stage evidence.

Neither juvenile resolution nor presumed loss replaces an independently
required positive nest notA visit. Do not enter a NESTS failure or alter raw
records to obtain either result.

### Field decision key — what evidence should I collect next?

1. **Has a genuinely age-J bird been reliably linked to its original brood?**
   Yes: record that individual, including a dead recovery if that is what was
   found, and check juvenile-stage resolution after refresh. No: go to 2.
2. **Have chicks or chick-tending parents been seen?** Yes: record the actual
   family, each bird separately, with shared date, site and gps_id/point; do
   not call the brood dead. No: go to 3.
3. **Are the former parents reliably identified?** No: collect mark and actual
   association behaviour using Section 5; unresolved identity cannot supply
   the two-parent loss inference. Yes: go to 4.
4. **Is a former parent genuinely associated with a new attempt, including a
   scrape?** Yes: record that nest under its own ID and the actual parent
   behaviour; check Route 2
   and report contrary chick evidence. No: go to 5.
5. **Have both former parents been observed without brood-tending on two
   separate dates each?** No: plan suitable repeat observations, without
   disturbance or invented records. Yes: check all Route 1 conditions,
   including the 21-day gate, explicit old brood links and BW limitation.
6. **Has the brood reached day 36 without any qualifying live encounter at
   ages 21–35?** Yes: Route 3 can suppress its work after refresh. Record any
   later live encounter truthfully so eligible work can return. A day-25
   encounter prevents this route; simply seeing an adult alone does not.
7. **Is the brood absent from a newly refreshed PDF?** Check the reason with
   the designated operator. Resolved parent association, normal completion,
   expiry, presumed brood loss and juvenile-stage resolution are different
   reasons for disappearance.
   Missing work or contrary survival evidence still needs a handover.

For event tables and examples, see Sections 13 and 14. No fieldworker needs
to alter a status table or manually “tick off” a brood: enter genuine evidence,
then have the designated operator refresh and review the dated work plan.

</details>

<a id="section-10"></a>

<details>
<summary><strong>10. End-of-day entry and review</strong></summary>

## 10. End-of-day entry and review

### Bring notebook, GPS and media together

1. Download and upload the Garmin records first. Check the unit IDs and
   waypoint numbers against your notebook.
2. Copy original media to the assigned drive. Check each sequence's subject,
   ring, camera and full first/last filenames.
3. Enter nest visits before their egg measurements and positive-nest bird
   observations that rely on that history.
4. Save genuine chick captures before parent-only resighting submissions or
   H rows that need to find those captures. Do not add duplicate chick sightings.
5. Submit parent and chick resightings from one encounter together. Compare
   their shared date, site and gps_id/point with any captures from the encounter.
6. Open **DATA ENTRY ISSUES**, correct mistakes and check again. Use Section 12
   for a valid exception or a message that contradicts the agreed procedure.
7. Save, check the submitted record and review an updated To-Do PDF. Put
   incomplete entries, family links and photographs in the team handover.

The form may prefill today's date, BADO or CR. Check these when entering older
notes or WRYB records. Hover over column headings for hints, but do not change
a truthful entry to follow a hint contradicted by the current procedure.
Different people can enter data simultaneously; agree who is entering each
encounter to avoid duplicate submissions.

### Read the To-Do PDF as a dated work plan

The PDF reads the published To-Do snapshot for its reference date. Saving a
record or downloading the PDF again does not necessarily rebuild that snapshot.
Check the date and ask the designated operator for a refresh if new records
are missing. Do not change the app-wide reference date casually; other outputs
use it too.

| PDF heading | What to do/check |
|---|---|
| Parents to capture | Intended bird, purpose and timing notes; Section 8. |
| Parents to resight for nest association | Obtain actual behaviour/identity evidence; do not convert resight-only work into capture. |
| Nests to process / re-process | Missing floatation or clutch/scrape/tent photographs, subject to hatch signs and the visit plan. |
| Nests to check for additional eggs | Actual clutch increase or stability. |
| Nests to check for potential hatch | Remaining eggs, hatch signs and chicks seen—not just the predicted date. |
| Broods to band | Separate captures and metal-ring identities for chicks handled. |
| Broods to photograph | Per-chick H-photo progress. Biological deadline before age seven days; display clocks in Section 7. |
| Broods to recapture for flagging | Current age estimate, identity, measurements and welfare; Section 6. |
| Nests requiring a notA closure visit | Final positive-nest closure, not a negative-brood entry. |

For chick work, compare **N chicks / N seen** with the latest qualifying
encounter described in Section 6, not automatically with the original clutch
or historical maximum brood size. Both the task gate and PDF display consume
the same published SQL counts. Re-download after the operator has refreshed
the snapshot if a new ring-linked flagging capture is not yet reflected.

Use the Parent–Nest summary to look up a family from the parent combination(s).
Map points for nests are stationary; brood points show the latest supported
encounter location, not a promise that the family is still there. Overview
panels help assess progress and hatch forecasts; they are not capture permits
or substitutes for the current To-Do instructions.

If a parent-association row disappears, first check whether its link was
resolved under Section 5. If brood work disappears, also check normal task
completion/expiry, presumed loss and juvenile-stage resolution in Section 9.
The fixed day-21-to-35 encounter window can also remove associated parent
work from day 36; later qualifying live evidence can bring eligible work back
after refresh. Check the recorded closure reason rather than assuming that
every missing row means the parent association was resolved.
The operator can inspect the recorded reason, date and supporting evidence;
absence alone does not tell the fieldworker which rule applied.

A positive nest can remain in the summary or on the map solely because its
notA visit is still due, even after brood follow-up ends. That is not an
instruction to keep trying to band or photograph the resolved brood.

### Before finishing

Compare notebook counts with saved rows. Check each new ring, negative ID and
family waypoint; then compare the media notes with the copied files. Confirm
that no form was accidentally saved twice. Missing work needs a clear handover
even if it has expired from the To-Do display.

</details>

<a id="section-11"></a>

<details>
<summary><strong>11. Field-to-database data dictionary</strong></summary>

## 11. Field-to-database data dictionary

These are the field names used on the forms. A column's presence does not mean
every event needs a value; use the procedure's requirement table.

### Identity, date and location

| Field | Meaning and use |
|---|---|
| `species` | BADO for this manual; WRYB for a Wrybill record. |
| `site` | CR for Cass River; supported in NESTS/CAPTURES/RESIGHTINGS, not EGGS. Other site codes serve wider work. |
| `observer` | Registered initials of the person observing/measuring/banding, not automatically the data uploader. |
| `date` | Actual field date, local NZ, `YYYY-MM-DD`. |
| `time_visit` | Actual nest-visit or egg-measurement time, `HH:MM`; no such RESIGHTINGS field. |
| `caught`, `released` | Actual capture/release times, CAPTURES only. |
| `nest_id` | Positive known-nest link or negative unknown-origin brood link. An unrelated adult capture leaves it blank and requires gps_id/point. Family-event blanks must satisfy Sections 5 and 7. |
| `gps_id`, `gps_point` | Garmin unit and saved waypoint number. Together identify the uploaded point; neither is a coordinate. |
| `comments` | Evidence, uncertainty, omitted observations and reasons for a justified exception. |

### Birds and marks

| Field | Meaning and use |
|---|---|
| `age` | A adult, J juvenile, C chick; the same age field exists in both bird tables. |
| `sex` / `field_sex` | Resighting / capture sex respectively. M/MU male/probably male; F/FU female/probably female; U unknown. Chicks/juveniles use U. |
| `ring` | Individual metal-ring code. Required in CAPTURES and H RESIGHTINGS; optional in other resighting classes. Supplements leg marks. |
| `UL`, `LL`, `UR`, `LR` | Bird's left/right upper/lower leg marks. Observed marks in RESIGHTINGS; release marks in CAPTURES. |
| `UL_in`, `LL_in`, `UR_in`, `LR_in` | Marks before handling, CAPTURES only. No question marks in any capture leg field. |
| `rclass` | R regular, P photography, V video, C failed capture, H hiding photograph. |
| `behav` | Behaviour observed. Multiple applicable tokens use commas; BC, FC or AC trigger the family checks. Do not comma-separate stacked band colours. |
| `capture_status` | F first marking, R unchanged recapture, C changed combination, D dead recovery. |
| `capture_method` | HA hand, TB clap-trap on brood, TN clap-trap on nest, SM stationary mistnet, MM mobile mistnet, O other with comment. |
| `parents` | Attending sex composition for a chick/juvenile capture; does not store parent identities. |
| `caught_with` | Companions caught with focal bird: M mate, M? probable mate, S same-sex conspecific, C chick/count such as 2C. Its question mark convention is separate from leg fields. |
| `book_id`, `form_id` | Capture notebook and page identifiers. |

### Nests and eggs

| Field | Meaning and use |
|---|---|
| `nest_state` | This visit's nest state; Section 9. |
| `bird_inc` | Sex(es) of bird attending/incubating, or E no bird seen. Not a parent identity or proof of an empty clutch. |
| `clutch_size`, `brood_size` | Remaining eggs / chicks observed. Blank is not zero. |
| `hatch_state` | Remaining egg counts and N/S/C/CC signs; e.g. 2N1S. |
| `egg_id` | Egg number 1–4 within the nest, repeated consistently on later measurements. |
| `float_angle` | Whole degrees, 0–90. |
| `float_location` | bottom, suspended or surface. |
| `float_surface` | Whole mm 0–3 for a surface egg; blank for bottom/suspended. |

### Measurements, media and devices

| Field(s) | Meaning and use |
|---|---|
| `tarsus`, `culmen`, `total_head`, `wing` | Lengths in mm using the team's defined methods. |
| `head_white`, `head_black`, `rufous_band` | Band widths in mm; age-specific requirements in Section 6. |
| `weight`, `wt_w_tag` | Mass in g; 0/1 says whether that mass included a tag. |
| `brood_patch`, `moult_left`, `moult_right`, `fat`, `feather_wear` | Condition/moult assessments, not substitutes for comments. Use trained scoring; Appendix A. |
| `breast_samp`, `primary_samp` | Feather-sample flags 0/1 where applicable. |
| `blood_samp`, `other_sample` | Blood preservation code or other actual sample description. No blood: blank. |
| `cam_id`, `photo_start`, `photo_end` | Camera and full first/last image identifiers. Present in NESTS/CAPTURES/RESIGHTINGS, not EGGS. |
| `nest_photo`, `tent_photo` | NESTS clutch photo flags. |
| `mugshot_photo`, `wing_photo`, `chick_tent_photo` | CAPTURES handling-photo flags. |
| `chick_hide_photo` | CAPTURES field retained by the form; use 0/blank as applicable. Actual hiding images require separate H rows. |
| `tag_action`, `tag_type`, `tag_id_in`, `tag_id` | Adult device action/type and before/after IDs; Section 8. Blank for chick/juvenile captures. |
| `eggs_handled` | CAPTURES-only 0/1: eggs temporarily removed during capture. |
| `observer_upload` | CAPTURES-only initials of the person entering the record. |
| `falcon_upload` | DOC/FALCON upload management, not fieldwork completion. Leave the form default/handling to the designated uploader. |
| `nov`, `pk` | App-managed validation/record identifiers. Do not edit to clear an error. |

Media storage location belongs in the team's media register, not an invented
`harddrive_id` column. Reports received from members of the public are curated
separately by the designated team member; do not move routine field observations
out of RESIGHTINGS to avoid its entry checks.

</details>

<a id="section-12"></a>

<details>
<summary><strong>12. Validator messages and repair guide</strong></summary>

## 12. Validator messages and repair guide

### Check the message against the notebook

Open **DATA ENTRY ISSUES** and read the named row and column. Correct a typo,
wrong default or omitted observation, then check again. A save-blocking error
needs attention before submission; a warning asks for review but does not prove
the observation is wrong.

| Message/problem | Check and response |
|---|---|
| Required field missing | Use the notebook and event-specific table; do not substitute zero for unknown. |
| GPS absent/not found | Upload GPS first. Check both actual numbers and the encounter date; never select a convenient uploaded point. |
| Age-C status R or C capture lacks gps_id/point | Enter both fields even with a positive ID. The status F exception does not apply to status R or C captures. |
| Parent-with-chicks lacks chick row | If chicks were captured, save the genuine age-C CAPTURES rows first with matching date, site and gps_id/point. Otherwise add the actual chick sightings. No invented extra resightings. |
| Chick resighting lacks parent | Include the tending parent's actual observation in the same submission; an unbanded parent is X-X. If no parent was seen, use the exception below. |
| Blank ordinary chick ID | Check date/GPS, parent BC, FC or AC and one reliable family association. For blank negative-family parent IDs, both social parents must already be resolved. |
| Ambiguous family/parent | Recheck identities and known ID with the field lead. Do not choose the first match or override an unresolved association as though it were established. |
| H ring missing/not found | Actual CP ring, already saved in current-season CAPTURES. An ordinary sighting's optional ring rule does not apply. |
| H/Class P or V media incomplete | Camera and both range endpoints. H also needs both GPS fields, including with a positive ID. |
| Unknown resighting mark rejected | Confirm supported ?, ?R, R?, or UR T? notation. A live inspector may still predate the correction: retain the true reading and refer the mismatch. |
| Question mark in capture marks | Read the handled bird's actual marks. Do not copy an uncertain resighting into capture fields or replace uncertainty with X. Refer a damaged/unreadable mark. |
| Bare T | Every tag has a spacer: actual known colour in a capture, or T? in a resighting if unreadable. |
| Photo range overlaps another event | Check camera, full prefix and sequence ownership. Only the same-session H-sharing rule permits shared ranges. |
| Status R but marks changed | Check before/after bands; a genuine changed combination uses status C. |
| Device-history mismatch | Check ring, old/new device IDs and prior action. Do not alter an ID to manufacture a history. |
| Measurement warning | Units, transcription, age/status and the true measurement. Keep a valid unusual value with explanation; review readiness for flagging where relevant. |
| Nest chronology or egg-visit mismatch | Actual visit sequence, observer and times. Never invent hatch evidence or change a measurement time to make a link pass. |
| First F with zero eggs rejected after chicks found inside the nest | Expected safeguard. Recheck the observation; if correct, retain true counts and explain the rare inside-nest discovery in comments. Use the documented override if blocked after checking all other fields. No programmed validator exception is needed. |
| Further pP, P or D visit rejected | Fate checks remain allowed until final notA under the approved method. Check the actual sequence and refer an older validator's terminal-state message. |
| Validator failed / no meaningful row or variable | Possible inspector failure. Retain the message and ask for technical review; it is not a biological finding. |

### Chicks seen without a parent

Record the chicks and waypoint as encountered. Add a specific comment, such
as “Two banded chicks resighted; no tending adult seen during this encounter.”
This is a legitimate exception to the normal companion-parent check, not a
reason to invent an adult.

Check every other field. If the truthful entry remains blocked, use the portal's
documented control: set **VALIDATION** to **OFF**, retain the explanatory
comment on the affected record and flag it in the handover. Return validation
to ON for subsequent ordinary entries. If the nest/brood ID is also unknown,
explain that separately; the missing parent does not supply a blank-ID link.

An observed unbanded parent is not absent: enter its X-X row. A forgotten
parent row, incomplete gps_id/point or missing H ring is not the same exceptional
situation. The override itself proves neither parentage nor completed To-Do
work, and does not remove H ring/GPS/media requirements.

### Rare discovery with chicks inside the nest and no eggs

The normal first-F zero-clutch rejection is intentional. In Section 4's very
rare F → H discovery, recheck that the chicks were actually inside an obvious
nest, retain the real counts and comment on the circumstances. The reviewed
message already asks you to double-check and add a validator bypass comment
if the entry is correct.

If still blocked after the other fields are checked, set **VALIDATION** to
**OFF** for the justified entry, keep the explanatory comment, and return it
to ON afterwards. Do not change the inspector or enter an imaginary egg count.

### When the live app differs from this draft

Keep the exact field observation and message. Refer the discrepancy to the
field lead before adopting a workaround. Do not switch off validation routinely
to imitate a corrected inspector that has not yet been installed. Recent local
checks are not live-portal verification; source/version details are in Section 15.

</details>

<a id="section-13"></a>

<details>
<summary><strong>13. Required database events by scenario</strong></summary>

## 13. Required database events by scenario

Use these tables to check the records needed for an encounter. “Resighting
details” means `species`, `site`, `observer`, `date`, `rclass`, `age`, `sex`,
observed leg marks and applicable `behav`. “Capture details” means the required
identity, status, times, marks and age-specific fields in Section 6. GPS and
family exceptions retain the conditions in Sections 3 and 5.

<details>
<summary><strong>New nest or scrape</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | Newly assigned positive ID: `NESTS`, one opening visit. |
| Required | `species`, `site`, `observer`, `date`, `time_visit`, `nest_id`, `nest_state`, both GPS fields. |
| Conditional | S has zero clutch; egg/chick counts, attending bird and hatch signs as observed. |
| Photographs | `nest_photo`/`tent_photo`, actual camera/range on NESTS. |
| Do not enter | Negative or placeholder ID, reused discovery tally or invented egg measurements. |
| Likely To-Do follow-up | Scrape photos, processing, additional eggs or hatch checks. |

</details>

<details>
<summary><strong>Newly hatched chicks found inside an obvious nest</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | Very rare first discovery with chicks still inside their nest: two NESTS rows, F then immediate H. |
| Required | Same new positive ID; F discovery gps_id/point; H time at least one minute later; actual egg/chick counts and normal visit details. |
| Conditional | No eggs remaining means clutch 0, not an invented earlier clutch. Individual birds receive their own capture/resighting events. |
| Photographs | Actual nest sequence on its visit; chick hiding/handling media remain separate. |
| Do not enter | Negative ID for this established nest origin; imaginary eggs/egg rows; F/H nest events for an unknown-origin brood found outside the nest. |
| Likely To-Do follow-up | Banding, H photographs and final notA. The normal zero-egg F safeguard is retained; explain a correct rare observation and use the documented override if needed. |

</details>

<details>
<summary><strong>Previously known nest</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | New visit to existing ID: `NESTS`, one new row. |
| Required | Existing `nest_id`, today's visit details/state and actual findings. |
| Conditional | Egg/chick counts, hatch/fate evidence; final closure conditions in Section 9. |
| Photographs | Today's sequence if taken. Direct nest GPS fields stay blank after the opening visit. |
| Do not enter | Today's findings over an earlier visit; a second F discovery for the same ID. |
| Likely To-Do follow-up | Processing, clutch/hatch review or closure. |

</details>

<details>
<summary><strong>Eggs measured, floated or photographed</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | Nest visit: one NESTS row. Measurements: one EGGS row per egg measured. Photography alone adds no EGGS rows. |
| Required | EGGS: `species`, `observer`, `date`, `time_visit`, positive `nest_id`, unique `egg_id`. Record actual float readings if obtained. |
| Conditional | `float_surface` blank submerged, 0–3 at surface; timing and nest-visit match in Section 4. |
| Photographs | NESTS photo flags, `cam_id`, `photo_start`, `photo_end`. |
| Do not enter | Negative IDs, `site`/camera/drive fields in EGGS, or float readings for starred/pipping eggs. |
| Likely To-Do follow-up | Nest processing, hatch forecast/checks; review missing measurement/visit link. |

</details>

<details>
<summary><strong>Adult or chick only seen</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | Unhandled bird: `RESIGHTINGS`, one row per individual. |
| Required | Resighting details; direct GPS where required. |
| Conditional | Nest/brood link, companion-parent check for age C, supported partial marks. |
| Photographs | class P or V/H require camera and complete range; H has additional ring/GPS rules. |
| Do not enter | Capture, samples or device action for a bird not handled. |
| Likely To-Do follow-up | Parent association, brood work or tagged-bird observation. |

</details>

<details>
<summary><strong>Unbanded bird, including a tending parent</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | Bird seen unbanded: `RESIGHTINGS`, one row per individual. |
| Required | Resighting details; at minimum `LL = X`, `LR = X`; actual age/sex/behaviour and location. |
| Conditional | Parent BC, FC or AC row accompanies chick sightings; explicit ID if needed. |
| Photographs | Actual class-dependent fields. |
| Do not enter | Omit the parent merely because unbanded; use X for unreadable bands; treat X-X as a globally unique bird. |
| Likely To-Do follow-up | Parent identity/banding or family-link review. |

</details>

<details>
<summary><strong>Brood linked to a positive nest</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `CAPTURES` for handled birds, `RESIGHTINGS` for sightings; one per individual event. |
| Required | Event details, shared family date, site and gps_id/point; known positive ID where required. |
| Conditional | Eligible later resightings may omit ID only under Section 5; positive parent-with-chicks history must support H/notA. |
| Photographs | Handling on CAPTURES; hiding on separate H rows. |
| Do not enter | Several chicks in one row, new negative ID merely because the brood moved, continued H nest visits after final hatch. |
| Likely To-Do follow-up | Banding, per-chick hiding photographs, flagging and positive-nest closure. |

</details>

<details>
<summary><strong>Mobile brood whose nest was never found</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `CAPTURES` / `RESIGHTINGS` only, one per individual event. |
| Required | Assigned negative `nest_id` where required; both GPS fields and shared family date/site. |
| Conditional | Later blank-ID family resightings only after the confirmed both-parent link in Section 5; no absent-parent row is invented. First chick captures retain the explicit ID. |
| Photographs | Separate tent/H events; H ring and camera/range mandatory. |
| Do not enter | NESTS or EGGS row, dropped minus sign, or a placeholder instead of the brood ID. |
| Likely To-Do follow-up | Parent association, banding, photographs and later flagging; photo display uses discovery days 1–6. |

</details>

<details>
<summary><strong>Adult or chick captured/recaptured</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `CAPTURES`, one new row per handling event. |
| Required | Capture details, metal `ring`, appropriate age/status measurements and before/after marks. |
| Conditional | Age-C status R or C direct GPS always; F first chick requires real positive/negative ID. Adult `caught_with` chicks requires direct GPS. Devices/samples as taken. |
| Photographs | Handling flags and actual camera/range; separate H rows for hiding photographs. |
| Do not enter | Question marks in any leg field; overwrite a prior capture; fictitious duplicate sighting. |
| Likely To-Do follow-up | Banding, parent/device work, per-chick photographs or flagging. |

</details>

<details>
<summary><strong>Chicks captured while parent(s) only resighted</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | One CAPTURES row per handled chick; one RESIGHTINGS row per observed parent. |
| Required | Save chick captures first. Match `date`, `site`, `gps_id`, `gps_point` across tables; actual parent BC, FC or AC. |
| Conditional | Normal nest/brood and capture fields; if H photographs also taken, separate H rows. |
| Photographs | Tent sequence on capture, hiding sequence on H. |
| Do not enter | Additional chick sightings merely to satisfy the parent-side check; fabricated parent. |
| Likely To-Do follow-up | Family association, chick photographs or flagging. |

</details>

<details>
<summary><strong>Chicks seen without a parent</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `RESIGHTINGS`, one row per chick actually seen. |
| Required | Resighting details, actual waypoint, specific no-parent explanation. |
| Conditional | Known ID; justified missing-parent override if blocked. Unknown ID needs separate explanation. |
| Photographs | H ring/GPS/photo requirements unchanged. |
| Do not enter | A fictitious tending parent or a claimed inferred family link without evidence. |
| Likely To-Do follow-up | Family-link review and truthful exceptional-entry handover. |

</details>

<details>
<summary><strong>Chick tent photograph</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | On the existing handling `CAPTURES` row; no second capture row. |
| Required | `chick_tent_photo = 1`, `cam_id`, `photo_start`, `photo_end`, normal capture details. |
| Conditional | Other handling measurements/samples as applicable. |
| Photographs | Tent sequence only. |
| Do not enter | Same sequence as a separate H hiding photograph. |
| Likely To-Do follow-up | Hiding photographs still needed if not done. |

</details>

<details>
<summary><strong>Chick hiding-spot photograph</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | Separate `RESIGHTINGS` H, one per photographed chick. |
| Required | Age C, sex U, explicit valid positive/negative `nest_id`, individual `ring`, observed marks, both GPS fields, complete camera/range and encounter details. |
| Conditional | Actual parent resighting in same submission, except justified no-parent case. Capture ring saved first. No blank-ID exception for a new H row. |
| Photographs | Hiding sequence; shared H range only under Section 7's same-session rule. |
| Do not enter | Hiding evidence only in `chick_hide_photo`; combined handling/H record; duplicate ring as another completed chick. |
| Likely To-Do follow-up | Broods to photograph: individual progress, biological deadline before seven days, separate display clock. |

</details>

<details>
<summary><strong>Regular versus specialised resighting</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `RESIGHTINGS`, one per bird per actual event. Choose R/class P or V/C/H using Section 2. |
| Required | Resighting details; behaviour except optional ordinary-R chick/H cases. |
| Conditional | class P or V/H camera/range. Age-C family and GPS checks remain applicable for every class. |
| Photographs | H specifically for chick hiding place, not generic P. |
| Do not enter | Obsolete class values, capture row for a failed attempt, or R plus media to avoid class P or V/H requirements. |
| Likely To-Do follow-up | Depends on actual parent/brood/device evidence, not the letter alone. |

</details>

<details>
<summary><strong>Adult geolocator deployment, retrieval, retention or replacement</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `CAPTURES`, one per handled adult. |
| Required | Normal capture details and Section 8's exact O/D/R/S/N before/after cells. |
| Conditional | Device history, known spacer colours, `wt_w_tag` and action-specific IDs. Eligibility/timing assessed before capture. |
| Photographs | Actual handling sequence if taken. |
| Do not enter | Device action on an unhandled sighting; O on a chick; T? on a capture; same-visit mate capture solely to complete a pair. |
| Likely To-Do follow-up | Luke Eberhart-Hertel's wave/stock directions, mate eligibility and future retrieval. |

</details>

<details>
<summary><strong>Tagged adult only observed</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `RESIGHTINGS`, one per observed adult. |
| Required | Resighting details and marks actually seen. |
| Conditional | UR TY, or T? if spacer unreadable; behaviour, family/location and class P or V fields as applicable. |
| Photographs | Class P or V if a corresponding session occurred. |
| Do not enter | Bare T; guessed device ID; retrieval inferred from a tag not being seen. |
| Likely To-Do follow-up | Tagged-bird history, status/identity review where uncertain. |

</details>

<details>
<summary><strong>Hatch observed</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | One `NESTS` visit, plus individual bird events as encountered. |
| Required | H state, true remaining-egg/chick counts and visit details. |
| Conditional | `hatch_state` for remaining eggs; one final notA later. |
| Photographs | Actual relevant nest sequence; chick media remain with their own events. |
| Do not enter | Chicks as eggs; later H nest visits after the final zero-egg hatch visit. |
| Likely To-Do follow-up | Banding, H photographs and closure while brood work continues. |

</details>

<details>
<summary><strong>Failure or final closure</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | `NESTS`, one per actual positive-nest visit. |
| Required | Existing ID, date/time, evidence and appropriate possible/confirmed state or final notA. |
| Conditional | Further pP, P or D fate-check visits remain allowed until final notA; counts and D → notA / post-H closure conditions in Section 9. |
| Photographs | Evidence sequence when taken. |
| Do not enter | Certainty from an empty nest alone; negative-brood closure; reopen notA for another attempt. |
| Likely To-Do follow-up | Agreed fate review/closure; surviving brood follow-up remains separate. |

</details>

<details>
<summary><strong>GPS, media and end-of-day handover</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | GPS upload supplies GPS_POINTS/GPS_TRACKS; biological records retain their individual events. |
| Required | Correct gps_id/point values, actual field dates and media identifiers; save/review records before handing over. |
| Conditional | Ask designated operator to refresh published To-Do results; review overrides and unresolved links. |
| Photographs | Copy originals, verify backups/ranges; storage location in media register. |
| Do not enter | Manually invent GPS rows/coordinates, duplicate submitted events, or use `nov`/`pk` as a repair. |
| Likely To-Do follow-up | Updated dated PDF and clear list of unfinished fieldwork. |

</details>

<details>
<summary><strong>Former parents seen without chicks, or at another nest</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | RESIGHTINGS: one row per adult actually observed on each genuine occasion. Another nest also needs its real NESTS visits, not a brood-loss NESTS row. |
| Required | Normal adult observer/date/site/age/sex, observed leg marks, `rclass` and actual `behav`. Collect the encounter gps_id/point. For Route 1 in Section 9, enter the reliable old brood ID explicitly. |
| Conditional | At another nest, enter that nest's own positive ID and actual association evidence. Record all chicks actually encountered; use normal family/submission rules when BC/FC/AC applies. Explain OB and uncertain fate in comments. |
| Photographs | Ordinary R needs no invented photo fields. Use P or V with their required media when such a session occurred. H remains specific to chick hiding photographs. |
| Do not enter | A fabricated mate/chick, false absence count, made-up IN/AC, duplicate sighting, shifted date or dead-recovery CAPTURES row to force presumed loss. No NESTS rows for a negative brood. |
| Likely To-Do follow-up | Parent association may resolve independently of brood fate. Qualifying renesting, repeated non-brood evidence or the fixed 21–35-day no-encounter rule may suppress brood and associated parent work. Qualifying live evidence can prevent presumed loss or reopen work. Section 9. |

</details>

<details>
<summary><strong>Dead recovery or origin-linked juvenile</strong></summary>

| Required database events | Entry |
|---|---|
| Circumstance / table / rows | CAPTURES: one row per bird recovered dead or genuinely handled. RESIGHTINGS: one row per juvenile only seen. Never fabricate handling or a sighting. |
| Required | Normal event fields from Section 6. For D: actual age, ring, all four recovered _in positions, blank release leg fields and blank released time. A juvenile's recovered marks need not include a flag. |
| Conditional | Known origin/brood ID and actual gps_id/point under the location rules. For automatic J resolution, the original brood must be reliably identified from the record/history, without conflicting identities. Preserve any later social brood link rather than rewriting earlier records. |
| Photographs | Actual photographs only, with their own camera/range metadata when entered. Do not invent photographs or live-release flags. |
| Do not enter | Question marks in capture leg fields, invented release marks/time, a D row for presumed loss, or J merely to clear a To-Do list. |
| Likely To-Do follow-up | Age-C D alone does not close the brood. One reliably origin-linked J event, including D, resolves chick-stage work; independently required positive notA work remains. |

</details>

</details>

<a id="section-14"></a>

<details>
<summary><strong>14. Worked examples</strong></summary>

## 14. Worked examples

### A new two-egg nest and its incubating parent

You find B0203, collect point 214 on Garmin 4, float both eggs and identify
the incubating parent.

| Record | Table/rows | Main entries |
|---|---|---|
| Discovery | NESTS, 1 | Positive ID B0203; F; actual visit details; clutch 2; GPS 4 / 214. |
| Egg measurements | EGGS, 2 | B0203, egg 1 and 2, actual measurer/times and each float reading. |
| Clutch photographs | On the NESTS row | Applicable flags, camera and range. |
| Parent incubating | RESIGHTINGS, 1 | A, R, IN, actual marks/sex and B0203. |

If B0203 began as a known scrape, keep its ID; the earlier S row already holds
the nest gps_id/point, so today's F leaves those GPS fields blank.

### One parent and two banded chicks

On 25 October, an adult reliably linked to B0203 is alert with two chicks.
The encounter waypoint is GPS 4 / point 216.

| Bird | Table | Age / class / behaviour | `nest_id` | GPS |
|---|---|---|---|---|
| Parent | RESIGHTINGS | A / R / AC | B0203 | 4 / 216 |
| Chick 1 | RESIGHTINGS | C / R / blank if no behaviour recorded | B0203, or eligible blank | 4 / 216 |
| Chick 2 | RESIGHTINGS | C / R / blank if no behaviour recorded | B0203, or eligible blank | 4 / 216 |

Submit the three rows together, using the same date/site and normal required
details. Ordinary chick rings may be blank. If both parents are seen and both
link to B0203, enter both: there is still only one unique family ID.

### Chicks captured, parent(s) resighted

Two chicks are captured while both parents tend nearby. Save the two chick
CAPTURES rows first, then enter the two genuine parent RESIGHTINGS rows. All
four records use the same date, site and gps_id/point.

The saved captures satisfy the parents' accompanying-chick check. No chick
RESIGHTINGS rows are needed merely because the chicks were handled. If you
also take hiding photographs, submit the actual parent observations and H
rows together after saving the captures; there is no need for a separate
parent-only submission first.

| Bird / event | Table / rows | Main entries |
|---|---|---|
| Chick 1 handled | CAPTURES, 1 | Age C; its own ring, actual capture status, marks and required measurements; nest/brood link under Section 6. Save before the parent resightings. |
| Chick 2 handled | CAPTURES, 1 | Age C; its own ring and capture details, as for Chick 1. A sibling's record does not cover this chick. |
| Parent 1 observed tending the chicks | RESIGHTINGS, 1 | Age A; ordinary `rclass = R`; actual BC, FC or AC behaviour, identity and nest/brood link under Section 5. |
| Parent 2 observed tending the chicks | RESIGHTINGS, 1 | Age A; its own identity and observed behaviour, as for Parent 1. Neither parent gets a CAPTURES row because neither was handled. |
| Chick 1 photographed hiding, if taken | RESIGHTINGS, 1 additional H row | Age C; `rclass = H`; Chick 1's ring; nest/brood link under Section 7; both GPS fields and this photograph's own `cam_id`, `photo_start` and `photo_end`. Submit with the actual parent observations. |
| Chick 2 photographed hiding, if taken | RESIGHTINGS, 1 additional H row | Age C; `rclass = H`; Chick 2's ring and its own hiding-photo details, as for Chick 1. Submit in the same family resighting submission. |

Use the same date, site and gps_id/point on every row in this encounter, and
complete the normal required fields for each event. Without hiding photographs,
there are **four rows**: two captures and two parent resightings. If both chicks
are photographed hiding, there are **six rows**: the same four plus two H rows.
Any tent photograph stays on the relevant chick's CAPTURES row; it does not
add another row or replace a hiding-photo record.

### A negative brood, first recorded and later recognised

The nest of brood -C0402 was never found. At its initial capture encounter,
save each handled chick under -C0402, with its individual ring and shared
family waypoint. Record the observed parents separately. Do not add NESTS or
EGGS rows.

Later, the confirmed parent records have resolved both social parents
unambiguously for -C0402. You see only one of them with two chicks at a new
waypoint. The approved blank-ID resighting route can apply, but only because of the preceeding encounter when the -C0402 nest_id was created:

| Row | Required current evidence | `nest_id` |
|---|---|---|
| Observed parent | A; actual BC, FC or AC; reliable selected identity | May be blank under the confirmed negative-family exception. |
| Chick 1 | C; actual sighting; same date, site and gps_id/point as parent | May be blank under the same exception. |
| Chick 2 | C; actual sighting; same date, site and gps_id/point as parent | May be blank under the same exception. |
| Absent second parent | No observation | No row. Its already resolved history is not a new sighting. |

Enter -C0402 directly if known. The exception does not apply to a new family's
first chick capture, an unresolved pair or a partly read parent that cannot
be identified reliably.

### When an omitted chick ID cannot be inferred

| Difference | Result / correct response |
|---|---|
| Parent only AT, not observed with chicks | AT does not supply BC, FC or AC evidence. Keep the true behaviour. |
| Parent date 24 October, chicks 25 October | Different encounters; do not alter dates to match. |
| Parent GPS 4 / 216, chick GPS 5 / 216 | Different Garmin units. Check the actual gps_id/point. |
| Parent IDs B0203 and B0204 at one point | Conflicting links. Resolve before relying on a blank ID. |
| Negative-brood pair has one unresolved social parent | Both-parent historical condition not met; enter the known negative ID or refer uncertainty. |
| Parent mark contains only unreadable evidence | The question mark is not a wildcard identity. Obtain a reliable link; do not guess the missing colour. |
| Parent already saved in an earlier resighting submission | A chick resighting submission still needs its actual companion-parent row. Do not invent a second observation; avoid splitting one family submission. |
| Chick resighting, class P or V with no camera/range | Family inference does not supply missing media. |
| H chick without a ring | H requires its individual ring, regardless of how the brood is linked. |

### What to enter for an unreadable mark

| Observation | Entry |
|---|---|
| Left tarsus: red over an unread band | `LL = R?` in RESIGHTINGS. |
| Left upper leg: unread band over red | `UL = ?R` in RESIGHTINGS. |
| Right lower leg: bands seen, no colour confidently read | `LR = ?` in RESIGHTINGS. |
| Right upper tag present, spacer colour unread | `UR = T?` in RESIGHTINGS, not T. |
| Same bird later handled | Read the actual marks and enter them in CAPTURES; no ? in release or incoming leg fields. |

Keep useful uncertainty in comments. Do not convert any of these readings to
X, which would describe an empty position.

### Three captured chicks, two hiding photographs

Three distinct rings are recorded in CAPTURES. Later, two chicks are photographed
hiding. Each receives an H row with its own ring, direct GPS and hiding range,
alongside the observed parent row(s).

The updated **Broods to photograph** To-Do progress remains two of three while
the To-Do display window is open. Entering one chick twice does not complete the third.
For a negative brood discovered six days ago, the list can expire tomorrow
even though a photograph is missing—and the chicks may already be older than
six days. Report the missing work; do not infer completion from expiry.

### Finding the family ID before entering a hiding photograph

An earlier capture linked a chick ring to its social family. You now photograph
that chick hiding and resight one known parent at the same waypoint; its mate
is absent. Enter the actual parent behaviour and the shared date, site and gps_id/point,
with the chick's ring and full H photo fields. Check the ring history and
Parent–Nest summary, then enter the established positive/negative ID explicitly
on the H row. No absent mate row is needed. If the family cannot be identified
reliably, keep the field notes and photographs and ask Luke Eberhart-Hertel to resolve it;
do not submit a new H row with a blank ID. Check updated per-ring To-Do progress
separately after the snapshot refresh.

### Unbanded parent versus no parent seen

An unbanded parent tending two banded chicks gets its own age-A RESIGHTINGS
row, `LL = X`, `LR = X`, observed BC, FC or AC, required ID and shared waypoint.
The two chicks each get a row as well.

If no adult was seen, enter only the chicks, waypoint and a specific no-parent
comment. Use Section 12's justified exception if blocked; do not add an X-X
adult simply to satisfy the check.

### An older chick receives its flag

A chick is recaptured under the current flagging plan and passes the bander's
condition/measurement assessment. Its old combination is recorded in the four
incoming fields; its actual new flag combination goes in the release fields.
Use `capture_status = C`, not R, and record both GPS fields even with a known
positive nest. Tarsus, culmen and weight remain required. No device action is
entered for the chick.

### Replacing a geolocator

An eligible adult arrives with GEO-017 and leaves with GEO-044. On its single
CAPTURES row enter `tag_action = N`, `tag_type = GEO`, `tag_id_in = GEO-017`,
`tag_id = GEO-044`, actual before/after spacer marks and `wt_w_tag` describing
the recorded mass. Complete its ring and normal capture fields.

A later resighting describes what was visible then. It is not another device
replacement, and a tag not seen later is not automatically a retrieval.

### Final hatch and closure

A visit establishes no eggs remaining and two chicks present: record the final
H nest visit with clutch 0 and brood 2. Individual captures/resightings record
the chicks separately. A later single notA closure can retain brood 2 with
zero clutch and blank hatch state. Continue brood encounters in the bird
tables under the same positive ID, using their new family waypoints.

### First discovery immediately after hatch, inside the nest

At 10:00 you find an obvious nest containing two newly hatched chicks and no
remaining eggs. Assign its positive ID and collect the nest waypoint.

| NESTS row | `time_visit` | `nest_state` | `clutch_size` / `brood_size` | GPS |
|---|---|---|---|---|
| Discovery | 10:00 | F | 0 / 2 | Both fields for the new nest. |
| Immediate hatch record | 10:01 | H | 0 / 2 | Blank; discovery point already recorded. |

Both rows describe the same discovery encounter. Explain that the chicks were
found inside the nest immediately after hatch. No egg measurements or earlier
egg visit are invented. The first-F zero-clutch check should flag this rare
entry. Recheck it, comment on the correct inside-nest discovery and use the
documented override if still blocked. Keep the true counts; no validator
change is needed.

If those chicks were found outside a nest and their origin was unknown, use
a negative brood ID and no NESTS events. Their young appearance alone is not
enough to establish a positive nest origin.

### A possible loss followed by further fate checks

You record pP with the evidence for possible predation. A later check confirms
P; another visit may clarify remaining evidence before the marks are removed
and the final notA is entered. Each actual check gets a new NESTS row. The
same principle applies to D: confirmed desertion does not itself close the
record. Do not invent extra visits, and do not treat disappearance from the
To-Do PDF as final closure.

### Confirming a parent is not the same as losing a brood

An identified male at B0210 is seen with AT on three genuine occasions.
Those three eligible nest-linked resightings can establish its association.
Alternatively, one clear IN observation at B0210 can establish the link.
The female still needs her own evidence.

| Records entered | What can change after refresh | What cannot be concluded |
|---|---|---|
| Three matching male AT resightings, or one male IN resighting | The male's association-resighting need may be resolved. | The female's identity is not established by this; the brood is not presumed dead merely because that To-Do row disappears. |
| Two plausible males each with equally strong association evidence | The association remains ambiguous. | Do not select the preferred mark or discard one truthful observation. |

### Both former parents repeatedly seen without brood-tending

B0211 has hatch evidence on 1 October. Both parent identities are already
unambiguously established. The following resightings are explicitly linked
to B0211 and have their actual encounter waypoints.

| Date | Bird / rows in RESIGHTINGS | `behav` | Contribution |
|---|---|---|---|
| 12 October | Male, 1 | FA | Male's first qualifying date and stronger non-brood behaviour. |
| 15 October | Female, 1 | AT | Female's first qualifying date and stronger non-brood behaviour. |
| 18 October | Male, 1 | BW | Male's second qualifying date; BW can supplement FA. |
| 20 October | Female, 1 | RS | Female's second qualifying date. |

With a 22 October reference date, the brood has reached the 21-day gate.
If there is no conflicting brood-tending chronology or later reactivation
evidence, these observations satisfy Route 1. The candidate loss date is
20 October, the later of the parents' last qualifying dates. Before the
21-day gate, the same records do not yet satisfy this route.

If both parents were seen repeatedly on 18 October only, that would still be
one date each, not two. If the male had BW on both his dates and no stronger
listed non-brood behaviour, he would not meet the requirement. If either
parent was recorded with BC on 20 October, the chronology condition would
fail; record the actual chick encounter rather than omitting it.

### A former parent is incubating another nest

B0212 has hatch evidence on 1 October and a reliably established female.
On 14 October a different nest, B0213, is discovered with eggs, and that
female is observed incubating it.

| Encounter component | Expected event | Key entries |
|---|---|---|
| New nest discovery | NESTS, 1 | B0213; F, actual date/time/counts and discovery gps_id/point. |
| Female incubating | RESIGHTINGS, 1 | Age A, actual marks/sex, `behav = IN`, `nest_id = B0213`; normal resighting details. |
| Old brood | No invented event | Do not add a B0212 nest failure, dead chick or absent mate observation. |

Once the same female is selected unambiguously for both attempts, the
later-nest route presumes loss of B0212 without waiting 21 days, once the
required nest and identity evidence exists. The old brood's To-Do work is
suppressed after refresh, but its required notA visit remains.

If a live chick from B0212 is genuinely encountered on 14 October itself or
later, record it and its family truthfully. A direct link or an approved
unambiguous blank-ID link prevents presumed loss at the next refresh. Keep
the shared date, site and gps_id/point. A nearby nest with unrelated parents
would not trigger the renesting rule.

### A former parent is scraping at a new attempt

The same principle applies if the new B0213 attempt is still a scrape.

| Encounter component | Expected event | Key entries |
|---|---|---|
| New stationary scrape | NESTS, 1 | B0213, S, actual date/time, zero eggs and the discovery gps_id/point. No invented EGGS rows. |
| Former parent genuinely scraping | RESIGHTINGS, 1 | Age A, its actual marks/sex, SC and B0213, with the encounter details. |
| Old brood | No invented event | No fabricated dead chick, failure visit or absent mate. |

One eligible SC observation can establish that parent's association. Once
the old and new associations meet Section 9's requirements, the scrape can
trigger presumed loss; there is no need to wait for the first egg.

### A dead chick is not a dead brood

One banded chick from B0214 is found dead. A sibling is still alive nearby.

| Bird | Expected event | Key entries |
|---|---|---|
| Recovered dead chick | CAPTURES, 1 | Age C, status D, its ring and all four actual recovered marks in the _in fields; release fields/time blank. Record the actual waypoint and known brood link. |
| Living sibling observed, not handled | RESIGHTINGS, 1 | Age C, observed marks, actual family gps_id/point and the normal linkage details. |
| Parent(s) actually observed | RESIGHTINGS, one each | Actual BC, FC or AC when tending the living chick, with the same date/site/gps_id/point. No row for an absent parent. |

The dead recovery does not prove survival and does not establish loss of the
whole brood. The living family evidence keeps the brood work open under the
usual timing/completion rules. Do not assign age J to clear the list.

### A brood disappears from the work plan, then is encountered again

A positive brood has recorded hatch evidence on 1 October. Its observation
window is 22 October through 5 November: ages 21–35 inclusive. There are no
qualifying live encounters during that window.

| Reference date / actual encounter | Expected work-plan result after refresh |
|---|---|
| 5 November, day 35 | The window is not yet over. This absence rule does not suppress the brood. Other established completion or closure rules may still apply. |
| 6 November, day 36, still no live encounter | Presumed dead under Route 3. Remove brood work, associated parent tasks and the brood's summary entry. An independently due positive-nest notA visit remains. |
| A live chick is genuinely seen on 6 November | Enter the chick and any parent(s) actually observed, using the normal family-link and gps_id/point rules. After refresh, the presumed-dead result no longer applies; outstanding flagging or parent work can return. |
| Instead, a genuine 26 October encounter is uploaded late | Keep 26 October as the field date: it was day 25. Once included in a refresh, it prevents Route 3 because it falls within the observation window. |

For a negative brood first found on 1 October with no reliable hatch date,
the same dates apply using discovery as the operational age proxy. Do not
invent a hatch visit. Neither disappearance nor reappearance justifies adding
fabricated field events or erasing earlier observations.

### One juvenile resolves the original brood, even after brood mixing

CP99001 was first banded as a chick from B0214. Later it joined B0215 and was
recaptured there, when its ring was recorded together with flag FWAB. On a
later field date, FWAB is genuinely observed as age J.

| Encounter | Expected event | What the record establishes |
|---|---|---|
| First chick marking at B0214 | CAPTURES, 1 | Age C, F, CP99001, B0214 and the actual initial marks. |
| Later recapture at B0215 | CAPTURES, 1 | Actual age, status C if the combination changed, CP99001, incoming/release marks including FWAB, and B0215. This records the later social association without erasing the original origin. |
| FWAB subsequently seen as a juvenile | RESIGHTINGS, 1 | Age J, FWAB in UL, other marks as observed, and normal date/site/observer/location details. The trace uses the earlier flag-to-ring capture and original chick record. |

The original B0214 brood resolves at the juvenile stage. This does not resolve
B0215's other chicks merely because CP99001 later joined them. The flag alone
does not establish age J; the observer must actually assess the bird as J.

If CP99001 is instead recovered dead and confirmed as J, enter one CAPTURES
row with D, its recovered marks in the incoming fields and no release marks
or release time. The reliable origin-linked J record still resolves B0214's
chick-stage work. Preserve its death and any known sibling deaths: this is
developmental resolution, not a statement that all siblings survived.

</details>

<a id="section-15"></a>

<details>
<summary><strong>15. Revision record and source notes</strong></summary>

## 15. Revision record and source notes

### Revision record

| Version | Change |
|---|---|
| v2.2 working manual | Separate Cass River/BADO Word/PDF draft; original reference retained. |
| v2.2 Markdown preview | Contents links and collapsible sections for local review. |
| v2.3, 26 October 2026 | Earlier full prose redraft, retained under the v2.2 preview filename. |
| v2.4 review draft, 26 October 2026 | All sections reviewed/redrafted; corrected split-table family entry, capture GPS/status table, blank negative-family IDs, uncertainty notation, H progress/two clocks, egg timing, adult device cells and pre-capture gates. Added consolidated scenarios/examples/checklists and explicit source-state notes. |
| v2.4.1, 26 October 2026 | Luke Eberhart-Hertel confirmed pP, P or D fate checks remain open until notA, and the very rare positive-nest discovery with newly hatched chicks inside uses F then H at least one minute later. Keys, procedures, scenarios, examples and checklists updated; remaining validator/task alignment explicitly distinguished. |
| v2.4.2, 26 October 2026 | Clarified that the normal first-F zero-clutch rejection is intentional. The correct rare observation needs an explanatory comment and documented override if blocked, not a programmed exception. Removed the mistaken validator-gap claim from procedures, scenarios, examples and source notes. |
| v2.4.3, 26 October 2026 | Preserved Luke Eberhart-Hertel's direct edits; replaced vague GPS wording with gps_id/point, standardised field house wording and expanded capture/resighting shortcuts. Removed the retired no-nest entry convention throughout; unrelated adult captures use blank nest_id and gps_id/point. Added the known-ring exception for uncertain parent marks and the same-encounter conflicting-ID rule. Full software integration verification remains pending. |
| v2.4.4, 26 October 2026 | Updated the reviewed protocol metadata to v1.3.14 and explained that one eligible nest-linked SC observation can confirm that parent's association, without requiring chick records or confirming the mate. Distinguished completed bounded checks from the pending full 27 October rehearsal and unverified live installation. |
| v2.4.5, 26 October 2026 | Added a per-bird event table to the split-table capture/resighting example, with submission order, optional separate hiding-photo rows and four-versus-six row totals. No protocol change. |
| v2.4.6, 27 October 2026 | Added the authorship/AI disclosure and Luke Eberhart-Hertel's contact address before Contents. Added a local app reading page with collapsible sections, contents navigation and search; no field-method or database-rule change. |
| v2.4.7, 27 October 2026 | Expanded parent-association behaviour codes, evidence ranking and MM follow-up. Added the two presumed-brood-loss routes, timing/identity/behaviour safeguards, later-nest evidence and reactivation limits, field decision key, event table, worked examples and review checklist. Updated the bounded local rehearsal status; no SQL, validator or live-state change. |
| v2.4.8, 27 October 2026 | Aligned the manual with Luke Eberhart-Hertel's approved automatic renesting-loss rule, including associated scrapes; same-day and unambiguous inferred live-evidence safeguards; separate whole-brood juvenile-stage resolution, including confirmed J dead recoveries; and truthful chick/juvenile D entries. Added decision-key steps, supporting tables and worked examples. Updated source-state notes to local protocol v1.3.17; live installation remains unverified. |
| v2.4.9, 28 October 2026 | New H records require an explicit nest/brood ID; older blank-H linkage is compatibility only. Added final-egg timing, two-egg confirmation/no-float proxy/third-egg reset, independent 36-hour gate, latest-encounter flagging counts, later ring-linked captures and GEO pair-completion guidance. Updated protocol/source status; final combined SQL/PDF rehearsal and live deployment remain separate checks. |
| v2.4.10, 29 October 2026 | Added the fixed inclusive age-21-to-35 live-encounter window, first suppression on day 36, negative-brood age proxy and later-live reactivation. Explained associated parent-task/summary suppression, late-upload correction and independent notA/juvenile resolution; added a dated worked example. |

This app publication copy is separate from Luke Eberhart-Hertel's editable private review
draft and the retained Word/PDF references; those files have not been
overwritten. Section numbers and contents links are retained for navigation.

### Source basis and deployment boundary

Luke Eberhart-Hertel's latest explicit decisions govern methodology. Field names and available
values were checked against current SQL and DataEntry forms; the recent
approved corrections were checked against the reviewed inspectors, local
protocol mirror, specialist handoffs and mock-test evidence. Older historical
wording does not override them.

| Source/state | Position at this revision |
|---|---|
| Remote `main` | Refreshed and inspected at `cd8ef26`; its tracked file tree matches local HEAD `72889c6`. |
| Local approved correction work | Uncommitted inspector, derived SQL and documentation changes. The install/refresh source and PDF helpers are frozen for isolated verification; not represented here as merged or deployed. |
| Reviewed local protocol mirror | Local v1.3.19, including mandatory explicit IDs for new H rows, family/uncertainty and SC corrections, and truthful chick/juvenile dead-recovery rules. Focused family and mark-history checks passed on invented data. This does not establish live installation or external-YAML synchronisation. |
| AGENTS protocol header | Still records the earlier v1.3.14 mirror. This metadata has not been silently updated; Luke Eberhart-Hertel's subsequent explicit decisions and the inspected reviewed mirror govern the new rules. |
| External canonical validator YAML | Last separately inspected at v1.3.5, generated 24 October 2026; no newer inspection or synchronisation is claimed by this manual revision. |
| Live database, inspectors and Shiny process | Not inspected; installation of the recent corrections is unverified. |

Some older protocol/handoff lists still mention EGGS media columns absent from
current SQL, retired no-nest instructions, older timing descriptions or superseded family
rules. This draft uses the current table definitions and Luke Eberhart-Hertel's explicit
decisions instead. It does not amend those source documents or implementation.

Luke Eberhart-Hertel resolved both field-method questions on 26 October: pP, P or D visits remain
open to further fate checks until final notA, and newly hatched chicks still
inside an obvious nest establish a positive origin with F followed immediately
by H at least one minute later. Chicks found outside a nest with no known
origin use the negative-brood route, without NESTS events. Banded Dotterels leave
the nest shortly after hatch, so the inside-nest exception is very rare.

The first-F zero-clutch rejection is an intentional safeguard, not an
implementation gap. Luke Eberhart-Hertel confirmed that this extremely rare, correct
observation should be handled through an explanatory comment and the
documented override if blocked; the validator must not be programmed to
accept it automatically. Preserve truthful counts and the F → H sequence.

The earlier isolated rehearsal used MariaDB 11.8.9 with the selected production
collation and case-sensitivity settings, invented records only, and exact
frozen source versions. Installation, refresh and the corrected family/identity
controls have been exercised. Snapshot upgrade, repeat-refresh and reference-date
checks passed. The normal four-page To-Do PDF rendered successfully, including
empty map plots; all four pages were inspected. The tested record set was
invented and deliberately contained many edge cases, not current field records.
This is not a deployment audit, an Adminer browser test or proof of performance
on production-sized data. Release, external-YAML synchronisation and live
verification remain separate steps.

Those earlier checks do not establish successful execution or performance of
the latest combined v2.4.9 SQL/PDF corrections. Their production-sized local
replay is still a separate release requirement.

The parent-association explanation follows the reviewed matching and selected
association rules in `DATABASE/views.SQL`. Brood inference follows the closure
stage and task exclusions in `DATABASE/refresh_todo_list_snapshot.SQL`.
The reviewed rules require shared date/site/gps_id/point, reject conflicting
inferred family targets, retain the verified-ring exception for uncertain
parent marks, accept same-day or later qualifying live evidence and distinguish
age-C deaths from age-J developmental resolution. They do not rewrite raw rows.

One reported ordinary-family failure proved to be a missing conflict event
in the invented test fixture. The original one-ID fixture correctly resolved;
after adding the actual conflicting bird event, the same unchanged SQL rejected
the link. Both cases were retained as controls rather than prompting an
unnecessary production-source change. Detailed test histories are kept in the
local audit record, not in field examples.

The detailed source inventory, change coverage and verification record are
kept separately with this local authoring review. Examples contain no copied
field records or real coordinates. The historical manual supplies writing and
visual-style evidence, not current codes or biological authority.

### If the app and manual disagree

Keep the actual observation. Record the exact message and refer it to the
field lead. Use only the justified exception described in Section 12; do not
change marks, dates, counts or family identity to obtain a pass.

Approval of this Markdown wording is not approval to change schema, install
inspectors, deploy the app or publish the manual. Those remain separate steps.

</details>

<a id="appendix-a"></a>

<details>
<summary><strong>Appendix A. Controlled values</strong></summary>

## Appendix A. Controlled values

### Bird details and resighting classes

| Field | Values |
|---|---|
| `species` | BADO; WRYB when a Wrybill nest/observation is recorded. Other app codes are outside this procedure. |
| `site` | CR for Cass River; other dropdown codes serve broader project sites. |
| `age` | A adult; J juvenile; C chick. |
| `sex`, `field_sex` | M male; MU probably male; F female; FU probably female; U unknown. C/J use U. |
| `rclass` | R regular; P photography; V video; C failed capture; H chick hiding photograph. |

| `behav` | Meaning |
|---|---|
| IN / NM | Incubating / nest maintenance. |
| BC / FC / AC | Brooding chicks / foraging with chicks / alert with chick(s). |
| BW | Broken-wing display; can occur near eggs or chicks. |
| CO | Courtship. |
| SC | Scraping. One eligible nest-linked observation can confirm that parent's association; it does not require accompanying chick rows. |
| FA / FM / FF | Foraging alone / with presumed mate / in flock. |
| PR / RS / LF | Preening / roosting / loafing. |
| AT / FT | Alert / fighting. |
| OB | Other behaviour; explain in comments. |

Use commas between multiple applicable behaviour tokens. An ordinary-R chick
or an H chick may leave behaviour blank when none was recorded; other rows
retain their required behaviour. Do not substitute AT for AC or turn BW alone
into evidence that individual chicks were seen.

### Nest and egg values

| Field | Values |
|---|---|
| `nest_state` | S scrape; F discovery; I active/incubated; H chicks seen; pP possible predation; pD possible desertion; P confirmed predation; D confirmed desertion; notA final inactive closure; O other with comment. pP, P or D permit further fate checks until notA. Rare inside-nest hatch discovery uses F then H, not an invented egg visit. |
| `bird_inc` | M male; F female; MF/FM both; U unknown sex; E no bird seen. |
| `hatch_state` | Egg count plus N no sign, S star, C crack, CC multiple/large cracks; e.g. 2N1S. |
| `egg_id` | 1, 2, 3, 4 within the nest. |
| `float_location` | bottom, suspended, surface. |
| `float_angle`, `float_surface` | Whole degrees 0–90; surface height whole mm 0–3 only when at surface, otherwise blank. |

### Capture, sample and device values

| Field | Values |
|---|---|
| `capture_status` | F first marking; R unchanged recapture; C changed combination; D dead recovery. |
| `capture_method` | HA hand; TB clap-trap on brood; TN clap-trap on nest; SM stationary mistnet; MM mobile mistnet; O other, with comment. |
| `parents` | MF both sexes; F female; M male; U1 one unknown-sex parent; U2 two unknown-sex parents; O other with comment. |
| `caught_with` | M mate; M? probable mate; S same-sex conspecific; C chick/count such as 2C. Comma-separated when needed. |
| `blood_samp` | BQ Queens buffer; BF filter paper; BE EDTA; blank if none. |
| `breast_samp`, `primary_samp`, `brood_patch`, `wt_w_tag`, `eggs_handled`, applicable photo flags | 0 no / 1 yes, only where the age/event table says applicable. |
| `fat` | 1–8, using the trained scoring method. |
| `feather_wear` | 0 fresh; 1 slightly worn; 2 moderately worn; 3 very worn. |
| `moult_left`, `moult_right` | Team's stage/count notation, e.g. 0(10) for ten old primaries with no moult. Record right separately if asymmetric. |
| `tag_action` | Adult only: O none; D deployment; R retrieval; S same device retained; N new replacement. |
| `tag_type` | GEO geolocator; GPS/PTT supported for other device work. Chick/juvenile device fields stay blank. |

### Mark notation

| Code/entry | Meaning |
|---|---|
| B, G, R, O, W, L, Y | Blue, green, red, orange, white, lime, yellow. |
| M | Metal band; not its individual ring number. |
| X | Observed empty leg position; not unreadable. |
| X-X | Unbanded resighting shorthand: at minimum LL X and LR X. |
| F + colour + engraving | Complete flag in an upper-leg field, e.g. FWAB. |
| R? / ?R | Resighting only: known red above / below the unread band. Applies to UL, LL, UR, LR. |
| ? | Resighting only: marks seen on that segment, none confidently read. |
| TY / T? | Resighting UR: tag with yellow / unread spacer colour. Bare T invalid; captures require the actual known spacer. |

Do not place `?` anywhere in any incoming/release CAPTURES leg field. The
separate `caught_with = M?` convention is not a leg-mark entry.

### IDs and blanks

| Entry | Use |
|---|---|
| Positive ID | Known nest and its reliably linked brood. |
| Negative ID | Unknown-origin brood; keep minus sign; bird tables only. |
| Blank ID | An unrelated adult capture uses blank `nest_id` and gps_id/point. Family-event blanks must meet Sections 5 and 7; a first-capture chick still needs its actual positive or negative ID. |

</details>

<a id="appendix-b"></a>

<details>
<summary><strong>Appendix B. Field and submission checklists</strong></summary>

## Appendix B. Field and submission checklists

### Before leaving the field house

- [ ] Current To-Do PDF, reference date and team allocation checked.
- [ ] Garmin/camera charged, IDs and local NZ clocks checked.
- [ ] Notebook, rings/bands/flags, measurement and sample equipment ready.
- [ ] Capture and GEO timing/eligibility checked before planning a trap.

### Before leaving the encounter

- [ ] Each bird and egg measurement has its own notebook line.
- [ ] Actual nest/brood ID retained; negative minus sign intact.
- [ ] Garmin waypoint collected where needed; unit ID and point written down.
- [ ] Family date, site and gps_id/point shared across sightings and captures.
- [ ] Adult behaviour recorded as observed; AT distinguished from AC and IN/NM/SC linked to the actual nest concerned.
- [ ] All observed parents recorded; no absent parent invented.
- [ ] Unbanded tending parent recorded X-X; unreadable resighting marks use ?.
- [ ] Incoming/release capture marks read directly; no ? in any leg field.
- [ ] Each photo sequence identifies subject/ring, camera and full endpoints.
- [ ] Tent and hiding sequences distinct; sample/device labels checked.

### Before saving

- [ ] Field date/time and observer checked against prefilled defaults.
- [ ] GPS uploaded; both numbers valid and match the encounter.
- [ ] First NESTS visit has GPS; later visits do not repeat it.
- [ ] Rare chicks-inside-nest discovery uses positive ID, F then H at least one minute later, with true counts; outside unknown-origin brood has no NESTS rows.
- [ ] If the rare correct zero-egg F triggers validation, the observation was rechecked and explained in comments; any override is documented, not a request to weaken the inspector.
- [ ] Egg numbers/counts, float blanks versus zero and actual times checked.
- [ ] Genuine chick captures saved before parent-only/H entries that use them.
- [ ] Parent and chick resightings from one encounter submitted together.
- [ ] No extra chick sightings invented alongside captures.
- [ ] Any blank ordinary-family or later-capture ID satisfies its specific conditions; the exception does not extend to a new H row.
- [ ] Conflicting family identities referred, not silently selected.
- [ ] Missing-parent exception has a specific truthful comment, if needed.
- [ ] Age-C status R or C captures have both GPS fields even with a positive ID.
- [ ] Every new H row has an explicit valid positive/negative nest_id, ring, leg observations, gps_id/point and camera/range.
- [ ] Class P or V media fields complete; ordinary ring optionality not applied to H.
- [ ] Device action, actual old/new IDs and adult-only fields checked.
- [ ] Capture status agrees with before/after combination; samples use own codes.
- [ ] A D recovery has actual incoming marks and blank release fields/time, whether age C or J; no flag or sighting invented.
- [ ] Unrelated adult captures have blank `nest_id` and gps_id/point; no placeholder IDs entered. Negative IDs appear only in bird tables.
- [ ] Validation reviewed; `nov`/`pk` not edited; any justified override documented.

### Before finishing the day

- [ ] Saved rows match notebook counts; no duplicate submissions.
- [ ] Original media copied and backup checked without renaming files.
- [ ] Updated To-Do PDF checked, including reference date and refresh status.
- [ ] Missing parent/brood work checked for association resolution, completion, expiry, presumed loss or juvenile-stage resolution—not assumed to mean chicks died.
- [ ] Broods sought again during ages 21–35; any later live encounter or late-uploaded window encounter handed over for a new refresh, without changing its field date.
- [ ] A confirmed origin-linked J record, including D, checked for brood-stage resolution; known sibling deaths retained and positive notA work still checked.
- [ ] Former parents, separate-date non-brood observations, new nesting attempts and any contrary chick evidence handed over with their correct IDs; Section 9.
- [ ] Hiding photographs planned before actual age seven days, not discovery age.
- [ ] Missing photographs checked per ring; expiry not mistaken for completion.
- [ ] Unresolved family links, validation discrepancies and unfinished work handed over.
- [ ] pP, P or D fate checks remain in the handover until final notA, even if absent from the To-Do PDF.

</details>
