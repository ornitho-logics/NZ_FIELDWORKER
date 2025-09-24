
-- COMMENT-s can be styled with html markup.

-- DROP DATABASE IF EXISTS FIELD_2025_BADOatNZ;

CREATE DATABASE IF NOT EXISTS FIELD_2025_BADOatNZ;

USE FIELD_2025_BADOatNZ;

DROP TABLE IF EXISTS CAPTURES;
CREATE TABLE CAPTURES (
  date date DEFAULT                             NULL COMMENT 'Date caught YYYY-MM-DD (local, NZDT or NZST)',

  cap_start time DEFAULT                        NULL COMMENT
  'hh:mm capture start (when you set the trap or commenced trapping with the mistnet)',

  caught time DEFAULT                           NULL COMMENT 'hh:mm time caught (local, NZDT or NZST)',

  released time DEFAULT                         NULL COMMENT 'hh:mm time released (local, NZDT or NZST)',

  species char(4) DEFAULT                       NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',

  site varchar(255) DEFAULT                     NULL COMMENT '2-letter site codes:<br>AU=Upper Ashburton<br>CH=Chatham Is.<br>CR=Cass R.<br>HC=Hawkes Bay Coast<br>HR=Hawkes Bay Rivers<br>KK=Kaikoura<br>KP=Kina Pen.<br>KT=Kaitorete Spit<br>MB=Maryburn<br>MR=Macaulay R.<br>MS=Motueka Spit<br>OD=Ohau Downs<br>OK=Okarito<br>OM=Old Mans Range<br>PB=Porters Beach<br>PR=Pisa Range<br>TA=Te Anau (Upukerora)<br>TO=Tongariro (Rangipo Desert)<br>TP=Tiwai Point<br>TR=Tekapo R.<br>TS=Tasman R. Valley<br>WA=Wairarapa',


  book_id int(2) unsigned zerofill DEFAULT      NULL COMMENT '3-character integer that is a unique book_id (i.e., your fieldnote book)',

  form_id int(3) unsigned zerofill DEFAULT      NULL COMMENT '2-character integer that is a unique page of your book_id',

  observer varchar(3) DEFAULT                   NULL COMMENT 'Initials of the bander (see OBSERVERS table)',

  capture_status char(1) DEFAULT                NULL COMMENT '
      F (First marking)<br>
      R (Recaptured but band combination not changed)<br>
      C (recaptured and band combination Changed),<br>
      D (was Dead when captured: write description in comments)',

  capture_method varchar(2) DEFAULT             NULL COMMENT '
      HA (HAnd)                <br>
      TB (clap-Trap on Brood)  <br>
      TN (clap-Trap on Nest)   <br>
      SM (Stationary Mistnet)  <br>
      MM (Mobile Mistnet)      <br>
      O  (Other; please specify in comments)',

  caught_with varchar(255) DEFAULT              NULL COMMENT '
      Social members caught with focal individual, comma separated: <br>
      M = mate (high certainty) <br>
      M? = mate (unsure, but likely) <br>
      S = same sex conspecific (e.g., rival individual) <br>
      C = chick (e.g., "2C" for two chicks)',

  parents varchar(2) DEFAULT                    NULL COMMENT '
  If chicks captured, which parents were seen attending? <br>
      "MF": male and female<br>
      "F" : female only<br>
      "M" : male only<br>
      "U1": one unknown sex parent<br>
      "U2": two unknown sex parent<br>
      "O" : other (write in comments)',

  nest_id varchar(8) DEFAULT                    NULL COMMENT '
  a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
  XX = your GPS number (01 to 11)           <br>
  YY = your running nest number (01 to 99).      <br>
  Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA0903).',

  gps_id int(2) unsigned zerofill DEFAULT       NULL COMMENT 'handheld Garmin GPS ID',
  gps_point int(10) unsigned zerofill DEFAULT   NULL COMMENT 'waypoint number of the capture location stored in your handheld Garmin GPS unit',

  field_sex varchar(2) DEFAULT                  NULL COMMENT '
   observed sex based on field observations (ornamentation, behaviour, etc.):<br>
   "M" (male),<br>
   "F" (female),<br>
   "U" (unknown)',

  age char(1) DEFAULT                           NULL COMMENT '
  age of captured individual: <br>
  "A" (Adult),<br>
  "J" (Juvenile)',

  ring varchar(50) DEFAULT    NULL COMMENT 'alpha-numeric code of metal ring assigned to captured individual',

  UL varchar(4) DEFAULT    NULL COMMENT '
  code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned):<br>
      X = blank              <br>
      O = orange             <br>
      Y = yellow             <br>
      W = white              <br>
      B = blue               <br>
      R = red                <br>
      G = green              <br>
      L = light green "lime" <br>
      M = metal              <br>
      FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  LL varchar(4) DEFAULT   NULL COMMENT '
  code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): <br>
      X = blank            <br>
      O = orange           <br>
      Y = yellow           <br>
      W = white            <br>
      B = blue             <br>
      R = red              <br>
      G = green            <br>
      L = light green lime <br>
      M = metal            <br>
   No flag assigned to tarsi',

  UR varchar(4) DEFAULT                         NULL COMMENT '
  code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band     assigned):<br>
      X = blank              <br>
      O = orange             <br>
      Y = yellow             <br>
      W = white              <br>
      B = blue               <br>
      R = red                <br>
      G = green              <br>
      L = light green "lime" <br>
      M = metal              <br>
  , FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  LR varchar(4) DEFAULT                         NULL COMMENT '
  code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one     band assigned): <br>
      X = blank              <br>
      O = orange             <br>
      Y = yellow             <br>
      W = white              <br>
      B = blue               <br>
      R = red                <br>
      G = green              <br>
      L = light green "lime" <br>
      M = metal              <br>
   No flag assigned to tarsi.',

  tarsus double DEFAULT                         NULL COMMENT '
  length (mm) of tarsus of captured individual. Measured as the distance between the notch at the end of the lateral condyle of the tibiotarsus on the backside of the leg, to the last tarsal scute on the front of the leg at the base of the foot (also known as the "outside tarsus" or "diagonal tarsus" measurement; <i> sensu page 11 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA) </i>',

  culmen double DEFAULT                         NULL COMMENT 'length (mm) of upper mandible of captured individual. Measured as the distance between the tip of the forehead feathering at the base of the upper bill, along the ridge of the culmen, and the tip of the bill (also known as the "exposed culmen" measurement; <i> sensu page 8 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA) </i>',

  total_head double DEFAULT                     NULL COMMENT 'combined length (mm) of the bill and the skull. Measured as the maximum distance from the tip of the bill to the back of the skull',

  head_white double DEFAULT                     NULL COMMENT 'width (mm) of black head band from top to bottom at the bird''s centreline.',

  head_black double DEFAULT                     NULL COMMENT 'width (mm) of black neck band from top to bottom at the bird''s centreline.',

  rufous_band double DEFAULT                    NULL COMMENT 'width (mm) of rufous breast band from top to bottom at the bird''s centreline.',

  wing double DEFAULT                           NULL COMMENT 'length (mm) of wing of captured individual. Measured as the distance from the carpal joint (the bend of the wing) to the longest primary feather whilst flattening the wing and straightening the primaries (also known as the "maximum flat" or "flattened and straightened" measurement; <i> sensu page 6 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)  </i>',

  brood_patch tinyint(1) unsigned DEFAULT       NULL COMMENT '"0" (no) or "1" (yes). Was there a brood patch when captured?',

  weight double DEFAULT                         NULL COMMENT 'Body mass (g) of captured individual (note: this includes the weight of the metal and colour rings. A metal ring weighs approximately 0.17g and a colour ring weighs approximately 0.08g.',
  wt_w_tag tinyint(1) unsigned DEFAULT          NULL COMMENT '"0" (no) or "1" (yes). Was the body weight measured with a tag on?',

  moult varchar(255) DEFAULT                    NULL COMMENT 'primary molt score of captured individual. Scored as a the stage of the moult and the number of feathers at     that stage. If all 10 primaries are old feathers with no moult, it would be scored as "0(10)". See Ringers Manual, British Trust for Ornithology, Thetford for more details.',

  fat int(1) unsigned DEFAULT                   NULL COMMENT 'fat score of captured individual, scored as the amount of visible fat in the furcular region or tracheal pit.    See <i>Ringers Manual, British Trust for Ornithology, Thetford for more details.</i>',

  feather_wear tinyint(1) unsigned DEFAULT     NULL COMMENT 'scored as "0" (Fresh), "1" (Slightly worn), "2" (Moderately worn), or "3" (Very worn). See NZNBBS Bird Banders Manual for more details',

  sample varchar(255) DEFAULT                   NULL COMMENT 'Samples taken, comma separated: <br>    FP = feather_primary <br>     FB = feather_breast <br>     BQ = blood in Queen <br>    BF = blood on filter paper <br>    BE = blood in EDTA',

  tag_id varchar(10) DEFAULT                    NULL COMMENT 'ID of tag deployed or retrived',
  tag_type char(3) DEFAULT                      NULL COMMENT 'type of tag deployed ("PTT" or "GPS")',

  tag_action char(1) DEFAULT                    NULL COMMENT '
  "O" (nO tag: bird did not have a tag when captured and was released without a tag)           <br>
      "D" (new Deployment: bird  did not have a tag when captured and was released with a tag) <br>
      "R" (Retrieved: bird had a tag when captured and was released without a tag)             <br>
      "S" (tag Stayed on: bird had a tag when captured and was released with the same tag)     <br>
      "N" (New tag: bird had a tag when captured and was released with a new tag)',

  tag_extras varchar(10) DEFAULT                NULL COMMENT 'type of tag deployed ("shield", "foam", or "shield and foam")',

  cam_id varchar(255) DEFAULT                   NULL COMMENT '2-character integer that is a unique ID of your field camera',

  photo_start varchar(255) DEFAULT              NULL COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255) DEFAULT                NULL COMMENT 'image filename for the last photo of the sequence',
  mugshot_photo tinyint(1) unsigned DEFAULT     NULL COMMENT '"0" (no) or "1" (yes). Was a mugshot photo taken?',
  wing_photo tinyint(1) unsigned DEFAULT        NULL COMMENT '"0" (no) or "1" (yes). Was a wing photo taken?',
  chick_photo tinyint(1) unsigned DEFAULT       NULL COMMENT '"0" (no) or "1" (yes). Was a chick photo taken?',

  harddrive_id int(2) unsigned zerofill DEFAULT NULL COMMENT 'harddrive ID where photos were uploaded after returning from the field',

  comments text DEFAULT                         NULL COMMENT 'Comments',

  falcon_upload tinyint(1) unsigned DEFAULT     NULL COMMENT '"0" (no) or "1" (yes). Was the capture uploaded to FALCON?',

  observer_upload varchar(3) DEFAULT            NULL COMMENT 'Initials of the person uploading to the database (see OBSERVERS table)',

  nov int(10) unsigned zerofill DEFAULT         NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY ID (ring),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS EGGS ;
CREATE TABLE EGGS (
  species char(4)                  DEFAULT NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  observer varchar(3)              DEFAULT NULL COMMENT 'Initials of the observer (see OBSERVERS table).',
  date date                        DEFAULT NULL COMMENT 'Date (YYYY-MM-DD) when eggs were measured (local, NZDT or NZST).',
  time_visit time                  DEFAULT NULL COMMENT 'Time (HH:MM) when the eggs were measured (local, NZDT or NZST)',

  nest_id varchar(8)               DEFAULT NULL COMMENT '
  a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), XX = your GPS number (01 to 11), YY = your running nest number (01 to 99).',

  egg1_float_angle int(3)          DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg1_float_surface int(3)        DEFAULT NULL COMMENT 'Height of egg above water surface (mm)',
  egg1_float_location varchar(255) DEFAULT NULL COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  egg2_float_angle int(3)          DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg2_float_surface int(3)        DEFAULT NULL COMMENT 'Height of egg above water surface (mm).',
  egg2_float_location varchar(255) DEFAULT NULL COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  egg3_float_angle int(3)          DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg3_float_surface int(3)        DEFAULT NULL COMMENT 'Height of egg above water surface (mm).',
  egg3_float_location varchar(255) DEFAULT NULL COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  egg4_float_angle int(3)          DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg4_float_surface int(3)        DEFAULT NULL COMMENT 'Height of egg above water surface (mm).',
  egg4_float_location varchar(255) DEFAULT NULL COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',

  cam_id varchar(255)              DEFAULT NULL COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)         DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255)           DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',
  harddrive_id int(2)              DEFAULT NULL COMMENT 'harddrive ID where photos were uploaded after returning from the field',
  comments text                    DEFAULT NULL COMMENT 'Comments.',
  observer_upload varchar(3)       DEFAULT NULL COMMENT 'Initials of the person uploading to the database (see OBSERVERS table)',
  nov int(1) unsigned zerofill     DEFAULT NULL COMMENT 'No validation. Do not edit !',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY date (date)
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS GPS_POINTS ;
CREATE TABLE GPS_POINTS (
  gps_id int(2) unsigned zerofill NOT NULL COMMENT 'gps id',
  gps_point int(10) unsigned zerofill NOT NULL COMMENT 'gps point',
  datetime_ datetime NOT NULL COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT NULL COMMENT 'latitude',
  lon double NOT NULL COMMENT 'longitude',
  ele double NOT NULL COMMENT 'elevation',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,gps_point),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB  ;


DROP TABLE IF EXISTS GPS_TRACKS ;
CREATE TABLE GPS_TRACKS (
  gps_id int(2) unsigned zerofill NOT NULL COMMENT 'gps id',
  seg_id int(10) unsigned zerofill NOT NULL COMMENT 'segment id',
  seg_point_id int(10) unsigned zerofill NOT NULL COMMENT 'segment point id',
  datetime_ datetime NOT NULL COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT NULL COMMENT 'latitude',
  lon double NOT NULL COMMENT 'longitude',
  ele float NOT NULL COMMENT 'elevation',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,seg_id),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB  ;


DROP TABLE IF EXISTS NESTS ;
CREATE TABLE NESTS (
  species char(4)                     DEFAULT NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',

  site varchar(255) DEFAULT                     NULL COMMENT '2-letter site codes:<br>AU=Upper Ashburton<br>CH=Chatham Is.<br>CR=Cass R.<br>HC=Hawkes Bay Coast<br>HR=Hawkes Bay Rivers<br>KK=Kaikoura<br>KP=Kina Pen.<br>KT=Kaitorete Spit<br>MB=Maryburn<br>MR=Macaulay R.<br>MS=Motueka Spit<br>OD=Ohau Downs<br>OK=Okarito<br>OM=Old Mans Range<br>PB=Porters Beach<br>PR=Pisa Range<br>TA=Te Anau (Upukerora)<br>TO=Tongariro (Rangipo Desert)<br>TP=Tiwai Point<br>TR=Tekapo R.<br>TS=Tasman R. Valley<br>WA=Wairarapa',

  observer varchar(3)                 DEFAULT NULL COMMENT 'Initials of the observer (see OBSERVERS table)',

  nest_id varchar(8)                  DEFAULT NULL COMMENT 'a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), XX = your GPS number (01 to 11), YY = your running nest number (01 to 99). Note if a brood was found of unknown origin, the nest_id is coded as a negative (e.g., -BA0903, would be the 3rd unknown banded dotterel brood encountered by the observer with GPS 09).',

  date date                           DEFAULT NULL COMMENT 'Date nest checked YYYY-MM-DD (local, NZDT or NZST)',

  time_visit time                     DEFAULT NULL COMMENT 'Time (HH:MM) when the nest was checked (local, NZDT or NZST)',

  gps_id int(2) unsigned zerofill     DEFAULT NULL COMMENT 'handheld Garmin GPS ID (1-12)',

  gps_point int(10) unsigned zerofill DEFAULT NULL COMMENT 'GPS waypoint (if nest_state is F this is the position of the nest, otherwise this is the escape distance when nest is still active)',

  clutch_size int(1)                  DEFAULT NULL COMMENT 'Clutch size (if nest)',

  brood_size int(1)                   DEFAULT NULL COMMENT 'Number of chicks seen (if brood)',

  female_ring varchar(50)             DEFAULT NULL COMMENT 'Metal ID of incubating female (this is entered once the COMBO of the female is 100% sure (e.g. confirmed twice independently))',

  male_ring varchar(50)               DEFAULT NULL COMMENT 'Metal ID of incubating male (this is entered once the COMBO of the male is 100% sure (e.g. confirmed twice independently))',

  female_UL varchar(4)                DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band on this segment): <br>
  X = blank              <br>
  O = orange             <br>
  Y = yellow             <br>
  W = white              <br>
  B = blue               <br>
  R = red                <br>
  G = green              <br>
  L = light green "lime" <br>
  M = metal              <br>
  FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  female_LL varchar(4)                DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band on this segment):
  X = blank              <br>
  O = orange             <br>
  Y = yellow             <br>
  W = white              <br>
  B = blue               <br>
  R = red                <br>
  G = green              <br>
  L = light green "lime" <br>
  M = metal              <br>
  No flag assigned to tarsi.',

  female_UR varchar(4)                DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band on this segment):
  X = blank              <br>
  O = orange             <br>
  Y = yellow             <br>
  W = white              <br>
  B = blue               <br>
  R = red                <br>
  G = green              <br>
  L = light green "lime" <br>
  M = metal              <br>
  FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  female_LR varchar(4)                DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',

  male_UL varchar(4)                  DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  male_LL varchar(4)                  DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',

  male_UR varchar(4)                  DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  male_LR varchar(4)                  DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',

  nest_state varchar(5)               DEFAULT NULL COMMENT '
  <b>I</b> [active nest being Incubated (eggs warm/parent(s) seen)],
  <b>P</b> [Predated (parents nowhere to be seen and scrape empty earlier than expected hatch date)],
  <b>D</b> [Deserted (parents nowhere to be seen and eggs are cold)],
  <b>H</b> (hatched, chicks seen),
  <b>B</b> (brood seen)
  <b>O</b> (Other, please note in comments)',

  behav text                          DEFAULT NULL COMMENT '
  behavioral class, as many as applicable, seperated by a comma:<br>
    "IN" = incubating                            <br>
    "CO" = courtship                             <br>
    "PR" = preening                              <br>
    "BW" = distraction display (e.g.broken wing) <br>
    "BC" = brooding chicks                       <br>
    "NM" = nest maintenance                      <br>
    "FC" = foraging with chicks                  <br>
    "FA" = foraging alone                        <br>
    "FM" = foraging with (presumed) mate         <br>
    "FF" = foraging in flock                     <br>
    "RS" = roosting                              <br>
    "LF" = loafing                               <br>
    "AT" = alert                                 <br>
    "FT" = fighting                              <br>
    "OB" = other behavious (please comment)',

  comments text                       DEFAULT NULL COMMENT 'Comments',

  observer_upload varchar(3)          DEFAULT NULL COMMENT 'Initials of the person uploading to the database (see OBSERVERS table)',

  nov int(1) unsigned zerofill        DEFAULT NULL COMMENT 'No validation. Do not edit !',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY species (species),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS OBSERVERS ;
CREATE TABLE OBSERVERS (
  name text DEFAULT NULL COMMENT 'Your full name.',
  observer varchar(3) DEFAULT NULL COMMENT 'Your initials. Use two or three letters. This is what you will use when entering data.',
  affiliation text DEFAULT NULL COMMENT 'Your affiliation as it would listed in a publication',
  email text DEFAULT NULL COMMENT 'An email address which can be used for data enquiries about your observations',
  gps_id int(2) unsigned zerofill DEFAULT NULL COMMENT 'Personal GPS ID',
  radio_id int(2) unsigned zerofill DEFAULT NULL COMMENT 'Personal radio ID',
  cam_id varchar(255) DEFAULT NULL COMMENT 'Personal camcorder ID',
  harddrive_id int(2) DEFAULT NULL COMMENT 'Team harddrive ID where photos were uploaded after returning from the field',
  remarks text DEFAULT NULL COMMENT 'Please provide any relevant information, such as your ratings in cooking, chess, or poker.'
) ENGINE=InnoDB  ;


DROP TABLE IF EXISTS RESIGHTINGS ;
CREATE TABLE RESIGHTINGS (

  species varchar(50)                       DEFAULT NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',

  observer varchar(3)                       DEFAULT NULL COMMENT 'Initials of the observer (see OBSERVERS table).',

  gps_id int(2) unsigned zerofill           DEFAULT NULL COMMENT 'handheld Garmin GPS ID',

  gps_point int(10) unsigned zerofill DEFAULT NULL COMMENT 'Required: waypoint number stored in your handheld Garmin GPS unit for the behavioural observation',

  date date                                 DEFAULT NULL,

  site varchar(255) DEFAULT                     NULL COMMENT '2-letter site codes:<br>AU=Upper Ashburton<br>CH=Chatham Is.<br>CR=Cass R.<br>HC=Hawkes Bay Coast<br>HR=Hawkes Bay Rivers<br>KK=Kaikoura<br>KP=Kina Pen.<br>KT=Kaitorete Spit<br>MB=Maryburn<br>MR=Macaulay R.<br>MS=Motueka Spit<br>OD=Ohau Downs<br>OK=Okarito<br>OM=Old Mans Range<br>PB=Porters Beach<br>PR=Pisa Range<br>TA=Te Anau (Upukerora)<br>TO=Tongariro (Rangipo Desert)<br>TP=Tiwai Point<br>TR=Tekapo R.<br>TS=Tasman R. Valley<br>WA=Wairarapa',


  rclass varchar(2)                         DEFAULT NULL COMMENT '
  Resighting class: <br>
      "C" (pre-capture) <br>
      "V" (video session) <br>
      "R" (regular) <br>
      "P" (photography session)',

  UL varchar(10)                            DEFAULT NULL COMMENT '
  code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned):     X = blank <br>    O = orange <br>    Y = yellow <br>    W = white <br>    B = blue <br>    R = red <br>    G = green <br>    L = light green "lime" <br>    M = metal <br>    FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ"     a two-character string that can contain the following characters, with there needing to be at least one letter:    <br> A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  LL varchar(10)                            DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned):<br>    X = blank <br>    O = orange <br>    Y = yellow <br>    W = white <br>    B = blue <br>    R = red <br>    G = green <br>    L = light green "lime" <br>    M = metal. No flag assigned to tarsi',

  UR varchar(10)                            DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band assigned):    X = blank <br>    O = orange <br>    Y = yellow <br>    W = white <br>    B = blue <br>    R = red <br>    G = green <br>    L = light green "lime" <br>    M = metal <br>    FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  LR varchar(10)                            DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one band assigned):<br>    X = blank <br>    O = orange <br>    Y = yellow <br>    W = white <br>    B = blue <br>    R = red <br>    G = green <br>    L = light green "lime", M = metal. No flag assigned to tarsi.',

  sex varchar(2)                            DEFAULT NULL,

  behav text                                DEFAULT NULL COMMENT
  'behavioral class, as many as applicable, seperated by a comma:<br>
    "IN" = incubating                            <br>
    "CO" = courtship                             <br>
    "PR" = preening                              <br>
    "BW" = distraction display (e.g.broken wing) <br>
    "BC" = brooding chicks                       <br>
    "NM" = nest maintenance                      <br>
    "FC" = foraging with chicks                  <br>
    "FA" = foraging alone                        <br>
    "FM" = foraging with (presumed) mate         <br>
    "FF" = foraging in flock                     <br>
    "RS" = roosting                              <br>
    "LF" = loafing                               <br>
    "AT" = alert                                 <br>
    "FT" = fighting                              <br>
    "OB" = other behavious (please comment)',

  cam_id varchar(255)                       DEFAULT NULL COMMENT '2-character integer that is a unique ID of your field camera',

  photo_start varchar(255)                  DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',

  photo_end varchar(255)                    DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',

  harddrive_id int(2)                       DEFAULT NULL COMMENT 'harddrive ID where photos/videos were uploaded after returning from the field',

  comments varchar(500)                     DEFAULT NULL COMMENT 'Comments',

  falcon_upload tinyint(1) unsigned         DEFAULT NULL COMMENT '"0" (no) or "1" (yes). Was the capture uploaded to FALCON?',

  observer_upload varchar(3)                DEFAULT NULL COMMENT 'Initials of the person uploading to the database (see OBSERVERS table)',
  nov int(1) unsigned zerofill              DEFAULT NULL COMMENT 'No validation. Do not edit !',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps1 (gps_id,gps_point)
) ENGINE=InnoDB  ;


DROP TABLE IF EXISTS RESIGHTINGS_PUBLIC ;
CREATE TABLE RESIGHTINGS_PUBLIC (
  species char(4)                NOT NULL,
  observer tinytext              NOT NULL,
  time time                      NOT NULL,
  date date                      NOT NULL,
  latitude double DEFAULT NULL,
  longitude double DEFAULT NULL,
  easting double DEFAULT NULL,
  northing double DEFAULT NULL,
  sex varchar(2) DEFAULT NULL,
  UL varchar(4)                  NOT NULL,
  LL varchar(4)                  NOT NULL,
  UR varchar(4)                  NOT NULL,
  LR varchar(4)                  NOT NULL,

  behav text                                DEFAULT NULL COMMENT
  'behavioral class, as many as applicable, seperated by a comma:<br>
    "IN" = incubating                            <br>
    "CO" = courtship                             <br>
    "PR" = preening                              <br>
    "BW" = distraction display (e.g.broken wing) <br>
    "BC" = brooding chicks                       <br>
    "NM" = nest maintenance                      <br>
    "FC" = foraging with chicks                  <br>
    "FA" = foraging alone                        <br>
    "FM" = foraging with (presumed) mate         <br>
    "FF" = foraging in flock                     <br>
    "RS" = roosting                              <br>
    "LF" = loafing                               <br>
    "AT" = alert                                 <br>
    "FT" = fighting                              <br>
    "OB" = other behavious (please comment)',

  num_photos int(11) DEFAULT NULL,
  source varchar(50)             NOT NULL,
  source_identifier varchar(500) NOT NULL,
  country char(2)                NOT NULL,

  site varchar(255) DEFAULT                     NULL COMMENT '2-letter site codes:<br>AU=Upper Ashburton<br>CH=Chatham Is.<br>CR=Cass R.<br>HC=Hawkes Bay Coast<br>HR=Hawkes Bay Rivers<br>KK=Kaikoura<br>KP=Kina Pen.<br>KT=Kaitorete Spit<br>MB=Maryburn<br>MR=Macaulay R.<br>MS=Motueka Spit<br>OD=Ohau Downs<br>OK=Okarito<br>OM=Old Mans Range<br>PB=Porters Beach<br>PR=Pisa Range<br>TA=Te Anau (Upukerora)<br>TO=Tongariro (Rangipo Desert)<br>TP=Tiwai Point<br>TR=Tekapo R.<br>TS=Tasman R. Valley<br>WA=Wairarapa',


  comments_obs varchar(500) DEFAULT NULL,
  comments_db varchar(500) DEFAULT NULL,
  falcon_upload char(1) DEFAULT NULL,
  nov int(1) unsigned zerofill   NOT NULL,
  pk int(10)                     NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk)
) ENGINE=InnoDB  ;