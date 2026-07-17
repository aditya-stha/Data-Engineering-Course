import logging


class DataQualityError(Exception):
    pass

def check_rows_count(rows):
    count = len(rows)
    passed = count > 0
    return {
        "check_identifier" : "check_rows_count",
        "status": "passed" if passed else "failed",
        "details" : f"Found {count} rows" if passed else "No rows found",
        "rank": "severe" if not passed else "info"
    }

def check_no_negative_fares(rows):
    invalid_rows = [r for r in rows if r["fare_amount"] < 0]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_no_negative_fares",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with negative fares" if invalid_rows else "No rows with negative fares found",
        "rank": "severe" if not passed else "info"
    }

def check_required_keys_not_null(rows):
    required_keys = ["source_trip_id", "date_key", "driver_key", "passenger_key", "pickup_location_key", "dropoff_location_key", "payment_method_key","tip_amount", "discount_amount", "trip_count","requested_at", "time_key"]
    invalid_rows = [r for r in rows if any(r[k] is None for k in required_keys)]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_required_keys_not_null",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with null values in required keys: {required_keys}" if invalid_rows else f"No rows with null values in required keys: {required_keys}"
    }

def unique_source_trip_id(rows):
    trip_ids = [r["source_trip_id"] for r in rows]
    unique_trip_ids = set(trip_ids)
    passed = len(trip_ids) == len(unique_trip_ids)
    return {
        "check_identifier" : "unique_source_trip_id",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(trip_ids) - len(unique_trip_ids)} duplicate source_trip_id values" if not passed else "All source_trip_id values are unique"
    }


def check_surge_multiplier(rows):
    invalid_rows = [r for r in rows if r["surge_multiplier"] < 0]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_surge_multiplier",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with negative surge_multiplier values" if invalid_rows else "No rows with negative surge_multiplier values found"
    }
def check_distance_km(rows):
    invalid_rows = [r for r in rows if r["distance_km"] < 0]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_distance_km",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with negative distance_km values" if invalid_rows else "No rows with negative distance_km values found"
    }

def check_tip_amount_discount_amount(rows):
    invalid_rows = [r for r in rows if r["tip_amount"] < 0 or r["discount_amount"] < 0]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_tip_amount_discount_amount",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with negative tip_amount or discount_amount values" if invalid_rows else "No rows with negative tip_amount or discount_amount values found"
    }

def check_fare_amount_recalculation(rows):
    invalid_rows = [r for r in rows if r["fare_amount"] != round(r["base_fare"] * r["surge_multiplier"] + r["tip_amount"] - r["discount_amount"], 2)]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_fare_amount_recalculation",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with incorrect fare_amount calculation" if invalid_rows else "All fare_amount values are correctly calculated"
    }

def check_duration_minutes_calculation(rows):
    invalid_rows = [r for r in rows if r["status"] == "completed" and r["completed_at"] and r["duration_minutes"] != round((r["completed_at"] - r["requested_at"]).total_seconds() / 60, 1)]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_duration_minutes_calculation",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} rows with incorrect duration_minutes calculation" if invalid_rows else "All duration_minutes values are correctly calculated"
    }   


def check_duration_completed_trips(rows):
    invalid_rows = [r for r in rows if r["status"] == "completed" and (r["completed_at"] is None or r["duration_minutes"] is None)]
    passed = not invalid_rows
    return {
        "check_identifier" : "check_duration_completed_trips",
        "status": "passed" if passed else "failed",
        "details" : f"Found {len(invalid_rows)} completed trips with null completed_at or duration_minutes values" if invalid_rows else "All completed trips have non-null completed_at and duration_minutes values"
    }

def threshold_check(rows, threshold=0.1):
    total_rows = len(rows)
    failed_checks = [check for check in rows if check["status"] == "failed"]
    failed_count = len(failed_checks)
    failed_percentage = failed_count / total_rows if total_rows > 0 else 0
    passed = failed_percentage <= threshold
    return {
        "check_identifier" : "threshold_check",
        "status": "passed" if passed else "failed",
        "details" : f"{failed_count} out of {total_rows} checks failed ({failed_percentage:.2%})" if not passed else f"{failed_count} out of {total_rows} checks failed ({failed_percentage:.2%}) - within threshold of {threshold:.2%}"
    }


def run_quality_checks(rows)-> dict:
    checks = [
        check_rows_count,
        check_no_negative_fares,
        check_required_keys_not_null,
        unique_source_trip_id,
        check_surge_multiplier,
        check_distance_km,
        check_tip_amount_discount_amount,
        check_fare_amount_recalculation,
        check_duration_minutes_calculation,
        check_duration_completed_trips
    ]
    results = []
    for check in checks:
        result = check(rows)
        results.append(result)
        if result["status"] == "failed":
            logging.error(f"Data quality check failed: {result['check_identifier']} - {result['details']}")
            raise DataQualityError(f"Data quality check failed: {result['check_identifier']} - {result['details']}")
        else:
            logging.info(f"Data quality check passed: {result['check_identifier']} - {result['details']}")
    return {
        "passed": True,
        "results": results
    }