/* Real Estate Agency Data Analysis

-- Task 1: Listing Activity Duration
-- Identify anomalous values (outliers) using percentile thresholds:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Find listing IDs without outliers while keeping missing values:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Use listing IDs from the filtered_id CTE that do not contain outliers for further analysis
-- Saint Petersburg and city type
spb AS (
  SELECT city_id AS spb_id
  FROM real_estate.city
  WHERE city = 'Saint Petersburg'
  LIMIT 1
),
city_type AS (
  SELECT type_id AS city_type_id
  FROM real_estate.type
  WHERE type = 'город'
  LIMIT 1
),
-- 2) Base dataset: period 2015–2018 + price per square meter
base AS (
  SELECT f.id, f.city_id, f.type_id, f.total_area, f.rooms, f.balcony, f.floor, f.floors_total, f.ceiling_height, a.first_day_exposition, a.days_exposition, a.last_price,
    (a.last_price::numeric / NULLIF(f.total_area,0)::numeric) AS price_per_m2
  FROM real_estate.flats f
  JOIN real_estate.advertisement a ON a.id = f.id
  WHERE f.id IN (SELECT id FROM filtered_id)
    AND a.first_day_exposition >= DATE '2015-01-01'
    AND a.first_day_exposition <  DATE '2019-01-01'
),
-- Region + activity segment (Saint Petersburg and cities of the Leningrad region only)
cat AS (
  SELECT
    CASE
      WHEN b.city_id = (SELECT spb_id FROM spb) THEN 'Saint Petersburg'
      WHEN b.city_id <> (SELECT spb_id FROM spb)
           AND b.type_id = (SELECT city_type_id FROM city_type) THEN 'Leningrad Region'
      ELSE 'Exclude'
    END AS region,
    CASE
      WHEN b.days_exposition BETWEEN 1  AND 30  THEN 'up to one month'
      WHEN b.days_exposition BETWEEN 31 AND 90  THEN 'up to three months'
      WHEN b.days_exposition BETWEEN 91 AND 180 THEN 'up to six months'
      WHEN b.days_exposition > 180             THEN 'more than six months'
      ELSE 'non category'
    END AS segment,
    b.price_per_m2,
    b.total_area,
    b.rooms,
    b.balcony,
    b.floors_total
  FROM base b
)
-- final summary table
SELECT
  region,
  segment,
  AVG(price_per_m2)  AS avg_price_per_m2,
  AVG(total_area)    AS avg_total_area,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rooms)        AS median_rooms,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY balcony)      AS median_balcony,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY floors_total) AS median_floors_total,
  COUNT(*)              AS ads_count,
  COUNT(*)::float / SUM(COUNT(*)) OVER (PARTITION BY region) AS share_in_region
FROM cat
WHERE region IN ('Saint Petersburg','Leningrad Region')
GROUP BY region, segment
ORDER BY region, segment;


-- Task 2: Listing Seasonality
-- Identify anomalous values (outliers) using percentile thresholds:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Find listing IDs without outliers while keeping missing values:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Use listing IDs from the filtered_id CTE that do not contain outliers for further analysis
-- Base dataset: cities only (type_id = F8EM), period 2015–2018, price per square meter
base AS (
  SELECT
    f.id,
    f.total_area,
    a.last_price,
    a.first_day_exposition,
    a.days_exposition,
    (a.last_price::numeric / NULLIF(f.total_area,0)::numeric) AS price_per_m2
  FROM real_estate.flats f
  JOIN real_estate.advertisement a ON a.id = f.id
  WHERE f.id IN (SELECT id FROM filtered_id)
    AND a.first_day_exposition >= DATE '2015-01-01'
    AND a.first_day_exposition <  DATE '2019-01-01'
    AND type_id ='F8EM'
),
months AS (
  SELECT
    id,
    EXTRACT(MONTH FROM first_day_exposition)::int AS pub_month,  -- только номер месяца публикации
    CASE
      WHEN days_exposition IS NOT NULL THEN
        CASE
          WHEN (first_day_exposition + (days_exposition::int) * INTERVAL '1 day') < DATE '2019-01-01'
          THEN EXTRACT(MONTH FROM (first_day_exposition + (days_exposition::int) * INTERVAL '1 day'))::int
        END
    END AS sold_month,                                            -- только номер месяца снятия
    price_per_m2,
    total_area
  FROM base
),
-- Calculate statistics by publication month (без учёта года)
pub_stats AS (
  SELECT
    pub_month AS month,
    COUNT(*) AS ads_count_pub,
    AVG(price_per_m2) AS avg_price_per_m2_pub,
    AVG(total_area) AS avg_total_area_pub
  FROM months
  GROUP BY pub_month
),
-- Calculate statistics by removal month (без учёта года)
sold_stats AS (
  SELECT
    sold_month AS month,
    COUNT(*) AS ads_count_sold,
    AVG(price_per_m2) AS avg_price_per_m2_sold,
    AVG(total_area) AS avg_total_area_sold
  FROM months
  WHERE sold_month IS NOT NULL
  GROUP BY sold_month
)
-- Combine publications and removals into a single monthly table
SELECT
  COALESCE(p.month, s.month) AS month,
  p.ads_count_pub,
  p.avg_price_per_m2_pub,
  p.avg_total_area_pub,
  s.ads_count_sold,
  s.avg_price_per_m2_sold,
  s.avg_total_area_sold
FROM pub_stats p
FULL JOIN sold_stats s ON p.month = s.month
ORDER BY month;
