
CREATE TABLE IF NOT EXISTS settings (
  variable varchar(128) NOT NULL,
  value date DEFAULT NULL,

  PRIMARY KEY (variable)
);


CREATE TABLE IF NOT EXISTS spatial_objects (
  variable varchar(128) NOT NULL
    COMMENT 'Readable name such as study_area, plot_01, or access_zone',

  value longtext NOT NULL
    COMMENT 'Polygon stored as human-readable WKT, for example POLYGON((longitude latitude, ...))',

  PRIMARY KEY (variable)
);


CREATE TABLE IF NOT EXISTS inspectors (
  table_name varchar(128) NOT NULL
    COMMENT '<strong>Inspected table</strong><br>Name of the database table this inspector applies to. This value is used by <code>inspector_loader(table_name)</code> to find the validation logic for that table.',

inspector longtext NOT NULL
  COMMENT '<strong>Validation rules</strong><br>Write the R checks that should run before this table is saved.<br><br>In these rules, <code>x</code> means the table being edited. Usually the rules are written as a <code>list(...)</code> of checks. For example:<br><code>list(x[, .(field)] |> is.na_validator())</code><br><br>If a check finds a problem, the app will show which rows need attention and will not save until the problems are fixed.<br><br>More details: https://ornitho-logics.github.io/DataEntry/articles/writing-validators.html',


  comments text NULL
    COMMENT '<strong>Inspector notes</strong><br>Optional notes about this inspector',

  updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP

);
