/*
  Metadata-only field-entry comment patch for FIELD_2026_BADOatNZ.

  This file is intentionally separate from main_tables.SQL. It does not create
  tables, change column types, change defaults, change indexes, update records,
  or reset the database. It updates only the comments for the fixed allowlist
  below, so the portal can stop advertising retired NO_NEST entry hints and
  can describe the current age-C H and RESIGHTINGS tag/spacer rules.

  Manual application only. Run with the SQL client set to stop on error, save
  the rollback_sql result before continuing, and apply in a quiet window. The
  script requires the selected database to be FIELD_2026_BADOatNZ and fails
  before any ALTER TABLE if the target metadata is missing or unsupported.

  Every target must remain an ordinary nullable, DEFAULT NULL, non-generated,
  non-extra column. The ALTER statements reconstruct the actual COLUMN_TYPE,
  character set, and collation read from information_schema, then change only
  COLUMN_COMMENT. ALGORITHM=INSTANT and LOCK=NONE are required; unsupported
  engines or metadata locks must produce an error rather than silently falling
  back to a table-copy operation. ALTER TABLE is not transactional: run this
  only in a quiet window, save the emitted rollback_sql statements first, and
  stop for manual rollback if the final verification reports FAIL.
*/

SET SESSION lock_wait_timeout = 30;
SET @field_entry_comment_old_group_concat_max_len := @@SESSION.group_concat_max_len;
SET SESSION group_concat_max_len = 65535;

/*
  Fixed target allowlist. Keep this list explicit; do not turn this file into a
  general schema generator.
*/
SET @field_entry_comment_target_count := 13;

/*
  All-target preflight. The selected database, target existence, basic type,
  nullability/default contract, generated-column state, and EXTRA metadata are
  checked before any ALTER TABLE is prepared or executed.
*/
SET @field_entry_comment_preflight_bad :=
(
  SELECT
    CASE
      WHEN COALESCE(DATABASE(), '') <> 'FIELD_2026_BADOatNZ' THEN 1
      ELSE 0
    END
    + SUM(
        CASE
          WHEN c.COLUMN_NAME IS NULL
            OR c.DATA_TYPE <> targets.expected_data_type
            OR c.IS_NULLABLE <> 'YES'
            OR NOT (
              c.COLUMN_DEFAULT IS NULL
              OR UPPER(TRIM(CAST(c.COLUMN_DEFAULT AS CHAR))) = 'NULL'
            )
            OR COALESCE(c.EXTRA, '') <> ''
            OR COALESCE(c.IS_GENERATED, 'NEVER') <> 'NEVER'
          THEN 1
          ELSE 0
        END
      )
  FROM
  (
    SELECT 'CAPTURES' AS table_name, 'nest_id' AS column_name, 'varchar' AS expected_data_type
    UNION ALL SELECT 'CAPTURES', 'gps_id', 'tinyint'
    UNION ALL SELECT 'CAPTURES', 'gps_point', 'int'
    UNION ALL SELECT 'EGGS', 'nest_id', 'varchar'
    UNION ALL SELECT 'NESTS', 'nest_id', 'varchar'
    UNION ALL SELECT 'RESIGHTINGS', 'gps_id', 'tinyint'
    UNION ALL SELECT 'RESIGHTINGS', 'gps_point', 'int'
    UNION ALL SELECT 'RESIGHTINGS', 'rclass', 'enum'
    UNION ALL SELECT 'RESIGHTINGS', 'UR', 'varchar'
    UNION ALL SELECT 'RESIGHTINGS', 'ring', 'varchar'
    UNION ALL SELECT 'RESIGHTINGS', 'nest_id', 'varchar'
    UNION ALL SELECT 'RESIGHTINGS', 'photo_start', 'varchar'
    UNION ALL SELECT 'RESIGHTINGS', 'photo_end', 'varchar'
  ) targets
  LEFT JOIN information_schema.COLUMNS c
    ON c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
   AND c.TABLE_NAME = targets.table_name
   AND c.COLUMN_NAME = targets.column_name
);

/* Show the complete preflight result for manual review. */
SELECT
  targets.table_name,
  targets.column_name,
  targets.expected_data_type,
  c.COLUMN_TYPE,
  c.IS_NULLABLE,
  c.COLUMN_DEFAULT,
  c.EXTRA,
  c.IS_GENERATED,
  CASE
    WHEN COALESCE(DATABASE(), '') <> 'FIELD_2026_BADOatNZ'
      THEN 'FAIL: select FIELD_2026_BADOatNZ before running this script'
    WHEN c.COLUMN_NAME IS NULL
      THEN 'FAIL: target column is missing'
    WHEN c.DATA_TYPE <> targets.expected_data_type
      THEN 'FAIL: unexpected data type'
    WHEN c.IS_NULLABLE <> 'YES'
      THEN 'FAIL: target is not nullable'
    WHEN NOT (
      c.COLUMN_DEFAULT IS NULL
      OR UPPER(TRIM(CAST(c.COLUMN_DEFAULT AS CHAR))) = 'NULL'
    )
      THEN 'FAIL: target default is not NULL'
    WHEN COALESCE(c.EXTRA, '') <> ''
      THEN 'FAIL: target has EXTRA metadata'
    WHEN COALESCE(c.IS_GENERATED, 'NEVER') <> 'NEVER'
      THEN 'FAIL: target is generated'
    ELSE 'PASS'
  END AS preflight_status
FROM
(
  SELECT 'CAPTURES' AS table_name, 'nest_id' AS column_name, 'varchar' AS expected_data_type
  UNION ALL SELECT 'CAPTURES', 'gps_id', 'tinyint'
  UNION ALL SELECT 'CAPTURES', 'gps_point', 'int'
  UNION ALL SELECT 'EGGS', 'nest_id', 'varchar'
  UNION ALL SELECT 'NESTS', 'nest_id', 'varchar'
  UNION ALL SELECT 'RESIGHTINGS', 'gps_id', 'tinyint'
  UNION ALL SELECT 'RESIGHTINGS', 'gps_point', 'int'
  UNION ALL SELECT 'RESIGHTINGS', 'rclass', 'enum'
  UNION ALL SELECT 'RESIGHTINGS', 'UR', 'varchar'
  UNION ALL SELECT 'RESIGHTINGS', 'ring', 'varchar'
  UNION ALL SELECT 'RESIGHTINGS', 'nest_id', 'varchar'
  UNION ALL SELECT 'RESIGHTINGS', 'photo_start', 'varchar'
  UNION ALL SELECT 'RESIGHTINGS', 'photo_end', 'varchar'
) targets
LEFT JOIN information_schema.COLUMNS c
  ON c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
 AND c.TABLE_NAME = targets.table_name
 AND c.COLUMN_NAME = targets.column_name
ORDER BY targets.table_name, c.ORDINAL_POSITION;

/*
  This deliberate PREPARE error stops normal SQL clients before any ALTER when
  the all-target preflight fails. Each later table statement also becomes a
  harmless SELECT 1 when the guard is false, protecting clients that continue
  after an error instead of stopping on error.
*/
SET @field_entry_comment_guard_sql := IF(
  @field_entry_comment_preflight_bad = 0,
  'SELECT ''field-entry comment preflight passed'' AS status',
  'THIS IS AN INTENTIONAL FIELD-ENTRY COMMENT PREFLIGHT FAILURE'
);
PREPARE field_entry_comment_guard_stmt FROM @field_entry_comment_guard_sql;
EXECUTE field_entry_comment_guard_stmt;
DEALLOCATE PREPARE field_entry_comment_guard_stmt;

/*
  Save these result rows before applying the patch. They restore the original
  comments only; the actual type, charset, collation, nullability, and default
  are read from the current metadata so the rollback remains metadata-only.
*/
SELECT
  CONCAT(
    'ALTER TABLE `', c.TABLE_SCHEMA, '`.`', c.TABLE_NAME,
    '` MODIFY COLUMN `', c.COLUMN_NAME, '` ',
    c.COLUMN_TYPE,
    CASE
      WHEN c.CHARACTER_SET_NAME IS NULL THEN ''
      ELSE CONCAT(' CHARACTER SET ', c.CHARACTER_SET_NAME)
    END,
    CASE
      WHEN c.COLLATION_NAME IS NULL THEN ''
      ELSE CONCAT(' COLLATE ', c.COLLATION_NAME)
    END,
    ' NULL DEFAULT NULL COMMENT ',
    QUOTE(COALESCE(c.COLUMN_COMMENT, '')),
    ', ALGORITHM=INSTANT, LOCK=NONE;'
  ) AS rollback_sql
FROM
(
  SELECT 'CAPTURES' AS table_name, 'nest_id' AS column_name
  UNION ALL SELECT 'CAPTURES', 'gps_id'
  UNION ALL SELECT 'CAPTURES', 'gps_point'
  UNION ALL SELECT 'EGGS', 'nest_id'
  UNION ALL SELECT 'NESTS', 'nest_id'
  UNION ALL SELECT 'RESIGHTINGS', 'gps_id'
  UNION ALL SELECT 'RESIGHTINGS', 'gps_point'
  UNION ALL SELECT 'RESIGHTINGS', 'rclass'
  UNION ALL SELECT 'RESIGHTINGS', 'UR'
  UNION ALL SELECT 'RESIGHTINGS', 'ring'
  UNION ALL SELECT 'RESIGHTINGS', 'nest_id'
  UNION ALL SELECT 'RESIGHTINGS', 'photo_start'
  UNION ALL SELECT 'RESIGHTINGS', 'photo_end'
) targets
JOIN information_schema.COLUMNS c
  ON c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
 AND c.TABLE_NAME = targets.table_name
 AND c.COLUMN_NAME = targets.column_name
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

/*
  Build one ALTER per table from the actual metadata. These statements modify
  comments only and preserve each target's live type, charset, and collation.
*/
SET @field_entry_comment_captures_sql := IF(
  @field_entry_comment_preflight_bad = 0,
  (
    SELECT CONCAT(
      'ALTER TABLE `FIELD_2026_BADOatNZ`.`CAPTURES` ',
      GROUP_CONCAT(
        CONCAT(
          'MODIFY COLUMN `', c.COLUMN_NAME, '` ',
          c.COLUMN_TYPE,
          CASE
            WHEN c.CHARACTER_SET_NAME IS NULL THEN ''
            ELSE CONCAT(' CHARACTER SET ', c.CHARACTER_SET_NAME)
          END,
          CASE
            WHEN c.COLLATION_NAME IS NULL THEN ''
            ELSE CONCAT(' COLLATE ', c.COLLATION_NAME)
          END,
          ' NULL DEFAULT NULL COMMENT ',
          QUOTE(
            CASE c.COLUMN_NAME
              WHEN 'nest_id' THEN 'Nest or brood association: <br> a positive ID identifies a real nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> A <b>negative</b> ID (e.g., -A0203, -BA0202) identifies a mobile brood of unknown origin: it has no NESTS or EGGS row. For a negative ID, record both gps_id and gps_point and enter each observed/captured individual as a separate event. <br> For an adult capture unrelated to any nest or brood, leave nest_id blank and record a complete gps_id/gps_point pair. Do not use a sentinel for an unknown or unresolved association; negative brood IDs are for known mobile broods, not missing information.'
              WHEN 'gps_id' THEN 'Handheld Garmin GPS ID. Required together with gps_point for a negative brood ID, an adult capture with chicks recorded in caught_with, an age-C capture with capture_status R or C even when nest_id is positive, or an unrelated adult capture with nest_id blank. For an age-C first capture at a positive nest, direct GPS may remain blank where the protocol permits it.'
              WHEN 'gps_point' THEN 'Waypoint number of the capture location stored in your handheld Garmin GPS unit. Required together with gps_id for a negative brood ID, an adult capture with chicks recorded in caught_with, an age-C capture with capture_status R or C even when nest_id is positive, or an unrelated adult capture with nest_id blank. For an age-C first capture at a positive nest, direct GPS may remain blank where the protocol permits it.'
            END
          )
        )
        ORDER BY c.ORDINAL_POSITION
        SEPARATOR ', '
      ),
      ', ALGORITHM=INSTANT, LOCK=NONE'
    )
    FROM information_schema.COLUMNS c
    WHERE c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND c.TABLE_NAME = 'CAPTURES'
      AND c.COLUMN_NAME IN ('nest_id', 'gps_id', 'gps_point')
  ),
  'SELECT 1'
);

/* The four table statements are intentionally executed separately. */
PREPARE field_entry_comment_captures_stmt FROM @field_entry_comment_captures_sql;
EXECUTE field_entry_comment_captures_stmt;
DEALLOCATE PREPARE field_entry_comment_captures_stmt;

SET @field_entry_comment_eggs_sql := IF(
  @field_entry_comment_preflight_bad = 0,
  (
    SELECT CONCAT(
      'ALTER TABLE `FIELD_2026_BADOatNZ`.`EGGS` MODIFY COLUMN `',
      c.COLUMN_NAME, '` ', c.COLUMN_TYPE,
      CASE WHEN c.CHARACTER_SET_NAME IS NULL THEN '' ELSE CONCAT(' CHARACTER SET ', c.CHARACTER_SET_NAME) END,
      CASE WHEN c.COLLATION_NAME IS NULL THEN '' ELSE CONCAT(' COLLATE ', c.COLLATION_NAME) END,
      ' NULL DEFAULT NULL COMMENT ',
      QUOTE('Positive ID of the real nest/scrape where this egg belongs (SXXYY; e.g., A0203 or BA0202). <br> Negative brood IDs are not valid in EGGS because broods of unknown origin have no egg history; record their events in CAPTURES or RESIGHTINGS. Do not enter a sentinel for a missing nest association.'),
      ', ALGORITHM=INSTANT, LOCK=NONE'
    )
    FROM information_schema.COLUMNS c
    WHERE c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND c.TABLE_NAME = 'EGGS'
      AND c.COLUMN_NAME = 'nest_id'
  ),
  'SELECT 1'
);
PREPARE field_entry_comment_eggs_stmt FROM @field_entry_comment_eggs_sql;
EXECUTE field_entry_comment_eggs_stmt;
DEALLOCATE PREPARE field_entry_comment_eggs_stmt;

SET @field_entry_comment_nests_sql := IF(
  @field_entry_comment_preflight_bad = 0,
  (
    SELECT CONCAT(
      'ALTER TABLE `FIELD_2026_BADOatNZ`.`NESTS` MODIFY COLUMN `',
      c.COLUMN_NAME, '` ', c.COLUMN_TYPE,
      CASE WHEN c.CHARACTER_SET_NAME IS NULL THEN '' ELSE CONCAT(' CHARACTER SET ', c.CHARACTER_SET_NAME) END,
      CASE WHEN c.COLLATION_NAME IS NULL THEN '' ELSE CONCAT(' COLLATE ', c.COLLATION_NAME) END,
      ' NULL DEFAULT NULL COMMENT ',
      QUOTE('Positive ID of a real stationary nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> Negative brood IDs are not valid in NESTS because a brood of unknown origin has no nest record; record its events in CAPTURES or RESIGHTINGS with direct GPS. Do not enter a sentinel for a missing nest association.'),
      ', ALGORITHM=INSTANT, LOCK=NONE'
    )
    FROM information_schema.COLUMNS c
    WHERE c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND c.TABLE_NAME = 'NESTS'
      AND c.COLUMN_NAME = 'nest_id'
  ),
  'SELECT 1'
);
PREPARE field_entry_comment_nests_stmt FROM @field_entry_comment_nests_sql;
EXECUTE field_entry_comment_nests_stmt;
DEALLOCATE PREPARE field_entry_comment_nests_stmt;

SET @field_entry_comment_resightings_sql := IF(
  @field_entry_comment_preflight_bad = 0,
  (
    SELECT CONCAT(
      'ALTER TABLE `FIELD_2026_BADOatNZ`.`RESIGHTINGS` ',
      GROUP_CONCAT(
        CONCAT(
          'MODIFY COLUMN `', c.COLUMN_NAME, '` ',
          c.COLUMN_TYPE,
          CASE WHEN c.CHARACTER_SET_NAME IS NULL THEN '' ELSE CONCAT(' CHARACTER SET ', c.CHARACTER_SET_NAME) END,
          CASE WHEN c.COLLATION_NAME IS NULL THEN '' ELSE CONCAT(' COLLATE ', c.COLLATION_NAME) END,
          ' NULL DEFAULT NULL COMMENT ',
          QUOTE(
            CASE c.COLUMN_NAME
              WHEN 'gps_id' THEN 'Handheld Garmin GPS ID. Required together with gps_point for every new age-C H hiding-spot-photo event, including positive nest IDs, and for negative brood IDs and eligible age-C R/P/V/C family events.'
              WHEN 'gps_point' THEN 'Waypoint number of the resighting location stored in your handheld Garmin GPS unit. Required together with gps_id for every new age-C H hiding-spot-photo event, including positive nest IDs, and for negative brood IDs and eligible age-C R/P/V/C family events.'
              WHEN 'rclass' THEN 'Resighting class: <br> <b>C</b> (failed capture attempt) <br> <b>V</b> (video session) <br> <b>R</b> (regular) <br> <b>P</b> (photography session) <br> <b>H</b> (chick hiding-spot photo session: for a new age-C H event, enter a valid positive nest_id or negative brood ID, the chick ring, paired direct GPS, cam_id, photo_start, and photo_end. A blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry)'
              WHEN 'UR' THEN 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned): <br> <b>X</b> (blank) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> <b>TY</b> (geolocator tag with known yellow spacer; use the actual spacer colour code) <br> <b>T?</b> (geolocator tag with unreadable spacer colour; RESIGHTINGS only; bare <b>T</b> is invalid) <br> FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).'
              WHEN 'ring' THEN 'alpha-numeric code of metal ring assigned to resighted individual (typically for chick with hiding spot photo; rclass H). For a new age-C H event, enter ring together with a valid nest_id, paired direct GPS, cam_id, photo_start, and photo_end.'
              WHEN 'nest_id' THEN 'Nest or brood association: <br> a positive ID identifies a real nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> A <b>negative</b> ID (e.g., -A0203, -BA0202) identifies a mobile brood of unknown origin: it has no NESTS or EGGS row. For a negative ID, record both gps_id and gps_point and enter each observed individual as a separate event. <br> Enter nest_id when a resighting first establishes social parentage at a nest or brood; do not omit it routinely. A new age-C H event must have a valid nest_id explicitly; a blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry. Other approved blank-ID routes are limited to eligible ordinary R/P/V/C family events or the S10 negative-brood parent/chick route resolving through authoritative parent association. Exact validation predicates are maintained by Thread 3.1. Do not use a no-nest sentinel in RESIGHTINGS.'
              WHEN 'photo_start' THEN 'First image filename for this resighting sequence. For a new age-C H event, enter cam_id, photo_start, photo_end, a valid nest_id, the chick ring, and paired direct GPS. A blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry.'
              WHEN 'photo_end' THEN 'Last image filename for this resighting sequence. For a new age-C H event, enter cam_id, photo_start, photo_end, a valid nest_id, the chick ring, and paired direct GPS. A blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry.'
            END
          )
        )
        ORDER BY c.ORDINAL_POSITION
        SEPARATOR ', '
      ),
      ', ALGORITHM=INSTANT, LOCK=NONE'
    )
    FROM information_schema.COLUMNS c
    WHERE c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND c.TABLE_NAME = 'RESIGHTINGS'
      AND c.COLUMN_NAME IN ('gps_id', 'gps_point', 'rclass', 'UR', 'ring', 'nest_id', 'photo_start', 'photo_end')
  ),
  'SELECT 1'
);
PREPARE field_entry_comment_resightings_stmt FROM @field_entry_comment_resightings_sql;
EXECUTE field_entry_comment_resightings_stmt;
DEALLOCATE PREPARE field_entry_comment_resightings_stmt;

SET @field_entry_comment_verification_bad :=
(
  SELECT
    CASE
      WHEN COUNT(*) <> @field_entry_comment_target_count
        OR SUM(
          CASE
            WHEN c.COLUMN_NAME IS NULL
              OR COALESCE(c.COLUMN_COMMENT, '') <> expected.expected_comment
            THEN 1
            ELSE 0
          END
        ) <> 0
      THEN 1
      ELSE 0
    END
  FROM
  (
    SELECT 'CAPTURES' AS table_name, 'nest_id' AS column_name,
      'Nest or brood association: <br> a positive ID identifies a real nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> A <b>negative</b> ID (e.g., -A0203, -BA0202) identifies a mobile brood of unknown origin: it has no NESTS or EGGS row. For a negative ID, record both gps_id and gps_point and enter each observed/captured individual as a separate event. <br> For an adult capture unrelated to any nest or brood, leave nest_id blank and record a complete gps_id/gps_point pair. Do not use a sentinel for an unknown or unresolved association; negative brood IDs are for known mobile broods, not missing information.' AS expected_comment
    UNION ALL SELECT 'CAPTURES', 'gps_id',
      'Handheld Garmin GPS ID. Required together with gps_point for a negative brood ID, an adult capture with chicks recorded in caught_with, an age-C capture with capture_status R or C even when nest_id is positive, or an unrelated adult capture with nest_id blank. For an age-C first capture at a positive nest, direct GPS may remain blank where the protocol permits it.'
    UNION ALL SELECT 'CAPTURES', 'gps_point',
      'Waypoint number of the capture location stored in your handheld Garmin GPS unit. Required together with gps_id for a negative brood ID, an adult capture with chicks recorded in caught_with, an age-C capture with capture_status R or C even when nest_id is positive, or an unrelated adult capture with nest_id blank. For an age-C first capture at a positive nest, direct GPS may remain blank where the protocol permits it.'
    UNION ALL SELECT 'EGGS', 'nest_id',
      'Positive ID of the real nest/scrape where this egg belongs (SXXYY; e.g., A0203 or BA0202). <br> Negative brood IDs are not valid in EGGS because broods of unknown origin have no egg history; record their events in CAPTURES or RESIGHTINGS. Do not enter a sentinel for a missing nest association.'
    UNION ALL SELECT 'NESTS', 'nest_id',
      'Positive ID of a real stationary nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> Negative brood IDs are not valid in NESTS because a brood of unknown origin has no nest record; record its events in CAPTURES or RESIGHTINGS with direct GPS. Do not enter a sentinel for a missing nest association.'
    UNION ALL SELECT 'RESIGHTINGS', 'gps_id',
      'Handheld Garmin GPS ID. Required together with gps_point for every new age-C H hiding-spot-photo event, including positive nest IDs, and for negative brood IDs and eligible age-C R/P/V/C family events.'
    UNION ALL SELECT 'RESIGHTINGS', 'gps_point',
      'Waypoint number of the resighting location stored in your handheld Garmin GPS unit. Required together with gps_id for every new age-C H hiding-spot-photo event, including positive nest IDs, and for negative brood IDs and eligible age-C R/P/V/C family events.'
    UNION ALL SELECT 'RESIGHTINGS', 'rclass',
      'Resighting class: <br> <b>C</b> (failed capture attempt) <br> <b>V</b> (video session) <br> <b>R</b> (regular) <br> <b>P</b> (photography session) <br> <b>H</b> (chick hiding-spot photo session: for a new age-C H event, enter a valid positive nest_id or negative brood ID, the chick ring, paired direct GPS, cam_id, photo_start, and photo_end. A blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry)'
    UNION ALL SELECT 'RESIGHTINGS', 'UR',
      'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned): <br> <b>X</b> (blank) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> <b>TY</b> (geolocator tag with known yellow spacer; use the actual spacer colour code) <br> <b>T?</b> (geolocator tag with unreadable spacer colour; RESIGHTINGS only; bare <b>T</b> is invalid) <br> FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).'
    UNION ALL SELECT 'RESIGHTINGS', 'ring',
      'alpha-numeric code of metal ring assigned to resighted individual (typically for chick with hiding spot photo; rclass H). For a new age-C H event, enter ring together with a valid nest_id, paired direct GPS, cam_id, photo_start, and photo_end.'
    UNION ALL SELECT 'RESIGHTINGS', 'nest_id',
      'Nest or brood association: <br> a positive ID identifies a real nest/scrape (SXXYY; e.g., A0203 or BA0202). <br> A <b>negative</b> ID (e.g., -A0203, -BA0202) identifies a mobile brood of unknown origin: it has no NESTS or EGGS row. For a negative ID, record both gps_id and gps_point and enter each observed individual as a separate event. <br> Enter nest_id when a resighting first establishes social parentage at a nest or brood; do not omit it routinely. A new age-C H event must have a valid nest_id explicitly; a blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry. Other approved blank-ID routes are limited to eligible ordinary R/P/V/C family events or the S10 negative-brood parent/chick route resolving through authoritative parent association. Exact validation predicates are maintained by Thread 3.1. Do not use a no-nest sentinel in RESIGHTINGS.'
    UNION ALL SELECT 'RESIGHTINGS', 'photo_start',
      'First image filename for this resighting sequence. For a new age-C H event, enter cam_id, photo_start, photo_end, a valid nest_id, the chick ring, and paired direct GPS. A blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry.'
    UNION ALL SELECT 'RESIGHTINGS', 'photo_end',
      'Last image filename for this resighting sequence. For a new age-C H event, enter cam_id, photo_start, photo_end, a valid nest_id, the chick ring, and paired direct GPS. A blank raw nest_id is retained only for historical derived-association compatibility and is not permission for new entry.'
  ) expected
  LEFT JOIN information_schema.COLUMNS c
    ON c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
   AND c.TABLE_NAME = expected.table_name
   AND c.COLUMN_NAME = expected.column_name
);

SELECT
  CASE
    WHEN @field_entry_comment_preflight_bad <> 0
    THEN 'FAIL: no ALTER TABLE executed because the preflight failed'
    WHEN @field_entry_comment_verification_bad <> 0
    THEN 'FAIL: metadata verification did not match all 13 expected comments; use the saved rollback_sql statements'
    ELSE 'PASS: field-entry comments updated; no column definitions or records were changed'
  END AS result;

SET SESSION group_concat_max_len = @field_entry_comment_old_group_concat_max_len;
