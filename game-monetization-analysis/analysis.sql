/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(DISTINCT id) AS total_users,
COUNT(DISTINCT CASE WHEN payer = 1 THEN id END) AS paying_users,
AVG(payer::numeric) AS payers_share
FROM users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race AS race,
COUNT(CASE WHEN u.payer = 1 THEN 1 END) AS paying_users,    
COUNT(*) AS total_users,
AVG(u.payer::numeric) AS payers_share   
FROM users u 
JOIN race r ON u.race_id = r.race_id
GROUP BY r.race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS total_purchases,  
SUM(amount) AS total_amount,
MIN(amount) AS min_amount,
MAX(amount) AS max_amount,
AVG(amount) AS avg_amount,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
STDDEV_SAMP(amount) AS stddev_amount
FROM events;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(*) FILTER (WHERE amount = 0) AS zero_purchases,
(COUNT(*) FILTER (WHERE amount = 0))::numeric / COUNT(*) AS zero_share
FROM events;

-- 2.3: Популярные эпические предметы:
SELECT i.game_items,
COUNT(*) AS sales_cnt,
COUNT(*)::float / SUM(COUNT(*)) OVER () AS sales_share,
COUNT(DISTINCT e.id) AS buyers_cnt,
COUNT(DISTINCT e.id)::float / (SELECT COUNT(DISTINCT id)
FROM events WHERE amount > 0) AS buyers_share
FROM events e
JOIN items  i ON i.item_code = e.item_code
WHERE e.amount > 0
GROUP BY i.item_code, i.game_items
ORDER BY buyers_share DESC, sales_cnt DESC, i.game_items;

-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH reg AS (SELECT u.race_id, r.race,
COUNT(DISTINCT u.id) AS registered_users
FROM users u
JOIN race  r ON r.race_id = u.race_id
GROUP BY u.race_id, r.race),
purchases AS (SELECT u.race_id, u.payer,  e.id AS user_id, e.amount
FROM events e
JOIN items  i ON i.item_code = e.item_code
JOIN users  u ON u.id = e.id
WHERE e.amount > 0),
buyers AS (SELECT race_id,
COUNT(DISTINCT user_id) AS purchasing_users,
COUNT(DISTINCT CASE WHEN payer = 1 THEN user_id END) AS payers_among_purch
FROM purchases
GROUP BY race_id),
activity AS (SELECT race_id,
COUNT(*) AS total_purchases,
SUM(amount) AS total_amount,  
AVG(amount) AS avg_purchase_amount
FROM purchases
GROUP BY race_id)
SELECT reg.race,  -- название расы
reg.registered_users,  -- сколько зарег-но игроков этой расы
b.purchasing_users, -- сколько игроков покупали
b.purchasing_users::float / NULLIF(reg.registered_users, 0)  AS purchasing_share,  -- их доля среди зарег-ых
b.payers_among_purch::float / NULLIF(b.purchasing_users, 0)    AS payers_share_among_purch, -- доля платящих среди тех, кто покупал
a.total_purchases::float / NULLIF(b.purchasing_users, 0)    AS avg_purchases_per_purch_user, -- ср. число покупок на одного покупателя
a.avg_purchase_amount,  -- ср. стоимость одной покупки (по amount)
a.total_amount::float / NULLIF(b.purchasing_users, 0)    AS avg_total_spend_per_purch_user  -- ср. сумм. трата на одного покупателя
FROM reg
LEFT JOIN buyers   b ON b.race_id = reg.race_id
LEFT JOIN activity a ON a.race_id = reg.race_id
ORDER BY reg.race;
