CREATE TABLE IF NOT EXISTS payment_methods (
    payment_method_id    SERIAL        PRIMARY KEY,
    payment_method_name  VARCHAR(100)  NOT NULL UNIQUE
);
