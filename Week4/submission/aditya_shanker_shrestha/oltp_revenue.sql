SELECT SUM( round(base_fare * surge_multiplier + tip_amount - discount_amount,2) ) AS revenue,
	   EXTRACT(MONTH FROM requested_at ) ride_month,
	   EXTRACT(YEAR FROM requested_at )  ride_year,
	   l.city_name pickup_city
FROM trips t 
JOIN locations l ON t.pickup_location_id = l.location_id
WHERE status = 'completed'
GROUP BY ride_month, ride_year, l.city_name
ORDER BY ride_year DESC, ride_month DESC;