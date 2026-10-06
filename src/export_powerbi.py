"""Export the star-schema tables used by the Power BI dashboard.

Run from the repository root after notebooks/01_cleaning.ipynb:

    python src/export_powerbi.py

Writes CSV files to dashboard/data/ (not tracked by git: regenerate them locally).
"""

import re
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DAILY = ROOT / "data" / "processed" / "volve_daily.parquet"
OUT = ROOT / "dashboard" / "data"

WELL_INFO = {
    # well: (role in the dashboard, display order, colour used in every chart)
    "F-12": ("Producer", 1, "#2a78d6"),
    "F-14": ("Producer", 2, "#eb6834"),
    "F-11": ("Producer", 3, "#1baf7a"),
    "F-1C": ("Producer", 4, "#eda100"),
    "F-15D": ("Producer", 5, "#e87ba4"),
    "F-5": ("Injector (producer in 2016)", 6, "#008300"),
    "F-4": ("Injector", 7, "#4a3aa7"),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect()
    con.execute(f"CREATE VIEW daily AS SELECT * FROM '{DAILY.as_posix()}'")

    queries = dict(re.findall(
        r"-- name: (\w+)\n(.*?)(?=\n-- name:|\Z)",
        (ROOT / "sql" / "kpis.sql").read_text(encoding="utf-8"),
        re.S,
    ))
    con.execute(f"CREATE VIEW daily_loss AS {queries['daily_loss']}")

    tables = {
        "fact_production": """
            SELECT date, well, role, day_hours, on_stream_hrs, efficiency,
                   oil_sm3, gas_sm3, water_sm3, water_injected_sm3,
                   choke_pct, whp_bar, downhole_pressure_bar, flag_gauge_failure
            FROM daily
            ORDER BY well, date""",
        "fact_downtime": """
            SELECT date, well, lost_hrs, lost_oil_sm3, full_day_stop
            FROM daily_loss
            WHERE lost_hrs > 0""",
        "dim_well": """
            SELECT well, MIN(date) AS first_day, MAX(date) AS last_day,
                   MIN(date) FILTER (WHERE oil_sm3 > 0) AS first_oil
            FROM daily
            GROUP BY well""",
    }
    for name, query in tables.items():
        df = con.execute(query).df()
        if name == "dim_well":
            df["role"] = df["well"].map(lambda w: WELL_INFO[w][0])
            df["sort_order"] = df["well"].map(lambda w: WELL_INFO[w][1])
            df["color"] = df["well"].map(lambda w: WELL_INFO[w][2])
            df = df.sort_values("sort_order")
        df.to_csv(OUT / f"{name}.csv", index=False)
        print(f"{name:16s} {len(df):>6,} rows -> {OUT / (name + '.csv')}")


if __name__ == "__main__":
    main()
