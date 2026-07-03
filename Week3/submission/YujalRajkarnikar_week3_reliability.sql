-- week3_reliability.sql
-- Week 3 Assignment
-- Name: Yujal Rajkarnikar
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
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3;
-- Query A before: Seq Scan, execution time = 145.298 ms
-- Query A after:  Index Scan using ..., execution time = 34.434 ms
-- Query B: filter by status
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	status = 'cancelled';
-- Query B before: Seq Scan, execution time = 99.108 ms
-- Query B after:  Index Scan using ..., execution time = 53.469 ms
-- Query C: filter by driver AND status (common in the pipeline)
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3
	AND status = 'completed';
-- Execution Time: 
-- Query C before: Seq Scan, execution time = 87.745 ms
-- Query C after:  Index Scan using ..., execution time = 20.829 ms
-- YOUR INDEXES HERE:
-- (add indexes, then re-run the EXPLAIN ANALYZE queries above)
CREATE INDEX idx_trips_driver_id
ON
trips(driver_id);

CREATE INDEX idx_trips_status
ON
trips(status);

CREATE INDEX idx_trips_driver_status
ON
trips(driver_id, status);
-- Record results in comments, e.g.:
-- Query A before: Seq Scan, execution time = X ms
-- Query A after:  Index Scan using ..., execution time = Y ms
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

CREATE VIEW completed_trips_view AS 
SELECT
	t.trip_id,
	d.name driver_name,
	p.name passenger_name,
	pu.city_name pickup_city,
	dof.city_name dropoff_city,
	t.fare_amount ,
	t.distance_km ,
	t.rating ,
	pm.name payment_method,
	t.requested_at,
	t.completed_at
FROM
	trips t
INNER JOIN drivers d 
ON
	t.driver_id = d.driver_id
INNER JOIN passengers p 
ON
	t.passenger_id = p.passenger_id
INNER JOIN locations pu
ON
	t.pickup_location_id = pu.location_id
INNER JOIN locations dof
ON
	t.dropoff_location_id = dof.location_id
INNER JOIN payment_methods pm 
ON
	t.payment_method_id = pm.payment_method_id
WHERE
	t.status = 'completed';

SELECT
	*
FROM
	completed_trips_view
LIMIT 5;

SELECT
	COUNT(*)
FROM
	completed_trips_view;
-- Expected count: ~2862 (all completed trips)
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
CREATE VIEW driver_summary AS 
SELECT
	d.name AS driver_name,
	count(t.trip_id) AS total_trips,
	count(t.trip_id) FILTER (
WHERE
	t.status = 'completed') AS completed_trips,
	count(t.trip_id) FILTER (
WHERE
	t.status = 'cancelled') AS cancelled_trips,
	round(count(t.trip_id) FILTER (WHERE t.status = 'cancelled')* 100.00 / NULLIF(count(trip_id), 0), 1) AS cancellation_rate,
	round(avg(t.fare_amount) FILTER (WHERE t.status = 'completed'), 2) AS avg_fare,
	round(avg(t.rating) FILTER (WHERE t.status = 'completed'), 1) AS avg_rating
FROM
	drivers d
LEFT JOIN trips t ON
	d.driver_id = t.driver_id
GROUP BY
	d.driver_id,
	d.name;

SELECT
	*
FROM
	driver_summary
ORDER BY
	completed_trips DESC;
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
SELECT
	*
FROM
	trips;

BEGIN;

INSERT
	INTO
	drivers (name)
VALUES ('Test Driver');

INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at)
VALUES ((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'),
1,
1,
2,
250.00,
8.5,
'completed',
NOW());

INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at)
VALUES ((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'),
2,
2,
3,
250.00,
9.5,
'completed',
NOW());

INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at)
VALUES ((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'),
3,
3,
4,
250.00,
7.5,
'completed',
NOW());

INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	rating)
VALUES ((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'),
1,
1,
2,
250.00,
9.5,
'completed',
NOW(),
9.9);

COMMIT;

ROLLBACK;
-- Verification query:
SELECT
	'drivers' AS tbl,
	COUNT(*) AS test_driver_rows
FROM
	drivers
WHERE
	name = 'Test Driver'
UNION ALL
SELECT
	'trips',
	COUNT(*)
FROM
	trips t
JOIN drivers d ON
	t.driver_id = d.driver_id
WHERE
	d.name = 'Test Driver';
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
	d.name AS driver_name,
	t.requested_at,
	t.fare_amount,
	SUM(t.fare_amount) OVER (
        PARTITION BY t.driver_id
ORDER BY
	t.requested_at
    ) AS running_total_fare
FROM
	trips t
INNER JOIN drivers d
    ON
	t.driver_id = d.driver_id
WHERE
	t.status = 'completed'
ORDER BY
	d.name,
	t.requested_at;