"""
scripts/load_data.py

Loads the raw APY crop production CSV into the normalized MySQL schema:
states -> districts -> crops -> seasons -> crop_production

Note: crop_code in the raw dataset is NOT reliably unique (one code can map
to multiple different crop names), so crops are keyed by crop_name instead,
via an auto-increment surrogate key (crop_id).

Usage:
    python3 load_data.py
"""

import pandas as pd
import mysql.connector
from mysql.connector import Error
import os

# ---------- CONFIG ----------
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": os.environ.get("MYSQL_PASSWORD", ""),
    "database": "agri_crop_db"
}


CSV_PATH = "../data/crop_production_raw.csv"
BATCH_SIZE = 5000
# -----------------------------


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Standardize column names and handle missing/placeholder values."""
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    placeholder_values = ["-", "NA", "N/A", "", " ", "nan", "NaN"]
    df = df.replace(placeholder_values, pd.NA)

    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].astype(str).str.strip()

    for col in ["area", "production", "yield"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Drop rows with no district_code or crop_name — can't be linked to dimension tables
    df = df.dropna(subset=["district_code", "crop_name"])

    return df


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


def load_states(cursor, df: pd.DataFrame):
    states = df[["state_code", "state_name"]].drop_duplicates().dropna()
    sql = "INSERT IGNORE INTO states (state_code, state_name) VALUES (%s, %s)"
    cursor.executemany(sql, states.values.tolist())
    print(f"Loaded {len(states)} unique states.")


def load_districts(cursor, df: pd.DataFrame):
    districts = df[["district_code", "district_name", "state_code"]].drop_duplicates().dropna()
    sql = """
        INSERT IGNORE INTO districts (district_code, district_name, state_code)
        VALUES (%s, %s, %s)
    """
    cursor.executemany(sql, districts.values.tolist())
    print(f"Loaded {len(districts)} unique districts.")


def load_crops(cursor, df: pd.DataFrame):
    # crop_name is the real unique identifier — crop_code repeats across
    # different crops in this dataset, so it's excluded from the key.
    crops = df[["crop_name", "crop_type"]].drop_duplicates(subset=["crop_name"]).dropna(subset=["crop_name"])
    sql = "INSERT IGNORE INTO crops (crop_name, crop_type) VALUES (%s, %s)"
    cursor.executemany(sql, crops.values.tolist())
    print(f"Loaded {len(crops)} unique crops (keyed by crop_name).")


def load_seasons(cursor, df: pd.DataFrame):
    seasons = df[["season"]].drop_duplicates().dropna()
    sql = "INSERT IGNORE INTO seasons (season_name) VALUES (%s)"
    cursor.executemany(sql, seasons.values.tolist())
    print(f"Loaded {len(seasons)} unique seasons.")


def get_season_map(cursor) -> dict:
    cursor.execute("SELECT season_id, season_name FROM seasons")
    return {name: sid for sid, name in cursor.fetchall()}


def get_crop_map(cursor) -> dict:
    cursor.execute("SELECT crop_id, crop_name FROM crops")
    return {name: cid for cid, name in cursor.fetchall()}


def load_crop_production(cursor, df: pd.DataFrame, season_map: dict, crop_map: dict):
    df = df.copy()
    df["season_id"] = df["season"].map(season_map)
    df["crop_id"] = df["crop_name"].map(crop_map)
    df = df.dropna(subset=["season_id", "crop_id", "district_code"])
    df["crop_id"] = df["crop_id"].astype(int)

    prod_df = df[[
        "district_code", "crop_id", "season_id", "year",
        "area", "production", "yield"
    ]].copy()

    # Convert NaN -> None so MySQL gets NULL instead of the literal word 'nan'
    prod_df = prod_df.astype(object).where(pd.notnull(prod_df), None)

    records = prod_df.values.tolist()

    sql = """
        INSERT IGNORE INTO crop_production
        (district_code, crop_id, season_id, year, area_hectares, production_tonnes, yield_tonnes_per_ha)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """

    total = len(records)
    for i in range(0, total, BATCH_SIZE):
        batch = records[i:i + BATCH_SIZE]
        cursor.executemany(sql, batch)
        print(f"Inserted {min(i + BATCH_SIZE, total)}/{total} production records...")


def main():
    print("Reading CSV...")
    df = pd.read_csv(CSV_PATH, low_memory=False)
    print(f"Raw rows: {len(df)}")

    df = clean_dataframe(df)
    print(f"Rows after cleaning: {len(df)}")

    conn = None
    try:
        conn = get_connection()
        cursor = conn.cursor()

        load_states(cursor, df)
        conn.commit()

        load_districts(cursor, df)
        conn.commit()

        load_crops(cursor, df)
        conn.commit()

        load_seasons(cursor, df)
        conn.commit()

        season_map = get_season_map(cursor)
        crop_map = get_crop_map(cursor)

        load_crop_production(cursor, df, season_map, crop_map)
        conn.commit()

        print("✅ Data load complete.")

    except Error as e:
        print(f"❌ MySQL error: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn and conn.is_connected():
            cursor.close()
            conn.close()


if __name__ == "__main__":
    main()
