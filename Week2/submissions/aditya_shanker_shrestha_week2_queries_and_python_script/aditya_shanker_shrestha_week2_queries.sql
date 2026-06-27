-- WEEK2 SQL QUERIES : Aditya Shanker Shrestha

-- QUESTION 1 ( normalized schema )

-- Week 2: Normalizing the flat rides table into 3NF
-- Entities: locations, drivers, passengers, payment_methods, trips
-- Cleaning: initcap + trim + regexp_replace for consistent dedup
-- Verified: 5000 rows preserved, end-to-end joins reconstruct original data
-- Cleaning and normalizing rides

-- Creating tables for normalization. In order for table data dependencies due to foreign key usages.

-- Locations Table
CREATE TABLE locations(
	location_id SERIAL PRIMARY KEY,
 	city_name VARCHAR(100) UNIQUE NOT NULL
 );

-- Drivers Table

CREATE TABLE drivers(
	driver_id SERIAL PRIMARY KEY,
	driver_name VARCHAR(100) NOT NULL
);

-- Passenger Table
CREATE TABLE passengers (
	passenger_id SERIAL PRIMARY KEY,
	passenger_name VARCHAR(100) NOT NULL
);

-- Payment Methods Table

CREATE TABLE payment_methods (
	payment_method_id SERIAL PRIMARY KEY,
	payment_method_name VARCHAR(100) UNIQUE NOT NULL
);

-- Trips table
CREATE TABLE trips (
    trip_id              SERIAL        PRIMARY KEY,
    driver_id            INTEGER       NOT NULL REFERENCES drivers(driver_id),
    passenger_id         INTEGER       NOT NULL REFERENCES passengers(passenger_id),
    pickup_location_id   INTEGER       NOT NULL REFERENCES locations(location_id),
    dropoff_location_id  INTEGER       NOT NULL REFERENCES locations(location_id),
    fare_amount          NUMERIC(10,2) NOT NULL CHECK (fare_amount > 0),
    distance_km          NUMERIC(6,2)  NOT NULL CHECK(distance_km >= 0),
    status               VARCHAR(50)   NOT NULL CHECK (status IN ('completed','cancelled','no_show')),
    requested_at         TIMESTAMP     NOT NULL,
    completed_at         TIMESTAMP,
    rating               NUMERIC(2,1)  CHECK (rating BETWEEN 1.0 AND 5.0),
    payment_method_id    INTEGER       REFERENCES payment_methods(payment_method_id)
);

-- Inserting cleaned data ( by using initcap/trim/regexp_replace for data consitency ) into drivers table.

INSERT INTO drivers  (driver_name)
SELECT DISTINCT
        initcap(trim(regexp_replace(r.driver_name,'\s+',' ','g' ))) AS driver_name
FROM rides r;
-- checking the inserted data in the drivers table.
SELECT * FROM drivers d ;

-- Inserting cleaned data ( by using initcap/trim/regexp_replace for data consitency ) into passengers table.

INSERT INTO passengers  (passenger_name)
SELECT DISTINCT
        initcap(trim(regexp_replace(r.passenger_name,'\s+',' ','g' ))) AS passenger_name
FROM rides r;

-- checking the inserted data in the passengers table.

SELECT * FROM passengers ;

-- Inserting cleaned data ( by using initcap/trim/regexp_replace for data consitency ) into locations table.
INSERT INTO locations(city_name)
SELECT DISTINCT
        initcap(trim(regexp_replace(r.pickup_city,'\s+',' ','g' )))
FROM rides r
UNION -- Union used for cases where count ( distinct ( r.pickup_city ) ) > count ( distinct ( r.dropoff_city ))
SELECT DISTINCT
        initcap(trim(regexp_replace(r.dropoff_city,'\s+',' ','g' )))
FROM rides r;

-- checking the inserted data in the passengers table.

SELECT * FROM locations;


-- Inserting data into payment_methods table.
INSERT INTO payment_methods ( payment_method_name)
SELECT DISTINCT trim(payment_method)
FROM rides
WHERE payment_method IS NOT NULL;

-- checking the inserted data in the payments methods table.

SELECT * FROM payment_methods pm ;

-- query to check foreign keys and data correlations to data in ride table before inserting final data into trips table.
SELECT
	(SELECT  driver_id
		FROM drivers d
	 WHERE d.driver_name = initcap(trim(regexp_replace(r.driver_name, '\s+', ' ','g' ))) ) AS driver_id,
	 (SELECT  passenger_id
		FROM passengers p
	 WHERE p.passenger_name = initcap(trim(regexp_replace(r.passenger_name, '\s+', ' ','g' ))) ) AS passenger_id,
	 (SELECT  location_id
		FROM locations l
	 WHERE l.city_name = initcap(trim(regexp_replace(r.pickup_city, '\s+', ' ','g' ))) ) AS pickup_location_id,
	 (SELECT  location_id
		FROM locations l
	 WHERE l.city_name = initcap(trim(regexp_replace(r.dropoff_city, '\s+', ' ','g' )))) AS dropoff_location_id,
	 r.fare_amount,
	 r.ride_distance_km,
	 r.ride_status,
	 r.requested_at,
	 r.completed_at,
	 r.rating,
	 (SELECT  payment_method_id
		FROM payment_methods pm
	 WHERE pm.payment_method_name = trim(r.payment_method)) AS payment_method_id,
	 *
FROM rides r;

-- inserting foreign keys and relevant data into trips, ensuring normalization and clean data.

INSERT INTO trips (
	driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_method_id)
SELECT
	(SELECT  driver_id
		FROM drivers d
	 WHERE d.driver_name = initcap(trim(regexp_replace(r.driver_name, '\s+', ' ','g' ))) ),
	 (SELECT  passenger_id
		FROM passengers p
	 WHERE p.passenger_name = initcap(trim(regexp_replace(r.passenger_name, '\s+', ' ','g' ))) ),
	 (SELECT  location_id
		FROM locations l
	 WHERE l.city_name = initcap(trim(regexp_replace(r.pickup_city, '\s+', ' ' ,'g'))) ),
	 (SELECT  location_id
		FROM locations l
	 WHERE l.city_name = initcap(trim(regexp_replace(r.dropoff_city, '\s+', ' ','g' )))),
	 r.fare_amount,
	 r.ride_distance_km,
	 r.ride_status,
	 r.requested_at,
	 r.completed_at,
	 r.rating,
	 (SELECT  payment_method_id
		FROM payment_methods pm
	 WHERE pm.payment_method_name = trim(r.payment_method))
FROM rides r;

-- checking the inserted data in the trips table.

SELECT * FROM trips;

SELECT count(*) FROM trips;
SELECT count(*) FROM rides;

-- Verifying end to end
SELECT t.trip_id, d.driver_name, p.passenger_name,
       pl.city_name AS pickup, dl.city_name AS dropoff,
       t.fare_amount, t.status, pm.payment_method_name
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
JOIN passengers p ON t.passenger_id = p.passenger_id
JOIN  locations pl ON t.pickup_location_id = pl.location_id
JOIN locations dl ON t.dropoff_location_id = dl.location_id
LEFT  JOIN payment_methods pm ON t.payment_method_id = pm.payment_method_id
LIMIT 10;

--  QUESTION 2 (Completed Rides per Driver DESC)

-- Initial query based on GROUP BY driver_name, Futher thought made me realize GROUP BY driver_id is a better option.

SELECT d.driver_name, COUNT(t.*) AS completed_rides 
FROM drivers d LEFT JOIN trips t 
ON d.driver_id = t.driver_id AND t.status = 'completed'  
GROUP BY d.driver_id, d.driver_name  
ORDER BY completed_rides DESC; 


-- Exploring another sql query that redeeems same results

-- Subquery with outer RIGHT JOIN (works, but redundant double-join on drivers) ; trains my sub query skills
SELECT d.driver_name, completed_rides 
FROM  ( 
	SELECT d.driver_id, COUNT(t.trip_id )
	AS completed_rides 
	FROM drivers d LEFT JOIN trips t 
	ON d.driver_id = t.driver_id AND t.status = 'completed'  
	GROUP BY d.driver_id 
	ORDER BY completed_rides DESC ) sub 
RIGHT JOIN drivers d ON d.driver_id = sub.driver_id ; 

-- following query works due to Postgres' Functional Dependency feature (not portable for others)

SELECT d.driver_name, COUNT(t.trip_id) AS completed_rides 
    FROM drivers d 
    LEFT JOIN trips t ON d.driver_id = t.driver_id AND t.status = 'completed'  
    GROUP BY d.driver_id; 

-- Data integrity verification (confirming both return 2862)
-- Both queries return same value.

SELECT COUNT(*) AS total_completed_rides FROM trips WHERE status = 'completed';

SELECT SUM(sub.completed_rides) AS total_completed_rides FROM ( SELECT d.driver_name, COUNT(t.trip_id ) AS completed_rides FROM drivers d INNER JOIN trips t ON d.driver_id = t.driver_id WHERE t.status = 'completed'  GROUP BY d.driver_id ) sub;

--  QUESTION 3 ( Driver with no rides )

SELECT d.driver_name AS driver_with_no_completed_rides 
FROM drivers d LEFT JOIN trips t ON d.driver_id = t.driver_id AND t.status ='completed'
WHERE t.driver_id IS NULL;

-- Alternative query

SELECT d.driver_name AS driver_with_no_completed_rides 
FROM drivers d
WHERE NOT EXISTS (
        SELECT 1 FROM trips t WHERE t.driver_id = d.driver_id AND t.status = 'completed');

-- QUESTION 4 ( Avg fare per city desc )
-- Note: The hint mentions a "3 table join", but logically only a 2-table join 
SELECT l.city_name AS pickup_city, ROUND(AVG(t.fare_amount),2) AS avg_fare 
FROM locations l  INNER JOIN trips t ON l.location_id = t.pickup_location_id
WHERE t.status = 'completed'
GROUP BY l.city_name 
ORDER BY avg_fare DESC;

-- Alternative for Integer only avg fare case

SELECT l.city_name AS pickup_city, DIV(SUM(t.fare_amount),COUNT(t.trip_id)) AS avg_fare 
FROM locations l  INNER JOIN trips t ON l.location_id = t.pickup_location_id
GROUP BY l.city_name 
ORDER BY avg_fare DESC;

-- QUESTION 5 ( rides where pickup and dropoff city are the same )

SELECT d.driver_name, p.passenger_name,
       pl.city_name AS pickup, dl.city_name AS dropoff,
       t.fare_amount, t.status, pm.payment_method_name
FROM trips t
INNER JOIN drivers d ON t.driver_id = d.driver_id
INNER JOIN passengers p ON t.passenger_id = p.passenger_id
INNER JOIN  locations pl ON t.pickup_location_id = pl.location_id
INNER JOIN locations dl ON t.dropoff_location_id = dl.location_id
LEFT  JOIN payment_methods pm ON t.payment_method_id = pm.payment_method_id
WHERE t.dropoff_location_id = t.pickup_location_id ;

-- QUESTION 6 ( total revenue )

SELECT SUM(t.fare_amount)
FROM trips t
WHERE t.status = 'completed';

-- verifying

SELECT SUM(fare_amount)
FROM rides
WHERE ride_status = 'completed';