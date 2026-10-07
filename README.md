# Volve Field Production Performance

> Which wells sustain field production, when and why did they lose performance (water, pressure, downtime), and how much oil was lost to downtime?

**Status:** data cleaning, SQL KPIs, production analysis and Power BI dashboard done. Decline-curve forecast in progress.

![Power BI – field overview: KPI cards, monthly oil by producer well, oil share by well](images/04_dashboard_overview.png)

![Monthly oil production by well](images/01_field_production.png)

## Key findings so far
| # | Finding | Number |
|---|---|---|
| 1 | Two wells carried the field | F-12 + F-14 = **85%** of the oil |
| 2 | Water arrived early and took over | Water cut passed 10% **13–23 months** after first oil in the original wells; field water cut **above 70%** from 2011 |
| 3 | Downtime was the largest controllable loss | ~**1.0 million Sm³** of oil estimated (~**10%** of production), worst in 2009 at the field's peak |

Details: [`notebooks/02_analysis.ipynb`](notebooks/02_analysis.ipynb) · [Power BI report (PDF)](dashboard/volve_dpr.pdf) · [water cut by well](images/02_water_cut.png) · [downtime loss by year](images/03_downtime_loss.png)

## Business question
A production data analyst at an operator has to answer three questions every day:
1. **Contribution:** which wells drive production?
2. **Well health:** how are water cut, GOR and pressures evolving?
3. **Losses:** how much production is lost to downtime?

This project answers those questions with real daily well data from the Equinor Volve field, as a *Daily Production Report* style analysis.

## Data
- **Source:** Equinor Volve open dataset, *Volve production data.xlsx* (daily production sheet), 2008–2016, North Sea.
  - [Equinor – Volve data sharing](https://www.equinor.com/energy/volve-data-sharing)
  - [Kaggle mirror](https://www.kaggle.com/datasets/lamyalbert/volve-production-data)
- **Licence:** Equinor Open Data Licence. Educational and research use, with attribution to Equinor and the Volve licence partners.
- The raw file is **not** stored in this repo. Download it and place it in `data/raw/`.

## Power BI — Daily Production Report
A four-page report built on a star schema (`fact_production`, `fact_downtime`, `dim_well`, `dim_date`), with Year and well slicers on every page. Full export: [`dashboard/volve_dpr.pdf`](dashboard/volve_dpr.pdf).

| Page | What it shows |
|---|---|
| 1 · Field overview | KPI cards (oil, water cut, producer efficiency, lost oil, water injected), monthly oil by **producer** well (injectors F-4 and F-5 are excluded from the production chart) and oil share by well |
| 2 · Well health | Water cut by well with the 10% breakthrough line, GOR over time, and a per-well table with first oil, volumes, water cut and GOR |
| 3 · Downtime & losses | Lost oil by year split into full-day stops vs partial days, lost oil by well, an efficiency matrix (well × year) and *Lost vs Potential %* |
| 4 · Daily report | Pick a day on the date slider and see each well's on-stream hours, volumes, water cut, choke, wellhead pressure and lost oil, like an operator's morning report. Wells with fewer than 24 on-stream hours are flagged |

Model, DAX measures and theme live in [`dashboard/`](dashboard/) (see its [README](dashboard/README.md)). The input tables are regenerated with `python src/export_powerbi.py`.

![Power BI – daily report for 15 Jun 2009](images/05_dashboard_daily_report.png)

## Approach
Cleaning (Python) → KPIs (SQL, DuckDB) → Analysis and decline curves (Python) → Dashboard (Power BI)

KPIs (implemented in [`sql/kpis.sql`](sql/kpis.sql) and as DAX measures in [`dashboard/measures.dax`](dashboard/measures.dax)):

| KPI | Definition |
|---|---|
| Oil, gas and water volumes | Per well and field, daily and monthly |
| Water cut | water / (oil + water) |
| GOR | gas / oil |
| Producer efficiency | on-stream hours / calendar hours, producers only |
| Estimated downtime loss | lost hours × the well's median full-day rate in the same month (upper bound) |
| Lost vs potential | lost oil / (produced oil + lost oil) |

## Tools
Python (pandas, scipy, matplotlib) · SQL (DuckDB) · Power BI

## Repository structure
```
data/raw/         original data (not tracked: download from source)
data/processed/   cleaned data
notebooks/        01_cleaning → 02_analysis → 03_decline
sql/              KPI queries
src/              reusable Python functions
dashboard/        Power BI file (.pbix), PDF export, DAX measures, theme
dashboard/data/   star-schema CSVs (not tracked: regenerate with src/export_powerbi.py)
images/           charts and dashboard screenshots
```

## How to reproduce
```bash
pip install -r requirements.txt
```
Then download the data into `data/raw/` and run the notebooks in order.

## About me
**Aguinaldo Miguel** — Automation & Control Engineer | Data Analytics for Oil & Gas Operations and Supply Chain · Luanda, Angola · [LinkedIn](https://linkedin.com/in/agmiguel)

---
*Code: MIT License. Data: © Equinor and the Volve licence partners, under the Equinor Open Data Licence.*
