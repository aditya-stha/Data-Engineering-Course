-- week3_reliability.sql
-- Week 3 Assignment
-- Submit TWO files:
--   1. week3_reliability.sql  (this file — SQL tasks)
--   2. transactional_loader.py (Python task — Q5)
--
-- All SQL runs against the normalized schema from Week 2
-- (drivers, riders, locations, trips)

-- ─────────────────────────────────────────────────────────────────
-- Q1: Add indexes to the trips table
--
-- Before adding ANY index, run EXPLAIN ANALYZE on each query below
-- and record the execution time in a comment.
-- Then add your indexes and run EXPLAIN ANALYZE again.
-- The comparison IS the answer — not just the CREATE INDEX statement.
-- ─────────────────────────────────────────────────────────────────

-- Baseline queries — run EXPLAIN ANALYZE on each BEFORE indexing:

-- Query A: filter by driver
EXPLAIN ANALYZE
SELECT * FROM trips WHERE driver_id = 3;

--Result:
--Seq Scan on trips  (cost=0.00..126.50 rows=481 width=67) (actual time=0.007..0.700 rows=481 loops=1)
--  Filter: (driver_id = 3)
--  Rows Removed by Filter: 4519
--Planning Time: 0.211 ms
--Execution Time: 0.751 ms

-- Query B: filter by status
EXPLAIN ANALYZE
SELECT * FROM trips WHERE status = 'cancelled';


--RESULT:
--Seq Scan on trips  (cost=0.00..126.50 rows=1408 width=67) (actual time=0.012..0.930 rows=1408 loops=1)
--  Filter: ((status)::text = 'cancelled'::text)
--  Rows Removed by Filter: 3592
--Planning Time: 0.071 ms
--Execution Time: 1.038 ms

-- Query C: filter by driver AND status (common in the pipeline)
EXPLAIN ANALYZE
SELECT * FROM trips
WHERE driver_id = 3 AND status = 'completed';

--RESULT:
--Seq Scan on trips  (cost=0.00..139.00 rows=275 width=67) (actual time=0.091..0.788 rows=284 loops=1)
--  Filter: ((driver_id = 3) AND ((status)::text = 'completed'::text))
--  Rows Removed by Filter: 4716
--Planning Time: 0.075 ms
--Execution Time: 0.823 ms

-- YOUR INDEXES HERE:
-- (add indexes, then re-run the EXPLAIN ANALYZE queries above)

CREATE INDEX IF NOT EXISTS idx_trips_driver_id ON trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_status ON trips(status);




-- Record results in comments, e.g.:
-- Query A before: Seq Scan, execution time = X ms
-- Query A after:  Index Scan using ..., execution time = Y ms

--Results 1:
--Bitmap Heap Scan on trips  (cost=8.01..78.02 rows=481 width=67) (actual time=0.040..0.179 rows=481 loops=1)
--  Recheck Cond: (driver_id = 3)
--  Heap Blocks: exact=64
--  ->  Bitmap Index Scan on idx_trips_driver_id  (cost=0.00..7.89 rows=481 width=0) (actual time=0.027..0.027 rows=481 loops=1)
--        Index Cond: (driver_id = 3)
--Planning Time: 0.078 ms
--Execution Time: 0.231 ms
-- Comments:
-- Query A before indexing: Seq scan, exec_time= 0.751 ms
-- Query A after indexing: Heap scan, exec_time= 0.231 ms
-- query became 3.25 times faster

--Results 2:
--Bitmap Heap Scan on trips  (cost=19.19..100.79 rows=1408 width=67) (actual time=0.072..0.457 rows=1408 loops=1)
--  Recheck Cond: ((status)::text = 'cancelled'::text)
--  Heap Blocks: exact=64
--  ->  Bitmap Index Scan on idx_status  (cost=0.00..18.84 rows=1408 width=0) (actual time=0.058..0.058 rows=1408 loops=1)
--        Index Cond: ((status)::text = 'cancelled'::text)
--Planning Time: 0.093 ms
--Execution Time: 0.598 ms
-- Comments:
-- Query B before indexing: Seq scan, exec_time= 1.038 ms
-- Query B after indexing: Heap scan, exec_time= 0.598 ms
-- query became 1.73 times faster



-- Result 3:
--Bitmap Heap Scan on trips  (cost=7.96..79.17 rows=275 width=67) (actual time=0.045..0.252 rows=284 loops=1)
--  Recheck Cond: (driver_id = 3)
--  Filter: ((status)::text = 'completed'::text)
--  Rows Removed by Filter: 197
--  Heap Blocks: exact=64
--  ->  Bitmap Index Scan on idx_trips_driver_id  (cost=0.00..7.89 rows=481 width=0) (actual time=0.029..0.030 rows=481 loops=1)
--        Index Cond: (driver_id = 3)
--Planning Time: 0.095 ms
--Execution Time: 0.295 ms
-- Comments:
-- Query C's execution time before indexing the condition indexes: 0.823ms
-- Query C's execution time after indexing the condition indexes: 0.295ms
-- Query C became 2.78 times faster

CREATE INDEX IF NOT EXISTS comp_idx_driver_id_X_status ON trips(driver_id,status);

--RESULT AFTER composite INDEX:
--Bitmap Heap Scan on trips  (cost=7.10..75.23 rows=275 width=67) (actual time=0.043..0.147 rows=284 loops=1)
--  Recheck Cond: ((driver_id = 3) AND ((status)::text = 'completed'::text))
--  Heap Blocks: exact=63
--  ->  Bitmap Index Scan on comp_idx_driver_id_x_status  (cost=0.00..7.03 rows=275 width=0) (actual time=0.030..0.031 rows=284 loops=1)
--        Index Cond: ((driver_id = 3) AND ((status)::text = 'completed'::text))
--Planning Time: 0.151 ms
--Execution Time: 0.190 ms
-- Query C's execution time after composite indexing, it became 4.3 times faster than query c with no index, and 1.5 times faster than seperated indexes.


--Observation: exec time isn't constant over multiple queries, however in a breif observation over 10 queries the exec time for indexed queries remain faster than non indexed queries.
-- Need to further investigate why the exec time defers, and maybe guage the estimated maxima query time for such queries.


-- ─────────────────────────────────────────────────────────────────
-- Q2: Create completed_trips_view
--
-- Must return only completed trips with ALL of these columns:
--   trip_id, driver_name, rider_name,
--   pickup_city, dropoff_city,
--   fare_amount, distance_km, rating,
--   payment_method, requested_at, completed_at
--
-- No IDs in the output — use JOINs to resolve all foreign keys.
-- ─────────────────────────────────────────────────────────────────

-- YOUR VIEW HERE:



CREATE OR REPLACE VIEW completed_trips_view AS 
SELECT t.trip_id, d.driver_name, p.passenger_name,
       pl.city_name AS pickup_city, dl.city_name AS dropoff_city,
       t.fare_amount, t.distance_km, t.rating, pm.payment_method_name,
       t.requested_at, t.completed_at
FROM trips t
INNER JOIN drivers d ON t.driver_id = d.driver_id
INNER JOIN passengers p ON t.passenger_id = p.passenger_id
INNER JOIN  locations pl ON t.pickup_location_id = pl.location_id
INNER JOIN locations dl ON t.dropoff_location_id = dl.location_id
LEFT  JOIN payment_methods pm ON t.payment_method_id = pm.payment_method_id
WHERE t.status ='completed';


-- Verify:
-- SELECT * FROM completed_trips_view LIMIT 5;
-- SELECT COUNT(*) FROM completed_trips_view;
-- Expected count: ~2862 (all completed trips)
SELECT * FROM completed_trips_view ;
SELECT COUNT(*) FROM completed_trips_view ; 

-- ─────────────────────────────────────────────────────────────────
-- Q3: Create driver_summary view
--
-- Must show one row per driver with:
--   driver_name
--   total_trips          (all statuses)
--   completed_trips
--   cancelled_trips
--   cancellation_rate    (cancelled / total * 100, rounded to 1dp)
--   avg_fare             (completed trips only, rounded to 2dp)
--   avg_rating           (completed trips only, rounded to 1dp)
--
-- Challenge: use COUNT(*) FILTER (WHERE ...) instead of CASE WHEN
-- ─────────────────────────────────────────────────────────────────


-- YOUR VIEW HERE:

--Two methods:

--subquery method:

CREATE OR REPLACE VIEW driver_summary_subquery_method AS
SELECT d.driver_name,
COALESCE(sub2.total_trips,0) total_trips,
COALESCE(sub3.completed_trips,0) completed_trips,
COALESCE(sub.cancelled_trips,0) cancelled_trips,
CONCAT( COALESCE (ROUND((sub.cancelled_trips::numeric/sub2.total_trips)*100, 1),0) , '%') cancellation_rate, 
COALESCE(sub3.avg_fare,0) avg_fare,
COALESCE(sub3.avg_rating,0) avg_rating  
FROM drivers d
LEFT JOIN 
(SELECT t.driver_id, coalesce(count(t.trip_id),0) cancelled_trips 
FROM trips t 
LEFT JOIN drivers d ON d.driver_id=t.driver_id 
WHERE t.status='cancelled' 
GROUP BY t.driver_id) sub
ON d.driver_id = sub.driver_id
LEFT JOIN 
(SELECT coalesce(count(t.trip_id),0) total_trips, t.driver_id  
FROM trips t 
LEFT JOIN drivers d ON d.driver_id=t.driver_id  
GROUP BY t.driver_id) sub2
ON d.driver_id = sub2.driver_id
LEFT JOIN 
(SELECT t.driver_id, coalesce(count(t.trip_id),0) completed_trips, 
COALESCE(round(avg(t.fare_amount),2),0) AS avg_fare,
COALESCE(round(avg(t.rating),1),0) avg_rating  
FROM drivers d
LEFT JOIN trips t ON d.driver_id=t.driver_id 
WHERE t.status='completed' 
GROUP BY t.driver_id) sub3
ON d.driver_id = sub3.driver_id
GROUP BY d.driver_name, sub.cancelled_trips, sub2.total_trips, sub3.completed_trips, sub3.avg_fare, sub3.avg_rating;


--conventional efficent method:

CREATE OR REPLACE VIEW driver_summary AS
SELECT 
d.driver_name, 
s.total_trips,
count(t.trip_id ) FILTER ( WHERE t.status='completed') completed_trips,
s.cancelled_trips,
CONCAT(COALESCE (ROUND((s.cancelled_trips::NUMERIC/NULLIF(s.total_trips,0))*100,1),0),'%') AS cancellation_rate,
COALESCE(round(avg(t.fare_amount) FILTER (WHERE t.status='completed'),2),0)  AS avg_fare,
COALESCE(round(avg(t.rating) FILTER (WHERE t.status='completed'),1),0) AS avg_rating  
FROM drivers d 
LEFT JOIN trips t
ON d.driver_id = t.driver_id
LEFT JOIN (
SELECT
d.driver_id,
count(t.trip_id) AS total_trips,
count(t.trip_id ) FILTER (WHERE t.status='cancelled') AS cancelled_trips
FROM drivers d 
LEFT JOIN trips t
ON d.driver_id = t.driver_id
GROUP BY d.driver_id) s
ON d.driver_id = s.driver_id
GROUP BY d.driver_id, s.total_trips, s.cancelled_trips    ;



-- Verify:
-- SELECT * FROM driver_summary ORDER BY completed_trips DESC;

SELECT * FROM driver_summary dts ORDER BY completed_trips DESC;
SELECT * FROM driver_summary_subquery_method dts_sm ORDER BY completed_trips DESC;


-- ─────────────────────────────────────────────────────────────────
-- Q4: Transaction with intentional failure
--
-- Write a transaction that:
--   1. Inserts a new driver named 'Test Driver'
--   2. Inserts 3 valid trips for that driver
--   3. Inserts a 4th trip with rating = 99 (violates CHECK constraint)
--
-- The entire transaction should roll back.
-- Verify with: SELECT * FROM drivers WHERE name = 'Test Driver';
-- Expected: 0 rows (atomicity — nothing committed)
-- ─────────────────────────────────────────────────────────────────

-- YOUR TRANSACTION HERE:

BEGIN;

INSERT INTO drivers (driver_name) VALUES('Test Driver');

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
VALUES(
(SELECT driver_id FROM drivers WHERE driver_name='Test Driver'),
5,
2,
3,
213,
12,
'completed',
'2024-04-07 07:26:37.000',
'2024-04-07 08:05:37.701',
3.1,
4);


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
VALUES(
(SELECT driver_id FROM drivers WHERE driver_name='Test Driver'),
4,
3,
2,
223,
14,
'completed',
'2024-04-09 07:26:37.000',
'2024-04-09 08:05:37.701',
3.1,
4);


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
VALUES(
(SELECT driver_id FROM drivers WHERE driver_name='Test Driver'),
5,
5,
6,
113,
15,
'completed',
'2024-04-12 07:26:37.000',
'2024-04-13 08:05:37.701',
3.5,
2);


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
VALUES(
(SELECT driver_id FROM drivers WHERE driver_name='Test Driver'),
5,
5,
6,
113,
15,
'completed',
'2024-04-12 07:26:37.000',
'2024-04-13 08:05:37.701',
9.9,
2);





COMMIT;

SELECT * FROM drivers WHERE driver_name='Test Driver';

SELECT * FROM trips ORDER BY trip_id DESC;



-- Verification query:
SELECT
    'drivers' AS tbl,
     COUNT(*) AS test_driver_rows
FROM drivers
WHERE driver_name = 'Test Driver'
UNION ALL
SELECT 'trips', COUNT(*)
FROM trips t
JOIN drivers d ON t.driver_id = d.driver_id
WHERE d.driver_name = 'Test Driver';

-- Expected: 0 / 0


-- ─────────────────────────────────────────────────────────────────
-- Q6 (STRETCH): Window function — running total fare per driver
--
-- For each completed trip, show:
--   trip_id, driver_name, requested_at, fare_amount,
--   running_total_fare (driver's cumulative fare up to this trip)
--
-- Use: SUM(fare_amount) OVER (PARTITION BY driver_id ORDER BY requested_at)
-- Order the final output by driver_name, requested_at
-- ─────────────────────────────────────────────────────────────────

-- YOUR QUERY HERE:


SELECT 
t.trip_id,
d.driver_name,
t.requested_at,
t.fare_amount,
SUM(t.fare_amount) OVER (PARTITION BY d.driver_id ORDER BY requested_at) AS running_total_fare
FROM trips t
JOIN drivers d
ON t.driver_id = d.driver_id
WHERE t.status='completed'
ORDER  BY d.driver_name, t.requested_at;
