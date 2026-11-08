-- TEMPORARY PAUSE: run this ENTIRE file in ONE Adminer SQL command.
-- Select FIELD_2026_BADOatNZ and enable Stop on error. Save a fresh backup.
-- Close inspector editors; do not edit inspectors concurrently.
-- Approved hard/warn exports are archived separately and are NOT changed here.
-- Expected starting state: exactly six distinct listed tables, each containing
-- inspector = list() and comments = NULL, required by this compatibility repair.
-- One atomic UPDATE replaces only these placeholders, without DDL or deletions.
-- If the full starting state differs, nothing is updated. Do not force guards.
-- No ROW_COUNT() receipt: Adminer can run intervening statements.

SET SESSION lock_wait_timeout = 15;
SET SESSION innodb_lock_wait_timeout = 15;
SET @pause_session_safe = (@@autocommit = 1 AND @@in_transaction = 0);
SET @pause_code = 'list(try_validator(data.table::data.table(rowid = integer(), variable = character(), reason = character()), nam = "TEMPORARY validation pause"))';
SET @pause_marker = 'LEH temporary validation pause 2026-11-08 hard';

UPDATE FIELD_2026_BADOatNZ.inspectors AS target
JOIN (
    SELECT COUNT(*) AS total_rows,
           COUNT(DISTINCT table_name) AS distinct_tables,
           SUM(CASE WHEN table_name IN (
                 'CAPTURES', 'EGGS', 'NESTS', 'OBSERVERS',
                 'RESIGHTINGS', 'RESIGHTINGS_PUBLIC')
                AND BINARY inspector = BINARY 'list()'
                AND comments IS NULL THEN 1 ELSE 0 END) AS matching_rows
    FROM FIELD_2026_BADOatNZ.inspectors
) AS reviewed
  ON reviewed.total_rows = 6
 AND reviewed.distinct_tables = 6
 AND reviewed.matching_rows = 6
SET target.inspector = @pause_code,
    target.comments = @pause_marker
WHERE COALESCE(DATABASE() = 'FIELD_2026_BADOatNZ', 0) = 1
  AND @pause_session_safe = 1
  AND target.table_name IN ('CAPTURES', 'EGGS', 'NESTS', 'OBSERVERS',
                            'RESIGHTINGS', 'RESIGHTINGS_PUBLIC')
  AND BINARY target.inspector = BINARY 'list()'
  AND target.comments IS NULL
  AND (
    SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND TABLE_NAME = 'inspectors'
      AND TABLE_TYPE = 'BASE TABLE' AND ENGINE = 'InnoDB'
  ) = 1
  AND (
    SELECT COUNT(*) FROM information_schema.TRIGGERS
    WHERE EVENT_OBJECT_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND EVENT_OBJECT_TABLE = 'inspectors'
  ) = 0;

SELECT CASE
         WHEN COALESCE(DATABASE() = 'FIELD_2026_BADOatNZ', 0) = 1
          AND COUNT(*) = 6
          AND COUNT(DISTINCT CASE
                WHEN BINARY inspector = BINARY @pause_code
                 AND BINARY comments = BINARY @pause_marker
                 AND table_name IN ('CAPTURES', 'EGGS', 'NESTS', 'OBSERVERS',
                                    'RESIGHTINGS', 'RESIGHTINGS_PUBLIC')
                THEN table_name END) = 6
           THEN 'PAUSED_6_VERIFIED'
         ELSE 'BLOCKED_OR_UNEXPECTED_STATE_DO_NOT_DELETE_ROWS'
       END AS pause_status,
       COUNT(*) AS total_inspector_rows,
       UTC_TIMESTAMP() AS verified_at_utc
FROM FIELD_2026_BADOatNZ.inspectors;

SELECT table_name, comments, updated_at
FROM FIELD_2026_BADOatNZ.inspectors
WHERE BINARY inspector = BINARY @pause_code
  AND BINARY comments = BINARY @pause_marker
ORDER BY table_name;
