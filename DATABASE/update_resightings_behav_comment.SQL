-- Apply once to an existing FIELD_2026_BADOatNZ database.
-- This changes only the RESIGHTINGS.behav column comment used by the
-- DataEntry hover help; it does not alter any recorded rows.

ALTER TABLE FIELD_2026_BADOatNZ.RESIGHTINGS
  MODIFY COLUMN `behav` text DEFAULT NULL COMMENT 'behavioral class, as many as applicable, separated by a comma: <br> <b>IN</b> = incubating <br> <b>CO</b> = courtship <br> <b>PR</b> = preening <br> <b>BW</b> = broken-wing display <br> <b>BC</b> = brooding chicks <br> <b>AC</b> = Alert with chick(s) <br> <b>NM</b> = nest maintenance <br> <b>SC</b> = scraping <br> <b>FC</b> = foraging with chicks <br> <b>FA</b> = foraging alone <br> <b>FM</b> = foraging with (presumed) mate <br> <b>FF</b> = foraging in flock <br> <b>RS</b> = roosting <br> <b>LF</b> = loafing <br> <b>AT</b> = alert <br> <b>FT</b> = fighting <br> <b>OB</b> = other behaviour (please comment)';
