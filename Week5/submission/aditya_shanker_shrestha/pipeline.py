import argparse
import logging

from config import SOURCE_DB_CONFIG, DEST_DB_CONFIG, get_connection, logger
from extract import (
    extract_driver,
    extract_passenger,
    extract_location,
    extract_payment_method,
    extract_promo_code,
    extract_vehicle,
    extract_trips_incremental,
    extract_trips_full,
    get_watermark,
)
from transform import transform
from quality import run_quality_checks
from load import (
    load_dim_driver,
    load_dim_passenger,
    load_dim_location,
    load_dim_payment_method,
    load_dim_promo_code,
    load_dim_vehicle,
    load_lookup_dim,
    load_fact_trips,
)
from time import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s %(filename)s %(lineno)d %(message)s"
)



def parse_args():
    parser = argparse.ArgumentParser(description="Rides ETL pipeline")
    parser.add_argument(
        "--full-reload",
        action="store_true",
        help="Re-extract all trips instead of incremental from the watermark"
    )
    return parser.parse_args()


def load_dimensions(src_conn, dst_conn):
    """Extract every dimension from the source DB and load it into the warehouse."""
    load_dim_driver(dst_conn, extract_driver(src_conn))
    load_dim_passenger(dst_conn, extract_passenger(src_conn))
    load_dim_location(dst_conn, extract_location(src_conn))
    load_dim_payment_method(dst_conn, extract_payment_method(src_conn))
    load_dim_promo_code(dst_conn, extract_promo_code(src_conn))
    load_dim_vehicle(dst_conn, extract_vehicle(src_conn))


def load_facts(src_conn, dst_conn, mode):
    """Incrementally load fact_trips using the warehouse watermark."""
    time0= time()
    lookups = load_lookup_dim(dst_conn)
    logger.info(f"Lookup loaded in {time()-time0:.2f}s")
    watermark = get_watermark(dst_conn)
    time0= time()
    if mode == "Incremental":
        rows = extract_trips_incremental(src_conn, watermark)
        logger.info(f"Trips rows loaded in {time()-time0:.2f}s")
    else:
        rows =extract_trips_full(src_conn)
    if not rows:
        logger.info("No new trips since watermark — nothing to transform or load")
        return
    time0=time()
    fact_rows = transform(rows, lookups)
    logger.info(f"Trips rows transformed in {time()-time0:.2f}s")
    time0=time()
    run_quality_checks(fact_rows)
    logger.info(f"Quality checks passed in {time()-time0:.2f}s")
    load_fact_trips(dst_conn, fact_rows)




def main():
    """Run the full ETL: dimensions first, then the incremental fact load."""
    args = parse_args()
    mode = 'FULL' if args.full_reload else 'Incremental'

    src_conn = get_connection(SOURCE_DB_CONFIG)
    dst_conn = get_connection(DEST_DB_CONFIG)
    logger.info("ETL started")

    try:
        time0=time()
        load_dimensions(src_conn, dst_conn)
        logger.info(f"Dimensions loaded in {time()-time0:.2f} seconds")
       
        time0=time()
        load_facts(src_conn, dst_conn, mode)
        logger.info(f"Fact trips loaded in {time()-time0:.2f} seconds")
      
        logger.info("ETL completed successfully")
    finally:
        src_conn.close()
        dst_conn.close()


if __name__ == "__main__":
    main()
