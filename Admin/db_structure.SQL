
-- COMMENT-s can be styled with html markup.

-- DROP DATABASE IF EXISTS FIELD_2026_BADOatNZ;

CREATE DATABASE IF NOT EXISTS FIELD_2026_BADOatNZ;

USE FIELD_2026_BADOatNZ;

DROP TABLE IF EXISTS OBSERVERS ;
CREATE TABLE OBSERVERS (
  name text DEFAULT NULL COMMENT 'Your full name.',
  observer varchar(3) DEFAULT NULL COMMENT 'Your initials. Use two or three letters. This is what you will use when entering data.',
  start date                   DEFAULT NULL COMMENT 'Start of work (YYYY-MM-DD)',
  stop date                    DEFAULT NULL COMMENT 'End of work (YYYY-MM-DD)',
  gps_id tinyint unsigned DEFAULT NULL COMMENT 'Personal GPS ID',
  cam_id varchar(255) DEFAULT NULL COMMENT 'Personal cameral ID',
  nznbbs_number CHAR(4) DEFAULT NULL COMMENT 'Your 4-character New Zealand National Bird Banding Scheme (NZNBBS) certification number'
) ENGINE=InnoDB ;

INSERT INTO OBSERVERS (name, observer, START, STOP, gps_id, cam_id)
VALUES
  (NULL, NULL, NULL, NULL, NULL, NULL),
  (NULL, NULL, NULL, NULL, NULL, NULL),
  (NULL, NULL, NULL, NULL, NULL, NULL);



DROP TABLE IF EXISTS CAPTURES;
CREATE TABLE CAPTURES (
  date date DEFAULT                             NULL COMMENT 'Date caught YYYY-MM-DD (local, NZDT or NZST)',

  cap_start time DEFAULT                        NULL COMMENT 'hh:mm capture start (when you set the trap or commenced trapping with the mistnet)',

  caught time DEFAULT                           NULL COMMENT 'hh:mm time caught (local, NZDT or NZST)',

  released time DEFAULT                         NULL COMMENT 'hh:mm time released (local, NZDT or NZST)',

  species char(4) DEFAULT                       NULL COMMENT '
  4-letter species code: <br>
  <b>BADO</b> (Banded Dotterel) <br>
  <b>WRYB</b> (Wrybill) <br> 
  <b>SNZD</b> (Southern New Zealand Dotterel) <br> 
  <b>BFDO</b> (Black-fronted Dotterel)',

  site varchar(2) DEFAULT                     NULL COMMENT '
      Sites:<br>
      <b>AR</b> (Aparima River)<br>
      <b>AU</b> (Upper Ashburton)<br>
      <b>CH</b> (Chathams)<br>
      <b>CL</b> (Clarence River)<br>
      <b>CR</b> (Cass River)<br>
      <b>HC</b> (Hawkes Bay Coast)<br>
      <b>HR</b> (Hawkes Bay Rivers)<br>
      <b>KK</b> (Kaikoura)<br>
      <b>KP</b> (Kina Peninsula)<br>
      <b>KT</b> (Kaitorete Spit)<br>
      <b>MB</b> (Maryburn)<br>
      <b>MR</b> (Macaulay River)<br>
      <b>MS</b> (Motueka Spit)<br>
      <b>OD</b> (Ohau Downs)<br>
      <b>OK</b> (Okarito)<br>
      <b>OM</b> (Old Man Range)<br>
      <b>PB</b> (Porters Beach)<br>
      <b>PR</b> (Pisa Range)<br>
      <b>TA</b> (Te Anau (Upukerora))<br>
      <b>TO</b> (Tongariro (Rangipo Desert))<br>
      <b>TP</b> (Tiwai Point)<br>
      <b>TR</b> (Tekapo River)<br>
      <b>TS</b> (Tasman River)<br>
      <b>WA</b> (Wairarapa)<br>
      <b>WN</b> (West Coast North)<br>
      <b>WS</b> (West Coast South)',

  book_id smallint unsigned DEFAULT      NULL COMMENT '3-character integer that is a unique book_id (i.e., your fieldnote book)',

  form_id smallint unsigned DEFAULT      NULL COMMENT '2-character integer that is a unique page of your book_id',

  observer varchar(3) DEFAULT                   NULL COMMENT '2- or 3-character initials of the bander (see OBSERVERS table)',

  capture_status ENUM('F','R','C','D') DEFAULT  NULL COMMENT '
      <b>F</b> (First marking)<br>
      <b>R</b> (Recaptured but band combination not changed)<br>
      <b>C</b> (recaptured and band combination Changed),<br>
      <b>D</b> (was Dead when captured: write description in comments)',

  capture_method ENUM('HA','TB','TN','SM','MM','O') DEFAULT NULL COMMENT '
      <b>HA</b> (HAnd)                <br>
      <b>TB</b> (clap-Trap on Brood)  <br>
      <b>TN</b> (clap-Trap on Nest)   <br>
      <b>SM</b> (Stationary Mistnet)  <br>
      <b>MM</b> (Mobile Mistnet)      <br>
      <b>O</b>  (Other; please specify in comments)',
  
  nest_id varchar(7) DEFAULT                    NULL COMMENT '
      a 6- or 7-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <b>negative</b> (e.g., -BA0903).',

  caught_with varchar(255) DEFAULT              NULL COMMENT '
      Social members caught with focal individual, comma separated: <br>
      M (mate, high certainty) <br>
      M? (mate, unsure, but likely) <br>
      S (same sex conspecific, e.g., rival individual) <br>
      C (chick, e.g., "2C" for two chicks)',

  parents ENUM('MF','F','M','U1','U2','O') DEFAULT NULL COMMENT '
      If chicks captured, which parents were seen attending? <br>
        <b>MF</b> (male and female) <br>
        <b>F</b> (female only) <br>
        <b>M</b> (male only) <br>
        <b>U1</b> (one unknown sex parent) <br>
        <b>U2</b> (two unknown sex parents) <br>
        <b>O</b> (other (write in comments)',
      
  gps_id tinyint unsigned DEFAULT       NULL COMMENT 'handheld Garmin GPS ID',
  
  gps_point int unsigned DEFAULT   NULL COMMENT 'waypoint number of the capture location stored in your handheld Garmin GPS unit',

  field_sex ENUM('M','MU','F','FU','U') DEFAULT NULL COMMENT '
   observed sex based on field observations (ornamentation, behaviour, etc.):<br>
   <b>M</b> (male), <br>
   <b>MU</b> (male, but uncertain), <br>
   <b>F</b> (female), <br>
   <b>FU</b> (fmale, but uncertain), <br>
   <b>U</b> (unknown, e.g., for chicks and juveniles)',

  age ENUM('A','J','C') DEFAULT                 NULL COMMENT '
  age of captured individual: <br>
  <b>A</b> (Adult),<br>
  <b>J</b> (Juvenile),<br>
  <b>C</b> (Chick)',

  ring varchar(50) DEFAULT    NULL COMMENT 'alpha-numeric code of metal ring assigned to captured individual',

  UL_in varchar(4) DEFAULT    NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter)',

  LL_in varchar(4) DEFAULT   NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): <br>
      <b>X</b> (blank)            <br>
      <b>O</b> (orange)           <br>
      <b>Y</b> (yellow)           <br>
      <b>W</b> (white)            <br>
      <b>B</b> (blue)             <br>
      <b>R</b> (red)              <br>
      <b>G</b> (green)            <br>
      <b>L</b> (light green lime) <br>
      <b>M</b> (metal)            <br>
   No flag assigned to tarsi',

  UR_in varchar(4) DEFAULT                         NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band     assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      <b>T</b> (tag; if used, also complete tag_id) <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).',

  LR_in varchar(4) DEFAULT                         NULL COMMENT '
  AT CAPTURE/BEFORE HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one     band assigned): <br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
   No flag assigned to tarsi.',
   
   UL varchar(4) DEFAULT    NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter)',

  LL varchar(4) DEFAULT   NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): <br>
      <b>X</b> (blank)            <br>
      <b>O</b> (orange)           <br>
      <b>Y</b> (yellow)           <br>
      <b>W</b> (white)            <br>
      <b>B</b> (blue)             <br>
      <b>R</b> (red)              <br>
      <b>G</b> (green)            <br>
      <b>L</b> (light green lime) <br>
      <b>M</b> (metal)            <br>
   No flag assigned to tarsi',

  UR varchar(4) DEFAULT                         NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band     assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      <b>T</b> (tag; if used, also complete tag_id) <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).',

  LR varchar(4) DEFAULT                         NULL COMMENT '
  AT RELEASE/AFTER HANDLING (leave blank if combo not changed);
  code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one     band assigned): <br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
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
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

  weight double DEFAULT                         NULL COMMENT 'Body mass (g) of captured individual (note: this includes the weight of the metal and colour rings).',
  
  wt_w_tag ENUM('0','1') DEFAULT                NULL COMMENT '
    Was the body weight measured with a tag on? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

  moult varchar(255) DEFAULT                    NULL COMMENT 'primary molt score of captured individual. Scored as a the stage of the moult and the number of feathers at that stage. If all 10 primaries are old feathers with no moult, it would be scored as "0(10)". See Ringers Manual, British Trust for Ornithology, Thetford for more details.',

  fat int(1) unsigned DEFAULT                   NULL COMMENT 'fat score of captured individual, scored as the amount of visible fat in the furcular region or tracheal pit. See <i>Ringers Manual, British Trust for Ornithology, Thetford for more details.</i>',

  breast_samp ENUM('0','1') DEFAULT             NULL COMMENT '
    Were breast feathers sampled? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',
    
  primary_samp ENUM('0','1') DEFAULT            NULL COMMENT '
    Was a primary feather sampled? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',
  
  blood_samp ENUM('BQ','BF','BE') DEFAULT       NULL COMMENT '
    Was blood taken?  <br>  
    <b>BQ</b> (blood in Queens buffer) <br>    
    <b>BF</b> (blood on filter paper) <br>    
    <b>BE</b> (blood in EDTA tube) <br> 
    leave blank if not collected',
  
  other_sample varchar(255) DEFAULT                    NULL COMMENT 'free text of any other samples collected (e.g., "lice")',
    
  feather_wear ENUM('0','1','2','3') DEFAULT   NULL COMMENT '
    scored as: <br>
      <b>0</b> (Fresh) <br> 
      <b>1</b> (Slightly worn) <br> 
      <b>2</b> (Moderately worn) or <br>
      <b>3</b> (Very worn). <br> 
    See NZNBBS Bird Banders Manual for more details',

  tag_id_in varchar(20) DEFAULT                 NULL COMMENT 'AT CAPTURE/BEFORE HANDLING: ID of tag/geolocator',
    
  tag_id varchar(20) DEFAULT                    NULL COMMENT 'AT RELEASE/AFTER HANDLING: ID of tag/geolocator',
  
  tag_type ENUM('PTT','GPS','GEO') DEFAULT      NULL COMMENT '
    type of tag deployed: <br>
    <b>PTT</b> (satellite tag) <br>
    <b>GPS</b> (GPS tag), or <br>
    <b>GEO</b> (light-logger geolocator)',

  tag_action ENUM('O','D','R','S','N') DEFAULT  NULL COMMENT '
      <b>O</b> (nO tag: bird did not have a tag when captured and was released without a tag)           <br>
      <b>D</b> (new Deployment: bird  did not have a tag when captured and was released with a tag) <br>
      <b>R</b> (Retrieved: bird had a tag when captured and was released without a tag)             <br>
      <b>S</b> (tag Stayed on: bird had a tag when captured and was released with the same tag)     <br>
      <b>N</b> (New tag: bird had a tag when captured and was released with a new tag)',

  cam_id varchar(10) DEFAULT                   NULL COMMENT '2- or 3-character string that is a unique ID of your field camera',

  photo_start varchar(255) DEFAULT              NULL COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255) DEFAULT                NULL COMMENT 'image filename for the last photo of the sequence',
  mugshot_photo ENUM('0','1') DEFAULT           NULL COMMENT '
    Was a mugshot photo taken? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',
  wing_photo ENUM('0','1') DEFAULT              NULL COMMENT '
    Was a wing photo taken? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',
  chick_tent_photo ENUM('0','1') DEFAULT        NULL COMMENT  '
    Was a chick photo taken in the tent? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',
  chick_hide_photo ENUM('0','1') DEFAULT        NULL COMMENT '
    Was an in-situ photo taken of a hiding chick? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

  comments text DEFAULT                         NULL COMMENT 'Comments',

  falcon_upload tinyint(1) unsigned DEFAULT     NULL COMMENT  '
    Was the capture uploaded to FALCON? Leave blank unless managing the DOC upload to FALCON <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

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
      <b>BADO</b> (Banded Dotterel) <br>
      <b>WRYB</b> (Wrybill) <br> 
      <b>SNZD</b> (Southern New Zealand Dotterel) <br> 
      <b>BFDO</b> (Black-fronted Dotterel)',

  observer varchar(3) DEFAULT NULL COMMENT '2- or 3-character initials of the observer (see OBSERVERS table)',

  date date DEFAULT NULL COMMENT 'Date eggs measured YYYY-MM-DD (local, NZDT or NZST)',

  time_visit time DEFAULT NULL COMMENT 'hh:mm time eggs were measured (local, NZDT or NZST)',

  nest_id varchar(8) DEFAULT NULL COMMENT '
      a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <b>negative</b> (e.g., -BA0903).',

  egg_id tinyint unsigned DEFAULT NULL COMMENT '
      egg number within the nest: <br>
      <b>1</b> (first egg) <br>
      <b>2</b> (second egg) <br>
      <b>3</b> (third egg) <br>
      <b>4</b> (fourth egg)',

  float_angle tinyint unsigned DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90)',

  float_surface tinyint unsigned DEFAULT NULL COMMENT 'Height of egg above water surface (mm)',

  float_location ENUM('bottom','suspended','surface') DEFAULT NULL COMMENT '
      Position of the egg in the floating jar: <br>
      <b>bottom</b> <br>
      <b>suspended</b> <br>
      <b>surface</b>',

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
  <b>BADO</b> (Banded Dotterel) <br>
  <b>WRYB</b> (Wrybill) <br> 
  <b>SNZD</b> (Southern New Zealand Dotterel) <br> 
  <b>BFDO</b> (Black-fronted Dotterel)',

  site varchar(2) DEFAULT NULL COMMENT '
      Sites:<br>
      <b>AR</b> (Aparima River)<br>
      <b>AU</b> (Upper Ashburton)<br>
      <b>CH</b> (Chathams)<br>
      <b>CL</b> (Clarence River)<br>
      <b>CR</b> (Cass River)<br>
      <b>HC</b> (Hawkes Bay Coast)<br>
      <b>HR</b> (Hawkes Bay Rivers)<br>
      <b>KK</b> (Kaikoura)<br>
      <b>KP</b> (Kina Peninsula)<br>
      <b>KT</b> (Kaitorete Spit)<br>
      <b>MB</b> (Maryburn)<br>
      <b>MR</b> (Macaulay River)<br>
      <b>MS</b> (Motueka Spit)<br>
      <b>OD</b> (Ohau Downs)<br>
      <b>OK</b> (Okarito)<br>
      <b>OM</b> (Old Man Range)<br>
      <b>PB</b> (Porters Beach)<br>
      <b>PR</b> (Pisa Range)<br>
      <b>TA</b> (Te Anau (Upukerora))<br>
      <b>TO</b> (Tongariro (Rangipo Desert))<br>
      <b>TP</b> (Tiwai Point)<br>
      <b>TR</b> (Tekapo River)<br>
      <b>TS</b> (Tasman River)<br>
      <b>WA</b> (Wairarapa)<br>
      <b>WN</b> (West Coast North)<br>
      <b>WS</b> (West Coast South)',

  date date DEFAULT NULL COMMENT 'Date nest checked YYYY-MM-DD (local, NZDT or NZST)',

  time_visit time DEFAULT NULL COMMENT 'hh:mm time nest checked (local, NZDT or NZST)',

  observer varchar(3) DEFAULT NULL COMMENT '2- or 3-character initials of the observer (see OBSERVERS table)',

  nest_id varchar(8) DEFAULT NULL COMMENT '
      a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <b>negative</b> (e.g., -BA0903).',

  nest_state ENUM('F','I','H','B','pP','pD','P','D','notA','O') DEFAULT NULL COMMENT '
      nest-state code for this visit. Examples include: <br>
      <b>F</b> (found, but not incubated, e.g., incomplete) <br>
      <b>I</b> (incubated, active nest, warm eggs) <br>
      <b>H</b> (hatched, chicks seen) <br>
      <b>B</b> (brood seen) <br>
      <b>pP</b> (possibly predated) <br>
      <b>pD</b> (possibly deserted) <br>
      <b>P</b> (confident predated) <br>
      <b>D</b> (confident deserted) <br>
      <b>notA</b> (not Active, nest marks removed) <br>
      <b>O</b> (other; describe in comments)',
      
  hatch_state varchar(50) DEFAULT NULL COMMENT '
    No. of eggs (1 to 4) followed by egg state: <br>
    <b>N</b> (no sign) <br>
    <b>S</b> (star) <br>
    <b>C</b> (crack) <br>
    <b>CC</b> (multiple or a big crack) <br>
    Examples: <br>
    <b>4N</b> <br>
    <b>2N2S</b> <br>
    <b>1N1S1C1CC</b>',
    
  bird_inc ENUM('M','F','U','E') DEFAULT NULL COMMENT '
    incubating or attending bird seen from a distance: <br>
    <b>M</b> (male) <br>
    <b>F</b> (female) <br>
    <b>U</b> (unknown) <br>
    <b>E</b> (nest empty; no bird seen)',
    
  gps_id tinyint unsigned DEFAULT NULL COMMENT 'handheld Garmin GPS ID (recorded when nest_id is assigned at intial discovery: for both nests and broods)',

  gps_point int unsigned DEFAULT NULL COMMENT 'waypoint number of the nest or brood location stored in your handheld Garmin GPS unit (recorded when nest_id is assigned at intial discovery: for both nests and broods)',

  clutch_size tinyint unsigned DEFAULT NULL COMMENT 'Clutch size (number of eggs in the nest excluding hatched chicks)',

  brood_size tinyint unsigned DEFAULT NULL COMMENT 'Number of hatched chicks at (or in the vicinity) of the nest',
  
  cam_id varchar(10) DEFAULT NULL COMMENT 'ID of your field camera',

  photo_start varchar(255) DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',

  photo_end varchar(255) DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',
  
  nest_photo ENUM('0','1') DEFAULT        NULL COMMENT '
    Was the clutch photographed in the scrape? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',
  
  tent_photo ENUM('0','1') DEFAULT        NULL COMMENT '
    Was the clutch photographed in the tent? <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

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
  <b>BADO</b> (Banded Dotterel) <br>
  <b>WRYB</b> (Wrybill) <br> 
  <b>SNZD</b> (Southern New Zealand Dotterel) <br> 
  <b>BFDO</b> (Black-fronted Dotterel)',

  observer varchar(3) DEFAULT NULL COMMENT '2- or 3-character initials of the observer (see OBSERVERS table)',

  gps_id tinyint unsigned DEFAULT NULL COMMENT 'handheld Garmin GPS ID',

  gps_point int unsigned DEFAULT NULL COMMENT 'waypoint number of the resighting location stored in your handheld Garmin GPS unit',

  date date DEFAULT NULL COMMENT 'Date resighting made YYYY-MM-DD (local, NZDT or NZST)',

  site varchar(2) DEFAULT NULL COMMENT '
      Sites:<br>
      <b>AR</b> (Aparima River)<br>
      <b>AU</b> (Upper Ashburton)<br>
      <b>CH</b> (Chathams)<br>
      <b>CL</b> (Clarence River)<br>
      <b>CR</b> (Cass River)<br>
      <b>HC</b> (Hawkes Bay Coast)<br>
      <b>HR</b> (Hawkes Bay Rivers)<br>
      <b>KK</b> (Kaikoura)<br>
      <b>KP</b> (Kina Peninsula)<br>
      <b>KT</b> (Kaitorete Spit)<br>
      <b>MB</b> (Maryburn)<br>
      <b>MR</b> (Macaulay River)<br>
      <b>MS</b> (Motueka Spit)<br>
      <b>OD</b> (Ohau Downs)<br>
      <b>OK</b> (Okarito)<br>
      <b>OM</b> (Old Man Range)<br>
      <b>PB</b> (Porters Beach)<br>
      <b>PR</b> (Pisa Range)<br>
      <b>TA</b> (Te Anau (Upukerora))<br>
      <b>TO</b> (Tongariro (Rangipo Desert))<br>
      <b>TP</b> (Tiwai Point)<br>
      <b>TR</b> (Tekapo River)<br>
      <b>TS</b> (Tasman River)<br>
      <b>WA</b> (Wairarapa)<br>
      <b>WN</b> (West Coast North)<br>
      <b>WS</b> (West Coast South)',

  rclass ENUM('C','V','R','P','H') DEFAULT NULL COMMENT '
  Resighting class: <br>
      <b>C</b> (pre-capture) <br>
      <b>V</b> (video session) <br>
      <b>R</b> (regular) <br>
      <b>P</b> (photography session) <br>
      <b>H</b> (hiding-spot photo observation)',

  UL varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter)',

  LL varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band assigned): <br>
      <b>X</b> (blank)            <br>
      <b>O</b> (orange)           <br>
      <b>Y</b> (yellow)           <br>
      <b>W</b> (white)            <br>
      <b>B</b> (blue)             <br>
      <b>R</b> (red)              <br>
      <b>G</b> (green)            <br>
      <b>L</b> (light green lime) <br>
      <b>M</b> (metal)            <br>
   No flag assigned to tarsi',

  UR varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      <b>T</b> (tag; if used, also complete tag_id) <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).',

  LR varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band assigned): <br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
   No flag assigned to tarsi.',

  sex ENUM('M','M?','F','F?','U') DEFAULT NULL COMMENT '
   observed sex based on field observations (ornamentation, behaviour, etc.):<br>
   <b>M</b> (male), <br>
   <b>M?</b> (male, but uncertain), <br>
   <b>F</b> (female), <br>
   <b>F?</b> (female, but uncertain), <br>
   <b>U</b> (unknown)',

  age ENUM('A','J','C') DEFAULT NULL COMMENT '
  age of observed individual: <br>
  <b>A</b> (Adult),<br>
  <b>J</b> (Juvenile),<br>
  <b>C</b> (Chick)',

  behav text DEFAULT NULL COMMENT '
  behavioral class, as many as applicable, separated by a comma:<br>
    <b>IN</b> = incubating <br>
    <b>CO</b> = courtship <br>
    <b>PR</b> = preening <br>
    <b>BW</b> = distraction display (e.g. broken wing) <br>
    <b>BC</b> = brooding chicks <br>
    <b>NM</b> = nest maintenance <br>
    <b>SC</b> = scraping <br>
    <b>FC</b> = foraging with chicks <br>
    <b>FA</b> = foraging alone <br>
    <b>FM</b> = foraging with (presumed) mate <br>
    <b>FF</b> = foraging in flock <br>
    <b>RS</b> = roosting <br>
    <b>LF</b> = loafing <br>
    <b>AT</b> = alert <br>
    <b>FT</b> = fighting <br>
    <b>OB</b> = other behaviour (please comment)',

  nest_id varchar(8) DEFAULT NULL COMMENT '
      a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)           <br>
      YY = your running nest number (01 to 99).      <br>
      Note if a brood was found of unknown origin, the nest_id is coded as a <b>negative</b> (e.g., -BA0903). <br>
      Only required when: <br>
      1) <b> behav </b> is <b>IN</b> or <b>NM</b> AND <br>
      2) bird does not need to be captured (e.g., already banded) AND <br>
      3) resighting is the first observation of the bird associating with the nest (i.e., to establish social parentage)',

  cam_id varchar(10) DEFAULT NULL COMMENT 'ID of your field camera',

  photo_start varchar(255) DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',

  photo_end varchar(255) DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',
  
  comments text DEFAULT NULL COMMENT 'Comments',

  falcon_upload tinyint(1) unsigned DEFAULT NULL COMMENT '
    Was the resighting uploaded to FALCON? Leave blank unless managing the DOC upload to FALCON <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

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
  species char(4) DEFAULT NULL COMMENT '
  4-letter species code: <br>
  <b>BADO</b> (Banded Dotterel) <br>
  <b>WRYB</b> (Wrybill) <br> 
  <b>SNZD</b> (Southern New Zealand Dotterel) <br> 
  <b>BFDO</b> (Black-fronted Dotterel)',

  observer varchar(255) DEFAULT NULL COMMENT 'Name or initials of the observer as provided by the original source',

  time time DEFAULT NULL COMMENT 'hh:mm time of observation (local time if known)',

  date date DEFAULT NULL COMMENT 'Date observation made YYYY-MM-DD',

  latitude double DEFAULT NULL COMMENT 'Latitude in decimal degrees',

  longitude double DEFAULT NULL COMMENT 'Longitude in decimal degrees',

  easting double DEFAULT NULL COMMENT 'Projected easting coordinate if supplied by the source',

  northing double DEFAULT NULL COMMENT 'Projected northing coordinate if supplied by the source',

  sex ENUM('M','M?','F','F?','U') DEFAULT NULL COMMENT '
   observed sex based on field observations, observer notes, or source metadata:<br>
   <b>M</b> (male), <br>
   <b>M?</b> (male, but uncertain), <br>
   <b>F</b> (female), <br>
   <b>F?</b> (female, but uncertain), <br>
   <b>U</b> (unknown)',

  UL varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter)',

  LL varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band assigned): <br>
      <b>X</b> (blank)            <br>
      <b>O</b> (orange)           <br>
      <b>Y</b> (yellow)           <br>
      <b>W</b> (white)            <br>
      <b>B</b> (blue)             <br>
      <b>R</b> (red)              <br>
      <b>G</b> (green)            <br>
      <b>L</b> (light green lime) <br>
      <b>M</b> (metal)            <br>
   No flag assigned to tarsi',

  UR varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned):<br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
      <b>T</b> (tag; if used, also complete tag_id) <br>
      FXYZ (flag with colour X and 2-character code YZ; use the same colour letters as above and include at least one letter).',

  LR varchar(4) DEFAULT NULL COMMENT '
  code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band assigned): <br>
      <b>X</b> (blank)              <br>
      <b>O</b> (orange)             <br>
      <b>Y</b> (yellow)             <br>
      <b>W</b> (white)              <br>
      <b>B</b> (blue)               <br>
      <b>R</b> (red)                <br>
      <b>G</b> (green)              <br>
      <b>L</b> (light green "lime") <br>
      <b>M</b> (metal)              <br>
   No flag assigned to tarsi.',

  behav text DEFAULT NULL COMMENT '
  behavioral class, as many as applicable, separated by a comma:<br>
    <b>IN</b> = incubating <br>
    <b>CO</b> = courtship <br>
    <b>PR</b> = preening <br>
    <b>BW</b> = distraction display (e.g. broken wing) <br>
    <b>BC</b> = brooding chicks <br>
    <b>NM</b> = nest maintenance <br>
    <b>FC</b> = foraging with chicks <br>
    <b>FA</b> = foraging alone <br>
    <b>FM</b> = foraging with (presumed) mate <br>
    <b>FF</b> = foraging in flock <br>
    <b>RS</b> = roosting <br>
    <b>LF</b> = loafing <br>
    <b>AT</b> = alert <br>
    <b>FT</b> = fighting <br>
    <b>OB</b> = other behaviour (please comment)',

  num_photos int unsigned DEFAULT NULL COMMENT 'Number of photos associated with this public observation',

  source varchar(50) DEFAULT NULL COMMENT 'Source of the public observation (e.g., eBird, email, WhatsApp, Banding Office, etc.)',

  source_identifier varchar(500) DEFAULT NULL COMMENT 'Identifier used by the source, such as the email-thread subject',

  country ENUM('NZ','AU','O') DEFAULT NULL COMMENT '
    country code of the observation source or observation location: <br>
    <b>NZ</b> (New Zealand) <br>
    <b>AU</b> (Australia) <br>
    <b>O</b> (Other; describe in comments_db)',

  site varchar(2) DEFAULT NULL COMMENT '
      Sites:<br>
      <b>AR</b> (Aparima River)<br>
      <b>AU</b> (Upper Ashburton)<br>
      <b>CH</b> (Chathams)<br>
      <b>CL</b> (Clarence River)<br>
      <b>CR</b> (Cass River)<br>
      <b>HC</b> (Hawkes Bay Coast)<br>
      <b>HR</b> (Hawkes Bay Rivers)<br>
      <b>KK</b> (Kaikoura)<br>
      <b>KP</b> (Kina Peninsula)<br>
      <b>KT</b> (Kaitorete Spit)<br>
      <b>MB</b> (Maryburn)<br>
      <b>MR</b> (Macaulay River)<br>
      <b>MS</b> (Motueka Spit)<br>
      <b>OD</b> (Ohau Downs)<br>
      <b>OK</b> (Okarito)<br>
      <b>OM</b> (Old Man Range)<br>
      <b>PB</b> (Porters Beach)<br>
      <b>PR</b> (Pisa Range)<br>
      <b>TA</b> (Te Anau (Upukerora))<br>
      <b>TO</b> (Tongariro (Rangipo Desert))<br>
      <b>TP</b> (Tiwai Point)<br>
      <b>TR</b> (Tekapo River)<br>
      <b>TS</b> (Tasman River)<br>
      <b>WA</b> (Wairarapa)<br>
      <b>WN</b> (West Coast North)<br>
      <b>WS</b> (West Coast South)',

  comments_obs text DEFAULT NULL COMMENT 'Observer/source comments copied from the original record',

  comments_db text DEFAULT NULL COMMENT 'Internal database comments added during checking or curation',

  falcon_upload ENUM('0','1') DEFAULT NULL COMMENT '
    Was the public resighting uploaded to FALCON? Leave blank unless managing the DOC upload to FALCON <br>
    <b>0</b> (no) or <br>
    <b>1</b> (yes)',

  nov int unsigned DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY species (species),
  KEY date (date),
  KEY site (site)
) ENGINE=InnoDB  ;


--- DROP TABLE IF EXISTS inspectors; 

CREATE TABLE IF NOT EXISTS inspectors (
  table_name varchar(128) NOT NULL
    COMMENT '<strong>Inspected table</strong><br>Name of the database table this inspector applies to. This value is used by <code>inspector_loader(table_name)</code> to find the validation logic for that table.',

inspector longtext NOT NULL
  COMMENT '<strong>Validation rules</strong><br>Write the R checks that should run before this table is saved.<br><br>In these rules, <code>x</code> means the table being edited. Usually the rules are written as a <code>list(...)</code> of checks. For example:<br><code>list(x[, .(field)] |> is.na_validator())</code><br><br>If a check finds a problem, the app will show which rows need attention and will not save until the problems are fixed.<br><br>More details: https://ornitho-logics.github.io/DataEntry/articles/writing-validators.html',


  comments text NULL
    COMMENT '<strong>Inspector notes</strong><br>Optional notes about this inspector',

  updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    
);


--- DROP TABLE IF EXISTS artifacts; 
CREATE TABLE IF NOT EXISTS artifacts (
  artifact_name varchar(128) NOT NULL
    COMMENT 'This is the value the app uses to load the relevant saved code, WKT, map plot code, or todo list code.',

  artifact longtext NULL
    COMMENT '<strong>Artifact content</strong><br>Saved artifact content. This can be R code, WKT geometry, todo-list code, map configuration, or another R code used by the app.',

  comments text NULL
    COMMENT 'Optional notes about this artifact',

  updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (artifact_name)
);

INSERT IGNORE INTO artifacts (artifact_name, artifact, comments)
VALUES
  ('study_area', NULL, NULL),
  ('nests_map', NULL, NULL),
  ('daily_todo', NULL, NULL),
  ('resightings_map', NULL, NULL);



-- VIEWS 

CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.CAPTURES_active AS
SELECT site, lat, lon ,date ,cap_start ,capture_method ,nest_id,observer,field_sex ,age  ,ring ,UL   ,LL   ,UR   ,LR   ,tag_id ,tag_action ,tag_type,NULL harness_size,culmen  ,tarsus ,total_head ,head_white,head_black     ,rufous_band ,wing ,weight ,moult,fat
FROM FIELD_2026_BADOatNZ.CAPTURES c LEFT JOIN FIELD_2026_BADOatNZ.GPS_POINTS g 
on c.gps_id = g.gps_id and c.gps_point = g.gps_point;



CREATE OR REPLACE VIEW FIELD_2026_BADOatNZ.CAPTURES_ARCHIVE AS

SELECT
ring,
mark,
date,
study_year,
site_code,
capture_status,
latitude,
longitude,
field_sex,
age,
tarsus,
culmen,
wing,
weight,
moult_left,
tag_id,
tag_type
FROM BADOatNZ.CAPTURES;