
-- COMMENT-s can be styled with html markup.

-- DROP DATABASE IF EXISTS FIELD_2026_BADOatNZ;

CREATE DATABASE IF NOT EXISTS FIELD_2026_BADOatNZ;

USE FIELD_2026_BADOatNZ;

DROP TABLE IF EXISTS OBSERVERS ;
CREATE TABLE OBSERVERS (
  name text DEFAULT NULL COMMENT 'Your full name.',
  observer varchar(3) DEFAULT NULL COMMENT 'Your initials. Use two or three letters. This is what you will use when entering data.',
  START date                   DEFAULT NULL COMMENT 'Start of work (YYYY-MM-DD)',
  STOP date                    DEFAULT NULL COMMENT 'End of work (YYYY-MM-DD)',
  gps_id tinyint unsigned DEFAULT NULL COMMENT 'Personal GPS ID',
  cam_id varchar(255) DEFAULT NULL COMMENT 'Personal camcorder ID'
) ENGINE=InnoDB ;

DROP TABLE IF EXISTS CAPTURES;
CREATE TABLE CAPTURES (
  date date DEFAULT                             NULL COMMENT 'Date caught YYYY-MM-DD (local, NZDT or NZST)',

  cap_start time DEFAULT                        NULL COMMENT 'hh:mm capture start (when you set the trap or commenced trapping with the mistnet)',

  caught time DEFAULT                           NULL COMMENT 'hh:mm time caught (local, NZDT or NZST)',

  released time DEFAULT                         NULL COMMENT 'hh:mm time released (local, NZDT or NZST)',

  species char(4) DEFAULT                       NULL COMMENT '
  4-letter species code: <br>
  <strong>BADO</strong> (Banded Dotterel) <br>
  <strong>WRYB</strong> (Wrybill) <br> 
  <strong>SNZD</strong> (Southern New Zealand Dotterel) <br> 
  <strong>BFDO</strong> (Black-fronted Dotterel)',

  site varchar(2) DEFAULT                     NULL COMMENT '
      2-letter site codes:<br>
      <strong>AR</strong> (Aparima River) <br>
      <strong>AU</strong> (Upper Ashburton) <br>
      <strong>CH</strong> (Chathams) <br>
      <strong>CL</strong> (Clarence River) <br>
      <strong>CR</strong> (Cass River) <br>
      <strong>HC</strong> (Hawkes Bay Coast) <br>
      <strong>HR</strong> (Hawkes Bay Rivers) <br>
      <strong>KK</strong> (Kaikoura) <br>
      <strong>KP</strong> (Kina Peninsula) <br>
      <strong>KT</strong> (Kaitorete Spit) <br>
      <strong>MB</strong> (Maryburn) <br>
      <strong>MR</strong> (Macaulay River) <br>
      <strong>MS</strong> (Motueka Spit) <br>
      <strong>OD</strong> (Ohau Downs) <br>
      <strong>OK</strong> (Okarito) <br>
      <strong>OM</strong> (Old Man Range) <br>
      <strong>PB</strong> (Porters Beach) <br>
      <strong>PR</strong> (Pisa Range) <br>
      <strong>TA</strong> (Te Anau (Upukerora)) <br>
      <strong>TO</strong> (Tongariro (Rangipo Desert)) <br>
      <strong>TP</strong> (Tiwai Point) <br>
      <strong>TR</strong> (Tekapo River) <br>
      <strong>TS</strong> (Tasman River) <br>
      <strong>WA</strong> (Wairarapa) <br>
      <strong>WN</strong> (West Coast North) <br>
      <strong>WS</strong> (West Coast South)',

  book_id smallint unsigned DEFAULT      NULL COMMENT '3-character integer that is a unique book_id (i.e., your fieldnote book)',

  form_id smallint unsigned DEFAULT      NULL COMMENT '2-character integer that is a unique page of your book_id',

  observer varchar(3) DEFAULT                   NULL COMMENT '2- or 3-character initials of the bander (see OBSERVERS table)',

  capture_status ENUM('F','R','C','D') DEFAULT  NULL COMMENT '
      <strong>F</strong> (First marking)<br>
      <strong>R</strong> (Recaptured but band combination not changed)<br>
      <strong>C</strong> (recaptured and band combination Changed),<br>
      <strong>D</strong> (was Dead when captured: write description in comments)',

  capture_method ENUM('HA','TB','TN','SM','MM','O') DEFAULT NULL COMMENT '
      <strong>HA</strong> (HAnd)                <br>
      <strong>TB</strong> (clap-Trap on Brood)  <br>
      <strong>TN</strong> (clap-Trap on Nest)   <br>
      <strong>SM</strong> (Stationary Mistnet)  <br>
      <strong>MM</strong> (Mobile Mistnet)      <br>
      <strong>O</strong>  (Other; please specify in comments)',
  
  nest_id varchar(7) DEFAULT                    NULL COMMENT '
      a 6- or 7-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA0903).',

  caught_with varchar(255) DEFAULT              NULL COMMENT '
      Social members caught with focal individual, comma separated: <br>
      M (mate, high certainty) <br>
      M? (mate, unsure, but likely) <br>
      S (same sex conspecific, e.g., rival individual) <br>
      C (chick, e.g., "2C" for two chicks)',

  parents ENUM('MF','F','M','U1','U2','O') DEFAULT NULL COMMENT '
      If chicks captured, which parents were seen attending? <br>
        <strong>MF</strong> (male and female) <br>
        <strong>F</strong> (female only) <br>
        <strong>M</strong> (male only) <br>
        <strong>U1</strong> (one unknown sex parent) <br>
        <strong>U2</strong> (two unknown sex parents) <br>
        <strong>O</strong> (other (write in comments)',
      
  gps_id tinyint unsigned DEFAULT       NULL COMMENT 'handheld Garmin GPS ID',
  
  gps_point int unsigned DEFAULT   NULL COMMENT 'waypoint number of the capture location stored in your handheld Garmin GPS unit',

  field_sex ENUM('M','M?','F','F?','U') DEFAULT NULL COMMENT '
   observed sex based on field observations (ornamentation, behaviour, etc.):<br>
   <strong>M</strong> (male), <br>
   <strong>M?</strong> (male, but uncertain), <br>
   <strong>F</strong> (female), <br>
   <strong>F?</strong> (fmale, but uncertain), <br>
   <strong>U</strong> (unknown, e.g., for chicks and juveniles)',

  age ENUM('A','J','C') DEFAULT                 NULL COMMENT '
  age of captured individual: <br>
  <strong>A</strong> (Adult),<br>
  <strong>J</strong> (Juvenile),<br>
  <strong>C</strong> (Chick)',

  ring varchar(50) DEFAULT    NULL COMMENT 'alpha-numeric code of metal ring assigned to captured individual',

  UL_in varchar(4) DEFAULT    NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      FXYZ (Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0)',

  LL_in varchar(4) DEFAULT   NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): <br>
      <strong>X</strong> (blank)            <br>
      <strong>O</strong> (orange)           <br>
      <strong>Y</strong> (yellow)           <br>
      <strong>W</strong> (white)            <br>
      <strong>B</strong> (blue)             <br>
      <strong>R</strong> (red)              <br>
      <strong>G</strong> (green)            <br>
      <strong>L</strong> (light green lime) <br>
      <strong>M</strong> (metal)            <br>
   No flag assigned to tarsi',

  UR_in varchar(4) DEFAULT                         NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band     assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      <strong>T</strong> (tag, e.g., for a geolocator on the tibia, note that when used, the tag_id field also needs to be completed)              <br>
      FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  LR_in varchar(4) DEFAULT                         NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one     band assigned): <br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
   No flag assigned to tarsi.',
   
   UL varchar(4) DEFAULT    NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      FXYZ (Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0)',

  LL varchar(4) DEFAULT   NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): <br>
      <strong>X</strong> (blank)            <br>
      <strong>O</strong> (orange)           <br>
      <strong>Y</strong> (yellow)           <br>
      <strong>W</strong> (white)            <br>
      <strong>B</strong> (blue)             <br>
      <strong>R</strong> (red)              <br>
      <strong>G</strong> (green)            <br>
      <strong>L</strong> (light green lime) <br>
      <strong>M</strong> (metal)            <br>
   No flag assigned to tarsi',

  UR varchar(4) DEFAULT                         NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band     assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      <strong>T</strong> (tag, e.g., for a geolocator on the tibia, note that when used, the tag_id field also needs to be completed)              <br>
      FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',

  LR varchar(4) DEFAULT                         NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one     band assigned): <br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
   No flag assigned to tarsi.',

  tarsus double DEFAULT                         NULL COMMENT 'length (mm) of tarsus of captured individual. Measured as the distance between the notch at the end of the lateral condyle of the tibiotarsus on the backside of the leg, to the last tarsal scute on the front of the leg at the base of the foot (also known as the "outside tarsus" or "diagonal tarsus" measurement; <i> sensu page 11 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA) </i>',

  culmen double DEFAULT                         NULL COMMENT 'length (mm) of upper mandible of captured individual. Measured as the distance between the tip of the forehead feathering at the base of the upper bill, along the ridge of the culmen, and the tip of the bill (also known as the "exposed culmen" measurement; <i> sensu page 8 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA) </i>',

  total_head double DEFAULT                     NULL COMMENT 'combined length (mm) of the bill and the skull. Measured as the maximum distance from the tip of the bill to the back of the skull',

  head_white double DEFAULT                     NULL COMMENT 'width (mm) of black head band from top to bottom at the bird''s centreline.',

  head_black double DEFAULT                     NULL COMMENT 'width (mm) of black neck band from top to bottom at the bird''s centreline.',

  rufous_band double DEFAULT                    NULL COMMENT 'width (mm) of rufous breast band from top to bottom at the bird''s centreline.',

  wing double DEFAULT                           NULL COMMENT 'length (mm) of wing of captured individual. Measured as the distance from the carpal joint (the bend of the wing) to the longest primary feather whilst flattening the wing and straightening the primaries (also known as the "maximum flat" or "flattened and straightened" measurement; <i> sensu page 6 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)  </i>',

  brood_patch ENUM('0','1') DEFAULT             NULL COMMENT '
    Was there a brood patch when captured? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',

  weight double DEFAULT                         NULL COMMENT 'Body mass (g) of captured individual (note: this includes the weight of the metal and colour rings).',
  
  wt_w_tag ENUM('0','1') DEFAULT                NULL COMMENT '
    Was the body weight measured with a tag on? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',

  moult varchar(255) DEFAULT                    NULL COMMENT 'primary molt score of captured individual. Scored as a the stage of the moult and the number of feathers at that stage. If all 10 primaries are old feathers with no moult, it would be scored as "0(10)". See Ringers Manual, British Trust for Ornithology, Thetford for more details.',

  fat int(1) unsigned DEFAULT                   NULL COMMENT 'fat score of captured individual, scored as the amount of visible fat in the furcular region or tracheal pit. See <i>Ringers Manual, British Trust for Ornithology, Thetford for more details.</i>',

  breast_samp ENUM('0','1') DEFAULT             NULL COMMENT '
    Were breast feathers sampled? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',
    
  primary_samp ENUM('0','1') DEFAULT            NULL COMMENT '
    Was a primary feather sampled? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',
  
  blood_samp ENUM('BQ','BF','BE') DEFAULT       NULL COMMENT '
    Was blood taken?  <br>  
    <strong>BQ</strong> (blood in Queens buffer) <br>    
    <strong>BF</strong> (blood on filter paper) <br>    
    <strong>BE</strong> (blood in EDTA tube) <br> 
    leave blank if not collected',
  
  other_sample varchar(255) DEFAULT                    NULL COMMENT 'free text of any other samples collected (e.g., "lice")',
    
  feather_wear ENUM('0','1','2','3') DEFAULT   NULL COMMENT '
    scored as: <br>
      <strong>0</strong> (Fresh) <br> 
      <strong>1</strong> (Slightly worn) <br> 
      <strong>2</strong> (Moderately worn) or <br>
      <strong>3</strong> (Very worn). <br> 
    See NZNBBS Bird Banders Manual for more details',

  tag_id_in varchar(20) DEFAULT                 NULL COMMENT 'AT CAPTURE/BEFORE HANDLING: ID of tag/geolocator',
    
  tag_id varchar(20) DEFAULT                    NULL COMMENT 'AT RELEASE/AFTER HANDLING: ID of tag/geolocator',
  
  tag_type ENUM('PTT','GPS','GEO') DEFAULT      NULL COMMENT '
    type of tag deployed: <br>
    <strong>PTT</strong> (satellite tag) <br>
    <strong>GPS</strong> (GPS tag), or <br>
    <strong>GEO</strong> (light-logger geolocator)',

  tag_action ENUM('O','D','R','S','N') DEFAULT  NULL COMMENT '
      <strong>O</strong> (nO tag: bird did not have a tag when captured and was released without a tag)           <br>
      <strong>D</strong> (new Deployment: bird  did not have a tag when captured and was released with a tag) <br>
      <strong>R</strong> (Retrieved: bird had a tag when captured and was released without a tag)             <br>
      <strong>S</strong> (tag Stayed on: bird had a tag when captured and was released with the same tag)     <br>
      <strong>N</strong> (New tag: bird had a tag when captured and was released with a new tag)',

  cam_id varchar(10) DEFAULT                   NULL COMMENT '2- or 3-character string that is a unique ID of your field camera',

  photo_start varchar(255) DEFAULT              NULL COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255) DEFAULT                NULL COMMENT 'image filename for the last photo of the sequence',
  mugshot_photo ENUM('0','1') DEFAULT           NULL COMMENT '
    Was a mugshot photo taken? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',
  wing_photo ENUM('0','1') DEFAULT              NULL COMMENT '
    Was a wing photo taken? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',
  chick_tent_photo ENUM('0','1') DEFAULT        NULL COMMENT  '
    Was a chick photo taken in the tent? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',
  chick_hide_photo ENUM('0','1') DEFAULT        NULL COMMENT '
    Was an in-situ photo taken of a hiding chick? <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',

  comments text DEFAULT                         NULL COMMENT 'Comments',

  falcon_upload tinyint(1) unsigned DEFAULT     NULL COMMENT  '
    Was the capture uploaded to FALCON? Leave blank unless managing the DOC upload to FALCON <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',

  observer_upload varchar(3) DEFAULT            NULL COMMENT 'Initials of the person uploading to the database (see OBSERVERS table)',

  nov int(10) unsigned zerofill DEFAULT         NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY ID (ring),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS EGGS ;
CREATE TABLE EGGS (
  species char(4) DEFAULT NULL COMMENT '
    4-letter species code: <br>
      <strong>BADO</strong> (Banded Dotterel) <br>
      <strong>WRYB</strong> (Wrybill) <br> 
      <strong>SNZD</strong> (Southern New Zealand Dotterel) <br> 
      <strong>BFDO</strong> (Black-fronted Dotterel)',

  observer varchar(3) DEFAULT NULL COMMENT '2- or 3-character initials of the observer (see OBSERVERS table)',

  date date DEFAULT NULL COMMENT 'Date eggs measured YYYY-MM-DD (local, NZDT or NZST)',

  time_visit time DEFAULT NULL COMMENT 'hh:mm time eggs were measured (local, NZDT or NZST)',

  nest_id varchar(8) DEFAULT NULL COMMENT '
      a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA0903).',

  egg_id tinyint unsigned DEFAULT NULL COMMENT '
      egg number within the nest: <br>
      <strong>1</strong> (first egg) <br>
      <strong>2</strong> (second egg) <br>
      <strong>3</strong> (third egg) <br>
      <strong>4</strong> (fourth egg)',

  float_angle tinyint unsigned DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90)',

  float_surface tinyint unsigned DEFAULT NULL COMMENT 'Height of egg above water surface (mm)',

  float_location ENUM('bottom','suspended','surface') DEFAULT NULL COMMENT '
      Position of the egg in the floating jar: <br>
      <strong>bottom</strong> <br>
      <strong>suspended</strong> <br>
      <strong>surface</strong>',

  cam_id varchar(10) DEFAULT NULL COMMENT 'ID of your field camera',

  photo_start varchar(255) DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',

  photo_end varchar(255) DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',

  harddrive_id smallint unsigned DEFAULT NULL COMMENT 'harddrive ID where photos were uploaded after returning from the field',

  comments text DEFAULT NULL COMMENT 'Comments',

  observer_upload varchar(3) DEFAULT NULL COMMENT 'Initials of the person uploading to the database (see OBSERVERS table)',

  nov int(10) unsigned zerofill DEFAULT         NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY nest_egg (nest_id, egg_id),
  KEY date (date)
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS GPS_POINTS ;
CREATE TABLE GPS_POINTS (
  gps_id tinyint unsigned NOT NULL COMMENT 'gps id',
  gps_point int unsigned NOT NULL COMMENT 'gps point',
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
  gps_id tinyint unsigned NOT NULL COMMENT 'gps id',
  seg_id int unsigned NOT NULL COMMENT 'segment id',
  seg_point_id int unsigned NOT NULL COMMENT 'segment point id',
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
  species char(4) DEFAULT NULL COMMENT '
  4-letter species code: <br>
  <strong>BADO</strong> (Banded Dotterel) <br>
  <strong>WRYB</strong> (Wrybill) <br> 
  <strong>SNZD</strong> (Southern New Zealand Dotterel) <br> 
  <strong>BFDO</strong> (Black-fronted Dotterel)',

  site varchar(2) DEFAULT NULL COMMENT '
      2-letter site codes:<br>
      <strong>AR</strong> (Aparima River) <br>
      <strong>AU</strong> (Upper Ashburton) <br>
      <strong>CH</strong> (Chathams) <br>
      <strong>CL</strong> (Clarence River) <br>
      <strong>CR</strong> (Cass River) <br>
      <strong>HC</strong> (Hawkes Bay Coast) <br>
      <strong>HR</strong> (Hawkes Bay Rivers) <br>
      <strong>KK</strong> (Kaikoura) <br>
      <strong>KP</strong> (Kina Peninsula) <br>
      <strong>KT</strong> (Kaitorete Spit) <br>
      <strong>MB</strong> (Maryburn) <br>
      <strong>MR</strong> (Macaulay River) <br>
      <strong>MS</strong> (Motueka Spit) <br>
      <strong>OD</strong> (Ohau Downs) <br>
      <strong>OK</strong> (Okarito) <br>
      <strong>OM</strong> (Old Man Range) <br>
      <strong>PB</strong> (Porters Beach) <br>
      <strong>PR</strong> (Pisa Range) <br>
      <strong>TA</strong> (Te Anau (Upukerora)) <br>
      <strong>TO</strong> (Tongariro (Rangipo Desert)) <br>
      <strong>TP</strong> (Tiwai Point) <br>
      <strong>TR</strong> (Tekapo River) <br>
      <strong>TS</strong> (Tasman River) <br>
      <strong>WA</strong> (Wairarapa) <br>
      <strong>WN</strong> (West Coast North) <br>
      <strong>WS</strong> (West Coast South)',

  date date DEFAULT NULL COMMENT 'Date nest checked YYYY-MM-DD (local, NZDT or NZST)',

  time_visit time DEFAULT NULL COMMENT 'hh:mm time nest checked (local, NZDT or NZST)',

  observer varchar(3) DEFAULT NULL COMMENT '2- or 3-character initials of the observer (see OBSERVERS table)',

  nest_id varchar(8) DEFAULT NULL COMMENT '
      a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA0903).',

  nest_state ENUM('F','I','H','B','pP','pD','P','D','notA','O') DEFAULT NULL COMMENT '
      nest-state code for this visit. Examples include: <br>
      <strong>F</strong> (found, but not incubated, e.g., incomplete) <br>
      <strong>I</strong> (incubated, active nest, warm eggs) <br>
      <strong>H</strong> (hatched, chicks seen) <br>
      <strong>B</strong> (brood seen) <br>
      <strong>pP</strong> (possibly predated) <br>
      <strong>pD</strong> (possibly deserted) <br>
      <strong>P</strong> (confident predated) <br>
      <strong>D</strong> (confident deserted) <br>
      <strong>notA</strong> (not Active, nest marks removed) <br>
      <strong>O</strong> (other; describe in comments)',
      
  hatch_state varchar(50) DEFAULT NULL COMMENT '
    No. of eggs (1 to 4) followed by egg state: <br>
    <strong>N</strong> (no sign) <br>
    <strong>S</strong> (star) <br>
    <strong>C</strong> (crack) <br>
    <strong>CC</strong> (multiple or a big crack) <br>
    Examples: <br>
    <strong>4N</strong> <br>
    <strong>2N2S</strong> <br>
    <strong>1N1S1C1CC</strong>',
    
  gps_id tinyint unsigned DEFAULT NULL COMMENT 'handheld Garmin GPS ID (recorded when nest_id is assigned at intial discovery: for both nests and broods)',

  gps_point int unsigned DEFAULT NULL COMMENT 'waypoint number of the nest or brood location stored in your handheld Garmin GPS unit (recorded when nest_id is assigned at intial discovery: for both nests and broods)',

  clutch_size tinyint unsigned DEFAULT NULL COMMENT 'Clutch size (number of eggs in the nest excluding hatched chicks)',

  brood_size tinyint unsigned DEFAULT NULL COMMENT 'Number of hatched chicks at (or in the vicinity) of the nest',
  
  cam_id varchar(10) DEFAULT NULL COMMENT 'ID of your field camera',

  photo_start varchar(255) DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',

  photo_end varchar(255) DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',

  comments text DEFAULT NULL COMMENT 'Comments',

  nov int unsigned DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY species (species),
  KEY date (date),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB ;


DROP TABLE IF EXISTS RESIGHTINGS ;
CREATE TABLE RESIGHTINGS (

  species char(4) DEFAULT NULL COMMENT '
  4-letter species code: <br>
  <strong>BADO</strong> (Banded Dotterel) <br>
  <strong>WRYB</strong> (Wrybill) <br> 
  <strong>SNZD</strong> (Southern New Zealand Dotterel) <br> 
  <strong>BFDO</strong> (Black-fronted Dotterel)',

  observer varchar(3) DEFAULT NULL COMMENT '2- or 3-character initials of the observer (see OBSERVERS table)',

  gps_id tinyint unsigned DEFAULT NULL COMMENT 'handheld Garmin GPS ID',

  gps_point int unsigned DEFAULT NULL COMMENT 'waypoint number of the resighting location stored in your handheld Garmin GPS unit',

  date date DEFAULT NULL COMMENT 'Date resighting made YYYY-MM-DD (local, NZDT or NZST)',

  site varchar(2) DEFAULT NULL COMMENT '
      2-letter site codes:<br>
      <strong>AR</strong> (Aparima River) <br>
      <strong>AU</strong> (Upper Ashburton) <br>
      <strong>CH</strong> (Chathams) <br>
      <strong>CL</strong> (Clarence River) <br>
      <strong>CR</strong> (Cass River) <br>
      <strong>HC</strong> (Hawkes Bay Coast) <br>
      <strong>HR</strong> (Hawkes Bay Rivers) <br>
      <strong>KK</strong> (Kaikoura) <br>
      <strong>KP</strong> (Kina Peninsula) <br>
      <strong>KT</strong> (Kaitorete Spit) <br>
      <strong>MB</strong> (Maryburn) <br>
      <strong>MR</strong> (Macaulay River) <br>
      <strong>MS</strong> (Motueka Spit) <br>
      <strong>OD</strong> (Ohau Downs) <br>
      <strong>OK</strong> (Okarito) <br>
      <strong>OM</strong> (Old Man Range) <br>
      <strong>PB</strong> (Porters Beach) <br>
      <strong>PR</strong> (Pisa Range) <br>
      <strong>TA</strong> (Te Anau (Upukerora)) <br>
      <strong>TO</strong> (Tongariro (Rangipo Desert)) <br>
      <strong>TP</strong> (Tiwai Point) <br>
      <strong>TR</strong> (Tekapo River) <br>
      <strong>TS</strong> (Tasman River) <br>
      <strong>WA</strong> (Wairarapa) <br>
      <strong>WN</strong> (West Coast North) <br>
      <strong>WS</strong> (West Coast South)',

  rclass ENUM('C','V','R','P','H') DEFAULT NULL COMMENT '
  Resighting class: <br>
      <strong>C</strong> (pre-capture) <br>
      <strong>V</strong> (video session) <br>
      <strong>R</strong> (regular) <br>
      <strong>P</strong> (photography session) <br>
      <strong>H</strong> (hiding-spot photo observation)',

  UL varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      FXYZ (Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0)',

  LL varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band assigned): <br>
      <strong>X</strong> (blank)            <br>
      <strong>O</strong> (orange)           <br>
      <strong>Y</strong> (yellow)           <br>
      <strong>W</strong> (white)            <br>
      <strong>B</strong> (blue)             <br>
      <strong>R</strong> (red)              <br>
      <strong>G</strong> (green)            <br>
      <strong>L</strong> (light green lime) <br>
      <strong>M</strong> (metal)            <br>
   No flag assigned to tarsi',

  UR varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      <strong>T</strong> (tag, e.g., for a geolocator on the tibia, note that when used, the tag_id field also needs to be completed)              <br>
      FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0)',

  LR varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band assigned): <br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
   No flag assigned to tarsi.',

  sex ENUM('M','M?','F','F?','U') DEFAULT NULL COMMENT '
   observed sex based on field observations (ornamentation, behaviour, etc.):<br>
   <strong>M</strong> (male), <br>
   <strong>M?</strong> (male, but uncertain), <br>
   <strong>F</strong> (female), <br>
   <strong>F?</strong> (female, but uncertain), <br>
   <strong>U</strong> (unknown)',

  age ENUM('A','J','C') DEFAULT NULL COMMENT '
  age of observed individual: <br>
  <strong>A</strong> (Adult),<br>
  <strong>J</strong> (Juvenile),<br>
  <strong>C</strong> (Chick)',

  behav text DEFAULT NULL COMMENT '
  behavioral class, as many as applicable, separated by a comma:<br>
    <strong>IN</strong> = incubating <br>
    <strong>CO</strong> = courtship <br>
    <strong>PR</strong> = preening <br>
    <strong>BW</strong> = distraction display (e.g. broken wing) <br>
    <strong>BC</strong> = brooding chicks <br>
    <strong>NM</strong> = nest maintenance <br>
    <strong>SC</strong> = scraping <br>
    <strong>FC</strong> = foraging with chicks <br>
    <strong>FA</strong> = foraging alone <br>
    <strong>FM</strong> = foraging with (presumed) mate <br>
    <strong>FF</strong> = foraging in flock <br>
    <strong>RS</strong> = roosting <br>
    <strong>LF</strong> = loafing <br>
    <strong>AT</strong> = alert <br>
    <strong>FT</strong> = fighting <br>
    <strong>OB</strong> = other behaviour (please comment)',

  nest_id varchar(8) DEFAULT NULL COMMENT '
      a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA0903).',

  cam_id varchar(10) DEFAULT NULL COMMENT 'ID of your field camera',

  photo_start varchar(255) DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',

  photo_end varchar(255) DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',

  harddrive_id smallint unsigned DEFAULT NULL COMMENT 'harddrive ID where photos/videos were uploaded after returning from the field',

  comments text DEFAULT NULL COMMENT 'Comments',

  falcon_upload tinyint(1) unsigned DEFAULT NULL COMMENT '
    Was the resighting uploaded to FALCON? Leave blank unless managing the DOC upload to FALCON <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',

  nov int unsigned DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,gps_point),
  KEY nest (nest_id),
  KEY species (species),
  KEY date (date),
  KEY site (site)
) ENGINE=InnoDB  ;


DROP TABLE IF EXISTS RESIGHTINGS_PUBLIC ;
CREATE TABLE RESIGHTINGS_PUBLIC (
  species char(4) NOT NULL COMMENT '
  4-letter species code: <br>
  <strong>BADO</strong> (Banded Dotterel) <br>
  <strong>WRYB</strong> (Wrybill) <br> 
  <strong>SNZD</strong> (Southern New Zealand Dotterel) <br> 
  <strong>BFDO</strong> (Black-fronted Dotterel)',

  observer varchar(255) NOT NULL COMMENT 'Name or initials of the observer as provided by the original source',

  time time NOT NULL COMMENT 'hh:mm time of observation (local time if known)',

  date date NOT NULL COMMENT 'Date observation made YYYY-MM-DD',

  latitude double DEFAULT NULL COMMENT 'Latitude in decimal degrees',

  longitude double DEFAULT NULL COMMENT 'Longitude in decimal degrees',

  easting double DEFAULT NULL COMMENT 'Projected easting coordinate if supplied by the source',

  northing double DEFAULT NULL COMMENT 'Projected northing coordinate if supplied by the source',

  sex ENUM('M','M?','F','F?','U') DEFAULT NULL COMMENT '
   observed sex based on field observations, observer notes, or source metadata:<br>
   <strong>M</strong> (male), <br>
   <strong>M?</strong> (male, but uncertain), <br>
   <strong>F</strong> (female), <br>
   <strong>F?</strong> (female, but uncertain), <br>
   <strong>U</strong> (unknown)',

  UL varchar(4) NOT NULL COMMENT '
  code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      FXYZ (Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0)',

  LL varchar(4) NOT NULL COMMENT '
  code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band assigned): <br>
      <strong>X</strong> (blank)            <br>
      <strong>O</strong> (orange)           <br>
      <strong>Y</strong> (yellow)           <br>
      <strong>W</strong> (white)            <br>
      <strong>B</strong> (blue)             <br>
      <strong>R</strong> (red)              <br>
      <strong>G</strong> (green)            <br>
      <strong>L</strong> (light green lime) <br>
      <strong>M</strong> (metal)            <br>
   No flag assigned to tarsi',

  UR varchar(4) NOT NULL COMMENT '
  code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned):<br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
      <strong>T</strong> (tag, e.g., for a geolocator on the tibia, note that when used, the tag_id field also needs to be completed)              <br>
      FXYZ (Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0)',

  LR varchar(4) NOT NULL COMMENT '
  code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band assigned): <br>
      <strong>X</strong> (blank)              <br>
      <strong>O</strong> (orange)             <br>
      <strong>Y</strong> (yellow)             <br>
      <strong>W</strong> (white)              <br>
      <strong>B</strong> (blue)               <br>
      <strong>R</strong> (red)                <br>
      <strong>G</strong> (green)              <br>
      <strong>L</strong> (light green "lime") <br>
      <strong>M</strong> (metal)              <br>
   No flag assigned to tarsi.',

  behav text DEFAULT NULL COMMENT '
  behavioral class, as many as applicable, separated by a comma:<br>
    <strong>IN</strong> = incubating <br>
    <strong>CO</strong> = courtship <br>
    <strong>PR</strong> = preening <br>
    <strong>BW</strong> = distraction display (e.g. broken wing) <br>
    <strong>BC</strong> = brooding chicks <br>
    <strong>NM</strong> = nest maintenance <br>
    <strong>FC</strong> = foraging with chicks <br>
    <strong>FA</strong> = foraging alone <br>
    <strong>FM</strong> = foraging with (presumed) mate <br>
    <strong>FF</strong> = foraging in flock <br>
    <strong>RS</strong> = roosting <br>
    <strong>LF</strong> = loafing <br>
    <strong>AT</strong> = alert <br>
    <strong>FT</strong> = fighting <br>
    <strong>OB</strong> = other behaviour (please comment)',

  num_photos int unsigned DEFAULT NULL COMMENT 'Number of photos associated with this public observation',

  source varchar(50) NOT NULL COMMENT 'Source of the public observation (e.g., eBird, email, WhatsApp, Banding Office, etc.)',

  source_identifier varchar(500) NOT NULL COMMENT 'Identifier used by the source, such as the email-thread subject',

  country ENUM('NZ','AU','O') NOT NULL COMMENT '
    country code of the observation source or observation location: <br>
    <strong>NZ</strong> (New Zealand) <br>
    <strong>AU</strong> (Australia) <br>
    <strong>O</strong> (Other; describe in comments_db)',

  site varchar(2) DEFAULT NULL COMMENT '
      2-letter site codes:<br>
      <strong>AR</strong> (Aparima River) <br>
      <strong>AU</strong> (Upper Ashburton) <br>
      <strong>CH</strong> (Chathams) <br>
      <strong>CL</strong> (Clarence River) <br>
      <strong>CR</strong> (Cass River) <br>
      <strong>HC</strong> (Hawkes Bay Coast) <br>
      <strong>HR</strong> (Hawkes Bay Rivers) <br>
      <strong>KK</strong> (Kaikoura) <br>
      <strong>KP</strong> (Kina Peninsula) <br>
      <strong>KT</strong> (Kaitorete Spit) <br>
      <strong>MB</strong> (Maryburn) <br>
      <strong>MR</strong> (Macaulay River) <br>
      <strong>MS</strong> (Motueka Spit) <br>
      <strong>OD</strong> (Ohau Downs) <br>
      <strong>OK</strong> (Okarito) <br>
      <strong>OM</strong> (Old Man Range) <br>
      <strong>PB</strong> (Porters Beach) <br>
      <strong>PR</strong> (Pisa Range) <br>
      <strong>TA</strong> (Te Anau (Upukerora)) <br>
      <strong>TO</strong> (Tongariro (Rangipo Desert)) <br>
      <strong>TP</strong> (Tiwai Point) <br>
      <strong>TR</strong> (Tekapo River) <br>
      <strong>TS</strong> (Tasman River) <br>
      <strong>WA</strong> (Wairarapa) <br>
      <strong>WN</strong> (West Coast North) <br>
      <strong>WS</strong> (West Coast South)',

  comments_obs text DEFAULT NULL COMMENT 'Observer/source comments copied from the original record',

  comments_db text DEFAULT NULL COMMENT 'Internal database comments added during checking or curation',

  falcon_upload ENUM('0','1') DEFAULT NULL COMMENT '
    Was the public resighting uploaded to FALCON? Leave blank unless managing the DOC upload to FALCON <br>
    <strong>0</strong> (no) or <br>
    <strong>1</strong> (yes)',

  nov int unsigned DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY species (species),
  KEY date (date),
  KEY site (site)
) ENGINE=InnoDB  ;


-- VIEWS
  CREATE OR REPLACE VIEW FIELD_2025_BADOatNZ.CAPTURES_ARCHIVE AS
  SELECT site, lat, lon ,date ,cap_start ,capture_method ,nest_id,observer,field_sex ,age  ,ring ,UL   ,LL   ,UR   ,LR   ,tag_id ,tag_action ,tag_type,tag_extras ,harness_size,culmen  ,tarsus ,total_head ,head_white,head_black     ,rufous_band ,wing ,weight ,moult,fat,sample
  FROM FIELD_2024_BADOatNZ.CAPTURES c LEFT JOIN FIELD_2024_BADOatNZ.GPS_POINTS g 
  on c.gps_id = g.gps_id and c.gps_point = g.gps_point


  CREATE OR REPLACE VIEW FIELD_2025_BADOatNZ.CAPTURES_active AS
  SELECT site, lat, lon ,date ,cap_start ,capture_method ,nest_id,observer,field_sex ,age  ,ring ,UL   ,LL   ,UR   ,LR   ,tag_id ,tag_action ,tag_type,tag_extras ,NULL harness_size,culmen  ,tarsus ,total_head ,head_white,head_black     ,rufous_band ,wing ,weight ,moult,fat,sample
  FROM FIELD_2025_BADOatNZ.CAPTURES c LEFT JOIN FIELD_2025_BADOatNZ.GPS_POINTS g 
  on c.gps_id = g.gps_id and c.gps_point = g.gps_point

-- WITHIN-SEASON UPDATES


  -- nest ID in all tables
  ALTER TABLE NESTS
    MODIFY COLUMN nest_id VARCHAR(8) DEFAULT NULL COMMENT
    'a 7-character string: SSXXYYY, Where SS is the species (the first two letters of the species name), <br>
    XX = your GPS number (01 to 30)                   <br>
    YYY = your running nest number (001 to 999).      <br>
    Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA09003).'

  ALTER TABLE CAPTURES
    MODIFY COLUMN nest_id VARCHAR(8) DEFAULT NULL COMMENT
    'a 7-character string: SSXXYYY, Where SS is the species (the first two letters of the species name), <br>
    XX = your GPS number (01 to 30)                   <br>
    YYY = your running nest number (001 to 999).      <br>
    Note if a brood was found of unknown origin, the nest_id is coded as a <strong>negative</strong> (e.g., -BA09003).'


  --  behav in  NEST table:

  ALTER TABLE NESTS
    CHANGE COLUMN behav behav_F TEXT DEFAULT NULL COMMENT
    '    female behavioral class, as many as applicable, seperated by a comma:<br>
      "IN" = incubating                            <br>
      "PR" = preening                              <br>
      "BW" = distraction display (e.g.broken wing) <br>
      "BC" = brooding chicks                       <br>
      "NM" = nest maintenance                      <br>
      "FC" = foraging with chicks                  <br>
      "RS" = roosting                              <br>
      "LF" = loafing                               <br>
      "AT" = alert                                 <br>
      "FT" = fighting                              <br>
      "OB" = other behavious (please comment)'



    ALTER TABLE NESTS
      ADD COLUMN behav_M TEXT DEFAULT NULL COMMENT
      'male behavioral class, as many as applicable, separated by a comma:<br>
      "IN" = incubating <br>
      "PR" = preening <br>
      "BW" = distraction display (e.g. broken wing) <br>
      "BC" = brooding chicks <br>
      "NM" = nest maintenance <br>
      "FC" = foraging with chicks <br>
      "RS" = roosting <br>
      "LF" = loafing <br>
      "AT" = alert <br>
      "FT" = fighting <br>
      "OB" = other behaviours (please comment)'
      AFTER behav_F;


--- behav in resightings
  ALTER TABLE RESIGHTINGS
    MODIFY COLUMN behav text  DEFAULT NULL COMMENT
    'behavioral class, as many as applicable, seperated by a comma:<br>
      "IN" = incubating                            <br>
      "CO" = courtship                             <br>
      "PR" = preening                              <br>
      "BW" = distraction display (e.g.broken wing) <br>
      "BC" = brooding chicks                       <br>
      "NM" = nest maintenance                      <br>
      "SC" = scraping                              <br>
      "FC" = foraging with chicks                  <br>
      "FA" = foraging alone                        <br>
      "FM" = foraging with (presumed) mate         <br>
      "FF" = foraging in flock                     <br>
      "RS" = roosting                              <br>
      "LF" = loafing                               <br>
      "AT" = alert                                 <br>
      "FT" = fighting                              <br>
      "OB" = other behavious (please comment)'


  --- nest and eggs

ALTER TABLE NESTS ADD COLUMN book_id INT(2)   DEFAULT NULL COMMENT
  '3-character integer that is a unique book_id (i.e., your fieldnote book)'; 

ALTER TABLE NESTS ADD COLUMN form_id INT(3)  LL DEFAULT NULL COMMENT
  '2-character integer that is a unique page of your book_id';

ALTER TABLE EGGS ADD COLUMN book_id INT(2) DEFAULT NULL COMMENT
  '3-character integer that is a unique book_id (i.e., your fieldnote book)';

ALTER TABLE EGGS ADD COLUMN form_id INT(3)   DEFAULT NULL COMMENT
  '2-character integer that is a unique page of your book_id';
