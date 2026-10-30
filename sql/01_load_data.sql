/*
Project: Roller Coaster Industry Analysis

Dataset from Kaggle @ https://www.kaggle.com/datasets/abdelrahmanatef01/roller-coasters-data



-- ========================================
/*
1. Set up the Snowflake environment.

Reuse the COMPUTE_WH warehouse, PRACTICE_DB database,
and THEME_PARKS schema created during previous practice.

*/
-- ========================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE PRACTICE_DB;
USE SCHEMA THEME_PARKS;

-- Verify the active environment
SELECT
    CURRENT_ROLE(),
    CURRENT_WAREHOUSE(),
    CURRENT_DATABASE(),
    CURRENT_SCHEMA();


-- ========================================
-- 2. PREPARE CSV FILE FORMAT
-- ========================================

/*
Create a file format for importing the roller coaster CSV.

TYPE = CSV: The file we're importing is a CSV.
SKIP_HEADER = 1: Skip the first row with column names.
FIELD_OPTIONALLY_ENCLOSED_BY: Keeps text inside double quotes together, even if it contains commas.
*/

CREATE FILE FORMAT IF NOT EXISTS COASTER_CSV_FORMAT
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

SHOW FILE FORMATS IN SCHEMA PRACTICE_DB.THEME_PARKS;

-- ========================================
-- 3. CREATE INTERNAL STAGE
-- ========================================

/*
Create a stage to hold the coaster CSV
before loading it into the raw table.
*/

CREATE STAGE COASTER_STAGE;

LIST @COASTER_STAGE;

--INSPECT THE CSV FILE

SELECT
    $1,
    $2,
    $3,
    $4,
    $5
FROM @COASTER_STAGE/coasters.csv
    (FILE_FORMAT => 'COASTER_CSV_FORMAT')
LIMIT 5;

-- ========================================
-- 4. CREATE RAW DATA TABLE
-- ========================================

/*
Create a table to store the original CSV data.
Use VARCHAR to preserve values before cleaning (before converting to numbers or dates). Avoids errors caused by inconsistent or invalid data types and formatting.
*/

CREATE TABLE COASTERS_RAW (
    NAME VARCHAR,
    AMUSEMENT_PARK VARCHAR, 
    TYPE VARCHAR,
    DESIGN VARCHAR,
    STATUS VARCHAR,
    OPENED VARCHAR,
    CITY VARCHAR,
    REGION VARCHAR,
    COUNTRY VARCHAR,
    MANUFACTURER VARCHAR,
    LENGTH_FT VARCHAR,
    HEIGHT_FT VARCHAR,
    SPEED_MPH VARCHAR,
    INVERSIONS VARCHAR,
    ELEMENTS VARCHAR,
    DROP_FT VARCHAR,
    DURATION VARCHAR,
    G_FORCE VARCHAR,
    VERTICAL_ANGLE VARCHAR,
    UPHILL_LENGTH_FT VARCHAR,
    DOWNHILL_LENGTH_FT VARCHAR,
    ELEVATION_CHANGE_FT VARCHAR,
    BANK_ANGLE VARCHAR,
    AIRTIME_POINTS VARCHAR,
    CROSSINGS VARCHAR,
    "DROP" VARCHAR
);

DESCRIBE TABLE COASTERS_RAW;

-- COPY INTO to load data (CSV) into table

COPY INTO
    COASTERS_RAW
FROM
    @COASTER_STAGE
FILE_FORMAT = (FORMAT_NAME = 'COASTER_CSV_FORMAT');

--confirming load 
SELECT COUNT(*)
FROM
    COASTERS_RAW; --12000 rows

SELECT *
FROM
    COASTERS_RAW; --load looks good

-- ========================================
--5. CHECK DATA QUALITY
-- ========================================

/*
Check total rows, duplicates, and missing values.
*/

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(DISTINCT NAME) AS repeated_names,
    COUNT_IF(MANUFACTURER IS NULL OR TRIM(MANUFACTURER) = '') AS missing_manufacturer,
    COUNT_IF(HEIGHT_FT IS NULL OR TRIM(HEIGHT_FT) = '') AS missing_height,
    COUNT_IF(SPEED_MPH IS NULL OR TRIM(SPEED_MPH) = '') AS missing_speed,
    COUNT_IF(OPENED IS NULL OR TRIM(OPENED) = '') AS missing_opened
FROM COASTERS_RAW;
-----------------------------------------------------------
/*
CHECK FOR DUPLICATE ROWS USING HASH(*).
RESEARCHED HOW TO COMPARE ALL COLUMNS IN SNOWFLAKE.
USED HASH(*) TO IDENTIFY POSSIBLE DUPLICATE RECORDS.

REFERENCE:
https://docs.snowflake.com/en/sql-reference/functions/hash
*/
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(DISTINCT HASH(*)) AS duplicate_rows
FROM COASTERS_RAW;
-----------------------------------------------------------

/*
CREATE A COPY OF COASTERS_RAW TO CLEAN AND MODIFY
WITHOUT CHANGING THE ORIGINAL DATA.
*/

CREATE TABLE COASTERS_CLEAN AS
    SELECT *
    FROM COASTERS_RAW;

--remove duplicates
SELECT DISTINCT *
FROM COASTERS_CLEAN;

--Remove duplicate rows using DISTINCT, keep only unique records in COASTERS_CLEAN
CREATE OR REPLACE TABLE COASTERS_CLEAN AS 
    SELECT DISTINCT *
    FROM COASTERS_CLEAN

--Check row count matches
SELECT COUNT(*)
FROM COASTERS_CLEAN; --It matches, duplicates were dropped

-- Check height and speed values, then calculate their averages

SELECT
    HEIGHT_FT,
    SPEED_MPH
FROM
    COASTERS_CLEAN
LIMIT 20;

-- Calculate average height, rounded to 2 decimal places
SELECT
    ROUND(AVG(HEIGHT_FT), 2) AS AVG_HEIGHT
FROM
    COASTERS_CLEAN;

-- Calculate average speed, rounded to 2 decimal places
SELECT
    ROUND(AVG(SPEED_MPH), 2) AS AVG_SPEED
FROM
    COASTERS_CLEAN;

--examine date formatting, only concerned with year.
SELECT DISTINCT
    OPENED
FROM
    COASTERS_CLEAN
ORDER BY
    OPENED;

SELECT DISTINCT
    OPENED
FROM
    COASTERS_CLEAN
ORDER BY
    OPENED
LIMIT 30;


/*
- Extract the opening year using SPLIT_PART().
- Count coasters by year using COUNT() and GROUP BY.
- Remove the rows that say 'unknown'.
- Sort results by year using ORDER BY.
- Check for invalid or unusual years.
*/


SELECT
    SPLIT_PART(OPENED, '/', -1) AS OPENING_YEAR,
    COUNT(*) AS TOTAL_COASTERS
FROM
    COASTERS_CLEAN
WHERE
    OPENED <> 'unknown'
GROUP BY
    OPENING_YEAR
ORDER BY
    OPENING_YEAR;

-- more analysis before cleaning
    
FROM
    COASTERS_CLEAN
WHERE
    OPENED <> 'unknown'
GROUP BY
    OPENING_YEAR
ORDER BY
    OPENING_YEAR;

SELECT
    MANUFACTURER,
    COUNT(*) AS TOTAL_COASTERS
FROM
    COASTERS_CLEAN
WHERE
    MANUFACTURER IS NOT NULL
    AND TRIM(MANUFACTURER) <> ''
    AND LOWER(TRIM(MANUFACTURER)) <> 'unknown'
GROUP BY
    MANUFACTURER
ORDER BY
    TOTAL_COASTERS DESC
LIMIT 10;

/*
Found 2,303 records with unknown coaster names.
Keep these records because other columns may contain useful data.
Exclude unknown names when needed for analysis.
*/

SELECT
    COUNT(*) AS UNKNOWN_NAMES
FROM
    COASTERS_CLEAN
WHERE
    LOWER(TRIM(NAME)) = 'unknown';


-- export CSVs for continued cleaning and analysis outside of Snowflake
SELECT *
FROM COASTERS_CLEAN;

SELECT *
FROM COASTERS_RAW;