SELECT count(ft.*) count_per_hour,
       ft.time_key / 100 AS hour,
       CONCAT(ROUND((count(ft.*)/sum(count(*)) OVER())*100,2),'%') AS contribution_percentage
FROM fact_trips ft
GROUP BY hour
ORDER BY ROUND((count(ft.*)/sum(count(*)) OVER())*100,2) DESC;
