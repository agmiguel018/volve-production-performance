# Power BI — Volve Daily Production Report

`volve_dpr.pbix` is a four-page report in the style of an operator's *Daily Production Report*.

| Page | Question it answers |
|---|---|
| 1 · Field overview | How much did the field produce, from which wells, and how efficiently? |
| 2 · Well health | How did water cut and GOR evolve in each well? |
| 3 · Downtime & losses | How much oil was lost to downtime, when, where, and how (full-day stops vs partial days)? |
| 4 · Daily report | What happened on a given day, well by well (hours, volumes, choke, pressure)? |

## Data model (star schema)

```
dim_date (Date) ──1:*── fact_production (date, well, volumes, hours, choke, pressures)
     │                        │
     └──────1:*── fact_downtime (date, well, lost hours, lost oil)
                              │
dim_well (well, role, colour) ┘ 1:* to both fact tables
```

- **Build the inputs:** `python src/export_powerbi.py` writes `fact_production.csv`, `fact_downtime.csv` and `dim_well.csv` to `dashboard/data/`.
- **dim_date:** a DAX calendar table, marked as the date table.
- **Measures:** [`measures.dax`](measures.dax).
- **Theme:** [`volve_theme.json`](volve_theme.json). It uses the same well colours as the Python charts.

The downtime loss is an **upper-bound estimate**; the method is explained in [`notebooks/02_analysis.ipynb`](../notebooks/02_analysis.ipynb).
