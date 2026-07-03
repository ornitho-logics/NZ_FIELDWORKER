CREATE OR REPLACE FUNCTION FIELD_2026_BADOatNZ.format_mark(
  p_UL varchar(10),
  p_LL varchar(10),
  p_UR varchar(10),
  p_LR varchar(10)
)
RETURNS varchar(50)
DETERMINISTIC
NO SQL
RETURN CONCAT(
  COALESCE(
    NULLIF(
      CONCAT_WS(
        '.',
        CASE WHEN NULLIF(TRIM(p_UL), '') NOT IN ('X', 'M') THEN TRIM(p_UL) END,
        CASE WHEN NULLIF(TRIM(p_LL), '') NOT IN ('X', 'M') THEN TRIM(p_LL) END
      ),
      ''
    ),
    'X'
  ),
  '-',
  COALESCE(
    NULLIF(
      CONCAT_WS(
        '.',
        CASE WHEN NULLIF(TRIM(p_UR), '') NOT IN ('X', 'M') THEN TRIM(p_UR) END,
        CASE WHEN NULLIF(TRIM(p_LR), '') NOT IN ('X', 'M') THEN TRIM(p_LR) END
      ),
      ''
    ),
    'X'
  )
);
