-- ============================================================
-- queries/analysis_queries.sql
-- Indian Agriculture & Crop Production DB
-- ============================================================

USE agri_crop_db;


-- ============================================================
-- SECTION 1: BASIC (single table, filters, aggregates)
-- ============================================================

-- 1.1 List all states
SELECT * FROM states ORDER BY state_name;

-- 1.2 List all crops of a specific type
SELECT crop_name, crop_type FROM crops WHERE crop_type = 'Cereals';

-- 1.3 Count total crop production records
SELECT COUNT(*) AS total_records FROM crop_production;

-- 1.4 All distinct crop types
SELECT DISTINCT crop_type FROM crops WHERE crop_type IS NOT NULL;

-- 1.5 All production records from a specific year
SELECT * FROM crop_production WHERE year = '1997-1998' LIMIT 20;

-- 1.6 Number of records per year
SELECT year, COUNT(*) AS record_count
FROM crop_production
GROUP BY year
ORDER BY year;

-- 1.7 Simple filter with a threshold
SELECT * FROM crop_production
WHERE production_tonnes > 100000
ORDER BY production_tonnes DESC
LIMIT 20;


-- ============================================================
-- SECTION 2: INTERMEDIATE (JOINS + GROUP BY + HAVING)
-- ============================================================

-- 2.1 All districts in a given state
SELECT d.district_name
FROM districts d
JOIN states s ON d.state_code = s.state_code
WHERE s.state_name = 'Gujarat'
ORDER BY d.district_name;

-- 2.2 Total production of a specific crop, all-time
SELECT SUM(cp.production_tonnes) AS total_production
FROM crop_production cp
JOIN crops c ON cp.crop_id = c.crop_id
WHERE c.crop_name = 'Rice';

-- 2.3 Average area cultivated per crop
SELECT c.crop_name, ROUND(AVG(cp.area_hectares), 2) AS avg_area
FROM crop_production cp
JOIN crops c ON cp.crop_id = c.crop_id
GROUP BY c.crop_name
ORDER BY avg_area DESC
LIMIT 10;

-- 2.4 Top 10 crop-producing states (all-time)
SELECT s.state_name, SUM(cp.production_tonnes) AS total_production
FROM crop_production cp
JOIN districts d ON cp.district_code = d.district_code
JOIN states s ON d.state_code = s.state_code
GROUP BY s.state_name
ORDER BY total_production DESC
LIMIT 10;

-- 2.5 Season-wise total production comparison
SELECT se.season_name, SUM(cp.production_tonnes) AS total_production
FROM crop_production cp
JOIN seasons se ON cp.season_id = se.season_id
GROUP BY se.season_name
ORDER BY total_production DESC;

-- 2.6 Crop diversity per state
SELECT s.state_name, COUNT(DISTINCT cp.crop_id) AS distinct_crops_grown
FROM crop_production cp
JOIN districts d ON cp.district_code = d.district_code
JOIN states s ON d.state_code = s.state_code
GROUP BY s.state_name
ORDER BY distinct_crops_grown DESC
LIMIT 10;

-- 2.7 Filtering grouped results with HAVING
SELECT d.district_name, s.state_name, COUNT(DISTINCT cp.crop_id) AS crop_variety
FROM crop_production cp
JOIN districts d ON cp.district_code = d.district_code
JOIN states s ON d.state_code = s.state_code
GROUP BY d.district_name, s.state_name
HAVING crop_variety > 20
ORDER BY crop_variety DESC
LIMIT 10;

-- 2.8 Top 5 districts by average yield for a given crop
SELECT d.district_name, s.state_name,
       ROUND(AVG(cp.yield_tonnes_per_ha), 2) AS avg_yield
FROM crop_production cp
JOIN districts d ON cp.district_code = d.district_code
JOIN states s ON d.state_code = s.state_code
JOIN crops c ON cp.crop_id = c.crop_id
WHERE c.crop_name = 'Wheat'
GROUP BY d.district_name, s.state_name
HAVING COUNT(*) > 5
ORDER BY avg_yield DESC
LIMIT 5;

-- 2.9 CASE WHEN — bucket production into size categories
SELECT cp.id, cp.production_tonnes,
    CASE
        WHEN cp.production_tonnes >= 100000 THEN 'Very High'
        WHEN cp.production_tonnes >= 10000  THEN 'High'
        WHEN cp.production_tonnes >= 1000   THEN 'Medium'
        ELSE 'Low'
    END AS production_category
FROM crop_production cp
LIMIT 20;

-- 2.10 Year-over-year production trend for a specific crop
SELECT cp.year, SUM(cp.production_tonnes) AS total_production
FROM crop_production cp
JOIN crops c ON cp.crop_id = c.crop_id
WHERE c.crop_name = 'Rice'
GROUP BY cp.year
ORDER BY cp.year;


-- ============================================================
-- SECTION 3: ADVANCED (standard subqueries, EXISTS)
-- ============================================================

-- 3.1 Crops whose average yield beats the overall average yield
SELECT c.crop_name,
       ROUND(AVG(cp.yield_tonnes_per_ha), 2) AS crop_avg_yield
FROM crop_production cp
JOIN crops c ON cp.crop_id = c.crop_id
GROUP BY c.crop_name
HAVING crop_avg_yield > (SELECT AVG(yield_tonnes_per_ha) FROM crop_production)
ORDER BY crop_avg_yield DESC
LIMIT 15;

-- 3.2 States that have ever produced more than 1,000,000 tonnes of any single crop (EXISTS)
SELECT s.state_name
FROM states s
WHERE EXISTS (
    SELECT 1
    FROM crop_production cp
    JOIN districts d ON cp.district_code = d.district_code
    WHERE d.state_code = s.state_code
      AND cp.production_tonnes > 1000000
)
ORDER BY s.state_name;

-- 3.3 Crops grown in every single season (subquery with COUNT comparison)
SELECT c.crop_name
FROM crop_production cp
JOIN crops c ON cp.crop_id = c.crop_id
GROUP BY c.crop_name
HAVING COUNT(DISTINCT cp.season_id) = (SELECT COUNT(*) FROM seasons);

-- 3.4 District(s) with the single highest production value recorded
SELECT d.district_name, s.state_name, c.crop_name, cp.year, cp.production_tonnes
FROM crop_production cp
JOIN districts d ON cp.district_code = d.district_code
JOIN states s ON d.state_code = s.state_code
JOIN crops c ON cp.crop_id = c.crop_id
WHERE cp.production_tonnes = (SELECT MAX(production_tonnes) FROM crop_production);


SELECT * FROM crop_production;