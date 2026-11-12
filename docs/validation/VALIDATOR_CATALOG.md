# Validator reference for maintainers

Generated from the current per-app source by
`tools/validation/build_validator_catalog.R`. No validators are evaluated.
This is GitHub documentation, not an app settings screen. Read
[selective validation](SELECTIVE_VALIDATION.md) before changing a check.

Keys combine the table and its existing `try_validator(nam = ...)` label.
A heading describes a whole check, which may cover several fields or conditions.
The message column lists up to three literal source messages, not every
possible dynamic result. The complete expression is authoritative.
Line links refer to current files; regenerate after editing or moving rules.

| Table | Checks | Source MD5 |
| --- | ---: | --- |
| [CAPTURES](#captures) | 98 | `7776398caa8ccc1bffede0ea536b931a` |
| [EGGS](#eggs) | 26 | `80623ef53863eda1edb11c666f182840` |
| [NESTS](#nests) | 53 | `b16d05751fb8e2289e06aa086b7391c1` |
| [OBSERVERS](#observers) | 6 | `a7d2d14d58d96ac150c3e397d66b27e5` |
| [RESIGHTINGS](#resightings) | 57 | `fb0749ce72000fc5f43a8b55f0fb6941` |
| [RESIGHTINGS_PUBLIC](#resightings_public) | 25 | `27a7f812b4e1c736e08e267e7e29d46e` |

## CAPTURES

| Check ID | What it checks | Example messages |
| --- | --- | --- |
| [`CAPTURES:val1`](../../DataEntry/CAPTURES/inspector.R#L3-L38) | Required fields. | Required. |
| [`CAPTURES:val2`](../../DataEntry/CAPTURES/inspector.R#L41-L71) | Require COMBO. | Required. |
| [`CAPTURES:val3`](../../DataEntry/CAPTURES/inspector.R#L74-L111) | Require a nest or brood for first chick captures. | Age-C status F requires a positive or negative nest_id. |
| [`CAPTURES:val4`](../../DataEntry/CAPTURES/inspector.R#L114-L174) | Require gps_id for negative brood. | Negative nest_id requires gps_id and gps_point. |
| [`CAPTURES:val5`](../../DataEntry/CAPTURES/inspector.R#L177-L241) | Require gps_id for adult with chicks. | Adult with chicks requires both GPS fields. |
| [`CAPTURES:val6`](../../DataEntry/CAPTURES/inspector.R#L244-L308) | Require gps_id for chick recapture or remarking. | Age-C R/C requires both GPS fields, including with nest_id. |
| [`CAPTURES:val7`](../../DataEntry/CAPTURES/inspector.R#L311-L378) | Require gps_id for unlinked capture. | Enter gps_id and gps_point without a positive nest link. |
| [`CAPTURES:val8`](../../DataEntry/CAPTURES/inspector.R#L381-L443) | Require gps_point for negative brood. | Negative nest_id requires gps_id and gps_point. |
| [`CAPTURES:val9`](../../DataEntry/CAPTURES/inspector.R#L446-L510) | Require gps_point for chick recapture or remarking. | Age-C R/C requires both GPS fields, including with nest_id. |
| [`CAPTURES:val10`](../../DataEntry/CAPTURES/inspector.R#L513-L580) | Require gps_point for unlinked capture. | Enter gps_id and gps_point without a positive nest link. |
| [`CAPTURES:val11`](../../DataEntry/CAPTURES/inspector.R#L583-L647) | Use the nest location when direct gps_point is not allowed. | Positive nest: usually blank GPS; adult with chicks needs both GPS fields and caught_with. |
| [`CAPTURES:val12`](../../DataEntry/CAPTURES/inspector.R#L650-L661) | Check release leg-mark characters. | Invalid leg-mark characters. |
| [`CAPTURES:val13`](../../DataEntry/CAPTURES/inspector.R#L664-L690) | Check the metal-ring format. | Use CP plus 5 digits, w dash. |
| [`CAPTURES:val14`](../../DataEntry/CAPTURES/inspector.R#L693-L729) | Age-A captures using capture_method HA require a positive nest_id. | Age-A captures using capture_method HA require a positive nest_id. |
| [`CAPTURES:val15`](../../DataEntry/CAPTURES/inspector.R#L732-L759) | Check the field-season dates. | Date not in 2026–2027 season. |
| [`CAPTURES:val16`](../../DataEntry/CAPTURES/inspector.R#L762-L801) | Check the site code. | Invalid site code. |
| [`CAPTURES:val17`](../../DataEntry/CAPTURES/inspector.R#L804-L874) | Check that the GPS pair has been uploaded. | GPS pair unverified; check the gpxui upload.<br>GPS  missing from GPS_POINTS  |
| [`CAPTURES:val18`](../../DataEntry/CAPTURES/inspector.R#L877-L901) | Keep the validation flag blank. | Leave blank. |
| [`CAPTURES:val20`](../../DataEntry/CAPTURES/inspector.R#L904-L956) | Check book, form, and event uniqueness. | Use book_id 1–5.<br>Use a positive integer.<br>Each [book_id, form_id] pair must represent only one capture event. |
| [`CAPTURES:val21`](../../DataEntry/CAPTURES/inspector.R#L959-L1004) | Released must be blank when capture_status is D. | Released must be blank when capture_status is D. |
| [`CAPTURES:val22`](../../DataEntry/CAPTURES/inspector.R#L1007-L1073) | Caught must be before released. | Caught must be before released. |
| [`CAPTURES:val23`](../../DataEntry/CAPTURES/inspector.R#L1076-L1092) | Check capture_status. | Use F, R, C, or D. |
| [`CAPTURES:val24`](../../DataEntry/CAPTURES/inspector.R#L1095-L1158) | Check nest links required by capture method. | capture_method TN requires a positive nest_id.<br>Method TB requires a positive or negative nest_id. |
| [`CAPTURES:val25`](../../DataEntry/CAPTURES/inspector.R#L1161-L1213) | Check the nest or brood identifier. | NO_NEST is invalid; use a valid nest_id or blank with both GPS fields.<br>nest_id must be blank or match the current site-specific positive/negative nest_id format. |
| [`CAPTURES:val26`](../../DataEntry/CAPTURES/inspector.R#L1216-L1242) | Check field_sex against age. | field_sex must follow the age-specific coding rule. |
| [`CAPTURES:val27`](../../DataEntry/CAPTURES/inspector.R#L1245-L1318) | First-marking captures must have all input band positions set to X or left blank. | First-marking captures must have all input band positions set to X or left blank. |
| [`CAPTURES:val28`](../../DataEntry/CAPTURES/inspector.R#L1321-L1391) | First-marking captures must not leave all release band positions as X. | First-marking captures must not leave all release band positions as X. |
| [`CAPTURES:val29`](../../DataEntry/CAPTURES/inspector.R#L1394-L1468) | Statuses R and C require all input and release band positions to be entered. | Statuses R and C require all input and release band positions to be entered. |
| [`CAPTURES:val30`](../../DataEntry/CAPTURES/inspector.R#L1471-L1577) | Check capture, release, age, and tag marks. | Bands changed; use capture_status C.<br>Recaptures with status R must keep the same band positions before and after handling. |
| [`CAPTURES:val31`](../../DataEntry/CAPTURES/inspector.R#L1580-L1651) | Status C requires at least one non-X input mark before the release combo is changed. | Status C requires at least one non-X input mark before the release combo is changed. |
| [`CAPTURES:val32`](../../DataEntry/CAPTURES/inspector.R#L1654-L1733) | Status C requires at least one change between input and release band positions. | Status C requires at least one change between input and release band positions. |
| [`CAPTURES:val33`](../../DataEntry/CAPTURES/inspector.R#L1736-L1803) | Dead-on-capture rows must record the recovered combo in all input band positions. | Dead-on-capture rows must record the recovered combo in all input band positions. |
| [`CAPTURES:val34`](../../DataEntry/CAPTURES/inspector.R#L1806-L1873) | Dead-on-capture rows must leave all release band positions blank. | Dead-on-capture rows must leave all release band positions blank. |
| [`CAPTURES:val35`](../../DataEntry/CAPTURES/inspector.R#L1876-L1943) | Only one T allowed across upper leg positions. | Only one T allowed across upper leg positions. |
| [`CAPTURES:val36`](../../DataEntry/CAPTURES/inspector.R#L1946-L2007) | Only one T allowed across upper leg positions. | Only one T allowed across upper leg positions. |
| [`CAPTURES:val37`](../../DataEntry/CAPTURES/inspector.R#L2010-L2074) | T codes are only allowed in upper leg positions. | T codes are only allowed in upper leg positions. |
| [`CAPTURES:val38`](../../DataEntry/CAPTURES/inspector.R#L2077-L2186) | Check UL for this capture or observation. | CR<br>CR chick: one LL colour, UR M, blank UL/LR, status F/R.<br>Non-CR chick: UL M, one LR colour, blank LL/UR, status F/R. |
| [`CAPTURES:val39`](../../DataEntry/CAPTURES/inspector.R#L2189-L2274) | Juvenile: UL flag, UR M, blank LL/LR, status F/C. | Juvenile: UL flag, UR M, blank LL/LR, status F/C. |
| [`CAPTURES:val40`](../../DataEntry/CAPTURES/inspector.R#L2277-L2364) | Juvenile F/C: UL flag, UR M, blank LL/LR. Dead D: complete _in combo. | Juvenile F/C: UL flag, UR M, blank LL/LR. Dead D: complete _in combo. |
| [`CAPTURES:val41`](../../DataEntry/CAPTURES/inspector.R#L2367-L2443) | CR adult LL: YR/YO/YY/GY/BY/WY/OY/LY; status D may leave all marks blank. | CR adult LL: YR/YO/YY/GY/BY/WY/OY/LY; status D may leave all marks blank. |
| [`CAPTURES:val42`](../../DataEntry/CAPTURES/inspector.R#L2446-L2522) | Non-CR adult LL cannot use YR/YO/YY/GY/BY/WY/OY/LY. | Non-CR adult LL cannot use YR/YO/YY/GY/BY/WY/OY/LY. |
| [`CAPTURES:val43`](../../DataEntry/CAPTURES/inspector.R#L2525-L2635) | Adult captures may not use the chick or juvenile release marking schemes. | Adult captures may not use the chick or juvenile release marking schemes. |
| [`CAPTURES:val44`](../../DataEntry/CAPTURES/inspector.R#L2638-L2732) | Short UR tag codes such as TY are reserved for GEO tags. | Short UR tag codes such as TY are reserved for GEO tags. |
| [`CAPTURES:val45`](../../DataEntry/CAPTURES/inspector.R#L2735-L2829) | Release GEO tag code requires tag_id. | Release GEO tag code requires tag_id. |
| [`CAPTURES:val46`](../../DataEntry/CAPTURES/inspector.R#L2832-L2926) | Input GEO tag code requires tag_id_in. | Input GEO tag code requires tag_id_in. |
| [`CAPTURES:val47`](../../DataEntry/CAPTURES/inspector.R#L2929-L3027) | Release GEO tags must use a short upper-leg T code such as TY. | Release GEO tags must use a short upper-leg T code such as TY. |
| [`CAPTURES:val48`](../../DataEntry/CAPTURES/inspector.R#L3030-L3128) | Input GEO tags must use a short upper-leg T code such as TY. | Input GEO tags must use a short upper-leg T code such as TY. |
| [`CAPTURES:val49`](../../DataEntry/CAPTURES/inspector.R#L3131-L3228) | Release GEO tag codes require tag_action D, S, or N. | Release GEO tag codes require tag_action D, S, or N. |
| [`CAPTURES:val50`](../../DataEntry/CAPTURES/inspector.R#L3231-L3328) | Input GEO tag codes require tag_action S, N, or R. | Input GEO tag codes require tag_action S, N, or R. |
| [`CAPTURES:val51`](../../DataEntry/CAPTURES/inspector.R#L3331-L3427) | tag_action D means the bird must not already carry a tag in the input combo. | tag_action D means the bird must not already carry a tag in the input combo. |
| [`CAPTURES:val52`](../../DataEntry/CAPTURES/inspector.R#L3430-L3526) | tag_action R means the bird must not retain a tag in the release combo. | tag_action R means the bird must not retain a tag in the release combo. |
| [`CAPTURES:val53`](../../DataEntry/CAPTURES/inspector.R#L3529-L3629) | tag_action O can only be used when no tag is present at capture or release. | tag_action O can only be used when no tag is present at capture or release. |
| [`CAPTURES:val54`](../../DataEntry/CAPTURES/inspector.R#L3632-L3733) | tag_type must be blank when no tag is present. | tag_type must be blank when no tag is present. |
| [`CAPTURES:val55`](../../DataEntry/CAPTURES/inspector.R#L3736-L3837) | tag_action must be O when no tag is present. | tag_action must be O when no tag is present. |
| [`CAPTURES:val56`](../../DataEntry/CAPTURES/inspector.R#L3840-L3888) | tag_action D requires the newly deployed tag in tag_id. | tag_action D requires the newly deployed tag in tag_id. |
| [`CAPTURES:val57`](../../DataEntry/CAPTURES/inspector.R#L3891-L3939) | tag_action D requires tag_id_in to be blank. | tag_action D requires tag_id_in to be blank. |
| [`CAPTURES:val58`](../../DataEntry/CAPTURES/inspector.R#L3942-L3990) | tag_action R requires the retrieved tag in tag_id_in. | tag_action R requires the retrieved tag in tag_id_in. |
| [`CAPTURES:val59`](../../DataEntry/CAPTURES/inspector.R#L3993-L4041) | tag_action R requires release tag_id to be blank. | tag_action R requires release tag_id to be blank. |
| [`CAPTURES:val60`](../../DataEntry/CAPTURES/inspector.R#L4044-L4092) | tag_action S requires the retained tag in tag_id_in. | tag_action S requires the retained tag in tag_id_in. |
| [`CAPTURES:val61`](../../DataEntry/CAPTURES/inspector.R#L4095-L4143) | tag_action S requires the retained tag in tag_id. | tag_action S requires the retained tag in tag_id. |
| [`CAPTURES:val62`](../../DataEntry/CAPTURES/inspector.R#L4146-L4199) | tag_action S requires the same tag_id before and after release. | tag_action S requires the same tag_id before and after release. |
| [`CAPTURES:val63`](../../DataEntry/CAPTURES/inspector.R#L4202-L4250) | tag_action N requires the removed tag in tag_id_in. | tag_action N requires the removed tag in tag_id_in. |
| [`CAPTURES:val64`](../../DataEntry/CAPTURES/inspector.R#L4253-L4301) | tag_action N requires the newly deployed tag in tag_id. | tag_action N requires the newly deployed tag in tag_id. |
| [`CAPTURES:val65`](../../DataEntry/CAPTURES/inspector.R#L4304-L4357) | tag_action N requires different input and release tag IDs. | tag_action N requires different input and release tag IDs. |
| [`CAPTURES:val66`](../../DataEntry/CAPTURES/inspector.R#L4360-L4653) | Check tag actions against earlier deployments. | Tag history unverified: CAPTURES unavailable.<br>Tag already deployed; redeployment requires prior R retrieval in tag_id_in.<br>tag_action S requires this tag to be active on the same ring from an earlier deployment. |
| [`CAPTURES:val67`](../../DataEntry/CAPTURES/inspector.R#L4656-L4762) | Require discovery before a positive nest-linked capture. | nest_id requires a same-day-or-earlier NESTS F event. |
| [`CAPTURES:val68`](../../DataEntry/CAPTURES/inspector.R#L4765-L5039) | Check band combinations against capture history. | Combination unverified:<br>CAPTURES_ARCHIVE unavailable.<br>Release match unknown; retry when |
| [`CAPTURES:val69`](../../DataEntry/CAPTURES/inspector.R#L5042-L5075) | Check optional measurements are numeric. | Enter a finite number. |
| [`CAPTURES:val70`](../../DataEntry/CAPTURES/inspector.R#L5078-L5128) | Check adult morphometric ranges . | Outside morphometric range. |
| [`CAPTURES:val71`](../../DataEntry/CAPTURES/inspector.R#L5131-L5172) | Check juvenile morphometric ranges . | Outside morphometric range. |
| [`CAPTURES:val72`](../../DataEntry/CAPTURES/inspector.R#L5175-L5216) | Check chick morphometric ranges . | Outside morphometric range. |
| [`CAPTURES:val73`](../../DataEntry/CAPTURES/inspector.R#L5219-L5260) | Check recaptured-chick morphometric ranges . | Outside morphometric range. |
| [`CAPTURES:val74`](../../DataEntry/CAPTURES/inspector.R#L5263-L5304) | Check rebanded-chick morphometric ranges . | Outside morphometric range. |
| [`CAPTURES:val75`](../../DataEntry/CAPTURES/inspector.R#L5307-L5360) | cam_id is required when any photo flag is 1. | cam_id is required when any photo flag is 1. |
| [`CAPTURES:val76`](../../DataEntry/CAPTURES/inspector.R#L5363-L5416) | photo_start is required when any photo flag is 1. | photo_start is required when any photo flag is 1. |
| [`CAPTURES:val77`](../../DataEntry/CAPTURES/inspector.R#L5419-L5472) | photo_end is required when any photo flag is 1. | photo_end is required when any photo flag is 1. |
| [`CAPTURES:val78`](../../DataEntry/CAPTURES/inspector.R#L5475-L5522) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`CAPTURES:val79`](../../DataEntry/CAPTURES/inspector.R#L5525-L5572) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`CAPTURES:val80`](../../DataEntry/CAPTURES/inspector.R#L5575-L5622) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`CAPTURES:val81`](../../DataEntry/CAPTURES/inspector.R#L5625-L5686) | photo_end must not precede photo_start. | photo_end must not precede photo_start. |
| [`CAPTURES:val82`](../../DataEntry/CAPTURES/inspector.R#L5689-L5976) | Check photo ranges for reuse. | Photo range overlaps another event; sharing allowed within one age-C H nest/GPS session. |
| [`CAPTURES:val83`](../../DataEntry/CAPTURES/inspector.R#L5979-L5994) | Check observer upload initials check 1. | Enter the uploader’s observer code. |
| [`CAPTURES:val84`](../../DataEntry/CAPTURES/inspector.R#L5997-L6014) | Check observer upload initials check 2. | Use 2–3 uppercase letters or digits. |
| [`CAPTURES:val85`](../../DataEntry/CAPTURES/inspector.R#L6017-L6022) | Check caught with format. | Use valid comma-separated caught_with codes. |
| [`CAPTURES:val86`](../../DataEntry/CAPTURES/inspector.R#L6025-L6036) | Check left tibia in. | Invalid capture left-tibia code. |
| [`CAPTURES:val87`](../../DataEntry/CAPTURES/inspector.R#L6039-L6050) | Check left tarsus in. | Invalid capture left-tarsus code. |
| [`CAPTURES:val88`](../../DataEntry/CAPTURES/inspector.R#L6053-L6064) | Check right tibia in. | Invalid capture right-tibia code. |
| [`CAPTURES:val89`](../../DataEntry/CAPTURES/inspector.R#L6067-L6078) | Check right tarsus in. | Invalid capture right-tarsus code. |
| [`CAPTURES:val90`](../../DataEntry/CAPTURES/inspector.R#L6081-L6106) | Check optional moult scores. | Invalid moult score. |
| [`CAPTURES:val91`](../../DataEntry/CAPTURES/inspector.R#L6109-L6132) | Check tag type required. | Tag type is required when tag ID is entered. |
| [`CAPTURES:val92`](../../DataEntry/CAPTURES/inspector.R#L6135-L6140) | Check tag id in format. | Invalid capture tag ID. |
| [`CAPTURES:val93`](../../DataEntry/CAPTURES/inspector.R#L6143-L6148) | Check tag id format. | Invalid release tag ID. |
| [`CAPTURES:val94`](../../DataEntry/CAPTURES/inspector.R#L6151-L6156) | Check camera id format. | Use a valid 2–3-character camera ID. |
| [`CAPTURES:val95`](../../DataEntry/CAPTURES/inspector.R#L6159-L6164) | Check photo filename format photo start. | Invalid photo filename. |
| [`CAPTURES:val96`](../../DataEntry/CAPTURES/inspector.R#L6167-L6172) | Check photo filename format photo end. | Invalid photo filename. |
| [`CAPTURES:val97`](../../DataEntry/CAPTURES/inspector.R#L6175-L6240) | Check whether the ring was already recorded. | Ring already recorded; check ring and identity. |
| [`CAPTURES:val98`](../../DataEntry/CAPTURES/inspector.R#L6243-L6505) | Check whether another ring uses this combination. | Band combination already used<br>by another ring;<br>check the full combination |
| [`CAPTURES:val99`](../../DataEntry/CAPTURES/inspector.R#L6508-L6558) | Review birds recorded as handled together. | Check caught_with against birds handled together. |

## EGGS

| Check ID | What it checks | Example messages |
| --- | --- | --- |
| [`EGGS:val1`](../../DataEntry/EGGS/inspector.R#L3-L3) | Required egg fields. | Required. |
| [`EGGS:val2`](../../DataEntry/EGGS/inspector.R#L6-L22) | Check the observer is active on the egg date. | Observer missing or inactive on egg date. |
| [`EGGS:val3`](../../DataEntry/EGGS/inspector.R#L25-L69) | One egg-check event requires one date. | One egg-check event requires one date. |
| [`EGGS:val4`](../../DataEntry/EGGS/inspector.R#L72-L117) | Same nest/date: time_visit must be within 5 minutes. | Same nest/date: time_visit must be within 5 minutes. |
| [`EGGS:val5`](../../DataEntry/EGGS/inspector.R#L120-L134) | Check the field-season dates. | Use a date in the 2026–2027 season. |
| [`EGGS:val6`](../../DataEntry/EGGS/inspector.R#L137-L152) | Require a positive nest identifier. | EGGS requires a positive nest_id; use CAPTURES or RESIGHTINGS for negative broods. |
| [`EGGS:val7`](../../DataEntry/EGGS/inspector.R#L155-L185) | float_surface must be blank when float_location is bottom. | float_surface must be blank when float_location is bottom. |
| [`EGGS:val8`](../../DataEntry/EGGS/inspector.R#L188-L218) | float_surface must be blank when float_location is suspended. | float_surface must be blank when float_location is suspended. |
| [`EGGS:val9`](../../DataEntry/EGGS/inspector.R#L221-L251) | Surface float requires float_surface 0–3 mm. | Surface float requires float_surface 0–3 mm. |
| [`EGGS:val10`](../../DataEntry/EGGS/inspector.R#L254-L307) | egg_id must be unique within an EGGS event. | egg_id must be unique within an EGGS event. |
| [`EGGS:val11`](../../DataEntry/EGGS/inspector.R#L310-L395) | egg_id must not exceed the clutch_size of the matching NESTS event. | egg_id must not exceed the clutch_size of the matching NESTS event. |
| [`EGGS:val12`](../../DataEntry/EGGS/inspector.R#L398-L401) | Check species allowed codes. | Invalid code. |
| [`EGGS:val13`](../../DataEntry/EGGS/inspector.R#L404-L407) | Check float location allowed codes. | Invalid code. |
| [`EGGS:val14`](../../DataEntry/EGGS/inspector.R#L410-L410) | Check observer initials. | Use 2–3 uppercase letters or digits. |
| [`EGGS:val15`](../../DataEntry/EGGS/inspector.R#L413-L426) | Check date format. | Use YYYY-MM-DD. |
| [`EGGS:val16`](../../DataEntry/EGGS/inspector.R#L429-L443) | Check time format. | Use hh:mm. |
| [`EGGS:val17`](../../DataEntry/EGGS/inspector.R#L446-L454) | Check egg_id is numeric. | Use egg_id 1–4. |
| [`EGGS:val18`](../../DataEntry/EGGS/inspector.R#L457-L468) | Check the egg_id range. | Use egg_id 1–4. |
| [`EGGS:val19`](../../DataEntry/EGGS/inspector.R#L471-L479) | Require a whole number for egg_id. | Use egg_id 1–4. |
| [`EGGS:val20`](../../DataEntry/EGGS/inspector.R#L482-L490) | Check float_angle is numeric. | Use an integer from 0 to 90. |
| [`EGGS:val21`](../../DataEntry/EGGS/inspector.R#L493-L504) | Check the float_angle range. | Use an integer from 0 to 90. |
| [`EGGS:val22`](../../DataEntry/EGGS/inspector.R#L507-L518) | Require a whole number for float_angle. | Use an integer from 0 to 90. |
| [`EGGS:val23`](../../DataEntry/EGGS/inspector.R#L521-L529) | Check float_surface is numeric. | Use a non-negative integer. |
| [`EGGS:val24`](../../DataEntry/EGGS/inspector.R#L532-L543) | Check the float_surface range. | Use a non-negative integer. |
| [`EGGS:val25`](../../DataEntry/EGGS/inspector.R#L546-L557) | Require a whole number for float_surface. | Use a non-negative integer. |
| [`EGGS:val26`](../../DataEntry/EGGS/inspector.R#L560-L627) | Match the egg event to a nest visit. | No matching NESTS visit; check nest_id, date, observer, and time_visit. |

## NESTS

| Check ID | What it checks | Example messages |
| --- | --- | --- |
| [`NESTS:val1`](../../DataEntry/NESTS/inspector.R#L3-L7) | Required nest fields. | Required. |
| [`NESTS:val2`](../../DataEntry/NESTS/inspector.R#L10-L21) | Check species allowed codes. | Invalid code. |
| [`NESTS:val3`](../../DataEntry/NESTS/inspector.R#L24-L59) | Check site allowed codes. | Invalid code. |
| [`NESTS:val4`](../../DataEntry/NESTS/inspector.R#L62-L81) | Check nest state allowed codes. | Invalid code. |
| [`NESTS:val5`](../../DataEntry/NESTS/inspector.R#L84-L99) | Check bird inc allowed codes. | Invalid code. |
| [`NESTS:val6`](../../DataEntry/NESTS/inspector.R#L102-L113) | Check nest photo allowed codes. | Invalid code. |
| [`NESTS:val7`](../../DataEntry/NESTS/inspector.R#L116-L127) | Check tent photo allowed codes. | Invalid code. |
| [`NESTS:val8`](../../DataEntry/NESTS/inspector.R#L130-L152) | Check other state comment. | nest_state O requires a comment describing the observation. |
| [`NESTS:val9`](../../DataEntry/NESTS/inspector.R#L155-L160) | Check observer initials. | Use 2–3 uppercase letters or digits. |
| [`NESTS:val10`](../../DataEntry/NESTS/inspector.R#L163-L217) | Check observer active. | Observer missing or inactive on visit date. |
| [`NESTS:val11`](../../DataEntry/NESTS/inspector.R#L220-L266) | Check hatch state clutch count. | hatch_state describes <br> egg(s), but clutch_size is <br>. Check counts; C = cracked egg, not chick. |
| [`NESTS:val12`](../../DataEntry/NESTS/inspector.R#L269-L337) | Check that the GPS pair has been uploaded. | GPS pair unverified; check the gpxui upload.<br>GPS pair missing from GPS_POINTS; upload via gpxui. |
| [`NESTS:val13`](../../DataEntry/NESTS/inspector.R#L340-L368) | Check date season. | Use YYYY-MM-DD within the 2026–2027 season. |
| [`NESTS:val14`](../../DataEntry/NESTS/inspector.R#L371-L397) | Check time format. | Use hh:mm. |
| [`NESTS:val15`](../../DataEntry/NESTS/inspector.R#L400-L484) | Check nest id pattern. | Negative nest_id is invalid in NESTS; use CAPTURES or RESIGHTINGS.<br>nest_id values beginning with WR are WRYB nest_id values. Set species to WRYB.<br>nest_id values beginning with A, B, C, or BA are BADO nest_id values. Set species to BADO. |
| [`NESTS:val16`](../../DataEntry/NESTS/inspector.R#L487-L544) | Check hatch state format. | Use positive counts followed by C, S, N, or CC, in any order. |
| [`NESTS:val17`](../../DataEntry/NESTS/inspector.R#L547-L562) | Check gps_id is numeric. | GPS ID must be a positive whole number. |
| [`NESTS:val18`](../../DataEntry/NESTS/inspector.R#L565-L581) | Check the gps_id range. | GPS ID must be a positive whole number. |
| [`NESTS:val19`](../../DataEntry/NESTS/inspector.R#L584-L603) | Require a whole number for gps_id. | GPS ID must be a positive whole number. |
| [`NESTS:val20`](../../DataEntry/NESTS/inspector.R#L606-L622) | Check gps_point is numeric. | GPS point must be a positive whole number. |
| [`NESTS:val21`](../../DataEntry/NESTS/inspector.R#L625-L646) | Check the gps_point range. | GPS point must be a positive whole number. |
| [`NESTS:val22`](../../DataEntry/NESTS/inspector.R#L649-L669) | Require a whole number for gps_point. | GPS point must be a positive whole number. |
| [`NESTS:val23`](../../DataEntry/NESTS/inspector.R#L672-L688) | Check clutch_size is numeric. | Use a non-negative integer. |
| [`NESTS:val24`](../../DataEntry/NESTS/inspector.R#L691-L712) | Check the clutch_size range. | Use a non-negative integer. |
| [`NESTS:val25`](../../DataEntry/NESTS/inspector.R#L715-L735) | Require a whole number for clutch_size. | Use a non-negative integer. |
| [`NESTS:val26`](../../DataEntry/NESTS/inspector.R#L738-L754) | Check brood_size is numeric. | Use a non-negative integer. |
| [`NESTS:val27`](../../DataEntry/NESTS/inspector.R#L757-L778) | Check the brood_size range. | Use a non-negative integer. |
| [`NESTS:val28`](../../DataEntry/NESTS/inspector.R#L781-L801) | Require a whole number for brood_size. | Use a non-negative integer. |
| [`NESTS:val29`](../../DataEntry/NESTS/inspector.R#L804-L828) | Check brood requires clutch. | brood_size requires clutch_size; use 0 if no eggs remain. |
| [`NESTS:val30`](../../DataEntry/NESTS/inspector.R#L831-L858) | Check hatch state for brood. | No eggs with chicks present requires nest_state H. |
| [`NESTS:val31`](../../DataEntry/NESTS/inspector.R#L861-L866) | Check camera id. | Use a valid 2–3-character camera ID. |
| [`NESTS:val32`](../../DataEntry/NESTS/inspector.R#L869-L874) | Check photo filename photo start. | Invalid photo filename. |
| [`NESTS:val33`](../../DataEntry/NESTS/inspector.R#L877-L882) | Check photo filename photo end. | Invalid photo filename. |
| [`NESTS:val34`](../../DataEntry/NESTS/inspector.R#L885-L933) | cam_id is required when nest_photo or tent_photo is 1. | cam_id is required when nest_photo or tent_photo is 1. |
| [`NESTS:val35`](../../DataEntry/NESTS/inspector.R#L936-L984) | photo_start is required when nest_photo or tent_photo is 1. | photo_start is required when nest_photo or tent_photo is 1. |
| [`NESTS:val36`](../../DataEntry/NESTS/inspector.R#L987-L1035) | photo_end is required when nest_photo or tent_photo is 1. | photo_end is required when nest_photo or tent_photo is 1. |
| [`NESTS:val37`](../../DataEntry/NESTS/inspector.R#L1038-L1091) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`NESTS:val38`](../../DataEntry/NESTS/inspector.R#L1094-L1147) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`NESTS:val39`](../../DataEntry/NESTS/inspector.R#L1150-L1203) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`NESTS:val40`](../../DataEntry/NESTS/inspector.R#L1206-L1268) | photo_end must not precede photo_start. | photo_end must not precede photo_start. |
| [`NESTS:val41`](../../DataEntry/NESTS/inspector.R#L1271-L1409) | The first chronological nest event must use nest_state S or F. | The first chronological nest event must use nest_state S or F. |
| [`NESTS:val42`](../../DataEntry/NESTS/inspector.R#L1412-L1551) | A first nest event with clutch_size 0 must use nest_state S. | A first nest event with clutch_size 0 must use nest_state S. |
| [`NESTS:val43`](../../DataEntry/NESTS/inspector.R#L1554-L1689) | The first nest event for a nest_id must record gps_id. | The first nest event for a nest_id must record gps_id. |
| [`NESTS:val44`](../../DataEntry/NESTS/inspector.R#L1692-L1827) | The first nest event for a nest_id must record gps_point. | The first nest event for a nest_id must record gps_point. |
| [`NESTS:val45`](../../DataEntry/NESTS/inspector.R#L1830-L1972) | Each nest_id may contain only one nest_state F event. | Each nest_id may contain only one nest_state F event. |
| [`NESTS:val46`](../../DataEntry/NESTS/inspector.R#L1975-L2112) | Only the first chronological event for a nest_id may record gps_id. | Only the first chronological event for a nest_id may record gps_id. |
| [`NESTS:val47`](../../DataEntry/NESTS/inspector.R#L2115-L2248) | Only the first chronological event for a nest_id may record gps_point. | Only the first chronological event for a nest_id may record gps_point. |
| [`NESTS:val48`](../../DataEntry/NESTS/inspector.R#L2251-L2447) | Check start state sequence. | F<br>After nest_state F, subsequent visits may use only I, H, pP, P, pD, D, notA, or O.<br>S |
| [`NESTS:val49`](../../DataEntry/NESTS/inspector.R#L2450-L2677) | Check terminal notA. | notA must be the final visit and can only follow S, F, H, pD, pP, P, or D.<br>When paired with D, notA may use the same timestamp but must not occur before D.<br>Terminal H permits only final notA; pre-closure checks allow pP/P/D/pD. |
| [`NESTS:val50`](../../DataEntry/NESTS/inspector.R#L2680-L2796) | Check notA inactive row. | notA rows must leave hatch_state blank.<br>notA rows must set clutch_size to 0 unless they immediately follow a D row<br>in the same submission and retain that D row's clutch_size. |
| [`NESTS:val51`](../../DataEntry/NESTS/inspector.R#L2799-L2976) | Check hatch progression. | Hatch-state progression cannot move backward. |
| [`NESTS:val52`](../../DataEntry/NESTS/inspector.R#L2979-L3279) | Check photo numbers unique. | Photo range overlaps another event; sharing allowed within one age-C H brood session. |
| [`NESTS:val53`](../../DataEntry/NESTS/inspector.R#L3282-L3439) | Check NEST in use. | nest_id tally <br>%02d<br> already used; no free two-digit tally for this GPS. |

## OBSERVERS

| Check ID | What it checks | Example messages |
| --- | --- | --- |
| [`OBSERVERS:val1`](../../DataEntry/OBSERVERS/inspector.R#L3-L8) | Check observer initials. | Use 2–3 uppercase letters or digits. |
| [`OBSERVERS:val2`](../../DataEntry/OBSERVERS/inspector.R#L11-L38) | Check start date. | Use YYYY-MM-DD. |
| [`OBSERVERS:val3`](../../DataEntry/OBSERVERS/inspector.R#L41-L68) | Check stop date. | Use YYYY-MM-DD. |
| [`OBSERVERS:val4`](../../DataEntry/OBSERVERS/inspector.R#L71-L115) | Check gps id. | Use integers 1–255, comma-separated if multiple. |
| [`OBSERVERS:val5`](../../DataEntry/OBSERVERS/inspector.R#L118-L147) | Check observer start and stop order. | start must not follow stop. |
| [`OBSERVERS:val6`](../../DataEntry/OBSERVERS/inspector.R#L150-L179) | Require a unique observer code. | Duplicate observer code. |

## RESIGHTINGS

| Check ID | What it checks | Example messages |
| --- | --- | --- |
| [`RESIGHTINGS:val1`](../../DataEntry/RESIGHTINGS/inspector.R#L3-L14) | Required. | Required. |
| [`RESIGHTINGS:val2`](../../DataEntry/RESIGHTINGS/inspector.R#L17-L53) | H-class resighting fields must be present. | H-class resighting fields must be present. |
| [`RESIGHTINGS:val3`](../../DataEntry/RESIGHTINGS/inspector.R#L56-L100) | Required resighting fields and links. | Class H requires both GPS fields, including with nest_id.<br>Negative nest_id requires gps_id and gps_point.<br>Enter gps_id and gps_point without a positive nest link. |
| [`RESIGHTINGS:val4`](../../DataEntry/RESIGHTINGS/inspector.R#L103-L147) | Required resighting fields and links. | Class H requires both GPS fields, including with nest_id.<br>Negative nest_id requires gps_id and gps_point.<br>Enter gps_id and gps_point without a positive nest link. |
| [`RESIGHTINGS:val5`](../../DataEntry/RESIGHTINGS/inspector.R#L150-L186) | Enter both GPS fields or neither; usually blank for positive nests. | Enter both GPS fields or neither; usually blank for positive nests. |
| [`RESIGHTINGS:val6`](../../DataEntry/RESIGHTINGS/inspector.R#L189-L215) | Required. | Required. |
| [`RESIGHTINGS:val7`](../../DataEntry/RESIGHTINGS/inspector.R#L218-L239) | Enter at least one leg mark. | Enter at least one leg mark. |
| [`RESIGHTINGS:val8`](../../DataEntry/RESIGHTINGS/inspector.R#L242-L278) | H chick: UR = M requires blank UL. | H chick: UR = M requires blank UL. |
| [`RESIGHTINGS:val9`](../../DataEntry/RESIGHTINGS/inspector.R#L281-L317) | H chick: blank UR requires UL = M. | H chick: blank UR requires UL = M. |
| [`RESIGHTINGS:val10`](../../DataEntry/RESIGHTINGS/inspector.R#L320-L357) | H chick: single LL colour requires blank LR. | H chick: single LL colour requires blank LR. |
| [`RESIGHTINGS:val11`](../../DataEntry/RESIGHTINGS/inspector.R#L360-L397) | H chick: blank LL requires one LR colour (B/G/R/O/W/L/Y). | H chick: blank LL requires one LR colour (B/G/R/O/W/L/Y). |
| [`RESIGHTINGS:val12`](../../DataEntry/RESIGHTINGS/inspector.R#L400-L422) | Require a ring for each hiding-photo chick. | Class H requires ring. |
| [`RESIGHTINGS:val13`](../../DataEntry/RESIGHTINGS/inspector.R#L425-L452) | Check the field-season dates. | Use a date in the 2026–2027 season. |
| [`RESIGHTINGS:val14`](../../DataEntry/RESIGHTINGS/inspector.R#L455-L537) | Require an earlier nest record for positive links. | nest_id requires a same-day-or-earlier NESTS F, I, or H event. |
| [`RESIGHTINGS:val15`](../../DataEntry/RESIGHTINGS/inspector.R#L540-L571) | Check photo metadata against resighting class. | When cam_id, photo_start, and photo_end are entered, rclass must be V, P, or H. |
| [`RESIGHTINGS:val16`](../../DataEntry/RESIGHTINGS/inspector.R#L574-L644) | Check that the GPS pair has been uploaded. | GPS pair unverified; check the gpxui upload.<br>GPS pair missing from GPS_POINTS; upload via gpxui. |
| [`RESIGHTINGS:val17`](../../DataEntry/RESIGHTINGS/inspector.R#L647-L692) | Check the site code. | Invalid site code. |
| [`RESIGHTINGS:val18`](../../DataEntry/RESIGHTINGS/inspector.R#L695-L749) | Keep the validation flag blank. | FALCON upload must be blank, 0, or 1.<br>Leave blank. |
| [`RESIGHTINGS:val19`](../../DataEntry/RESIGHTINGS/inspector.R#L752-L791) | Check the observer is active on the resighting date. | Observer missing or inactive on resighting date. |
| [`RESIGHTINGS:val20`](../../DataEntry/RESIGHTINGS/inspector.R#L794-L818) | Check the resighting class. | Use R, V, P, C, or H. |
| [`RESIGHTINGS:val21`](../../DataEntry/RESIGHTINGS/inspector.R#L821-L831) | Use M, MU, F, FU, or U. | Use M, MU, F, FU, or U. |
| [`RESIGHTINGS:val22`](../../DataEntry/RESIGHTINGS/inspector.R#L834-L844) | Use A, J, or C. | Use A, J, or C. |
| [`RESIGHTINGS:val23`](../../DataEntry/RESIGHTINGS/inspector.R#L847-L861) | Chick and juvenile resightings must use sex U. | Chick and juvenile resightings must use sex U. |
| [`RESIGHTINGS:val24`](../../DataEntry/RESIGHTINGS/inspector.R#L864-L880) | Class H requires age C. | Class H requires age C. |
| [`RESIGHTINGS:val25`](../../DataEntry/RESIGHTINGS/inspector.R#L883-L945) | Check behaviour codes against age. | Chick and juvenile resightings can only use OB, FT, AT, LF, RS, FF, FA, FC, or PR. |
| [`RESIGHTINGS:val26`](../../DataEntry/RESIGHTINGS/inspector.R#L948-L1011) | Check the nest or brood identifier. | CR<br>Cass River nest_id must use plot + gps_id + sequence, e.g. B0112 or -B0203.<br>Use species prefix + 4 digits, e.g. BA0804 or -BA0804. |
| [`RESIGHTINGS:val27`](../../DataEntry/RESIGHTINGS/inspector.R#L1014-L1534) | Check nest links for adult and chick observations. | See source for constructed messages. |
| [`RESIGHTINGS:val28`](../../DataEntry/RESIGHTINGS/inspector.R#L1537-L1647) | Check incubation links against the latest nest state. | Adult IN/NM requires nest_id with latest state F, I, or H. |
| [`RESIGHTINGS:val29`](../../DataEntry/RESIGHTINGS/inspector.R#L1650-L1782) | Require linked parent and chick observations. | Add a same-session age-A BC/FC/AC parent with matching nest_id or GPS pair.<br>Add one class-R row per chick with observed band and the parent’s GPS pair; ring optional. |
| [`RESIGHTINGS:val30`](../../DataEntry/RESIGHTINGS/inspector.R#L1785-L1944) | Check brood links and GPS after nest closure. | BC/FC/AC requires nest_id with latest state H or notA.<br>After notA, enter both GPS fields for parent/chick links. |
| [`RESIGHTINGS:val31`](../../DataEntry/RESIGHTINGS/inspector.R#L1947-L2210) | Check observations against earlier death records. | This combo was already recorded dead in CAPTURES before this resighting date. |
| [`RESIGHTINGS:val32`](../../DataEntry/RESIGHTINGS/inspector.R#L2213-L2257) | rclass V, P, and H require cam_id, photo_start, and photo_end. | rclass V, P, and H require cam_id, photo_start, and photo_end. |
| [`RESIGHTINGS:val33`](../../DataEntry/RESIGHTINGS/inspector.R#L2260-L2304) | rclass V, P, and H require cam_id, photo_start, and photo_end. | rclass V, P, and H require cam_id, photo_start, and photo_end. |
| [`RESIGHTINGS:val34`](../../DataEntry/RESIGHTINGS/inspector.R#L2307-L2351) | rclass V, P, and H require cam_id, photo_start, and photo_end. | rclass V, P, and H require cam_id, photo_start, and photo_end. |
| [`RESIGHTINGS:val35`](../../DataEntry/RESIGHTINGS/inspector.R#L2354-L2401) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`RESIGHTINGS:val36`](../../DataEntry/RESIGHTINGS/inspector.R#L2404-L2451) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`RESIGHTINGS:val37`](../../DataEntry/RESIGHTINGS/inspector.R#L2454-L2501) | Enter cam_id, photo_start, and photo_end together. | Enter cam_id, photo_start, and photo_end together. |
| [`RESIGHTINGS:val38`](../../DataEntry/RESIGHTINGS/inspector.R#L2504-L2575) | End photo filenames with digits. | End photo filenames with digits. |
| [`RESIGHTINGS:val39`](../../DataEntry/RESIGHTINGS/inspector.R#L2578-L2651) | photo_end must not precede photo_start. | photo_end must not precede photo_start. |
| [`RESIGHTINGS:val40`](../../DataEntry/RESIGHTINGS/inspector.R#L2654-L2934) | Check photo ranges for reuse. | Photo range overlaps another event; sharing allowed within one age-C H brood session. |
| [`RESIGHTINGS:val41`](../../DataEntry/RESIGHTINGS/inspector.R#L2937-L2942) | Check observer initials. | Use 2–3 uppercase letters or digits. |
| [`RESIGHTINGS:val42`](../../DataEntry/RESIGHTINGS/inspector.R#L2945-L2962) | Check gps_id is numeric. | GPS ID must be a positive whole number. |
| [`RESIGHTINGS:val43`](../../DataEntry/RESIGHTINGS/inspector.R#L2965-L2983) | Check the gps_id range. | GPS ID must be a positive whole number. |
| [`RESIGHTINGS:val44`](../../DataEntry/RESIGHTINGS/inspector.R#L2986-L3007) | Require a whole number for gps_id. | GPS ID must be a positive whole number. |
| [`RESIGHTINGS:val45`](../../DataEntry/RESIGHTINGS/inspector.R#L3010-L3028) | Check gps_point is numeric. | GPS point must be a positive whole number. |
| [`RESIGHTINGS:val46`](../../DataEntry/RESIGHTINGS/inspector.R#L3031-L3054) | Check the gps_point range. | GPS point must be a positive whole number. |
| [`RESIGHTINGS:val47`](../../DataEntry/RESIGHTINGS/inspector.R#L3057-L3079) | Require a whole number for gps_point. | GPS point must be a positive whole number. |
| [`RESIGHTINGS:val48`](../../DataEntry/RESIGHTINGS/inspector.R#L3082-L3109) | Check date format. | Use YYYY-MM-DD. |
| [`RESIGHTINGS:val49`](../../DataEntry/RESIGHTINGS/inspector.R#L3112-L3123) | Check left tibia format. | Invalid left-tibia code. |
| [`RESIGHTINGS:val50`](../../DataEntry/RESIGHTINGS/inspector.R#L3126-L3137) | Check left tarsus format. | Invalid left-tarsus code. |
| [`RESIGHTINGS:val51`](../../DataEntry/RESIGHTINGS/inspector.R#L3140-L3151) | Check right tibia format. | Invalid right-tibia code. |
| [`RESIGHTINGS:val52`](../../DataEntry/RESIGHTINGS/inspector.R#L3154-L3165) | Check right tarsus format. | Invalid right-tarsus code. |
| [`RESIGHTINGS:val53`](../../DataEntry/RESIGHTINGS/inspector.R#L3168-L3228) | Check behaviour tokens. | Use valid comma-separated behaviour codes. |
| [`RESIGHTINGS:val54`](../../DataEntry/RESIGHTINGS/inspector.R#L3231-L3236) | Check camera id format. | Use a valid 2–3-character camera ID. |
| [`RESIGHTINGS:val55`](../../DataEntry/RESIGHTINGS/inspector.R#L3239-L3281) | Check photo filename format. | Invalid photo filename. |
| [`RESIGHTINGS:val56`](../../DataEntry/RESIGHTINGS/inspector.R#L3284-L3322) | Check hiding-photo chick ring format. | H chick ring: CP plus 5 digits, optional dash. |
| [`RESIGHTINGS:val57`](../../DataEntry/RESIGHTINGS/inspector.R#L3325-L3394) | Match hiding-photo chick rings to captures. | H chick ring unverified; use a CP ring recorded in CAPTURES.<br>H chick ring missing from CAPTURES; check ring or add capture. |

## RESIGHTINGS_PUBLIC

| Check ID | What it checks | Example messages |
| --- | --- | --- |
| [`RESIGHTINGS_PUBLIC:val1`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L3-L13) | Required. | Required. |
| [`RESIGHTINGS_PUBLIC:val2`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L16-L30) | Enter at least one leg mark. | Enter at least one leg mark. |
| [`RESIGHTINGS_PUBLIC:val3`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L33-L46) | Check the field-season dates. | Use a date in the 2026–2027 season. |
| [`RESIGHTINGS_PUBLIC:val4`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L49-L60) | Restrict public observations to BADO. | Use BADO. |
| [`RESIGHTINGS_PUBLIC:val5`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L63-L71) | Check the observation time. | Use hh:mm. |
| [`RESIGHTINGS_PUBLIC:val6`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L74-L77) | Check species allowed codes. | Invalid code. |
| [`RESIGHTINGS_PUBLIC:val7`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L80-L83) | Check sex allowed codes. | Invalid code. |
| [`RESIGHTINGS_PUBLIC:val8`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L86-L89) | Check country allowed codes. | Invalid code. |
| [`RESIGHTINGS_PUBLIC:val9`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L92-L96) | Check site allowed codes. | Invalid code. |
| [`RESIGHTINGS_PUBLIC:val10`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L99-L102) | Check falcon upload allowed codes. | Invalid code. |
| [`RESIGHTINGS_PUBLIC:val11`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L105-L118) | Check date format. | Use YYYY-MM-DD. |
| [`RESIGHTINGS_PUBLIC:val12`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L121-L129) | Check latitude is numeric. | Use decimal degrees from -90 to 90. |
| [`RESIGHTINGS_PUBLIC:val13`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L132-L143) | Check the latitude range. | Use decimal degrees from -90 to 90. |
| [`RESIGHTINGS_PUBLIC:val14`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L146-L154) | Check longitude is numeric. | Use decimal degrees from -180 to 180. |
| [`RESIGHTINGS_PUBLIC:val15`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L157-L168) | Check the longitude range. | Use decimal degrees from -180 to 180. |
| [`RESIGHTINGS_PUBLIC:val16`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L171-L184) | Check easting numeric. | Easting must be numeric. |
| [`RESIGHTINGS_PUBLIC:val17`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L187-L200) | Check northing numeric. | Northing must be numeric. |
| [`RESIGHTINGS_PUBLIC:val18`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L203-L209) | Check left tibia. | Invalid left-tibia code. |
| [`RESIGHTINGS_PUBLIC:val19`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L212-L218) | Check left tarsus. | Invalid left-tarsus code. |
| [`RESIGHTINGS_PUBLIC:val20`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L221-L227) | Check right tibia. | Invalid right-tibia code. |
| [`RESIGHTINGS_PUBLIC:val21`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L230-L236) | Check right tarsus. | Invalid right-tarsus code. |
| [`RESIGHTINGS_PUBLIC:val22`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L239-L265) | Check behaviour codes. | Use valid comma-separated behaviour codes. |
| [`RESIGHTINGS_PUBLIC:val23`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L268-L276) | Check num_photos is numeric. | Use a non-negative integer. |
| [`RESIGHTINGS_PUBLIC:val24`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L279-L290) | Check the num_photos range. | Use a non-negative integer. |
| [`RESIGHTINGS_PUBLIC:val25`](../../DataEntry/RESIGHTINGS_PUBLIC/inspector.R#L293-L304) | Require a whole number for num_photos. | Use a non-negative integer. |
