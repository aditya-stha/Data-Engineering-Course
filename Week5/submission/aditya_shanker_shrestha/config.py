import logging
import os

import psycopg2
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s"
)
logger = logging.getLogger(__name__)


SOURCE_DB_CONFIG = dict(
    host=    os.getenv("SRC_DB_HOST"),
    port =   os.getenv("SRC_DB_PORT"),
    dbname = os.getenv("SRC_DB_NAME"),
    user=    os.getenv("SRC_DB_USER"),
    password=os.getenv("SRC_DB_PASSWORD")
)
DEST_DB_CONFIG = dict(
    host=    os.getenv("DES_DB_HOST"),
    port =   os.getenv("DES_DB_PORT"),
    dbname = os.getenv("DES_DB_NAME"),
    user=    os.getenv("DES_DB_USER"),
    password=os.getenv("DES_DB_PASSWORD")
)


def get_connection(db_config):
    return psycopg2.connect(**db_config)

