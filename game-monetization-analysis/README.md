# Game Monetization Analysis

## Project Overview

This project focuses on analyzing player behavior and in-game purchases in a fantasy game.

The main goal was to study how player and character attributes influence purchases of in-game currency and epic items, as well as evaluate differences in player purchasing activity.

## Objectives

- Analyze the share of paying players
- Study in-game purchases and their cost
- Identify the most popular epic items
- Explore differences in purchasing activity between character races
- Provide recommendations for the marketing team

## Analysis Workflow

1. Exploratory data analysis
2. In-game purchase analysis
3. Player segmentation
4. Ad hoc analysis
5. Preparation of conclusions and recommendations

## Darkwood Secrets Project

### 1. Exploratory Data Analysis Results

#### 1.1. Share of Paying Players

The game has slightly more than 22,000 registered players, with nearly 4,000 making purchases. Paying users account for approximately 18% of the total player base (roughly every sixth player spends real money in the game).

By race, the share of paying players ranges from 17% to 19%:
- lowest among Elves and Angels (17%);
- highest among Demons (19%).

Overall, the differences are relatively small.

---

#### 1.2. In-Game Purchases Analysis

A total of 1,307,678 purchases were made in the game, generating approximately 686.6 million in revenue.

The value of individual purchases ranges from 0 to nearly 486.6 thousand.

- Average purchase amount: ~526
- Median purchase amount: ~75

This indicates that most transactions are relatively small.

The standard deviation is high (~2,517), suggesting significant variability: rare large purchases substantially increase the average value.

---

#### 1.3. Anomalous Purchases

The dataset contains 907 purchases with zero cost (0.07%).

These records can be treated as isolated anomalies and were excluded from further analysis because they do not provide value for analyzing the in-game economy.

---

#### 1.4. Popular Epic Items

The most popular epic item is **Book of Legends**, accounting for 77% of all purchases. About 88% of buyers purchased this item at least once.

The second most popular item is **Bag of Holding**:
- 21% of purchases
- purchased by nearly 87% of buyers

All other items significantly lag behind the leaders:
- each accounts for no more than 1% of purchases;
- no more than 12% of players purchased them at least once.

---

### 2. Ad Hoc Analysis Results

The project explored the relationship between player purchasing activity and character race.

The analysis focused on epic item purchases across different races and tested the hypothesis that completing the game with different races requires approximately the same number of epic item purchases.

The tendency to make purchases is relatively similar across races:
- around 60–63% of registered players purchased epic items at least once;
- 16–20% of those players were paying users.

However, purchase intensity differs significantly.

- Demons and Elves average around 78–79 transactions per buyer;
- Humans exceed 121 transactions per buyer.

Total spending also varies:
- lowest among Demons and Orcs (~41–42k);
- highest among Northmen (over 62.5k).

Thus, while the probability of starting to make purchases is similar across races, the activity level of engaged players differs substantially.

As a result, the hypothesis that all races require approximately the same number of epic item purchases is not confirmed.
