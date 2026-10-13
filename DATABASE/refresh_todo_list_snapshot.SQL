/*
  Refresh the derived TODO task snapshot after source data or settings change.

  Run this against the live FIELD_2026_BADOatNZ database after field rows are
  loaded and after changing settings.reference_date. It never reads an RDS
  file. The public TODO_LIST view remains a small read-only UNION over the
  snapshot's parent and non-parent task partitions.
*/
TRUNCATE TABLE FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT;

INSERT INTO FIELD_2026_BADOatNZ.TODO_PARENT_STATUS_SNAPSHOT
SELECT *
FROM FIELD_2026_BADOatNZ.ADULT_PARENT_STATUS;

TRUNCATE TABLE FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT;

INSERT INTO FIELD_2026_BADOatNZ.TODO_LIST_SNAPSHOT
SELECT *
FROM FIELD_2026_BADOatNZ.TODO_LIST_CALCULATE;
