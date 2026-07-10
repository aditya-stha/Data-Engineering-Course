SELECT 
    SUM(ft.fare_amount) AS revenue, 
    d.month_name AS ride_month, 
    d.year::text AS ride_year,
    l.city_name AS pickup_city
FROM fact_trips ft
JOIN dim_location l ON ft.pickup_location_key = l.location_key
JOIN dim_date d ON ft.date_key = d.date_key 
WHERE ft.duration_minutes IS NOT NULL
GROUP BY d.year, d.month, d.month_name, l.city_name
ORDER BY d.year DESC, d.month DESC;