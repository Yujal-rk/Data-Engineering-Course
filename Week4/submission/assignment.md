# Week 4 Assignment — Ride-Sharing Warehouse

Complete the tasks below directly in `warehouse.sql` and `etl.py`. Add any
analysis queries and your written answers to this file under the matching
section.

## 1. `warehouse.sql` — add the vehicle dimension

- Create a `dim_vehicle` table (surrogate key `vehicle_key`, natural key
  `vehicle_id`, plus the descriptive vehicle attributes from the OLTP
  `vehicles` table: plate number, make, model, year, color, category,
  is_active).
- Add `vehicle_key` and `time_key` columns to `fact_trips`, referencing
  `dim_vehicle(vehicle_key)` and `dim_time(time_key)` respectively.
  - Think about whether each new key should be `NOT NULL` — is `vehicle_id`
    always present on a trip in the OLTP schema? Is a time always known?

## 2. `etl.py` — implement the remaining dimension + fact columns

- Add `extract_vehicle` / `load_dim_vehicle` following the pattern of the
  existing dimension loaders.
- Add `vehicle` and `time` to `load_lookup_dim`.
- In `transform`, resolve `vehicle_key` and `time_key` for each trip
  (remember `dim_time.time_key` is the requested time rounded **down** to
  the nearest 15-minute bucket, e.g. 14:37 → `1430`).
- Wire the new columns through `load_fact_trips`.

## 3. Revenue by city / month

Write a warehouse query that returns total revenue grouped by pickup city
and month.

SELECT
    dl.city_name,
    dd.year,
    dd.month,
    dd.month_name,
    SUM(ft.fare_amount) AS total_revenue,
    COUNT(ft.trip_key) AS trip_count
FROM fact_trips ft
JOIN dim_date dd ON ft.date_key = dd.date_key
JOIN dim_location dl ON ft.pickup_location_key = dl.location_key
GROUP BY dl.city_name, dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month, dl.city_name;

Then write the equivalent query against the OLTP schema (`trips`,
`locations`, etc.) directly.

  SELECT
    l.city_name,
    EXTRACT(YEAR FROM t.requested_at) AS year,
    EXTRACT(MONTH FROM t.requested_at) AS month,
    TO_CHAR(t.requested_at, 'Month') AS month_name,
    SUM(t.base_fare * t.surge_multiplier + t.tip_amount - t.discount_amount) AS total_revenue,
    COUNT(t.trip_id) AS trip_count
FROM trips t
JOIN locations l ON t.pickup_location_id = l.location_id
GROUP BY l.city_name, EXTRACT(YEAR FROM t.requested_at), EXTRACT(MONTH FROM t.requested_at), TO_CHAR(t.requested_at, 'Month')
ORDER BY EXTRACT(YEAR FROM t.requested_at), EXTRACT(MONTH FROM t.requested_at), l.city_name;

**Answer:** how many table joins does each version need? Which one needed
fewer, and why?

Warehouse: 2 joins (fact_trips → dim_date, dim_location). OLTP: 1 join (trips → locations). The OLTP query needs fewer joins because date extraction happens inline with SQL functions, while the warehouse denormalizes dates into a surrogate key requiring a separate lookup.


## 4. Payment method revenue

- Write a warehouse query for total revenue per payment method.

SELECT
    dpm.name AS payment_method,
    SUM(ft.fare_amount) AS total_revenue,
    COUNT(ft.trip_key) AS trip_count
FROM fact_trips ft
JOIN dim_payment_method dpm ON ft.payment_method_key = dpm.payment_method_key
GROUP BY dpm.payment_method_key, dpm.name
ORDER BY total_revenue DESC;

- Extend it (or write a second query) for **average fare per trip, per
  payment method, per month**.

SELECT
    dpm.name AS payment_method,
    dd.year,
    dd.month,
    dd.month_name,
    AVG(ft.fare_amount) AS avg_fare_per_trip,
    COUNT(ft.trip_key) AS trip_count,
    SUM(ft.fare_amount) AS total_revenue
FROM fact_trips ft
JOIN dim_payment_method dpm ON ft.payment_method_key = dpm.payment_method_key
JOIN dim_date dd ON ft.date_key = dd.date_key
GROUP BY dpm.payment_method_key, dpm.name, dd.date_key, dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month, dpm.name;


## 5. Busiest hour of day

Write a warehouse query that returns trip count per hour of day (0–23),
along with each hour's percentage of all trips — computed with a **window
function** (not a second query for the grand total).

SELECT
    dt.hour,
    dt.time_label,
    COUNT(ft.trip_key) AS trip_count,
    ROUND(
        100.0 * COUNT(ft.trip_key) / SUM(COUNT(ft.trip_key)) OVER (),
        2
    ) AS percent_of_total_trips
FROM fact_trips ft
JOIN dim_time dt ON ft.time_key = dt.time_key
GROUP BY dt.hour, dt.time_label
ORDER BY dt.hour;

## 7. Stretch: incremental load (watermark pattern)

Modify `etl.py` so the fact load only extracts trips newer than the
`MAX(requested_at)` already present in `fact_trips`. Where should that
watermark be read from, and what happens the very first time the ETL runs
against an empty warehouse?
