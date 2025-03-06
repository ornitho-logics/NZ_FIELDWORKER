
-- COMMENT-s can be styled with html markup. 

DROP DATABASE IF EXISTS FIELD_2024_BADOatNZ;

CREATE DATABASE IF NOT EXISTS FIELD_2024_BADOatNZ;

USE FIELD_2024_BADOatNZ;


CREATE TABLE OBSERVERS (
  name char(50)                        COMMENT 'Your full name.',
  observer varchar(3)                  COMMENT 'Your initials. Use two or three letters. This is what you will use when entering data.',
  affiliation char(1)                  COMMENT 'Your affiliation as it would listed in a publication',
  email char(1)                        COMMENT 'An email address which can be used for data enquiries about your observations',
  gps_id int(2)                        COMMENT 'Personal GPS ID',
  radio_id int(2)                      COMMENT 'Personal radio ID',
  cam_id int(2)                        COMMENT 'Personal camcorder ID',
  harddrive_id int(2)                  COMMENT 'Team harddrive ID where photos were uploaded after returning from the field',
  remarks varchar(50)                  COMMENT 'Please provide any relevant information, such as your ratings in cooking, chess, or poker.'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;

DROP TABLE IF EXISTS CAPTURES;
CREATE TABLE CAPTURES (
  species varchar(50)                  
    COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  `site` varchar(100)    
    COMMENT '2-letter abbreviation for the site of capture: <br>
    MS = Motueka Spit <br> 
    CR = Cass River <br> 
    KK = Kaikoura <br> 
    KT = Kaitorete Spit <br> 
    MR = Macaulay River <br> 
    TP = Tiwai Point <br> 
    MB = Maryburn <br> 
    TS = Tasman <br> 
    OD = Ohau Downs <br> 
    TR = Tekapo River <br> 
    TA = Te Anau <br> 
    PR = Pisa Range <br> 
    HR = Hawkes Bay (Coast) <br> 
    OW = Old Mans Range <br> 
    CH = Chatham Islands <br> 
    TO = Tongariro <br> 
    EB = Eastbourne <br> 
    HR = Hawkes Bay (Rivers)',
  `date` date                            
    COMMENT 'Date caught YYYY-MM-DD (local, NZDT or NZST)',
  cap_start time                       
    COMMENT 'hh:mm capture start (when you set the trap or commenced trapping with the mistnet)',
  caught time                          
    COMMENT 'hh:mm time caught (local, NZDT or NZST)',
  released time                        
    COMMENT 'hh:mm time released (local, NZDT or NZST)',
  capture_method varchar(2)               
    COMMENT '
    HA (HAnd)<br>
    TB (clap-Trap on Brood)<br>
    TN (clap-Trap on Nest)<br>
    SM (Stationary Mistnet)<br>
    MM (Mobile Mistnet)<br>
    O <br>(Other; please specify in comments)',
  nest_id varchar(7)                   
    COMMENT 'a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), <br>
      XX = your GPS number (01 to 11)<br>
      YY = your running nest number (01 to 99).
      <br>Note if a brood was found of unknown origin, the nest_id is coded as a negative (e.g., -BA0903, would be the 3rd unknown banded dotterel brood encountered by the observer with GPS 09).',
  book_id int(2)                       
    COMMENT '3-character integer that is a unique book_id (i.e., your fieldnote book)',
  form_id int(3)                       
    COMMENT '2-character integer that is a unique page of your book_id',
  observer varchar(3)                  
    COMMENT 'Initials of the bander (see OBSERVERS table)',
  gps_id int(11)                       
    COMMENT 'handheld Garmin GPS ID',
  gps_point int(11)                    
    COMMENT 'waypoint number of the capture location stored in your handheld Garmin GPS unit',
  field_sex char(1)                    
    COMMENT 'observed sex based on field observations (ornamentation, behaviour, etc.):<br>"M" (male),<br> "F" (female),<br> "U" 
    (unknown)',
  age char(1)                          
    COMMENT 'age of captured individual: <br>"A" (Adult),<br> "J" (Juvenile)',
  ring varchar(255)                    
    COMMENT 'alpha-numeric code of metal ring assigned to captured individual',
  UL varchar(10)          
    COMMENT 'code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band 
    assigned):<br>
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime" <br>
    M = metal <br>
    FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  LL varchar(10)         
    COMMENT 'code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned): <br>
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green lime <br>
    M = metal <br> No flag assigned to tarsi',
  UR varchar(10)         
    COMMENT 'code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band 
    assigned):<br>
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime" <br>
    M = metal <br>, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  LR varchar(10)        
    COMMENT 'code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one 
    band assigned): <br>
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime" <br>
    M = metal <br> No flag assigned to tarsi.',
  tag_id  varchar(10)            
    COMMENT 'ID of tag deployed or retrieved',
  tag_action varchar(10)               
    COMMENT '
    "O" (nO tag: bird did not have a tag when captured and was released without a tag) <br>
    "D" (new Deployment: bird  did not have a tag when captured and was released with a tag)<br>
    "R" (Retrieved: bird had a tag when captured and was released without a tag)<br>
    "S" (tag Stayed on: bird had a tag when captured and was released with the same tag)<br>
    "N" (New tag: bird had a tag when captured and was released with a new tag)',
  tag_type char(3)                     
    COMMENT 'type of tag deployed ("PTT" or "GPS")',
  tag_extras varchar(10)               
    COMMENT 'type of tag deployed ("shield", "foam", or "shield and foam")',
  harness_size char(3)                 
    COMMENT 'type of harness deployed ("AVG", "BIG", "SML")',
  culmen double                        
    COMMENT 'length (mm) of upper mandible of captured individual. Measured as the distance between the tip of the forehead feathering at the base of the upper bill, along the ridge of the culmen, and the tip of the bill (also known as the "exposed culmen" measurement; sensu page 8 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  tarsus double                        
    COMMENT 'length (mm) of tarsus of captured individual. Measured as the distance between the notch at the end of the 
    lateral condyle of the tibiotarsus on the backside of the leg, to the last tarsal scute on the front of the leg at the base of the foot (also known as the "outside tarsus" or "diagonal tarsus" measurement; sensu page 11 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  total_head double                    
    COMMENT 'combined length (mm) of the bill and the skull. Measured as the maximum distance from the tip of the bill to the back of the skull',
  head_band double                     
    COMMENT 'width (mm) of black head band from top to bottom at the bird''s centreline.',
  black_band double                    
    COMMENT 'width (mm) of black neck band from top to bottom at the bird''s centreline.',
  rufous_band double                   
    COMMENT 'width (mm) of rufous breast band from top to bottom at the bird''s centreline.',
  wing double                          
    COMMENT 'length (mm) of wing of captured individual. Measured as the distance from the carpal joint (the bend of the wing) to the longest primary feather whilst flattening the wing and straightening the primaries (also known as the "maximum flat" or "flattened and straightened" measurement; sensu page 6 of Pyle, P. 1997. Identification guide to North American birds. Part 1, Columbidae to Ploceidae. State Creek Press, Bolinas, CA)',
  weight double                        
    COMMENT 'Body mass (g) of captured individual (note: this includes the weight of the metal and colour rings. A metal ring weighs approximately 0.17g and a colour ring weighs approximately 0.08g.',
    wt_w_tag tinyint(1)                  
    COMMENT '"0" (no) or "1" (yes). Was the body weight measured with a tag on?',
  moult varchar(10)                    
    COMMENT 'primary molt score of captured individual. Scored as a the stage of the moult and the number of feathers at 
    that stage. If all 10 primaries are old feathers with no moult, it would be scored as "0(10)". See Ringers Manual, British Trust for Ornithology, Thetford for more details.',
  fat varchar(10)                      
    COMMENT 'fat score of captured individual, scored as the amount of visible fat in the furcular region or tracheal pit. 
    See Ringers'' Manual, British Trust for Ornithology, Thetford for more details.',
  `sample`  varchar(10)  
    COMMENT 'Samples taken, comma separated: <br>
    FP = feather_primary <br> 
    FB = feather_breast <br> 
    BQ = blood in Queen <br>
    BF = blood on filter paper <br>
    BE = blood in EDTA
    ',
  cam_id varchar(255)                  
    COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)             
    COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255)               
    COMMENT 'image filename for the last photo of the sequence',
  harddrive_id int(2)                  
    COMMENT 'harddrive ID where photos were uploaded after returning from the field',
  capture_status varchar(5)            
    COMMENT '
    "F" (First marking)<br>
    "R" (Recaptured but band combination not changed)<br> 
    "C" (recaptured and band combination Changed),<br>
    "D" (was Dead when captured: write description in comments)',
  parents varchar(11)                      
    COMMENT 'If chicks captured, which parents were attending?<br>
    "MF": male and female<br>
    "F" : female only<br>
    "M" : male only<br>
    "U1": one unknown sex parent<br>
    "U2": two unknown sex parent<br>
    "O" : other (write in comments)',
  comments varchar(255)  
      COMMENT 'Comments',
  nov int(10) unsigned zerofill        
    COMMENT 'Validation flag. Do not edit this column!',
  pk int(11) NOT NULL AUTO_INCREMENT,
    PRIMARY KEY (pk),
    KEY ID (ring),
    KEY gps (gps_id,gps_point)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;

DROP TABLE IF EXISTS RESIGHTINGS;
CREATE TABLE RESIGHTINGS (
  species varchar(50)                  
    COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  observer varchar(3)                  
    COMMENT 'Initials of the observer (see OBSERVERS table).',
  gps_id int(2)                        
    COMMENT 'handheld Garmin GPS ID',
  gps_point_start int(3)               
    COMMENT 'Required: waypoint number stored in your handheld Garmin GPS unit for the start of the behavioural observation',
  gps_point_stop int(3)                
    COMMENT 'Optional: waypoint number stored in your handheld Garmin GPS unit for the end of the behavioural observation',
  rclass varchar(2)                    
    COMMENT 'Resighting class: <br>
    "C" (pre-capture) <br>
    "V" (video session) <br>
    "R" (regular) <br>
    "P" (photography session)',
  UL varchar(10)          
    COMMENT 'code for the color/type of band(s) assigned to the left tibia (upper band listed first if more than one band assigned): 
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime" <br>
    M = metal <br>
    FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" 
    a two-character string that can contain the following characters, with there needing to be at least one letter:
    <br> A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  LL varchar(10)         
    COMMENT 'code for the color/type of band(s) assigned to the left tarsus (upper band listed first if more than one band assigned):<br>
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime" <br>
    M = metal. No flag assigned to tarsi',
  UR varchar(10)         
    COMMENT 'code for the color/type of band(s) assigned to the right tibia (upper band listed first if more than one band assigned):
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime" <br>
    M = metal <br>
    FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  LR varchar(10)        
    COMMENT 'code for the color/type of band(s) assigned to the right tarsus (upper band listed first if more than one band assigned):<br>
    X = blank <br>
    O = orange <br>
    Y = yellow <br>
    W = white <br>
    B = blue <br>
    R = red <br>
    G = green <br>
    L = light green "lime", M = metal. No flag assigned to tarsi.',
  behav text                           
    COMMENT 'behavioral class, as many as applicable, seperated by a comma:<br>"IN" = incubating <br>
    "CO" = courtship <br>
    "PR" = preening <br>
    "BW" = distraction display (e.g.broken wing) <br>
    "BC" = brooding chicks <br>
    "NM" = nest maintenance <br>
    "FC" = foraging with chicks <br>
    "FA" = foraging alone <br>
    "RS" = roosting <br>
    "LF" = loafing <br>
    "AT" = alert <br>
    "FT" = fighting <br>
    "OB" = other behavious (please comment)',
  cam_id int(2)                        
    COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)             
    COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255)               
    COMMENT 'image filename for the last photo of the sequence',
  harddrive_id int(2)                  
    COMMENT 'harddrive ID where photos/videos were uploaded after returning from the field',
  comments varchar(500)                
    COMMENT 'Comments',
  nov int(1) unsigned zerofill         
    COMMENT 'No validation. Do not edit !',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps1 (gps_id,gps_point_start),
  KEY gps2 (gps_id,gps_point_stop)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;


DROP TABLE IF EXISTS EGGS;
CREATE TABLE EGGS (
  species varchar(50)                  
    COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  observer varchar(3)                  
    COMMENT 'Initials of the observer (see OBSERVERS table).',
  date date                            
    COMMENT 'Date (YYYY-MM-DD) when eggs were measured (local, NZDT or NZST).',
  time_visit time                      
    COMMENT 'Time (HH:MM) when the eggs were measured (local, NZDT or NZST)',
  nest_id varchar(7)                   
    COMMENT 'a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), XX = your GPS number (01 to 11), YY = your running nest number (01 to 99). Note if a brood was found of unknown origin, the nest_id is 
    oded as a negative (e.g., -BA0903, would be the 3rd unknown banded dotterel brood encountered by the observer with GPS 09).',
  egg1_float_angle int(3)              
    COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg1_float_surface int(3)            
    COMMENT 'Height of egg above water surface (mm)',
  egg1_float_location varchar(255)     
    COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  egg2_float_angle int(3)              
    COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg2_float_surface int(3)            
    COMMENT 'Height of egg above water surface (mm).',
  egg2_float_location varchar(255)     
    COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  egg3_float_angle int(3)              
    COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg3_float_surface int(3)            
    COMMENT 'Height of egg above water surface (mm).',
  egg3_float_location varchar(255)     
    COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  egg4_float_angle int(3)              
    COMMENT 'Egg floating angle (degrees, minimum 20, maximum 90).',
  egg4_float_surface int(3)            
    COMMENT 'Height of egg above water surface (mm).',
  egg4_float_location varchar(255)     
    COMMENT 'Position of the egg ("bottom", "suspended", or "surface")',
  cam_id varchar(255)                  
    COMMENT '2-character integer that is a unique ID of your field camera',
  photo_start varchar(255)             
    COMMENT 'image filename for the first photo of the sequence',
  photo_end varchar(255)               
    COMMENT 'image filename for the last photo of the sequence',
  harddrive_id int(2)                  
    COMMENT 'harddrive ID where photos were uploaded after returning from the field',
  comments varchar(500)                COMMENT 'Comments.',
  nov int(1) unsigned zerofill         COMMENT 'No validation. Do not edit !',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY date (date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;

DROP TABLE IF EXISTS NESTS;
CREATE TABLE NESTS (
  species varchar(50)                  
    COMMENT '4-letter species code, e.g. BADO, WRYB, SNZD, BFDO',
  site varchar(100)                    
    COMMENT '2-letter abbreviation for the site of capture (MS = Motueka Spit, CR = Cass River, KK = Kaikoura, KT = Kaitorete Spit, MR = Macaulay River, TP = Tiwai Point, MB = Maryburn, TS = Tasman, OD = Ohau Downs, TR = Tekapo River, TA = Te Anau, PR = Pisa Range, HR = Hawkes Bay (Coast), OW = Old Mans Range, CH = Chatham Islands, TO = Tongariro, EB = Eastbourne, HR = Hawkes Bay (Rivers)',
  date date                            
    COMMENT 'Date nest checked YYYY-MM-DD (local, NZDT or NZST)',
  time_visit time                      
    COMMENT 'Time (HH:MM) when the nest was checked (local, NZDT or NZST)',
  observer varchar(3)                  
    COMMENT 'Initials of the observer (see OBSERVERS table)',
  nest_id varchar(7)                   
    COMMENT 'a 6-character string: SSXXYY, Where SS is the species (the first two letters of the species name), XX = your GPS number (01 to 11), YY = your running nest number (01 to 99). Note if a brood was found of unknown origin, the nest_id is coded as a negative (e.g., -BA0903, would be the 3rd unknown banded dotterel brood encountered by the observer with GPS 09).',
  nest_state varchar(5)                
    COMMENT '<b>I</b> [active nest being Incubated (eggs warm/parent(s) seen)], <b>P</b> [Predated (parents nowhere to be seen and scrape empty earlier than expected hatch date)], <b>D</b> [Deserted (parents nowhere to be seen and eggs are cold)], <b>H</b> (hatched, chicks seen), <b>B</b> (brood seen)<b>O</b> (Other, please note in comments)',
  gps_id int(2)                        
    COMMENT 'handheld Garmin GPS ID (1-12)',
  gps_point int(3)                     
    COMMENT 'GPS waypoint (if nest_state is F this is the position of the nest, otherwise this is the escape distance when nest is still active)',
  clutch_size int(1)                   
    COMMENT 'Clutch size (if nest)',
  brood_size int(1)                    
    COMMENT 'Number of chicks seen (if brood)',
  female_ring int(10)                    
    COMMENT 'Metal ID of incubating female (this is entered once the COMBO of the female is 100% sure (e.g. confirmed twice independently))',
  male_ring int(10)                      
    COMMENT 'Metal ID of incubating male (this is entered once the COMBO of the male is 100% sure (e.g. confirmed twice independently))',
  female_UL varchar(10)   
    COMMENT 'code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  female_LL varchar(10)  
    COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',
  female_UR varchar(10)  
    COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  female_LR varchar(10) 
    COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',
  male_UL varchar(10)     
    COMMENT 'code for the color/type of band(s) observed on the left tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  male_LL varchar(10)    
    COMMENT 'code for the color/type of band(s) observed on the left tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',
  male_UR varchar(10)    
    COMMENT 'code for the color/type of band(s) observed on the right tibia (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal, FXYZ = Flag with colour "X" (same color codes as rings) and two-character alphanumeric code "YZ" a two-character string that can contain the following characters, with there needing to be at least one letter: A, C, E, H, J, K, L, M, N, P, T, U, V, X, Y, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0.',
  male_LR varchar(10)   
    COMMENT 'code for the color/type of band(s) observed on the right tarsus (upper band listed first if more than one band on this segment): X = blank, O = orange, Y = yellow, W = white, B = blue, R = red, G = green, L = light green "lime", M = metal. No flag assigned to tarsi.',
  behav text                           
    COMMENT 'behavioral class, as many as applicable, seperated by a comma: "IN" = incubating, "CO" = courtship, "PR" = preening, "BW" = distraction display (e.g., broken wing), "BC" = brooding chicks, "NM" = nest maintenance, "FC" = foraging with chicks, "FA" = foraging alone, "RS" = roosting, "LF" = loafing, "AT" = alert, "FT" = fighting, "OB" = other behavious (please comment)',
  comments varchar(500)                
    COMMENT 'Comments',
  nov int(1) unsigned zerofill         
    COMMENT 'No validation. Do not edit !',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY nest (nest_id),
  KEY species (species),
  KEY gps (gps_id,gps_point)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;



CREATE TABLE GPS_POINTS (
  gps_id int(2) NOT NULL                            COMMENT 'gps id',
  gps_point int(10) NOT NULL                        COMMENT 'gps point',
  datetime_ datetime NOT NULL                       COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT NULL                               COMMENT 'latitude',
  lon double NOT NULL                               COMMENT 'longitude',
  ele double NOT NULL                               COMMENT 'elevation',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,gps_point),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;


CREATE TABLE GPS_TRACKS (
  gps_id int(2) NOT NULL                            COMMENT 'gps id',
  seg_id int(10) NOT NULL                           COMMENT 'segment id',
  seg_point_id int(10) NOT NULL                     COMMENT 'segment point id',
  datetime_ datetime NOT NULL                       COMMENT 'gps date-time (NZST / NZDT)',
  lat double NOT NULL                               COMMENT 'latitude',
  lon double NOT NULL                               COMMENT 'longitude',
  ele float NOT NULL                                COMMENT 'elevation',
  pk int(10) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (pk),
  KEY gps (gps_id,seg_id),
  KEY datetime_ (datetime_)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ;
