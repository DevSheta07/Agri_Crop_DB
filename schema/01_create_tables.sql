-- schema/01_create_tables.sql
CREATE DATABASE agri_crop_db;

USE agri_crop_db;

CREATE TABLE states (
    state_code   VARCHAR(10) PRIMARY KEY,
    state_name   VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE districts (
    district_code VARCHAR(10) PRIMARY KEY,
    district_name VARCHAR(100) NOT NULL,
    state_code    VARCHAR(10) NOT NULL,
    FOREIGN KEY (state_code) REFERENCES states(state_code),
    UNIQUE KEY uq_district_state (district_name, state_code)
);

CREATE TABLE crops (
    crop_code   INT PRIMARY KEY,
    crop_name   VARCHAR(100) NOT NULL,
    crop_type   VARCHAR(50)
);

CREATE TABLE seasons (
    season_id   INT AUTO_INCREMENT PRIMARY KEY,
    season_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE crop_production (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    district_code         VARCHAR(10) NOT NULL,
    crop_code             INT NOT NULL,
    season_id             INT NOT NULL,
    year                  VARCHAR(9) NOT NULL,          -- e.g. '2020-21'
    area_hectares         DECIMAL(12,2),
    production_tonnes     DECIMAL(12,2),
    yield_tonnes_per_ha   DECIMAL(10,4),
    FOREIGN KEY (district_code) REFERENCES districts(district_code),
    FOREIGN KEY (crop_code) REFERENCES crops(crop_code),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id),
    UNIQUE KEY uq_production_record (district_code, crop_code, season_id, year)
);


-- Drop and rebuild in dependency order
DROP TABLE IF EXISTS crop_production;
DROP TABLE IF EXISTS crops;

CREATE TABLE crops (
    crop_id     INT AUTO_INCREMENT PRIMARY KEY,
    crop_name   VARCHAR(100) NOT NULL UNIQUE,
    crop_type   VARCHAR(50)
);

CREATE TABLE crop_production (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    district_code         VARCHAR(10) NOT NULL,
    crop_id               INT NOT NULL,
    season_id             INT NOT NULL,
    year                  VARCHAR(9) NOT NULL,
    area_hectares         DECIMAL(12,2),
    production_tonnes     DECIMAL(12,2),
    yield_tonnes_per_ha   DECIMAL(10,4),
    FOREIGN KEY (district_code) REFERENCES districts(district_code),
    FOREIGN KEY (crop_id) REFERENCES crops(crop_id),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id),
    UNIQUE KEY uq_production_record (district_code, crop_id, season_id, year)
);