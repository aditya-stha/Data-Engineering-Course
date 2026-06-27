CREATE TABLE IF NOT EXISTS passengers (
    passenger_id    SERIAL        PRIMARY KEY,
    passenger_name  VARCHAR(100)  NOT NULL UNIQUE
);
