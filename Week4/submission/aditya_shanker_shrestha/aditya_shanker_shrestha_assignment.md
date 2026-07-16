# Week 4 — Aditya Shanker Shrestha

My answers for the week 4 assignment. Code changes are in `warehouse.sql` and
`etl.py`, queries are in the separate .sql files in this folder.

## 1. warehouse.sql — vehicle dimension

Added `dim_vehicle` with `vehicle_key` as the surrogate key and `vehicle_id`
as the natural key (NOT NULL UNIQUE, same convention I've been using since
week 3 — the unique constraint is also what makes ON CONFLICT work in the
ETL). Added `vehicle_key` and `time_key` to `fact_trips`.

For the NOT NULL question:

- `vehicle_key` — I left it nullable. Honestly my first instinct was NOT NULL
  because I figured even a cancelled or no-show trip would have a vehicle
  attached to it. And the current data actually agrees with me: 0 null
  vehicle_ids in all 10,000 trips. But `trips.vehicle_id` is nullable in the
  OLTP schema, which means a trip without a vehicle is a legal state (like a
  passenger cancelling while the app is still searching for a driver). If I
  put NOT NULL on the fact table, the ETL either crashes or silently drops
  those trips the day the first one shows up. So I designed against the
  schema, not against what the data happens to look like today. There's also
  a pattern where you add an "unknown vehicle" row to the dimension and keep
  the fact column NOT NULL, but I kept it simple and did the same thing the
  starter code already does for payment_method and promo_code.
- `time_key` — NOT NULL. `requested_at` is NOT NULL in OLTP and dim_time is
  pre-populated with all 96 fifteen-minute buckets, so there's always a valid
  time to resolve to.

One more thing I learned here: my first version of dim_vehicle was stricter
than the source (NOT NULL on make/model/year, color VARCHAR(20) vs the
source's 30). That's backwards: if the dimension is stricter than the OLTP
table, the ETL is forced to drop legal rows. So I matched the constraints to
the source.

## 2. etl.py — vehicle + time in the ETL

 `extract_vehicle` / `load_dim_vehicle` follow the same pattern as the
other dimensions. In `transform`, vehicle uses the same nullable-key logic as
payment_method (null passes through as null, but an id that exists and is NOT
in the dimension is a data problem, so it warns and skips). time_key is
derived from requested_at: `hour * 100 + (minute // 15) * 15`, so 14:37
becomes 1430.

Final run: 10,000 extracted, 10,000 transformed, 0 skipped, 10,000 inserted.

**Bug I found in the starter code:** `load_dim_driver` and
`load_dim_passenger` use a bare `ON CONFLICT DO NOTHING`, but dim_driver and
dim_passenger had no unique constraint on driver_id/passenger_id. ON CONFLICT
only does something if there's actually a constraint to conflict with — so
every rerun of the ETL was quietly re-inserting every driver and passenger.
After a few test runs I had 150 rows in dim_driver for 25 drivers. Fixed it
by adding UNIQUE to both natural keys in warehouse.sql and naming the
conflict target explicitly (`ON CONFLICT (driver_id)`) like the other
dimensions already do. Now a second run inserts 0 rows everywhere.

## 3. Revenue by city / month

Warehouse version: `olap_revenue.sql`. OLTP version: `oltp_revenue.sql`.

Join count: the warehouse query needs 2 joins (dim_location + dim_date), the
OLTP one only needs 1 (locations). So for this specific question OLTP
actually wins the join count, since trips already has requested_at on it and
I can extract the month inline. But that's kind of missing the point: the
OLTP query has to calculate the fare by hand (base_fare * surge_multiplier +
tip_amount - discount_amount) and do date math on every row every time it
runs, while the warehouse did that once at load time. And the moment I ask a
follow-up question (revenue by region, weekend vs weekday, by quarter), the
warehouse already has those as columns in dim_date/dim_location, while the
OLTP version needs new expressions or joins each time.

I'm counting revenue as completed trips only (`duration_minutes IS NOT NULL`
in the warehouse, `status = 'completed'` in OLTP: I checked and both filters
select exactly the same trips).

Both queries return the same 1,049 city-month groups. The grand totals are
$652,337.92 (OLAP) vs $652,342.72 (OLTP) — off by $4.80, which bugged me
until we tracked it down: exactly 480 trips have a fare that lands on a
perfect half cent, and Python's round() (which my ETL uses) does banker's
rounding (rounds half to the nearest EVEN cent) while Postgres round() always
rounds half up. One cent difference on 480 trips = $4.80, to the cent.
Neither number is wrong, they're just two rounding conventions: the real
lesson is pick one and use it everywhere, and if two systems disagree you
should be able to reconcile the difference exactly like this. But i should test of a better way, because it seems $4.80 vanished in etl. For 1 billion rides it maybe $480,000, which is a big amount that could cause issues.

## 4. Payment method revenue

Total per method: `revenue_by_payment_method.sql`. Avg fare per method per
month: `avg_fare.sql`.

The per-method totals add back up to the $652,337.92 from task 3, which was a
nice sanity check. One thing worth noting: the inner join to
dim_payment_method drops trips with a null payment_method_key. That's fine
here because zero completed trips are missing a payment method (makes sense,
you can't complete a ride without paying), but if I removed the
completed-only filter, the no-show trips would just silently disappear from
the report instead of showing up as an unknown row.

## 5. Busiest hour of day

Query: `busiest_hour.sql`. The trick is
`SUM(COUNT(*)) OVER ()` — the window part runs after GROUP BY, so it sums the
24 hourly counts into a grand total without a second query. And getting the
hour is free with my time_key format: `time_key / 100` (integer division), so
1430 → 14.

I counted all 10,000 trips here (including cancelled/no-show), so this
measures demand per hour, not completed rides.

Result: the "busiest" hour is 3am with 446 trips (4.46%). But every hour is
sitting right around 1/24 ≈ 4.17%, basically flat. Real ride data would have
rush hour peaks and a dead zone around 4am — a flat distribution with 3am on
top is a pretty clear sign the timestamps were generated randomly, i.e. this
is synthetic data.

## 7. Stretch: incremental load (watermark)

Implemented in etl.py. `get_watermark()` reads
`COALESCE(MAX(requested_at), '1900-01-01')` from fact_trips, and
extract_trips filters with `WHERE t.requested_at > %(watermark)s` as a bound
parameter (I gave the shared extract() helper an optional params argument for
this).

Where to read the watermark from: the warehouse, not the source. The
watermark means "what have I already loaded", and only the warehouse knows
that.

First run against an empty warehouse: MAX() on an empty table returns NULL,
and `requested_at > NULL` is never true — so without handling it, the first
run would load nothing and not even error. The COALESCE to 1900-01-01 makes
the first run just turn into a full load. My actual logs:

```
run 1 (empty warehouse):
  Watermark: 1900-01-01 00:00:00
  Extracted 10000 from the table
  10000 inserted to fact_trips

run 2 (right after):
  Watermark: 2026-06-29 21:53:01
  Extracted 0 from the table
  No fact rows to load — skipping
```

The difference that matters: before the watermark, run 2 would pull all
10,000 rows from the source and throw them away at the ON CONFLICT check.
Now it extracts 0 rows, the source never ships them at all.

One caveat: `>` (strictly greater) works here because each load commits
all-or-nothing, but in a live system with writes happening mid-extract, a
timestamp watermark can miss late rows that share the boundary timestamp.
Real pipelines usually watermark on a monotonic id or re-extract a small
overlap and dedupe.
