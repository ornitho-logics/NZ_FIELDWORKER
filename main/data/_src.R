# Scratch code for rebuilding ./data/gam_float_to_hach.rds.
# TODO: gam_float_to_hach.rds is for lapwings

if (FALSE) {
  x <- DBq(
    "
    SELECT nest_id nest, date, float_angle, float_surface surface
    FROM EGGS
    WHERE float_angle IS NOT NULL
      AND float_surface IS NOT NULL
    "
  )

  x
}
