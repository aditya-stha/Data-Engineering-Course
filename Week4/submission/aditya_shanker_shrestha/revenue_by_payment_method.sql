SELECT SUM(ft.fare_amount) revenue,
	dpm.name payment_method_name	
FROM fact_trips ft 
JOIN dim_payment_method dpm 
ON ft.payment_method_key = dpm.payment_method_key
WHERE ft.duration_minutes IS NOT NULL
GROUP BY payment_method_name ;