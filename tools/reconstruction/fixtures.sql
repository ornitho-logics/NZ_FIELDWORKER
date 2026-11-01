-- Entirely invented connected demonstration, not field data or a validation override.
-- Schema names deliberately match the reference engine. Run only in runner-owned instance.
CREATE DATABASE BADOatNZ CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;
CREATE TABLE BADOatNZ.CAPTURES (
 ring varchar(50), UL varchar(10), LL varchar(10), UR varchar(10), LR varchar(10),
 date date, study_year int, site_code varchar(2), capture_status varchar(1),
 latitude double, longitude double, field_sex varchar(1), age varchar(1),
 tarsus double, culmen double, wing double, weight double, moult_left varchar(20),
 tag_id varchar(50), tag_type varchar(20)
);
CREATE TABLE BADOatNZ.SEX (ring varchar(50), gen_sex varchar(1));
USE FIELD_2026_BADOatNZ;
INSERT INTO settings VALUES ('reference_date','2026-11-02');
INSERT INTO OBSERVERS (name,observer,start,stop,gps_id,cam_id)
VALUES ('Invented demonstration observer','ZZ','2026-01-01','2026-12-31','250','C99');
INSERT INTO GPS_POINTS (gps_id,gps_point,datetime_,lat,lon,ele)
VALUES (250,1,'2026-10-01 08:00:00',-41.000,174.001,0),
       (250,2,'2026-10-01 08:00:00',-41.000,174.005,0),
       (250,3,'2026-10-01 08:00:00',-41.000,174.009,0);
INSERT INTO NESTS (species,site,date,time_visit,observer,nest_id,nest_state,clutch_size,brood_size,gps_id,gps_point,nest_photo,tent_photo)
VALUES ('BADO','CR','2026-10-15','08:00:00','ZZ','C9901','F',3,0,250,1,'1','1'),
       ('BADO','CR','2026-11-01','08:00:00','ZZ','C9901','I',3,0,NULL,NULL,'1','1'),
       ('BADO','CR','2026-10-01','08:00:00','ZZ','C9902','F',3,0,250,2,'1','1'),
       ('BADO','CR','2026-10-05','08:00:00','ZZ','C9902','H',0,3,NULL,NULL,'1','1'),
       ('BADO','CR','2026-10-01','08:00:00','ZZ','C9903','F',3,0,250,3,'1','1'),
       ('BADO','CR','2026-10-20','08:00:00','ZZ','C9903','notA',0,0,NULL,NULL,'1','1'),
       ('BADO','CR','2026-10-25','08:00:00','ZZ','C9904','F',3,0,250,3,'1','1');
INSERT INTO EGGS (species,observer,date,time_visit,nest_id,egg_id,float_angle,float_location)
VALUES ('BADO','ZZ','2026-10-15','08:00:00','C9901',1,30,'bottom'),
       ('BADO','ZZ','2026-10-15','08:00:00','C9901',2,30,'bottom'),
       ('BADO','ZZ','2026-10-15','08:00:00','C9901',3,30,'bottom'),
       ('BADO','ZZ','2026-10-25','08:00:00','C9904',1,30,'bottom'),
       ('BADO','ZZ','2026-10-25','08:00:00','C9904',2,30,'bottom'),
       ('BADO','ZZ','2026-10-25','08:00:00','C9904',3,30,'bottom');
INSERT INTO CAPTURES (date,caught,released,species,site,observer,capture_status,capture_method,nest_id,gps_id,gps_point,field_sex,age,ring,UL,LL,UR,LR,tag_action)
VALUES ('2026-10-02','09:00:00','09:10:00','BADO','CR','ZZ','F','TN','C9903',250,3,'M','A','CP99101','X','RY','X','BY','O'),
       ('2026-10-02','10:00:00','10:10:00','BADO','CR','ZZ','F','TN','C9903',250,3,'F','A','CP99102','X','OY','X','YG','O');
INSERT INTO CAPTURES (date,caught,released,species,site,observer,capture_status,capture_method,nest_id,gps_id,gps_point,field_sex,age,ring,UL_in,LL_in,UR_in,LR_in,UL,LL,UR,LR,tag_action)
VALUES ('2026-10-26','09:00:00','09:10:00','BADO','CR','ZZ','R','TN','C9904',250,3,'M','A','CP99101','X','RY','X','BY','X','RY','X','BY','O');
INSERT INTO CAPTURES (date,caught,released,species,site,observer,capture_status,capture_method,nest_id,gps_id,gps_point,field_sex,age,ring,UL,LL,UR,LR,tarsus,culmen,weight,chick_tent_photo,chick_hide_photo)
VALUES ('2026-10-06','09:00:00','09:10:00','BADO','CR','ZZ','F','HA','C9902',250,2,'U','C','CP99001','X','R','X','X',20,9,10,'1','0'),
       ('2026-10-06','09:00:00','09:10:00','BADO','CR','ZZ','F','HA','C9902',250,2,'U','C','CP99002','X','R','X','X',20,9,10,'1','0'),
       ('2026-10-06','09:00:00','09:10:00','BADO','CR','ZZ','F','HA','C9902',250,2,'U','C','CP99003','X','R','X','X',20,9,10,'1','0');
INSERT INTO CAPTURES (date,caught,released,species,site,observer,capture_status,capture_method,nest_id,gps_id,gps_point,field_sex,age,ring,UL_in,LL_in,UR_in,LR_in,UL,LL,UR,LR,tarsus,culmen,weight)
VALUES ('2026-11-01','09:00:00','09:10:00','BADO','CR','ZZ','C','HA',NULL,250,2,'U','C','CP99001','X','R','X','X','FWAB','R','X','X',28,14,24);
INSERT INTO RESIGHTINGS (species,observer,gps_id,gps_point,date,site,rclass,UL,LL,UR,LR,sex,age,behav,nest_id)
VALUES ('BADO','ZZ',250,1,'2026-10-30','CR','R','X','XX','X','XX','M','A','IN','C9901'),
       ('BADO','ZZ',250,1,'2026-10-30','CR','R','X','OY','X','LY','F','A','IN','C9901');
-- All map geometry for this demonstration is invented; no real spatial_objects are read.
