-- Actual schema from SQLite
PRAGMA foreign_keys=ON;

CREATE TABLE dim_campaign (
    campaign_key INTEGER PRIMARY KEY AUTOINCREMENT,
    campaign_id TEXT NOT NULL UNIQUE,
    campaign_name TEXT NOT NULL,
    objective TEXT NOT NULL
);

CREATE TABLE dim_content (
    content_key INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL UNIQUE
);

CREATE TABLE dim_creator (
    creator_key INTEGER PRIMARY KEY AUTOINCREMENT,
    creator_id TEXT NOT NULL UNIQUE,
    creator_name TEXT NOT NULL,
    country_name TEXT NOT NULL,
    region_name TEXT NOT NULL
);

CREATE TABLE dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date TEXT NOT NULL UNIQUE,
    calendar_year INTEGER NOT NULL,
    calendar_quarter INTEGER NOT NULL,
    calendar_month INTEGER NOT NULL,
    calendar_day INTEGER NOT NULL
);

CREATE TABLE dim_platform (
    platform_key INTEGER PRIMARY KEY AUTOINCREMENT,
    platform_name TEXT NOT NULL UNIQUE
);

CREATE TABLE fact_post (
    post_key INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id TEXT NOT NULL UNIQUE,
    date_key INTEGER NOT NULL,
    platform_key INTEGER NOT NULL,
    creator_key INTEGER NOT NULL,
    content_key INTEGER NOT NULL,
    campaign_key INTEGER NOT NULL,
    likes INTEGER NOT NULL CHECK(likes >= 0),
    comments INTEGER NOT NULL CHECK(comments >= 0),
    shares INTEGER NOT NULL CHECK(shares >= 0),
    impressions INTEGER NOT NULL CHECK(impressions >= 0),
    engagements INTEGER NOT NULL CHECK(engagements >= 0),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (platform_key) REFERENCES dim_platform(platform_key),
    FOREIGN KEY (creator_key) REFERENCES dim_creator(creator_key),
    FOREIGN KEY (content_key) REFERENCES dim_content(content_key),
    FOREIGN KEY (campaign_key) REFERENCES dim_campaign(campaign_key)
);

CREATE TABLE sqlite_sequence(name,seq);

CREATE INDEX idx_fact_post_date_plat ON fact_post(date_key, platform_key);

-- Q1 Roll-up
SELECT
    d.calendar_year,
    d.calendar_month,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.likes) AS total_likes,
    SUM(fp.comments) AS total_comments,
    SUM(fp.shares) AS total_shares,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN dim_date d ON fp.date_key = d.date_key
GROUP BY d.calendar_year, d.calendar_month
ORDER BY d.calendar_month ASC;


-- Q2 Drill-down parent
SELECT
    c.region_name,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN dim_creator c ON fp.creator_key = c.creator_key
GROUP BY c.region_name
ORDER BY total_posts DESC;


-- Q2 Drill-down child
SELECT
    c.region_name,
    c.country_name,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN dim_creator c ON fp.creator_key = c.creator_key
GROUP BY c.region_name, c.country_name
ORDER BY c.region_name, total_posts DESC;


-- Q3 Slice
SELECT
    d.calendar_month,
    p.platform_name,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN dim_date d ON fp.date_key = d.date_key
JOIN dim_platform p ON fp.platform_key = p.platform_key
WHERE p.platform_name = 'Instagram'
GROUP BY d.calendar_month
ORDER BY d.calendar_month ASC;


-- Q4 Dice
SELECT
    p.platform_name,
    ct.content_type,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN dim_platform p ON fp.platform_key = p.platform_key
JOIN dim_content ct ON fp.content_key = ct.content_key
JOIN dim_date d ON fp.date_key = d.date_key
JOIN dim_campaign c ON fp.campaign_key = c.campaign_key
WHERE p.platform_name IN ('Instagram', 'YouTube')
  AND ct.content_type IN ('Image', 'Video')
  AND d.calendar_year = 2025
  AND d.calendar_quarter = 3
  AND c.objective = 'Awareness'
GROUP BY p.platform_name, ct.content_type
ORDER BY total_posts DESC;


-- Q5 Pivot
SELECT
    p.platform_name,
    SUM(CASE WHEN d.calendar_quarter = 1 THEN 1 ELSE 0 END) AS Q1,
    SUM(CASE WHEN d.calendar_quarter = 2 THEN 1 ELSE 0 END) AS Q2,
    SUM(CASE WHEN d.calendar_quarter = 3 THEN 1 ELSE 0 END) AS Q3,
    SUM(CASE WHEN d.calendar_quarter = 4 THEN 1 ELSE 0 END) AS Q4,
    COUNT(fp.post_key) AS total_posts
FROM fact_post fp
JOIN dim_platform p ON fp.platform_key = p.platform_key
JOIN dim_date d ON fp.date_key = d.date_key
GROUP BY p.platform_name;


-- Q6 Aggregation
SELECT
    c.objective,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.likes) AS total_likes,
    SUM(fp.comments) AS total_comments,
    SUM(fp.shares) AS total_shares,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN dim_campaign c ON fp.campaign_key = c.campaign_key
GROUP BY c.objective
ORDER BY total_posts DESC;


-- Supplementary content
SELECT
    ct.content_type,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.likes) AS total_likes,
    SUM(fp.comments) AS total_comments,
    SUM(fp.shares) AS total_shares,
    SUM(fp.engagements) AS total_engagements
FROM fact_post fp
JOIN dim_content ct ON fp.content_key = ct.content_key
GROUP BY ct.content_type;


-- Supplementary creator segments
WITH creator_posting_counts AS (
    SELECT
        creator_key,
        COUNT(post_key) as posts_count
    FROM fact_post
    GROUP BY creator_key
),
creator_activity_tiers AS (
    SELECT
        creator_key,
        posts_count,
        CASE
            WHEN posts_count > 20 THEN 'High Activity'
            WHEN posts_count BETWEEN 10 AND 20 THEN 'Medium Activity'
            ELSE 'Low Activity'
        END AS creator_activity_tier
    FROM creator_posting_counts
)
SELECT
    cat.creator_activity_tier,
    COUNT(fp.post_key) AS total_posts,
    SUM(fp.engagements) AS total_engagements,
    SUM(fp.impressions) AS total_impressions,
    ROUND(100.0 * SUM(fp.engagements) / NULLIF(SUM(fp.impressions), 0), 2) AS weighted_engagement_rate
FROM fact_post fp
JOIN creator_activity_tiers cat ON fp.creator_key = cat.creator_key
GROUP BY cat.creator_activity_tier;


-- Supplementary monthly trends
SELECT
    d.calendar_month,
    SUM(fp.likes) AS total_likes,
    SUM(fp.comments) AS total_comments,
    SUM(fp.shares) AS total_shares
FROM fact_post fp
JOIN dim_date d ON fp.date_key = d.date_key
GROUP BY d.calendar_month
ORDER BY d.calendar_month ASC;
