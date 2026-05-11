/* Анализ данных для агентства недвижимости

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
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
-- Используем id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
-- СПб и тип "город"
spb AS (
  SELECT city_id AS spb_id
  FROM real_estate.city
  WHERE city = 'Санкт-Петербург'
  LIMIT 1
),
city_type AS (
  SELECT type_id AS city_type_id
  FROM real_estate.type
  WHERE type = 'город'
  LIMIT 1
),
-- 2) База: период 2015–2018 + цена за м²
base AS (
  SELECT f.id, f.city_id, f.type_id, f.total_area, f.rooms, f.balcony, f.floor, f.floors_total, f.ceiling_height, a.first_day_exposition, a.days_exposition, a.last_price,
    (a.last_price::numeric / NULLIF(f.total_area,0)::numeric) AS price_per_m2
  FROM real_estate.flats f
  JOIN real_estate.advertisement a ON a.id = f.id
  WHERE f.id IN (SELECT id FROM filtered_id)
    AND a.first_day_exposition >= DATE '2015-01-01'
    AND a.first_day_exposition <  DATE '2019-01-01'
),
-- регион + сегмент активности (только СПб и города ЛенОбл)
cat AS (
  SELECT
    CASE
      WHEN b.city_id = (SELECT spb_id FROM spb) THEN 'Санкт-Петербург'
      WHEN b.city_id <> (SELECT spb_id FROM spb)
           AND b.type_id = (SELECT city_type_id FROM city_type) THEN 'ЛенОбл'
      ELSE 'Исключить'
    END AS region,
    CASE
      WHEN b.days_exposition BETWEEN 1  AND 30  THEN 'до месяца'
      WHEN b.days_exposition BETWEEN 31 AND 90  THEN 'до трех месяцев'
      WHEN b.days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
      WHEN b.days_exposition > 180             THEN 'более полугода'
      ELSE 'non category'
    END AS segment,
    b.price_per_m2,
    b.total_area,
    b.rooms,
    b.balcony,
    b.floors_total
  FROM base b
)
-- финальная сводная таблица
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
WHERE region IN ('Санкт-Петербург','ЛенОбл')
GROUP BY region, segment
ORDER BY region, segment;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
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
-- Используем id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
-- База: только города (type_id = 'F8EM'), период 2015–2018, цена за м²
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
-- Считаем статистику по месяцам публикации (без учёта года)
pub_stats AS (
  SELECT
    pub_month AS month,
    COUNT(*) AS ads_count_pub,
    AVG(price_per_m2) AS avg_price_per_m2_pub,
    AVG(total_area) AS avg_total_area_pub
  FROM months
  GROUP BY pub_month
),
-- Считаем статистику по месяцам снятия (без учёта года)
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
-- Объединяем публикации и снятия в единую таблицу по месяцу
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
