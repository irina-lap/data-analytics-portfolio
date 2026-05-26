/* Project "Darkwood Secrets"
 * Project goal: analyze how player and character attributes influence
 * purchases of the in-game currency "Heavenly Petals" and evaluate
 * player activity related to in-game purchases
*/

-- Part 1. Exploratory Data Analysis
-- Task 1. Analysis of Paying Players Share

-- 1.1. Share of paying users across all data:
SELECT COUNT(DISTINCT id) AS total_users,
COUNT(DISTINCT CASE WHEN payer = 1 THEN id END) AS paying_users,
AVG(payer::numeric) AS payers_share
FROM users;

-- 1.2. Share of paying users by character race:
SELECT r.race AS race,
COUNT(CASE WHEN u.payer = 1 THEN 1 END) AS paying_users,    
COUNT(*) AS total_users,
AVG(u.payer::numeric) AS payers_share   
FROM users u 
JOIN race r ON u.race_id = r.race_id
GROUP BY r.race;

-- Task 2. Analysis of In-Game Purchases
-- 2.1. Statistical metrics for the amount field:
SELECT COUNT(*) AS total_purchases,  
SUM(amount) AS total_amount,
MIN(amount) AS min_amount,
MAX(amount) AS max_amount,
AVG(amount) AS avg_amount,
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
STDDEV_SAMP(amount) AS stddev_amount
FROM events;

-- 2.2. Anomalous zero-value purchases:
SELECT COUNT(*) FILTER (WHERE amount = 0) AS zero_purchases,
(COUNT(*) FILTER (WHERE amount = 0))::numeric / COUNT(*) AS zero_share
FROM events;

-- 2.3. Popular epic items:
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

-- Part 2. Ad Hoc Analysis
-- Task: Player activity dependence on character race:
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
SELECT reg.race,  -- race name
reg.registered_users,  -- number of registered players of this race
b.purchasing_users, -- number of purchasing players
b.purchasing_users::float / NULLIF(reg.registered_users, 0)  AS purchasing_share,  -- share among registered players
b.payers_among_purch::float / NULLIF(b.purchasing_users, 0)    AS payers_share_among_purch, -- share of paying users among purchasers
a.total_purchases::float / NULLIF(b.purchasing_users, 0)    AS avg_purchases_per_purch_user, -- average number of purchases per buyer
a.avg_purchase_amount,  -- average purchase amount
a.total_amount::float / NULLIF(b.purchasing_users, 0)    AS avg_total_spend_per_purch_user  -- average total spending per buyer
FROM reg
LEFT JOIN buyers   b ON b.race_id = reg.race_id
LEFT JOIN activity a ON a.race_id = reg.race_id
ORDER BY reg.race;
