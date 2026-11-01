# Parent identity and MM chronology

Authority: Luke Eberhart-Hertel's explicit decisions on 31 October and
1 November 2026. The approved 1 November same-day linkage decision supersedes
the earlier blanket prohibition on linking same-day X-X and first capture.
This is a biological task-association contract, not a new data-entry validator,
permission to alter observations, or evidence of live deployment.

## Known individual versus an unbanded placeholder

For a reliably identified bird at the same nest and of the same sex, eligible
pre-MM evidence remains valid. A later MM capture does not reset proof. Two
eligible nonconfirming sightings before MM plus one afterwards reach three;
an independently qualifying confirming observation or direct capture remains
proof under the existing four-gate hierarchy. MM capture alone is not proof.

X-X denotes an unbanded bird of a particular sex at a particular nest, not a
unique individual across encounters. A confirming X-X observation on a later
date than an earlier same-sex MM-only capture establishes the unbanded parent
instead of that merely captured candidate. The other sex is evaluated independently.

## Approved same-day linkage — 1 November 2026

An unambiguous confirming X-X resighting and exactly one eligible `capture_status = F`
(first banding) captured identity of the same sex, at the same nest and on the
same field date are assumed to be the targeted same individual. Transfer that
same-day confirming evidence to the newly marked identity, including an MM
capture with no later sightings. This is a specific identity assumption, not
an inference of the observed before/after order.

The `first_marking_counts` pool counts all eligible first-banding (`F`)
distinct capture identity keys in the same-sex/same-nest/
same-date pool **before** later-proof or ambiguity filters. Multiple captured
identities cannot become a unique link merely because another candidate lacks
later proof or fails a later ambiguity filter. Count identity keys, not rows.
The same-day link is limited to a unique replacement and an unambiguous
confirming resighting (`r` in the SQL); original X-X history remains available
so an earlier displaced MM-only candidate cannot revive through this replacement.

Keep the observation date and raw rows. RESIGHTINGS has no observation-time
field: infer no exact sighting time from capture time, primary keys or midnight.
The approved SQL contract will conservatively date linked proof at the capture
datetime on that date; this is a derived proof timestamp, not an observed time.

No unique link is available with multiple competing captured identities,
ambiguous or otherwise ineligible evidence, another sex or nest, a recapture-only
record, or evidence beyond the reference date. All existing evidence-eligibility
and hierarchy guards still apply. A later X-X event stays separate.

If the confirming X-X was on an earlier, different day, a later first-marked
bird, including one caught by MM, cannot inherit that older proof. It needs its
own one eligible confirming observation or three distinct qualifying observations
after first marking. Its own valid same-day confirming linkage under the rule
above is now sufficient proof without waiting for later sightings. Only one
qualifying candidate can retire the older same-sex X-X placeholder; the older
proof is not transferred and the new association is not backdated to it.
Retirement means omission from derived association evidence, not raw-row deletion
or proof that all historical X-X encounters were that captured individual.

## Chronology and conflicts

- A bird merely caught by MM before the confirmed X-X event must not revive
  through accumulated nonconfirming observations after that placeholder retires.
- Independently established earlier evidence is not erased. Competing strong
  evidence, including later definitive/confirming evidence, remains subject to
  the ordinary hierarchy and ambiguity rules; do not silently choose a parent.
- Use original X-X history for displacement, even after its old placeholder is
  retired in the derived calculation. A later X-X event remains separate evidence.
- Same-day sighting/capture order is unknown: RESIGHTINGS has no time field.
  The approved same-day first-banding assumption above supplies the narrow link;
  it does not infer order or erase independent proof by guessing that order.
- Restrict both sexes, candidates and proof to the reference date and exact
  nest. Ambiguous identity matches do not qualify replacement. Count each
  observation event once, including when calculating the third-event proof date.
- The new bird's association date is its own proof date, including the linked
  capture date for valid same-day confirmation, not an older X-X date. Never
  backdate closure, tag provenance or a historical link using newly earned proof.

The different-day subsequent-observation requirement is an **X-X identity**
safeguard, not a universal post-MM clock. Seven-day clutch timing, 36-hour
disturbance, tag eligibility and hierarchy remain unchanged. Unrelated same-day
safety rules, including juvenile origins and brood closure, are unchanged.

Invented examples (relative days, no field identities):

- `sameDayXXIN + firstMM`: day 1 X-X IN and a unique eligible status-F MM
  capture of the same sex/nest resolve the marked identity on day 1 with no
  later proof. Use the capture datetime for linked proof, never a claimed
  exact observation time.
- `differentDayXXIN + firstMM`: day 1 X-X IN, day 2 first MM capture and no
  own confirmation leave the newly marked identity pending. A qualifying day-2
  same-day X-X IN link could supply its own proof and retire the older placeholder,
  without transferring day-1 proof.

## Implementation and verification

`DATABASE/views.SQL`, `ADULT_PARENT_NEST_ASSOCIATIONS`, owns the calculation.
The snapshot reads this authoritative result; no parallel R or refresh-only
association definition is introduced. Public view columns remain unchanged.

`tests/testthat/test-mm-xx-chronology-2026-10-31.R` evaluates the actual extracted
SQL SELECT using invented CTE inputs, including both-sex timelines, pre-MM proof,
X-X replacement through one/three observations, duplicate IDs, future evidence,
the approved same-day targeted-banding exception, conflicting candidates and
displaced-identity protection. The earlier same-day no-link expectation is
superseded, while the 31 October results remain historical.
[Machine-readable cases](parent-association-cases.json) are a planning crosswalk,
not a second executable association implementation or complete scientific oracle.

1 November verification: **PASS for the focused synthetic scope** — 65 actual-SQL
chronology assertions, 1,004 assertions overall, and one fresh isolated MariaDB
11.8.9 synthetic install/refresh. See the source hashes, exact coverage and
unexecuted field/PDF/live/browser limits in
[the new verification record](SAME_DAY_LINKAGE_VERIFICATION_2026-11-01.md).

No field dump, field-server query, new deployment or automatic live migration
is authorized by this document. A full field refresh/PDF and performance replay
remain separate release checks. To roll back an unpublished candidate, remove
only this reviewed source/doc/test patch; for a deployed view, reinstall the
previous reviewed view source and rebuild the snapshot under human control.
