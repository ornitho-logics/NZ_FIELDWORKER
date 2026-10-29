/*
  READ-ONLY generator for six observer-code field-description updates.
  No ALTER is executed by this file. Select FIELD_2026_BADOatNZ in Adminer.
  Require six PASS rows, save the rollback_sql VALUES privately, then copy only
  the six apply_sql VALUES into a new SQL command with Stop on error enabled.
  Adminer's SQL export may save this generating query, not the result values.

  Generated ALTERs preserve actual types/charset/collation/nullability/defaults
  and require INSTANT / LOCK=NONE. Never remove these safeguards to force a
  failure through. These are comment-only DDL; ordinary ROLLBACK cannot undo it.
  QUOTE-based literals require backslash escaping: fail preflight under
  NO_BACKSLASH_ESCAPES, and reassert the inspected session mode in each generated
  command so a new Adminer connection interprets saved comment literals alike.
*/
WITH targets AS (
  SELECT 'OBSERVERS' AS table_name, 'observer' AS column_name,
    'Your registered observer code: two or three uppercase letters or digits (for example AB or P3). Use this same code when entering data.' AS new_comment
  UNION ALL SELECT 'CAPTURES', 'observer',
    'Registered code of the bander: two or three uppercase letters or digits (see OBSERVERS table)'
  UNION ALL SELECT 'CAPTURES', 'observer_upload',
    'Registered code of the person uploading to the database: two or three uppercase letters or digits (see OBSERVERS table)'
  UNION ALL SELECT 'EGGS', 'observer',
    'Registered code of the observer: two or three uppercase letters or digits (see OBSERVERS table)'
  UNION ALL SELECT 'NESTS', 'observer',
    'Registered code of the observer: two or three uppercase letters or digits (see OBSERVERS table)'
  UNION ALL SELECT 'RESIGHTINGS', 'observer',
    'Registered code of the observer: two or three uppercase letters or digits (see OBSERVERS table)'
), checked AS (
  SELECT targets.*, c.COLUMN_TYPE, c.CHARACTER_SET_NAME, c.COLLATION_NAME,
    c.COLUMN_COMMENT,
    COALESCE(DATABASE() = 'FIELD_2026_BADOatNZ'
      AND FIND_IN_SET('NO_BACKSLASH_ESCAPES', @@SESSION.sql_mode) = 0
      AND c.DATA_TYPE = 'varchar' AND c.CHARACTER_MAXIMUM_LENGTH = 3
      AND c.IS_NULLABLE = 'YES'
      AND (c.COLUMN_DEFAULT IS NULL OR UPPER(TRIM(c.COLUMN_DEFAULT)) = 'NULL')
      AND COALESCE(c.EXTRA, '') = ''
      AND COALESCE(c.IS_GENERATED, 'NEVER') = 'NEVER', 0) AS is_safe
  FROM targets LEFT JOIN information_schema.COLUMNS c
    ON c.TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
   AND c.TABLE_NAME = targets.table_name AND c.COLUMN_NAME = targets.column_name
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
  IF(is_safe = 1, 'PASS', 'FAIL: do not apply; inspect target metadata and SQL mode') AS preflight_status,
  IF(is_safe = 1, CONCAT(statement_prefix, QUOTE(new_comment),
    ', ALGORITHM=INSTANT, LOCK=NONE;'), NULL) AS apply_sql,
  IF(is_safe = 1, CONCAT(statement_prefix, QUOTE(COALESCE(COLUMN_COMMENT, '')),
    ', ALGORITHM=INSTANT, LOCK=NONE;'), NULL) AS rollback_sql
FROM statements ORDER BY table_name, column_name;
