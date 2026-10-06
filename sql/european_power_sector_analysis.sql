/* ============================================================
   EUROPEAN POWER SECTOR BI
   SQL Analysis & Validation Queries

   Database: european_power_sector_bi
   Period: 2015-2024
   ============================================================ */

USE european_power_sector_bi;
GO


/* ============================================================
   1. TOTAL GENERATION BY YEAR
   ============================================================ */

SELECT
    y.year,
    SUM(f.generation_twh) AS total_generation_twh
FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
WHERE s.electricity_source = 'Total generation'
GROUP BY y.year
ORDER BY y.year;

/* ============================================================
   2. RENEWABLE GENERATION BY YEAR
   ============================================================ */

SELECT
    y.year,
    SUM(f.generation_twh) AS renewable_generation_twh
FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
WHERE s.electricity_source = 'Renewables'
GROUP BY y.year
ORDER BY y.year;

/* ============================================================
   3. POWER SECTOR EMISSIONS BY YEAR
   ============================================================ */

SELECT
    y.year,
    SUM(f.emissions_mtco2e) AS power_sector_emissions_mtco2e
FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
WHERE s.electricity_source = 'Total generation'
GROUP BY y.year
ORDER BY y.year;

/* ============================================================
   4. POWER SECTOR EMISSIONS INTENSITY BY YEAR
   ============================================================ */

SELECT
    y.year,
    SUM(f.emissions_mtco2e) * 1000.0
        / NULLIF(SUM(f.generation_twh), 0)
        AS emissions_intensity_gco2e_kwh
FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
WHERE s.electricity_source = 'Total generation'
GROUP BY y.year
ORDER BY y.year;


/* ============================================================
   5. KEY GENERATION SOURCES — 2015 VS 2024
   ============================================================ */

SELECT
    y.year,
    s.electricity_source,
    SUM(f.generation_twh) AS generation_twh,
    SUM(f.emissions_mtco2e) AS emissions_mtco2e
FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
WHERE y.year IN (2015, 2024)
  AND s.electricity_source IN (
      'Total generation',
      'Renewables',
      'Fossil',
      'Wind',
      'Solar'
  )
GROUP BY
    y.year,
    s.electricity_source
ORDER BY
    y.year,
    s.electricity_source;


/* ============================================================
   6. RENEWABLE AND FOSSIL SHARE BY YEAR
   Shares are calculated from generation totals rather than
   averaging country-level percentages.
   ============================================================ */

SELECT
    y.year,

    SUM(CASE
        WHEN s.electricity_source = 'Renewables'
        THEN f.generation_twh ELSE 0
    END) * 100.0
    / NULLIF(
        SUM(CASE
            WHEN s.electricity_source = 'Total generation'
            THEN f.generation_twh ELSE 0
        END), 0
    ) AS renewable_share_pct,

    SUM(CASE
        WHEN s.electricity_source = 'Fossil'
        THEN f.generation_twh ELSE 0
    END) * 100.0
    / NULLIF(
        SUM(CASE
            WHEN s.electricity_source = 'Total generation'
            THEN f.generation_twh ELSE 0
        END), 0
    ) AS fossil_share_pct

FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
WHERE s.electricity_source IN (
    'Total generation',
    'Renewables',
    'Fossil'
)
GROUP BY y.year
ORDER BY y.year;


/* ============================================================
   7. THERMAL CATEGORY VALIDATION
   In this dataset:
   Thermal = Fossil + Bioenergy
   Nuclear is excluded from Thermal.
   ============================================================ */

SELECT
    y.year,

    SUM(CASE
        WHEN s.electricity_source = 'Thermal'
        THEN f.generation_twh ELSE 0
    END) AS thermal_twh,

    SUM(CASE
        WHEN s.electricity_source = 'Fossil'
        THEN f.generation_twh ELSE 0
    END) AS fossil_twh,

    SUM(CASE
        WHEN s.electricity_source = 'Bioenergy'
        THEN f.generation_twh ELSE 0
    END) AS bioenergy_twh,

    SUM(CASE
        WHEN s.electricity_source = 'Nuclear'
        THEN f.generation_twh ELSE 0
    END) AS nuclear_twh,

    SUM(CASE
        WHEN s.electricity_source IN ('Fossil', 'Bioenergy')
        THEN f.generation_twh ELSE 0
    END) AS fossil_plus_bioenergy_twh

FROM analytics.fact_electricity AS f
JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key
GROUP BY y.year
ORDER BY y.year;


/* ============================================================
   8. DATA QUALITY — FACT TABLE ROW COUNT
   ============================================================ */

SELECT
    COUNT(*) AS fact_row_count
FROM analytics.fact_electricity;


/* ============================================================
   9. DATA QUALITY — DUPLICATE GRAIN CHECK
   Expected result: 0 rows
   ============================================================ */

SELECT
    area_key,
    year_key,
    electricity_source_key,
    COUNT(*) AS row_count
FROM analytics.fact_electricity
GROUP BY
    area_key,
    year_key,
    electricity_source_key
HAVING COUNT(*) > 1;


/* ============================================================
   10. DATA QUALITY — ORPHAN KEY CHECKS
   Expected result: all counts = 0
   ============================================================ */

SELECT
    SUM(CASE WHEN a.area_key IS NULL THEN 1 ELSE 0 END)
        AS orphan_area_keys,
    SUM(CASE WHEN y.year_key IS NULL THEN 1 ELSE 0 END)
        AS orphan_year_keys,
    SUM(CASE WHEN s.electricity_source_key IS NULL THEN 1 ELSE 0 END)
        AS orphan_source_keys
FROM analytics.fact_electricity AS f
LEFT JOIN analytics.dim_area AS a
    ON f.area_key = a.area_key
LEFT JOIN analytics.dim_year AS y
    ON f.year_key = y.year_key
LEFT JOIN analytics.dim_electricity_source AS s
    ON f.electricity_source_key = s.electricity_source_key;