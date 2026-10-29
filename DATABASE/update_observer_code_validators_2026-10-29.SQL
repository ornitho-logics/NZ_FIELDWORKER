/*
  Allow two- or three-character uppercase-letter/digit observer codes (e.g. P3).
  Manual installation only; no biological records or column definitions change.
  Export the inspectors table privately before use. Run this WHOLE file in one
  Adminer request with Stop on error enabled and no concurrent inspector edits.

  This deliberately accepts only the five reviewed TABLE_hard rows and exact
  old/new R snippets. Custom, missing, duplicate or differently formatted rows
  cause FAIL with no updates; do not weaken the guard to force installation.
  Re-running after success is safe. The external protocol is not synchronized.
*/
SET SESSION innodb_lock_wait_timeout = 30;
SET @observer_old_call := 'is.regexp_validator(x[, .(observer)], regexp = "^[A-Z]{2,3}$", reason = "Observer initials must use two or three uppercase letters.")';
SET @observer_new_call := 'is.regexp_validator(x[, .(observer)], regexp = "^[A-Z0-9]{2,3}$", reason = "Observer codes must use two or three uppercase letters or digits.")';
SET @observer_upload_old_call := '!grepl("^[A-Z]{2,3}$", raw), .(rowid, variable = "observer_upload", reason = "Observer-upload initials must use two or three uppercase letters.")';
SET @observer_upload_new_call := '!grepl("^[A-Z0-9]{2,3}$", raw), .(rowid, variable = "observer_upload", reason = "Observer-upload codes must use two or three uppercase letters or digits.")';
SET @observer_upload_old_required := 'all capture events require the initials of the observer entering the record to the database';
SET @observer_upload_new_required := 'all capture events require the observer code of the person entering the record to the database';

START TRANSACTION;

/* Lock only inspector configuration rows, never field records. */
SELECT table_name AS locked_inspector
FROM FIELD_2026_BADOatNZ.inspectors
WHERE table_name IN ('OBSERVERS_hard', 'EGGS_hard', 'NESTS_hard',
                     'RESIGHTINGS_hard', 'CAPTURES_hard')
FOR UPDATE;

SET @observer_patch_ready :=
  COALESCE(DATABASE() = 'FIELD_2026_BADOatNZ', 0)
  AND EXISTS (
    SELECT 1 FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'FIELD_2026_BADOatNZ'
      AND TABLE_NAME = 'inspectors' AND TABLE_TYPE = 'BASE TABLE'
      AND ENGINE = 'InnoDB'
  )
  AND (
    SELECT COUNT(*) = 5 AND COUNT(DISTINCT table_name) = 5
      AND SUM(
        CASE WHEN table_name = 'CAPTURES_hard' THEN
          (
            (CHAR_LENGTH(inspector) - CHAR_LENGTH(REPLACE(inspector, @observer_upload_old_call, ''))) / CHAR_LENGTH(@observer_upload_old_call)
            + (CHAR_LENGTH(inspector) - CHAR_LENGTH(REPLACE(inspector, @observer_upload_new_call, ''))) / CHAR_LENGTH(@observer_upload_new_call)
          ) = 1
          AND (
            (CHAR_LENGTH(inspector) - CHAR_LENGTH(REPLACE(inspector, @observer_upload_old_required, ''))) / CHAR_LENGTH(@observer_upload_old_required)
            + (CHAR_LENGTH(inspector) - CHAR_LENGTH(REPLACE(inspector, @observer_upload_new_required, ''))) / CHAR_LENGTH(@observer_upload_new_required)
          ) = 1
        ELSE
          (
            (CHAR_LENGTH(inspector) - CHAR_LENGTH(REPLACE(inspector, @observer_old_call, ''))) / CHAR_LENGTH(@observer_old_call)
            + (CHAR_LENGTH(inspector) - CHAR_LENGTH(REPLACE(inspector, @observer_new_call, ''))) / CHAR_LENGTH(@observer_new_call)
          ) = 1
        END
      ) = 5
    FROM FIELD_2026_BADOatNZ.inspectors
    WHERE table_name IN ('OBSERVERS_hard', 'EGGS_hard', 'NESTS_hard',
                         'RESIGHTINGS_hard', 'CAPTURES_hard')
  );

/* Replace only observer-specific fragments, not entire inspector lists. */
UPDATE FIELD_2026_BADOatNZ.inspectors
SET inspector = CASE WHEN table_name = 'CAPTURES_hard' THEN
      REPLACE(REPLACE(inspector,
        @observer_upload_old_call, @observer_upload_new_call),
        @observer_upload_old_required, @observer_upload_new_required)
    ELSE REPLACE(inspector, @observer_old_call, @observer_new_call) END
WHERE @observer_patch_ready = 1
  AND table_name IN ('OBSERVERS_hard', 'EGGS_hard', 'NESTS_hard',
                     'RESIGHTINGS_hard', 'CAPTURES_hard');
SET @observer_rows_changed := ROW_COUNT();

SET @observer_patch_verified := (
  SELECT COUNT(*) = 5 AND COUNT(DISTINCT table_name) = 5
    AND SUM(
      CASE WHEN table_name = 'CAPTURES_hard' THEN
        LOCATE(@observer_upload_new_call, inspector) > 0
        AND LOCATE(@observer_upload_new_required, inspector) > 0
      ELSE LOCATE(@observer_new_call, inspector) > 0 END
      AND LOCATE('^[A-Z]{2,3}$', inspector) = 0
    ) = 5
  FROM FIELD_2026_BADOatNZ.inspectors
  WHERE table_name IN ('OBSERVERS_hard', 'EGGS_hard', 'NESTS_hard',
                       'RESIGHTINGS_hard', 'CAPTURES_hard')
);

/* A failed guard or verification rolls the transaction back automatically. */
SET @observer_finish_sql := IF(
  @observer_patch_ready = 1 AND @observer_patch_verified = 1,
  'COMMIT', 'ROLLBACK'
);
PREPARE observer_finish_stmt FROM @observer_finish_sql;
EXECUTE observer_finish_stmt;
DEALLOCATE PREPARE observer_finish_stmt;

SELECT CASE
  WHEN @observer_patch_ready = 1 AND @observer_patch_verified = 1
    THEN 'PASS: observer-code validators installed (or already current); no field records or column definitions changed'
  ELSE 'FAIL: no changes committed; check selected database, InnoDB engine, five hard rows and exact source snippets'
END AS result, @observer_rows_changed AS inspector_rows_changed;

/* Start a new data-entry session after installing; existing sessions may cache
   validators. Register P3 with the correct person and active dates in OBSERVERS.
   No views installation, To-Do refresh or field-record rewrite is needed. */
