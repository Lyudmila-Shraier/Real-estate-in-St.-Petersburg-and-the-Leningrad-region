/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Шрайер Людмила
 * Дата: 27.09
*/



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
    category_reg_days AS (
SELECT fi.id,
       CASE
        WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
        ELSE 'ЛенОбл'
    END AS city_region,
    CASE 
    	WHEN a.days_exposition <= 30 THEN 'До месяца'
    	WHEN a.days_exposition >= 31 AND a.days_exposition <= 90 THEN 'До трех месяцев'
    	WHEN a.days_exposition >= 91 AND a.days_exposition <= 180 THEN 'До полугода'
    	WHEN a.days_exposition >= 181 THEN 'Более полугода'
    	ELSE 'non category' -- в задании написали объединить, если объявления ещё на продаже, а в таблице её нет
    	END AS activ_days,
    	a.last_price/f.total_area AS price_kv_m,
    	f.total_area,
    	f.rooms,
    	f.balcony,
        f.floors_total,
        f.ceiling_height
    	FROM real_estate.advertisement AS a 
    	JOIN filtered_id AS fi USING(id)
    	LEFT JOIN real_estate.flats AS f USING(id)
    	LEFT JOIN real_estate.city AS c USING(city_id)
    	WHERE EXTRACT(YEAR FROM a.first_day_exposition) =  2015 OR EXTRACT(YEAR FROM a.first_day_exposition) = 2016 
    	OR EXTRACT(YEAR FROM a.first_day_exposition) = 2017 OR EXTRACT(YEAR FROM a.first_day_exposition) = 2018
    	)
    	SELECT crd.city_region,
    	crd.activ_days,
    	COUNT(crd.id) AS count_advertisement,
    	ROUND(COUNT(crd.id)/ SUM(COUNT(crd.id)) OVER (PARTITION BY crd.city_region)::numeric, 2) AS dola_advertisement,
    	ROUND(AVG(crd.price_kv_m)::numeric, 2) AS avg_price_kv_m,
    	ROUND(AVG(crd.total_area)::NUMERIC, 2) AS avg_total_area,
    	ROUND(AVG(crd.ceiling_height)::numeric, 2) AS avg_ceiling_height,
    	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY crd.rooms)AS medi_rooms,
        PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY crd.balcony) AS medi_balcony,
    	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY crd.floors_total) AS medi_floors
    	FROM category_reg_days AS crd
    	GROUP BY crd.city_region, crd.activ_days
    	ORDER BY crd.city_region DESC, COUNT(crd.id) DESC;



-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS ( -- дата публикации
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
    month_advertisement AS (
    SELECT fi.id, 
    EXTRACT(MONTH FROM a.first_day_exposition) AS date_exposition,
    EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::integer) AS date_withdrawal,
    a.last_price
    FROM filtered_id AS fi 
    LEFT JOIN real_estate.advertisement AS a USING(id)
    WHERE EXTRACT(YEAR FROM a.first_day_exposition) =  2015 OR EXTRACT(YEAR FROM a.first_day_exposition) = 2016 
    	OR EXTRACT(YEAR FROM a.first_day_exposition) = 2017 OR EXTRACT(YEAR FROM a.first_day_exposition) = 2018
    	)
    SELECT ma.date_exposition,
    COUNT(ma.id),
    ROUND(AVG(ma.last_price/f.total_area)::NUMERIC, 2) AS avg_price_kv_m,
    ROUND(AVG(f.total_area)::NUMERIC, 2) AS avg_total_area
    FROM month_advertisement AS ma
    LEFT JOIN real_estate.flats AS f USING(id)
    GROUP BY ma.date_exposition
    ORDER BY COUNT(ma.id) DESC;

WITH limits AS ( -- снятые объявления
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
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
    month_advertisement AS (
    SELECT fi.id, 
    EXTRACT(MONTH FROM a.first_day_exposition) AS date_exposition,
    EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::integer) AS date_withdrawal,
    a.last_price
    FROM filtered_id AS fi 
    LEFT JOIN real_estate.advertisement AS a USING(id)
    WHERE EXTRACT(YEAR FROM a.first_day_exposition) =  2015 OR EXTRACT(YEAR FROM a.first_day_exposition) = 2016 
    	OR EXTRACT(YEAR FROM a.first_day_exposition) = 2017 OR EXTRACT(YEAR FROM a.first_day_exposition) = 2018
    	)
    SELECT 
    ma.date_withdrawal,
    COUNT(ma.id),
    ROUND(AVG(ma.last_price/f.total_area)::NUMERIC, 2) AS avg_price_kv_m,
    ROUND(AVG(f.total_area)::NUMERIC, 2) AS avg_total_area
    FROM month_advertisement AS ma
    LEFT JOIN real_estate.flats AS f USING(id)
    GROUP BY ma.date_withdrawal
    ORDER BY COUNT(ma.id) DESC;
    
    
    
-- Продолжите запрос здесь month_advertisement AS (
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
