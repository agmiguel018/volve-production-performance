-- KPI queries for the Volve field (DuckDB).
-- Source table `daily` = data/processed/volve_daily.parquet (built by notebooks/01_cleaning.ipynb).
-- Each query starts with "-- name: <id>" so the notebook can run them by name.

-- name: well_totals
-- Contribution of each producer: volumes, share of field oil and producing life.
WITH producers AS (
    SELECT * FROM daily WHERE role = 'producer'
),
totals AS (
    SELECT
        well,
        MIN(date) FILTER (WHERE oil_sm3 > 0) AS first_oil,
        MAX(date) FILTER (WHERE oil_sm3 > 0) AS last_oil,
        SUM(oil_sm3)   AS oil_sm3,
        SUM(gas_sm3)   AS gas_sm3,
        SUM(water_sm3) AS water_sm3
    FROM producers
    GROUP BY well
)
SELECT
    well,
    first_oil,
    last_oil,
    ROUND(oil_sm3)                                         AS oil_sm3,
    ROUND(water_sm3)                                       AS water_sm3,
    ROUND(100 * oil_sm3 / SUM(oil_sm3) OVER (), 1)         AS oil_share_pct,
    ROUND(100 * SUM(oil_sm3) OVER (ORDER BY oil_sm3 DESC)
              / SUM(oil_sm3) OVER (), 1)                   AS cumulative_share_pct,
    ROUND(water_sm3 / NULLIF(oil_sm3 + water_sm3, 0), 3)  AS lifetime_water_cut,
    ROUND(gas_sm3 / NULLIF(oil_sm3, 0), 1)                AS lifetime_gor
FROM totals
WHERE oil_sm3 > 0
ORDER BY oil_sm3 DESC;

-- name: monthly_well
-- Monthly volumes and well-health indicators per producer.
SELECT
    DATE_TRUNC('month', date)                                    AS month,
    well,
    SUM(oil_sm3)                                                 AS oil_sm3,
    SUM(gas_sm3)                                                 AS gas_sm3,
    SUM(water_sm3)                                               AS water_sm3,
    SUM(on_stream_hrs)                                           AS on_stream_hrs,
    SUM(water_sm3) / NULLIF(SUM(oil_sm3) + SUM(water_sm3), 0)   AS water_cut,
    SUM(gas_sm3) / NULLIF(SUM(oil_sm3), 0)                      AS gor
FROM daily
WHERE role = 'producer'
GROUP BY ALL
ORDER BY month, well;

-- name: yearly_field
-- Field-level view per year: production, water handling, injection and uptime.
SELECT
    YEAR(date)                                                         AS year,
    ROUND(SUM(oil_sm3))                                                AS oil_sm3,
    ROUND(SUM(water_sm3))                                              AS water_sm3,
    ROUND(SUM(water_injected_sm3))                                     AS water_injected_sm3,
    ROUND(SUM(water_sm3) / NULLIF(SUM(oil_sm3) + SUM(water_sm3), 0), 3) AS water_cut,
    ROUND(AVG(efficiency) FILTER (WHERE role = 'producer'), 3)        AS producer_efficiency
FROM daily
GROUP BY ALL
ORDER BY year;

-- name: downtime_loss
-- Estimated oil lost to downtime, per producer and year.
-- Reference rate = median oil rate (Sm3 per on-stream hour) of the well's full days
-- (>= 23 h on stream) in the same month, carried forward when a month has no full day.
-- Lost oil = hours not on stream × reference rate, inside the well's producing life only.
WITH life AS (
    SELECT well, MIN(date) AS first_oil, MAX(date) AS last_oil
    FROM daily
    WHERE role = 'producer' AND oil_sm3 > 0
    GROUP BY well
),
in_life AS (
    SELECT d.*
    FROM daily d
    JOIN life l USING (well)
    WHERE d.role = 'producer' AND d.date BETWEEN l.first_oil AND l.last_oil
),
monthly_ref AS (
    SELECT
        well,
        DATE_TRUNC('month', date) AS month,
        MEDIAN(oil_rate_sm3_per_hr) FILTER (WHERE on_stream_hrs >= 23) AS ref_rate
    FROM in_life
    GROUP BY ALL
),
filled_ref AS (
    SELECT
        well,
        month,
        LAST_VALUE(ref_rate IGNORE NULLS) OVER (
            PARTITION BY well ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS ref_rate
    FROM monthly_ref
),
daily_loss AS (
    SELECT
        i.well,
        YEAR(i.date)                                       AS year,
        i.day_hours - i.on_stream_hrs                      AS lost_hrs,
        (i.day_hours - i.on_stream_hrs) * f.ref_rate       AS lost_oil_sm3,
        i.on_stream_hrs = 0                                AS full_day_stop,
        i.oil_sm3
    FROM in_life i
    JOIN filled_ref f ON f.well = i.well AND f.month = DATE_TRUNC('month', i.date)
)
SELECT
    well,
    year,
    ROUND(SUM(oil_sm3))                                        AS produced_oil_sm3,
    ROUND(SUM(lost_oil_sm3))                                   AS lost_oil_sm3,
    ROUND(SUM(lost_oil_sm3) FILTER (WHERE full_day_stop))      AS lost_full_day_stops_sm3,
    ROUND(SUM(lost_oil_sm3) FILTER (WHERE NOT full_day_stop))  AS lost_partial_days_sm3,
    COUNT(*) FILTER (WHERE full_day_stop)                      AS full_stop_days,
    ROUND(SUM(lost_hrs))                                       AS lost_hours
FROM daily_loss
GROUP BY ALL
ORDER BY well, year;
