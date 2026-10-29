# Thread 8 — retained field-manual template distillation

This is a tracked field-manual orientation and template record. It does not
modify the retained reference manual or any application source.

## Current authoring boundary — 26 October 2026

The retained template measurements below are historical style evidence, not
current biological or validation instructions. A4 remains the approved output
geometry; preserve Calibri/Arial and the original handbook character. Current
protocol versions must be read from the reviewed source, not the dated
authoring-plan entries below.

The private Markdown review is being edited directly by Luke. Do not replace
it from a backup or regenerate its preview during that review. Queue technical
wording separately, then reconcile against his actual edited file once the
implementation contract and verification are final. Private working drafts
remain excluded from a source PR unless publication is explicitly approved.

Latest approved methodology includes the verified-ring exception to uncertain
marks, same-site/date/GPS family matching, same-occasion conflicting-ID checks,
retirement of the former no-nest sentinel, pP/P/D fate reviews until final
notA, and the rare truthful F-zero/H sequence with the intentional validator
rejection/comment procedure. The H reconciliation and owning specialist
handoffs record those contracts; do not infer a live deployment from them.

For GEO work, sampling both pair members is a longitudinal objective, not
permission to handle both on one visit. Current task/timing/welfare gates and
Luke's pause/continue directions apply to each bird. Early/late phenology is
a sampling prediction, not a proven resident/migrant classification.

## Retained reference

- Path: `/Users/luketheduke2/ownCloud/kemp_projects/bdot/admin/protocols/BADO_FIELD_MANUAL_2026.docx`
- SHA-256: `dba4c358dcdd6db499feb89b6f7480d380cf144ec7605645291575afd804e269`
- Size: 37,039,584 bytes
- Read-only render: `/private/tmp/thread8-field-manual-orientation/template-reference-render`
- Rendered pages: 34 PNG pages plus a PDF render
- Visual inspection: every rendered page inspected in five batches

## Page and section system

- Word page size: 12,240 x 15,840 twips (US Letter, 612 x 792 pt), despite the requested target being described as compact A4.
- One section; title-page setting enabled.
- Margins: top 720 twips, right 1,440, bottom 902, left 1,440; header/footer distance 720 twips.
- One running header and one running footer. Header text is `Banded Dotterel Field Manual v2.0`; footer contains a Word PAGE field aligned at the lower right.
- Contents page uses a real TOC field with hyperlinks and 24 PAGEREF fields. The package has no automatic update-fields setting, so final field refresh must be checked in Word/LibreOffice before delivery.

## Style evidence

- Normal style: Calibri 11 pt with 200 twips after-paragraph spacing and 276 twips line spacing.
- Heading 1: Arial, bold, 14 pt, outline level 0, keep-with-next.
- Heading 2: Arial, bold, 14 pt, centred, outline level 1.
- Heading 3: theme heading font, blue accent, 12 pt, outline level 2, keep-lines.
- Heading 4 exists as a 14 pt bold outline level 3 style but is not materially used in the visible manual.
- List Paragraph is a real style with a 720-twip left indent; Caption is a real italic 9 pt style.
- Contents styles TOCHeading, TOC1, TOC2, and TOC3 are present; TOC1/2 use right-aligned dotted leader tabs.
- The package contains 66 abstract numbering definitions and 66 numbering instances, including decimal, letter, Roman, and bullet patterns. Existing numbering IDs should be reused rather than rebuilt casually.

## Document/package structure

- Approximately 742 body paragraphs, 281 using ListParagraph, 10 Heading1, 15 Heading3, 2 Caption, and visible TOC styles.
- Two tables; numerous floating/anchored drawings; the rendered manual uses photographs, figure-like callouts, and captions as practical teaching aids.
- 38 anchored drawing elements were found in the document XML; the image audit reported 23 media-target rows, with 48 image relationships and 46 media filenames in the package.
- Footnotes and endnotes parts are present. No comments part and no content controls were found.
- Preserve the complete OPC package, including custom XML, theme, font table, numbering, settings, header/footer, footnotes/endnotes, and unaffected media relationships.

## Visual/writing pattern to preserve

- Compact field-handbook appearance rather than a report or brochure.
- Cover/front matter combines title, version/date, author credit, a field image, and the contents opening.
- Practical section headings, concise operational prose, numbered procedures, short bullets, photographs, annotated figures, and small tables.
- Running furniture is quiet and functional; page numbering is visible but unobtrusive.
- New flowcharts should be editable Word shapes where practical. Any image-based diagram needs a retained editable source and a matching text key.
- The reference renders cleanly without visible clipping or overlap, but page density is uneven and several pages contain large white areas. The revised handbook should preserve readability while tightening avoidable gaps.

## Historical content requiring authority checks

The reference is style evidence only. Its historical field/database content includes obsolete or potentially obsolete rclass values, identifier conventions, field names, photo categories, nest/egg assumptions, and database-entry instructions. Current SQL, app code, approved protocol documents, and the user’s latest methodological decisions must control the revision.

## Authoring decisions recorded 2026-09-28

- The revised manual will use A4 page geometry. The retained Letter-format reference remains unchanged.
- Historical authoring plan (2026-09-28): use validator protocol version 1.2.4 and record the then-reported `AGENTS.md` discrepancy. This plan was superseded during the final 2026-10-23 authoring pass by the directly inspected current protocol v1.3.4 and current `AGENTS.md`.
- The main hiding-spot workflow will use a positive or negative `nest_id` where available. An advanced exception will explain that a later chick resighting may omit `nest_id` after an earlier CAPTURES event has linked chick and social-parent identities, provided the same occasion includes the parent and all resighted family members share the same `gps_id`/`gps_point` event location.
- The main manual will be Cass River/Pohowera field-facing. Broader database site support will be noted briefly.
- Procedures will focus on BADO. WRYB nests may also be found and photographed in the field; examples in the manual will remain invented unless real records are separately cleared for publication.
- Geolocator deployment guidance will describe two planned phenology waves of approximately 50 units each, balanced across early/resident and late/migrant nesting, with pair members sampled together for an approximately equal sex ratio. Luke will direct pause/continue decisions as nesting waves develop. A possible third wave will be described as a mixture of renesters and double-brooding parents, subject to field direction.

## Private working-copy boundary — 2026-10-23

A separate working draft was produced and visually reviewed against the
retained template, current validator authority, and specialist handoffs. The
draft DOCX, rendered PDF, filenames, hashes, and artifact metadata are private,
ignored working materials. They must not be committed, pushed, attached to a
PR, or otherwise published unless the user explicitly approves publication in
a later task. This tracked note preserves only the reusable template method and
authority decisions needed to restart Thread 8 safely.
