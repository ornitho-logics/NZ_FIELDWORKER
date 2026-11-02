/*
  READ-ONLY generator for eight CAPTURES incoming/release leg-field comments.
  Desired comments below are copied verbatim from main_tables.SQL; keep all
  eight synchronized with that source. No ALTER is executed by this file.
  Select FIELD_2026_BADOatNZ in Adminer and execute this complete SELECT.
  Require eight PASS rows. Save rollback_sql RESULT VALUES privately before
  copying only apply_sql RESULT VALUES to a separately authorized SQL command.
  Adminer's export may contain this query rather than the generated values.

  All output commands are withheld unless all eight columns pass exact
  varchar(10), nullable, SQL-NULL-default, and ordinary-column metadata checks.
  Actual charset/collation/type are retained. Generated commands require
  INSTANT / LOCK=NONE and a 30-second metadata-lock wait; do not remove guards.
  Comment-only DDL still commits separately and is not undone by ROLLBACK.
  QUOTE uses backslash escaping: NO_BACKSLASH_ESCAPES fails preflight.
  Each generated command reasserts the inspected SESSION sql_mode so saved
  literals are interpreted consistently on a new connection.
*/
WITH targets AS (
  SELECT 1 AS target_order, 'CAPTURES' AS table_name, 'UL_in' AS column_name,
    'AT CAPTURE/BEFORE HANDLING. F: enter X in all four incoming fields (validator also tolerates blanks). R: complete incoming and identical release marks. C: complete incoming (not all X) and changed release marks. D: all four actual recovered incoming marks; release fields and released time blank. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter)' AS new_comment
  UNION ALL SELECT 2, 'CAPTURES', 'LL_in',
    'AT CAPTURE/BEFORE HANDLING. F: enter X in all four incoming fields (validator also tolerates blanks). R: complete incoming and identical release marks. C: complete incoming (not all X) and changed release marks. D: all four actual recovered incoming marks; release fields and released time blank. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> No flag assigned to tarsi'
  UNION ALL SELECT 3, 'CAPTURES', 'UR_in',
    'AT CAPTURE/BEFORE HANDLING. F: enter X in all four incoming fields (validator also tolerates blanks). R: complete incoming and identical release marks. C: complete incoming (not all X) and changed release marks. D: all four actual recovered incoming marks; release fields and released time blank. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> <b>T</b> (tag; if used, also add spacer band e.g., geolocators are deployed with a "spacer" band above the knee-joint, in this case the spacer is yellow: "TY") <br> FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).'
  UNION ALL SELECT 4, 'CAPTURES', 'LR_in',
    'AT CAPTURE/BEFORE HANDLING. F: enter X in all four incoming fields (validator also tolerates blanks). R: complete incoming and identical release marks. C: complete incoming (not all X) and changed release marks. D: all four actual recovered incoming marks; release fields and released time blank. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> No flag assigned to tarsi.'
  UNION ALL SELECT 5, 'CAPTURES', 'UL',
    'AT RELEASE/AFTER HANDLING. F: actual new marks, not all X. R: complete release marks identical to complete incoming marks. C: complete incoming/release marks with at least one changed position. D: leave all four release fields and released time blank; record recovered marks in incoming fields. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter)'
  UNION ALL SELECT 6, 'CAPTURES', 'LL',
    'AT RELEASE/AFTER HANDLING. F: actual new marks, not all X. R: complete release marks identical to complete incoming marks. C: complete incoming/release marks with at least one changed position. D: leave all four release fields and released time blank; record recovered marks in incoming fields. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> No flag or tag assigned to tarsi.'
  UNION ALL SELECT 7, 'CAPTURES', 'UR',
    'AT RELEASE/AFTER HANDLING. F: actual new marks, not all X. R: complete release marks identical to complete incoming marks. C: complete incoming/release marks with at least one changed position. D: leave all four release fields and released time blank; record recovered marks in incoming fields. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> <b>T</b> (tag; if used, also add spacer band e.g., geolocators are deployed with a "spacer" band above the knee-joint, in this case the spacer is yellow: "TY") <br> FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).'
  UNION ALL SELECT 8, 'CAPTURES', 'LR',
    'AT RELEASE/AFTER HANDLING. F: actual new marks, not all X. R: complete release marks identical to complete incoming marks. C: complete incoming/release marks with at least one changed position. D: leave all four release fields and released time blank; record recovered marks in incoming fields. Never use ? or X for an unreadable mark; code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one band assigned, e.g., YB): <br> <b>X</b> (no mark; not missing) <br> <b>O</b> (orange) <br> <b>Y</b> (yellow) <br> <b>W</b> (white) <br> <b>B</b> (blue) <br> <b>R</b> (red) <br> <b>G</b> (green) <br> <b>L</b> (light green "lime") <br> <b>M</b> (metal) <br> No flag or tag assigned to tarsi.'
), checked AS (
  SELECT targets.*,
    c.COLUMN_TYPE, c.CHARACTER_SET_NAME, c.COLLATION_NAME,
    c.IS_NULLABLE, c.COLUMN_DEFAULT, c.EXTRA, c.IS_GENERATED,
    c.COLUMN_COMMENT,
    COALESCE(
      BINARY DATABASE() = BINARY 'FIELD_2026_BADOatNZ'
      AND FIND_IN_SET('NO_BACKSLASH_ESCAPES', @@SESSION.sql_mode) = 0
      AND t.TABLE_TYPE = 'BASE TABLE' AND t.ENGINE = 'InnoDB'
      AND c.DATA_TYPE = 'varchar'
      AND LOWER(c.COLUMN_TYPE) = 'varchar(10)'
      AND c.CHARACTER_MAXIMUM_LENGTH = 10
      AND c.CHARACTER_SET_NAME IS NOT NULL AND c.COLLATION_NAME IS NOT NULL
      AND c.IS_NULLABLE = 'YES'
      AND (c.COLUMN_DEFAULT IS NULL OR UPPER(TRIM(c.COLUMN_DEFAULT)) = 'NULL')
      AND COALESCE(c.EXTRA, '') = ''
      AND COALESCE(c.IS_GENERATED, 'NEVER') = 'NEVER'
      AND CHAR_LENGTH(targets.new_comment) <= 1024,
      0
    ) AS is_safe
  FROM targets
  /* Literal schema/table predicates let MariaDB prune metadata to CAPTURES,
     avoiding unrelated view expansion; BINARY guards retain exact spelling. */
  LEFT JOIN information_schema.COLUMNS c
    ON c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
   AND c.TABLE_NAME = 'CAPTURES'
   AND BINARY c.TABLE_SCHEMA = BINARY 'FIELD_2026_BADOatNZ'
   AND BINARY c.TABLE_NAME = BINARY targets.table_name
   AND BINARY c.COLUMN_NAME = BINARY targets.column_name
  LEFT JOIN information_schema.TABLES t
    ON t.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
   AND t.TABLE_NAME = 'CAPTURES'
   AND BINARY t.TABLE_SCHEMA = BINARY c.TABLE_SCHEMA
   AND BINARY t.TABLE_NAME = BINARY c.TABLE_NAME
), all_targets AS (
  SELECT CASE WHEN COUNT(*) = 8 AND SUM(is_safe) = 8
    AND COUNT(DISTINCT column_name) = 8 THEN 1 ELSE 0 END AS all_safe
  FROM checked
), statements AS (
  SELECT checked.*,
    CONCAT('SET SESSION sql_mode = ', QUOTE(@@SESSION.sql_mode),
      '; SET SESSION lock_wait_timeout = 30; ALTER TABLE `FIELD_2026_BADOatNZ`.`',
      table_name, '` MODIFY COLUMN `', column_name, '` ', COLUMN_TYPE,
      ' CHARACTER SET ', CHARACTER_SET_NAME, ' COLLATE ', COLLATION_NAME,
      ' NULL DEFAULT NULL COMMENT ') AS statement_prefix
  FROM checked
)
SELECT table_name, column_name,
  CASE
    WHEN is_safe = 0 THEN 'FAIL: inspect target metadata, selected database, and SQL mode'
    WHEN all_safe = 0 THEN 'FAIL: another target failed preflight; no commands generated'
    ELSE 'PASS'
  END AS preflight_status,
  COLUMN_TYPE, CHARACTER_SET_NAME, COLLATION_NAME, IS_NULLABLE, COLUMN_DEFAULT,
  COLUMN_COMMENT AS current_comment, new_comment AS desired_comment,
  IF(all_safe = 1, CONCAT(statement_prefix, QUOTE(new_comment),
    ', ALGORITHM=INSTANT, LOCK=NONE;'), NULL) AS apply_sql,
  IF(all_safe = 1, CONCAT(statement_prefix, QUOTE(COALESCE(COLUMN_COMMENT, '')),
    ', ALGORITHM=INSTANT, LOCK=NONE;'), NULL) AS rollback_sql
FROM statements CROSS JOIN all_targets
ORDER BY target_order;
