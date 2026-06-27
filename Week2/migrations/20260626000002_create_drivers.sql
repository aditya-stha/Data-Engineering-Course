CREATE TABLE IF NOT EXISTS drivers (
    driver_id     SERIAL        PRIMARY KEY,
    driver_name   VARCHAR(100)  NOT NULL UNIQUE
);
