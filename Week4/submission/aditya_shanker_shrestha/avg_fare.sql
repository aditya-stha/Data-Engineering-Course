
SELECT AVG(ft.fare_amount) avg_fare_per_trip_per_payment_method_per_month,
	dpm.name payment_method_name,
	count(ft.*) trips,
	d.month_name ride_month,
	d.year::text ride_year
FROM fact_trips ft 
JOIN dim_payment_method dpm 
ON ft.payment_method_key = dpm.payment_method_key
JOIN dim_date d
ON ft.date_key = d.date_key
WHERE ft.duration_minutes IS NOT NULL
GROUP BY payment_method_name, ride_month , d.month, d.year
ORDER BY d.year DESC, d.month DESC ;