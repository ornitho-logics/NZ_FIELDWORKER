# Manual shortening — section-by-section relocation checklist

**Human-review proposal · 3 November 2026 · No relocation performed**

Source: [manual v2.4.20](../../main/www/field-manual/manual.md), approximately
28,400 Markdown words. Companion: [draft Core Team Field Guide](core-team-field-guide.md).
The source manual, generated HTML, app interface, and protocol rules are unchanged
by these review drafts.

## Proposed reading structure

1. **Core Team Field Guide:** the daily-use starting point for experienced staff.
   Target roughly 2–4 pages after layout review; the current Markdown draft has
   not been paginated. Keep actions, restrictions, and links to exceptions.
2. **Detailed protocol reference:** complete field and entry requirements,
   decision rules, exceptions, controlled values, and selected examples. Keep
   available without requiring a separate repository visit during routine work.
3. **Onboarding and project information:** explanatory biology, rationale,
   authorship/AI disclosure, and links to development resources. Repository-only
   engineering material should be separated from field instructions.

These are reading layers, not three competing protocol authorities. Maintain
one complete authoritative procedure for each topic, then summarise and link
from the short guide. Future rule changes must update both the procedure and
its summary.

## Relocation decisions for every current section

Every row is proposed, not completed. “Move” means preserve at the destination,
not delete. Retain existing anchors or provide working redirects when approved.

| Current section | In the short guide | Destination and consolidation | Details that must remain available |
|---|---|---|---|
| **1. How to use this manual** | Brief scope, trained-team audience, truthful records, and a record-per-event table. | Put reading/navigation instructions here; move fuller background to onboarding. Merge repeated basic row explanations with Section 2. | NZ-wide scope; site-specific schemes are not universal; handled versus observed birds; separate H-photo records; required/optional/blank meanings; zero, X, and ? distinctions. |
| **2. What have I encountered?** | One compact “what happened → which record” key and positive/negative-ID rules. | Retain one detailed decision key in the reference, not both a large tree and a full duplicate text key. Preserve an accessible text alternative if keeping the diagram. | Unknown-origin versus uncertain association; positive IDs after hatch; unrelated-adult blank ID; retired NO_NEST; resighting classes and event-specific exceptions. |
| **3. Before leaving the field house** | Short equipment/date check and core GPS reminders. | Combine routine preparation with Appendix B. Keep one full GPS matrix in the reference. Move extended equipment explanations to onboarding. | Garmin unit plus point; shared family encounter; first versus later stationary nest visit; negative-ID, H, and chick R/C capture requirements; permitted positive-ID exceptions. Do not make GPS mandatory on every row. |
| **4. Nests, scrapes, and eggs** | Common S/F/I/H actions, true counts, no floating starred/pipping eggs, and rare-discovery signpost. | Keep one nest-visit procedure and one egg-measurement procedure, with field requirements. Move introductory breeding biology to onboarding. | Nest-ID allocation, repeated visits, F after S, chicks inside obvious nest F→H timing, no invented EGGS rows, per-egg numbering, float values/blanks, measurement timing, and photo ownership. |
| **5. Adults, chicks, and broods** | Shared encounter, each observed bird, X-X, AT versus AC, genuine parent evidence, submission order, and MM caution. | Keep one authoritative family-entry procedure and a separate parent-association reference. Move SQL implementation detail and verification history to existing technical docs. | Parent/chick co-entry directionality; capture-first pathway; no-parent exception; blank-ID limits; explicit H IDs; sex-specific evidence hierarchy; uncertain-mark exclusions; pre/post-MM evidence; same-day targeted X-X first marking; different-day non-transfer; narrow cross-nest override and safeguards. |
| **6. Captures, bands, rings, flags, and tags** | F/R/C/D meanings, incoming/release marks, allocated combinations, flagging thresholds, and link to required measurements. | Retain the complete age/status measurement table, marking layouts, and capture-field instructions in the reference. Consolidate repeated marking examples with Section 14. | No ? capture leg fields; dead-recovery blanks; no automatic age change for a flag; 22 g/27 mm limits plus welfare judgement; latest-encounter flagging counts; duplicate-ring, dead, unresolved, and fallback safeguards. |
| **7. Photographs and media handling** | Tent versus hiding photo; one H row per chick; essential H fields; actual-age deadline; original filenames. | Keep a single photo-ownership table and complete H submission procedure. Move camera/file-handling explanations for new staff to onboarding while retaining a concise backup checklist. | Explicit valid H ID, known ring, leg observations, GPS pair, camera/range, capture-first order, parent records, permitted shared H ranges, distinct-ring progress, zero-history safeguards, and task expiry versus completion. Keep biological-age and discovery-date clocks distinct. |
| **8. Geolocator deployment and retrieval** | Both capture restrictions, no pair-completion exemption, literal conditional-note interpretation, and site-specific allocation warning. | Keep complete timing and tag-entry procedures in reference. Present the current season's cutoff/plots/allocation as an explicitly dated site card. Move rollout rationale and implementation history to project docs. | Final-egg date versus discovery/confirmation; proxy/reset boundaries; independent 36 hours; 08:00 PDF assumption; same-nest authoritative GEO evidence; already-tagged pending birds; conditional X-X pathway; completion strictly after 9 October; tag actions, IDs, spacers, and adult-only fields. |
| **9. Fate, hatching, failure, and notA** | True eggs/chicks, uncertainty, final notA, fixed 21–35-day window, later live evidence, and presumed versus observed death. | Keep one field decision key plus full fate/closure and brood-follow-up reference. Place detailed calculation chronology beside its technical specification rather than repeatedly within field examples. | pP/pD/P/D checks until notA; surviving brood after closure; approved retained-egg D→notA exception; three distinct presumed-loss routes; exact evidence/chronology; negative-brood proxy; no age anchor; reopen rules; J-origin timing and dead-J distinction. Never replace these with “missing 14 days = dead.” |
| **10. End-of-day entry and review** | A short upload/save/review/handover sequence. | Make this the home of the daily completion checklist; merge repeated Appendix B items. Keep map/PDF interpretation and historical notA-summary help as separate linked reference topics. | GPS-first order; captures before dependent parent/H submissions; family co-submission; prefilled defaults; DATA ENTRY ISSUES; reference date/refresh; popup and Est Hatch meanings; task disappearance versus completion. |
| **11. Field-to-database data dictionary** | No full dictionary; link from unfamiliar field names. | Retain a searchable reference dictionary. Replace duplicated narrative with links to the relevant procedure; leave concise field meanings and applicability. | Canonical field names, units, blanks versus zero, age/event applicability, and CAPTURES-only observer_upload. No widening of field requirements through shorthand. |
| **12. Validator messages and repair guide** | “Correct errors; explain real exceptions; never change truthful evidence to pass.” | Keep one troubleshooting destination with message-to-procedure links. Put inspector installation and developer details in repository docs, not the core guide. | Save-blocking versus warning distinction; no-parent and rare-discovery review; approved override controls; no nov/pk edits; field-hint disagreements; no routine validation bypass. |
| **13. Required database events by scenario** | Fold the common encounter choices into the guide's record table. | Convert this section to a compact scenario index linking to authoritative procedures. Keep unique combinations as small scenario cards rather than repeating whole procedures. | Before removing repetition, check all existing scenario cards for unique requirements, record order, genuinely optional rows, and exception conditions. Preserve every unique rule at a named destination. |
| **14. Worked examples** | None beyond very short action examples needed to avoid error. | Retain a small set of high-value, invented field examples; move longer chronology/counterexamples to an optional reference annex or reconstruction docs as appropriate. | Same-day versus different-day X-X/MM, H plus capture, no-parent exception, rare F→H discovery, D recovery, tag restrictions, fixed-window reopening, and J-origin cases must remain traceable. Examples illustrate rules; they cannot silently introduce them. |
| **15. Revision record and source notes** | Only a version/date and link. | Keep a concise reader-facing change summary. Move hashes, SQL/runtime evidence, installation instructions, and detailed development history to repository release/technical records; link rather than discard. | Approved decision dates, remaining limitations, source-versus-deployment distinction, and a route to prior versions. Historical decisions must not override current approved rules. |
| **Appendix A. Controlled values** | Only the few codes needed for everyday decisions. | Keep a searchable lookup grouped by task; link from entry procedures. | Exact spelling/case, units, valid combinations, X/?/tag-spacer notation, resighting classes, behaviours, capture/tag actions, and event-specific blanks. Avoid a second competing code list. |
| **Appendix B. Field and submission checklists** | Absorb the short before-leaving and end-of-day checks. | Merge into Sections 3 and 10; retain a downloadable/printable full submission checklist as an optional reference. | Every unique pre-save safeguard, rare-exception check, unfinished fate task, media check, and handover item must survive the merge. Avoid keeping three independently edited daily checklists. |
| **Authorship and use of AI** | A brief attribution and direct link to the complete disclosure. | Retain the approved full disclosure as an accessible end section, including its contents entry. Do not bury it solely in developer docs. | Luke Eberhart-Hertel's accountability, actual AI role, human-controlled field-server installation, truthful real-data/mock-data distinction, public resource links, privacy limits, and the separate-window hint for in-app links. Do not strengthen assurances beyond evidence. |

## Concrete cuts in the core reading path

- Remove introductory explanations such as what “precocial” means from the
  experienced-team route. Preserve them in optional onboarding where useful.
  Keep the associated action: young chicks outside a never-found nest do not
  establish a positive nest origin.
- Replace repeated “which table?” explanations with one small encounter key.
- Replace repeated full rules inside scenarios and examples with links to the
  authoritative procedure, retaining unique combinations and exceptions.
- Keep SQL object names, source hashes, test counts, and installation history
  out of daily instructions, except where a field name is necessary for entry.
- Keep safety-critical exceptions reachable at the point of use, rather than
  making all exceptions disappear into an undifferentiated appendix.
- Keep the comments-versus-events warning prominent in the encounter key, nest
  procedure, and submission checklist: identities written only in NESTS comments
  do not replace RESIGHTINGS or supply the To-Do's parent-association evidence.
  Apply the same reminder to other events requiring their own records.

## Acceptance checklist before any restructuring

- [ ] Luke Eberhart-Hertel reviews the short guide for scientific meaning,
  omissions, and suitability for experienced staff.
- [ ] Agree the approximate reading length after layout review. A page target
  must not force illegible text or remove capture restrictions.
- [ ] Inventory every subsection, supporting table, scenario, and example;
  record its exact destination before moving content. This section-level
  checklist is the plan, not proof that this detailed inventory is complete.
- [ ] Extract every unique action, condition, threshold, and exception before
  consolidating repetitions. Resolve any source disagreement explicitly.
- [ ] Preserve a single complete procedure per topic. Check the guide against
  it, including MM/X-X chronology, cross-nest evidence, timing gates, H photos,
  flagging identity counts, brood closure, and juvenile resolution.
- [ ] Preserve the explicit warning that comments supplement required event
  records, not replace them. Include a nest visit plus separate bird resighting
  example and a pre-save check for observations recorded only in comments.
- [ ] Preserve search, contents navigation, and old anchors or redirects in
  both Markdown and generated HTML. Do not silently break app/help links.
- [ ] Keep the full requirements, worked exceptions, and disclosure accessible
  from the app. Do not assume phone users can open GitHub links inside the app.
- [ ] Preserve the Oxford comma, canonical field names, and consistent
  “Luke Eberhart-Hertel” attribution. Do not change inspector severity or rules
  through prose editing.
- [ ] Inspect the phone-sized reading view and printable layout after approved
  implementation. Record source version and actual verification scope.
- [ ] Review a documentation-only diff. No database, SQL, validator, or user
  workflow changes belong in this shortening exercise without separate approval.

## Decisions requested at human review

1. **Is this the right daily-use level?** Recommendation: this concise guide
   plus the full reference, rather than a short guide that tries to repeat every
   measurement field and exception.
2. **Keep the site card separate?** Recommendation: yes, so New Zealand-wide
   instructions are not confused with the current Cass River tag allocation,
   marking scheme, and calendar cutoff.
3. **What should open first later?** Recommendation: the short guide, with
   prominent access to the full reference and troubleshooting. This draft does
   not implement that presentation change.

No new biological decisions are requested here. No source sections have been
moved, deleted, or replaced; no app or database checks were run for these prose
drafts. The existing local association-code work remains separate and untouched.
