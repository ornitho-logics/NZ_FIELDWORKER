-- Active: 1721374781990@@127.0.0.1@3306

-- COMMENT-s can be styled with html markup. 

DROP DATABASE IF EXISTS FIELD_2024_BADOatNZ;

CREATE DATABASE IF NOT EXISTS FIELD_2024_BADOatNZ;

USE FIELD_2024_BADOatNZ;

SHOW TABLES FROM FIELD_2024_BADOatNZ;

CREATE TABLE OBSERVERS (
  name varchar(255)                          DEFAULT NULL COMMENT 'Your full name.',
  observer varchar(255)                      DEFAULT NULL COMMENT 'Your initials. Use two or three letters. This is what you will use when entering data.',
  affiliation varchar(255)                   DEFAULT NULL COMMENT 'Your affiliation as it would listed in a publication',
  email varchar(255)                         DEFAULT NULL COMMENT 'An email address which can be used for data enquiries about your observations',
  gps_id int(5)                              DEFAULT NULL COMMENT 'Personal GPS ID',
  radio_id int(5)                            DEFAULT NULL COMMENT 'Personal radio ID',
  cam_id int(5)                              DEFAULT NULL COMMENT 'Personal camcorder ID',
  harddrive_id int(5)                        DEFAULT NULL COMMENT 'Team harddrive ID where photos were uploaded after returning from the field',
  remarks TEXT                               DEFAULT NULL COMMENT 'Please provide any relevant information, such as your ratings in cooking, chess, or poker.'
) ENGINE=InnoDB;

DROP TABLE CAPTURES;

CREATE TABLE CAPTURES (
  species varchar(50)                  DEFAULT NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  site char(2)                         DEFAULT NULL COMMENT 
        '2-letter abbreviation for the site of capture<hr> MS = Motueka Spit<br>, CR = Cass River<br>, KK = Kaikoura<br>, KT = Kaitorete Spit<br>, MR = Macaulay River<br>, TP = Tiwai Point<br>, MB = Maryburn<br>, TS = Tasman<br>, OD = Ohau Downs<br>, TR = Tekapo River<br>, TA = Te Anau<br>, PR = Pisa Range<br>',
  date date                            DEFAULT NULL COMMENT 'Date caught YYYY-MM-DD (local)',
  cap_start time                       DEFAULT NULL COMMENT 'hh:mm capture start (when you set the trap or commenced trapping with the mistnet)',
  caught time                          DEFAULT NULL COMMENT 'hh:mm time caught (local, NZDT or NZST)',
  released time                        DEFAULT NULL COMMENT 'hh:mm time released (local, NZDT or NZST)',
  capture_method char(2)               DEFAULT NULL COMMENT 'HA (HAnd), TB (clap-Trap on Brood), TN (clap-Trap on Nest), SM (Stationary Mistnet), MM (Mobile Mistnet), O (Other; please specify in comments)',
  nest_id varchar(6)                   DEFAULT NULL COMMENT 'a 4- to 5-character string: SXYY, Where S is the species (the first letter of the species name), X = your GPS number, YY = your running nest number (01 to 99). Note if a brood was found of unknown origin, the nest_id is coded as a negative (e.g., -B903, would be the 3rd unknown banded dotterel brood encountered by the observer with GPS 9).',
  book_id int(2)                       DEFAULT NULL COMMENT '3-character integer that is a unique book_id (i.e., your fieldnote book)',
  form_id int(3)                       DEFAULT NULL COMMENT '2-character integer that is a unique page of your book_id',
  observer varchar(3)                  DEFAULT NULL COMMENT 'Initials of the bander (see OBSERVERS table)',
  gps_id int(11)                       DEFAULT NULL COMMENT 'handheld Garmin GPS ID',
  gps_point int(11)                    DEFAULT NULL COMMENT 'waypoint number of the capture location stored in your handheld Garmin GPS unit',
  field_sex char(1)                    DEFAULT NULL COMMENT 'observed sex based on field observations (ornamentation, behaviour, etc.): "M" (male), "F" (female), "U" (unknown)',
  age char(1)                          DEFAULT NULL COMMENT 'age of captured individual: "A" (Adult), "J" (Juvenile)',
  ring varchar(255)                    DEFAULT NULL COMMENT 'alpha-numeric code of metal ring assigned to captured individual',
  band_left_tibia varchar(10)          DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  band_left_tarsus varchar(10)         DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  band_right_tibia varchar(10)         DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  band_right_tarsus varchar(10)        DEFAULT NULL COMMENT 'code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  tag_id_deploy varchar(10)            DEFAULT NULL COMMENT 'ID of tag deployed on bird when it was released',
  tag_id_retrieve varchar(10)          DEFAULT NULL COMMENT 'ID of tag that was retrieved from bird',
  tag_weight double                    DEFAULT NULL COMMENT 'weight (g) of deployed tag including harness',
  tag_action varchar(4)                DEFAULT NULL COMMENT '"O" (nO tag: bird did not have a tag when captured and was released without a tag), "D" (new Deployment: bird did not have a tag when captured and was released with a tag), "R" (Retrieved: bird had a tag when captured and was released without a tag), "S" (tag Stayed on: bird had a tag when captured and was released with the same tag), "N" (New tag: bird had a tag when captured and was released with a new tag)',
  culmen double                        DEFAULT NULL COMMENT 'length (mm) of upper mandible of captured individual. Measured as the distance between the tip of the forehead feathering at the base of the upper bill, along the ridge of the culmen, and the tip of the bill (also known as the "exposed culmen" measurement; sensu page 8 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  left_tarsus double                   DEFAULT NULL COMMENT 'length (mm) of left tarsus of captured individual. Measured as the distance between the notch at the end of the lateral condyle of the tibiotarsus on the backside of the leg, to the last tarsal scute on the front of the leg at the base of the foot (also known as the "outside tarsus" or "diagonal tarsus" measurement; sensu page 11 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  right_tarsus double                  DEFAULT NULL COMMENT 'length (mm) of right tarsus of captured individual. Measured as the distance between the notch at the end of the lateral condyle of the tibiotarsus on the backside of the leg, to the last tarsal scute on the front of the leg at the base of the foot (also known as the "outside tarsus" or "diagonal tarsus" measurement; sensu page 11 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  rufous_band double                   DEFAULT NULL COMMENT 'width (mm) of rufous breast band from top to bottom at the bird''s centreline.',
  left_wing double                     DEFAULT NULL COMMENT 'length (mm) of left wing of captured individual. Measured as the distance from the carpal joint (the bend of the wing) to the longest primary feather whilst flattening the wing and straightening the primaries (also known as the "maximum flat" or "flattened and straightened" measurement; sensu page 6 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  right_wing double                    DEFAULT NULL COMMENT 'length (mm) of right wing of captured individual. Measured as the distance from the carpal joint (the bend of the wing) to the longest primary feather whilst flattening the wing and straightening the primaries (also known as the "maximum flat" or "flattened and straightened" measurement; sensu page 6 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  weight double                        DEFAULT NULL COMMENT 'Body mass (g) of captured individual (note: this includes the weight of the metal and colour rings. A metal ring weighs approximately 0.17g and a colour ring weighs approximately 0.08g.',
  wt_w_tag tinyint(1)                  DEFAULT NULL COMMENT '"0" (no) or "1" (yes). Was the body weight measured with a tag on?',
  moult varchar(10)                    DEFAULT NULL COMMENT 'primary molt score of captured individual. Scored as a the stage of the moult and the number of feathers at that stage. If all 10 primaries are old feathers with no moult, it would be scored as "0(10)". See Ringers'' Manual, British Trust for Ornithology, Thetford for more details.',
  fat varchar(10)                      DEFAULT NULL COMMENT 'fat score of captured individual, scored as the amount of visible fat in the furcular region or tracheal pit. See Ringers'' Manual, British Trust for Ornithology, Thetford for more details.',
  feather_primary tinyint(1)           DEFAULT NULL COMMENT '"0" (no) or "1" (yes). Was an inner-most primary feather collected?',
  feather_breast tinyint(1)            DEFAULT NULL COMMENT '"0" (no) or "1" (yes). Were at least 3 breast feathers collected?',
  blood varchar(255)                   DEFAULT NULL COMMENT '"0" (no) or "1" (yes).  Was blood was sampled?',
  cam_id varchar(255)                  DEFAULT NULL COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)             DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255)               DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',
  harddrive_id int(2)                  DEFAULT NULL COMMENT 'harddrive ID where photos were uploaded after returning from the field',
  capture_status tinyint(1)            DEFAULT NULL COMMENT '"F" (First marking), "R" (Recaptured but band combination not changed), "C" (recaptured and band combination Changed), "D" (was Dead when captured: write description in comments)',
  release_status tinyint(1)            DEFAULT NULL COMMENT '"A" (released Alive), "D" (Dead: write description in comments)',
  parents int(11)                      DEFAULT NULL COMMENT 'If chicks captured, which parents were attending? "MF" male and female, "F" female only, "M" male only, "U1" one unknown sex parent, "U2" two unknown sex parent, "O" other (write in comments)',
  comments varchar(255)                DEFAULT NULL COMMENT 'Comments',
  nov int(10) unsigned zerofill        DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY ID (ring),
  KEY tagID (tag_id_deploy),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB;

CREATE TABLE RESIGHTINGS (
  species varchar(50)                  DEFAULT NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  observer varchar(3)                  DEFAULT NULL COMMENT 'Initials of the observer (see OBSERVERS table).',
  gps_id int(2)                        DEFAULT NULL COMMENT 'handheld Garmin GPS ID',
  gps_point_start int(3)               DEFAULT NULL COMMENT 'Required: waypoint number stored in your handheld Garmin GPS unit for the start of the behavioural observation',
  gps_point_stop int(3)                DEFAULT NULL COMMENT 'Optional: waypoint number stored in your handheld Garmin GPS unit for the end of the behavioural observation',
  rclass varchar(2)                    DEFAULT NULL COMMENT 'Resighting class. "C" (pre-capture), "V" (video session), "R" (regular), "P" (photography session)',
  band_left_tibia varchar(10)          DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  band_left_tarsus varchar(10)         DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  band_right_tibia varchar(10)         DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  band_right_tarsus varchar(10)        DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band assigned): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  behaviour text                       DEFAULT NULL COMMENT 'description of the behaviour or, when a protocol exist, behavioral class.',
  cam_id int(2)                        DEFAULT NULL COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)             DEFAULT NULL COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255)               DEFAULT NULL COMMENT 'image filename for the last photo of the sequence',
  harddrive_id int(2)                  DEFAULT NULL COMMENT 'harddrive ID where photos were uploaded after returning from the field',
  comments varchar(500)                DEFAULT NULL COMMENT 'Comments',
  nov int(1) unsigned zerofill         DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps1 (gps_id,gps_point_start),
  KEY gps2 (gps_id,gps_point_stop)
) ENGINE=InnoDB;


CREATE TABLE EGGS (
  species varchar(50)                  DEFAULT NULL COMMENT '4 letter code, e.g. NOLA.',
  observer varchar(3)                  DEFAULT NULL COMMENT 'Initials of the observer (see OBSERVERS table).',
  date date                            DEFAULT NULL COMMENT 'Date (YYYY-MM-DD) when eggs were measured (local, NZDT or NZST).',
  time_visit time                      DEFAULT NULL COMMENT 'Time (HH:MM) when the eggs were measured (local, NZDT or NZST)',
  nest_id varchar(7)                   DEFAULT NULL COMMENT '<kbd>Nest ID</kbd>, see NESTS table',
  egg_id varchar(7)                    DEFAULT NULL COMMENT '<kbd>Egg ID</kbd> ',
  float_angle DOUBLE                   DEFAULT NULL COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  float_surface DOUBLE                 DEFAULT NULL COMMENT 'Egg surface (mm).',
  cam_id varchar(255)                  DEFAULT NULL COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)             DEFAULT NULL COMMENT 'Image filename for the first photo of the sequence',
  photo_end varchar(255)               DEFAULT NULL COMMENT 'Image filename for the last photo of the sequence',
  harddrive_id int(2)                  DEFAULT NULL COMMENT 'Harddrive ID where photos were uploaded after returning from the field',
  comments varchar(500)                DEFAULT NULL COMMENT 'Comments.',
  nov int(1) unsigned zerofill         DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY date (date)
) ENGINE=InnoDB;

CREATE TABLE NESTS (
  species varchar(50)                  DEFAULT NULL COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  site varchar(7)                      DEFAULT NULL COMMENT '2-letter abbreviation for the site of capture (MS = Motueka Spit, CR = Cass River, KK = Kaikoura, KT = Kaitorete Spit, MR = Macaulay River, TP = Tiwai Point, MB = Maryburn, TS = Tasman, OD = Ohau Downs, TR = Tekapo River, TA = Te Anau, PR = Pisa Range',
  date date                            DEFAULT NULL COMMENT 'Date nest checked YYYY-MM-DD (local, NZDT or NZST)',
  time_visit time                      DEFAULT NULL COMMENT 'Time (HH:MM) when the nest was checked (local, NZDT or NZST)',
  observer varchar(3)                  DEFAULT NULL COMMENT 'Initials of the observer (see OBSERVERS table)',
  nest_id varchar(7)                   DEFAULT NULL COMMENT 'Nest ID: SXYY, Where S is Species (the first letter of the species name), X = your GPS number, YY = your running nest number. Note if a brood was found of unknown origin, the nest_id is coded as a negative (e.g., -B903, would be the 3rd unknown banded dotterel brood encountered by the observer with GPS 9).',
  nest_state varchar(5)                DEFAULT NULL COMMENT '<b>I</b> [active nest being Incubated (eggs warm/parent(s) seen)], <b>P</b> [Predated (parents nowhere to be seen and scrape empty earlier than expected hatch date)], <b>D</b> [Deserted (parents nowhere to be seen and eggs are cold)], <b>H</b> (hatched, chicks seen), <b>O</b> (Other, please note in comments)',
  gps_id int(2)                        DEFAULT NULL COMMENT 'handheld Garmin GPS ID (1-12)',
  gps_point int(3)                     DEFAULT NULL COMMENT 'GPS waypoint (if nest_state is F this is the position of the nest, otherwise this is the escape distance when nest is still active)',
  clutch_size int(1)                   DEFAULT NULL COMMENT 'Clutch size',
  female_ID int(10)                    DEFAULT NULL COMMENT 'Metal ID of incubating female (this is entered once the COMBO of the female is 100% sure (e.g. confirmed twice independently))',
  male_ID int(10)                      DEFAULT NULL COMMENT 'Metal ID of incubating male (this is entered once the COMBO of the male is 100% sure (e.g. confirmed twice independently))',
  female_band_left_tibia varchar(10)   DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  female_band_left_tarsus varchar(10)  DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  female_band_right_tibia varchar(10)  DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  female_band_right_tarsus varchar(10) DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  male_band_left_tibia varchar(10)     DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  male_band_left_tarsus varchar(10)    DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  male_band_right_tibia varchar(10)    DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  male_band_right_tarsus varchar(10)   DEFAULT NULL COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ".',
  behav varchar(50)                    DEFAULT NULL COMMENT 'Behaviour of the incubating bird (comma separated): INC=Incubating, DF=Driving Flight, BW=Distraction Display (e.g. Broken Wing) or O=Other behaviours (describe in comments)',
  comments varchar(500)                DEFAULT NULL COMMENT 'Comments',
  nov int(1) unsigned zerofill         DEFAULT NULL COMMENT 'Validation flag. Do not edit this column!',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY species (species),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB;

CREATE TABLE GPS_POINTS (
  gps_id int(2) NOT      NULL COMMENT 'gps id',
  gps_point int(10) NOT  NULL COMMENT 'gps point',
  datetime_ datetime NOT NULL COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT         NULL COMMENT 'latitude',
  lon double NOT         NULL COMMENT 'longitude',
  ele double NOT         NULL COMMENT 'elevation',
  pk int(10) NOT         NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,gps_point),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB;

CREATE TABLE GPS_TRACKS (
  gps_id int(2) NOT        NULL COMMENT 'gps id',
  seg_id int(10) NOT       NULL COMMENT 'segment id',
  seg_point_id int(10) NOT NULL COMMENT 'segment point id',
  datetime_ datetime NOT   NULL COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT           NULL COMMENT 'latitude',
  lon double NOT           NULL COMMENT 'longitude',
  ele float NOT            NULL COMMENT 'elevation',
  pk int(10) NOT           NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,seg_id),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB;



DROP   VIEW IF EXISTS nest_locations;

CREATE VIEW nest_locations AS 
SELECT DISTINCT nest_id nest, lat, lon from NESTS n join `GPS_POINTS` g on n.gps_id = g.gps_id AND n.gps_point = g.gps_point;
