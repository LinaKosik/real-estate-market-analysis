-- Проект первого модуля (знакомствои и исследование данных)
-- Автор:  Косарева Алина 
-- Дата: 11.04.2025


-- min\max first day
SELECT min(first_day_exposition) AS min_d,
max(first_day_exposition) AS max_id
FROM real_estate.advertisement;

-- type and adv
SELECT t.TYPE, count(DISTINCT id) AS adv  
FROM real_estate.advertisement
JOIN real_estate.flats f USING (id)
JOIN real_estate."type" t USING (type_id)
GROUP BY t.type 
ORDER BY adv DESC 

-- STATISTICS 
SELECT min(days_exposition) AS min,
max(days_exposition) AS max,
round(avg(days_exposition::NUMERIC), 2) AS sred,
PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY days_exposition)AS mediana
FROM real_estate.advertisement


-- % of all sold
SELECT 
    ROUND(
        COUNT(CASE WHEN days_exposition IS NOT NULL THEN 1 END) * 100.0 
        / COUNT(*), 
        2
    ) AS percent_sold
FROM real_estate.advertisement;

-- ratio Spb and ALL 
SELECT 
    ROUND(
        COUNT(CASE WHEN c.city = 'Санкт-Петербург' THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS spb_share
FROM real_estate.flats f
JOIN real_estate.city c ON f.city_id = c.city_id;

--sqr meter
WITH one_sqrm AS (
SELECT 
	round(last_price::NUMERIC / f.total_area::NUMERIC, 2) AS price_per_one_sqrm
FROM real_estate.advertisement a 
JOIN real_estate.flats f USING (id)
)
SELECT min(price_per_one_sqrm) AS min_pr,
max(price_per_one_sqrm) AS max_pr,
round(avg(price_per_one_sqrm), 2) AS avg_pr,
percentile_disc(0.5) WITHIN GROUP(ORDER BY price_per_one_sqrm) AS mediana
FROM one_sqrm

--stat_other
SELECT 
-- total_area
min(f.total_area) AS min_area,
max(f.total_area) AS max_area,
round(avg(f.total_area::NUMERIC), 2) AS avg_area,
percentile_disc(0.5) WITHIN GROUP(ORDER BY f.total_area) AS mediana_area,
percentile_disc(0.99) WITHIN GROUP(ORDER BY f.total_area) AS perc99_area,

-- rooms
min(f.rooms) AS min_rooms,
max(f.rooms) AS max_rooms,
round(avg(f.rooms), 2) AS avg_rooms,
percentile_disc(0.5) WITHIN GROUP(ORDER BY f.rooms) AS mediana_rooms,
percentile_disc(0.99) WITHIN GROUP(ORDER BY f.rooms) AS perc99_rooms,

-- balcony
min(f.balcony) AS min_balcony,
max(f.balcony) AS max_balcony,
round(avg(f.balcony::NUMERIC), 2) AS avg_balcony,
percentile_disc(0.5) WITHIN GROUP(ORDER BY f.balcony) AS mediana_balcony,
percentile_disc(0.99) WITHIN GROUP(ORDER BY f.balcony) AS perc99_balcony,

-- ceiling_height
min(f.ceiling_height) AS min_ceiling_height,
max(f.ceiling_height) AS max_ceiling_height,
round(avg(f.ceiling_height::NUMERIC), 2) AS avg_ceiling_height,
percentile_disc(0.5) WITHIN GROUP(ORDER BY f.ceiling_height) AS mediana_ceiling_height,
percentile_disc(0.99) WITHIN GROUP(ORDER BY f.ceiling_height) AS perc99_ceiling_height,

-- floor
min(f.floor) AS min_floor,
max(f.floor) AS max_floor,
round(avg(f.floor), 2) AS avg_floor,
percentile_disc(0.5) WITHIN GROUP(ORDER BY f.floor) AS mediana_floor,
percentile_disc(0.99) WITHIN GROUP(ORDER BY f.floor) AS perc99_floor
	FROM real_estate.advertisement a 
	JOIN real_estate.flats f USING (id)
