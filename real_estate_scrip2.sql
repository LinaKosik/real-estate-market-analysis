-- Проект первого модуля: анализ данных для агентства недвижимости
-- Автор:  Косарева Алина 
-- Дата: 11.04.2025 

-- Задача 1. Время активности объявлений

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
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
-- Классифицируем:
classified AS (   
    SELECT a.id,
    c.city,
    f.total_area,
    f.rooms,
    f.balcony,
    f.floor,
    ROUND(a.last_price / f.total_area) AS price_per_sq,
    CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область'
        END AS region,
        CASE 
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'Месяц'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'Квартал'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'Полгода'
            ELSE 'Более полугода'
        END AS duration_category, 
        CASE WHEN f.rooms = 1 THEN 1 ELSE 0 END AS is_studio_apart,
    	CASE WHEN f.parks_around3000 IS NOT NULL THEN 1 ELSE 0 END AS is_with_parks
	    FROM real_estate.advertisement a
	    JOIN real_estate.flats f ON a.id = f.id
	    JOIN real_estate.city c ON f.city_id = c.city_id
	    JOIN real_estate.type t ON f.type_id = t.type_id
	 WHERE a.id IN (SELECT * FROM filtered_id)
	  AND a.days_exposition IS NOT NULL
      AND f.total_area IS NOT NULL
      AND a.last_price IS NOT NULL
      AND f.rooms IS NOT NULL 
      AND f.balcony IS NOT NULL 
      AND t.type = 'город'
 ),
 aggregated AS (
  	SELECT 
        region,
        duration_category,
        COUNT(*) AS total_ads,
        ROUND(avg (price_per_sq::NUMERIC),1) AS avg_price_m2,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_sq)) AS median_price_m2,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)) AS median_area,
        ROUND(avg(total_area::NUMERIC), 1) AS avg_area,
        ROUND(AVG(rooms::NUMERIC), 1) AS avg_rooms,
        ROUND(AVG(balcony::NUMERIC), 1) AS avg_balcony,
		round(avg(floor::NUMERIC), 1) AS avg_floor,
		ROUND(SUM(is_studio_apart) * 1.0 / COUNT(*), 2) AS studio_share,
		ROUND(SUM(is_with_parks) * 1.0 / COUNT(*), 2) AS parks_share
    FROM classified
    GROUP BY region, duration_category
 ) 
SELECT *
FROM aggregated 
ORDER BY region, 
    CASE duration_category
        WHEN 'Месяц' THEN 1
        WHEN 'Квартал' THEN 2
        WHEN 'Полгода' THEN 3
        WHEN 'Более полугода' THEN 4
    END;
    
   
-- Задача 2. Сезонность объявлений   
    
-- Вычисление месяца публикации и месяца снятия объявления
WITH limits AS (
    SELECT 
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY last_price) AS min_price,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY last_price) AS max_price,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY f.total_area) AS min_area,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY f.total_area) AS max_area
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING (id)
),
filtered AS (
    SELECT a.id
    FROM real_estate.advertisement a
    JOIN real_estate.flats f USING (id)
    JOIN real_estate.city c USING (city_id)
    JOIN real_estate."type" t USING (type_id)
    CROSS JOIN limits l
    WHERE 
        t.type = 'город'
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
        AND a.last_price BETWEEN l.min_price AND l.max_price
        AND f.total_area BETWEEN l.min_area AND l.max_area
),
months AS (
SELECT 
 	CASE -- Месяц публикации
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 1 THEN 'Январь'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 2 THEN 'Февраль'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 3 THEN 'Март'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 4 THEN 'Апрель'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 5 THEN 'Май'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 6 THEN 'Июнь'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 7 THEN 'Июль'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 8 THEN 'Август'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 9 THEN 'Сентябрь'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 10 THEN 'Октябрь'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 11 THEN 'Ноябрь'
            WHEN EXTRACT(MONTH FROM a.first_day_exposition) = 12 THEN 'Декабрь'
        END AS publication_month,
  CASE -- Месяц снятия
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 1 THEN 'Январь'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 2 THEN 'Февраль'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 3 THEN 'Март'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 4 THEN 'Апрель'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 5 THEN 'Май'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 6 THEN 'Июнь'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 7 THEN 'Июль'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 8 THEN 'Август'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 9 THEN 'Сентябрь'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 10 THEN 'Октябрь'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 11 THEN 'Ноябрь'
    WHEN EXTRACT(MONTH FROM a.first_day_exposition + INTERVAL '1 day' * a.days_exposition) = 12 THEN 'Декабрь'
END AS removal_month,
	ROUND(a.last_price::NUMERIC / f.total_area::NUMERIC,0) AS price_per_sq,
	f.total_area 
    FROM real_estate.advertisement a 
    JOIN real_estate.flats f USING (id)  
),
-- Анализ активности публикаций 
pub_activity AS (
    SELECT
    	publication_month,
        COUNT(*) AS publication_count,
        round(avg(price_per_sq), 1) AS avg_price,
        round(avg(total_area::NUMERIC), 1) AS avg_area
        FROM months
    	GROUP BY publication_month
),
-- Кол-во снятых объявлений 
removes AS (
	SELECT
        removal_month,
        COUNT(*) AS removal_count,
        ROUND(AVG(price_per_sq), 1) AS avg_price_rem,
        ROUND(AVG(total_area::NUMERIC), 1) AS avg_area_rem
        FROM months
    	GROUP BY removal_month
),
totals AS (
	SELECT 
	(SELECT SUM(publication_count) FROM pub_activity) AS total_pub,
    (SELECT SUM(removal_count) FROM removes) AS total_rem
)
-- Объединение данных по активности публикации и снятия объявлений
SELECT 
RANK() OVER (ORDER BY p.publication_count DESC) AS pub_rank,
publication_month,
publication_count,
ROUND(publication_count * 100 / total_pub, 1) AS pub_share,
avg_price,
avg_area,
RANK() OVER (ORDER BY r.removal_count DESC) AS rem_rank,
removal_month,
removal_count,
ROUND(removal_count * 100 / total_rem, 1) AS pub_share,
avg_price_rem,
avg_area_rem
FROM pub_activity p
JOIN removes r ON p.publication_month = r.removal_month
CROSS JOIN totals
ORDER BY p.publication_month;


-- Задача 3. Анализ рынка недвижимости Ленобласти
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY floor) AS floor_limit
    FROM real_estate.flats  
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT f.id
    FROM real_estate.flats f
    WHERE 
    	f.total_area < (SELECT total_area_limit FROM limits)
        AND (f.rooms < (SELECT rooms_limit FROM limits) OR f.rooms IS NULL)
      	AND (f.balcony < (SELECT balcony_limit FROM limits) OR f.balcony IS NULL)
      	AND f.city_id <> '6X8I' 
), 
months AS (
	SELECT c.city, 
			a.first_day_exposition, 
			a.days_exposition,
    		EXTRACT (MONTH from a.first_day_exposition) AS month_pub,
            EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::int) AS month_rem,    		
        	f.id,
    		round(a.last_price/f.total_area) AS price_per_sq,
    		f.total_area,
    		f.rooms,
    		f.balcony,
    		f.floor 
FROM filtered_id
LEFT JOIN real_estate.flats f USING(id)
LEFT JOIN real_estate.advertisement a USING(id)
LEFT JOIN real_estate.city c USING(city_id)
),
aggregated AS (
	SELECT 
	city,
	count(month_pub) AS count_pub,
	count(month_rem) AS count_rem,
 	(COUNT(month_rem)/COUNT(month_pub)::float)::NUMERIC(10,2) AS share_removal,
 	ROUND(AVG(days_exposition::NUMERIC), 0) AS avg_days_exposition,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_area)) AS median_area,
	ROUND(avg(price_per_sq::NUMERIC),1) AS avg_price_m2,
    ROUND(AVG(rooms), 1) AS avg_rooms,
    ROUND(AVG(balcony::NUMERIC), 1) AS avg_balcony,
    round(avg(floor::NUMERIC), 1) AS avg_floor
FROM months
GROUP BY city
HAVING COUNT(month_rem) > 50
), 
ranked AS (
    SELECT *,
    NTILE(4) OVER (ORDER BY count_pub DESC) AS activity_quartile
    FROM aggregated
)
SELECT *
FROM ranked
ORDER BY count_pub DESC
LIMIT 15;
