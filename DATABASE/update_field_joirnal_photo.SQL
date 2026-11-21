-- Apply manually only if field_joirnal already exists with a BLOB photo column.
-- New installations use the definition in main_tables.SQL.
USE FIELD_2026_BADOatNZ;

ALTER TABLE `field_joirnal`
  MODIFY COLUMN `photo` MEDIUMBLOB DEFAULT NULL
  COMMENT 'Optional photo resized in the browser and stored as JPEG image data';
