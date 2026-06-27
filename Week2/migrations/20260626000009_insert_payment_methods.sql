INSERT INTO payment_methods (payment_method_name)
SELECT DISTINCT payment_method
FROM rides
WHERE payment_method IS NOT NULL
ON CONFLICT DO NOTHING;
