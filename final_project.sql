-- =====================================================================
-- Фінальний проєкт: датасет infectious_cases (PostgreSQL)
-- =====================================================================


-- =====================================================================
-- Завдання 1. Завантаження даних
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS pandemic;
SET search_path TO pandemic;

-- Усі колонки імпортуються як TEXT, бо в CSV багато порожніх значень.
-- Приведення до числових типів виконується під час нормалізації.
DROP TABLE IF EXISTS infectious_cases CASCADE;
CREATE TABLE infectious_cases (
    entity               TEXT,
    code                 TEXT,
    year                 TEXT,
    number_yaws          TEXT,
    polio_cases          TEXT,
    cases_guinea_worm    TEXT,
    number_rabies        TEXT,
    number_malaria       TEXT,
    number_hiv           TEXT,
    number_tuberculosis  TEXT,
    number_smallpox      TEXT,
    number_cholera_cases TEXT
);

-- Імпорт (psql). В pgAdmin / DBeaver можна скористатися майстром Import Data.
-- \copy pandemic.infectious_cases FROM 'infectious_cases.csv' WITH (FORMAT csv, HEADER true);

-- Огляд даних
SELECT * FROM infectious_cases LIMIT 10;
SELECT COUNT(*) AS total_rows FROM infectious_cases;


-- =====================================================================
-- Завдання 2. Нормалізація до 3НФ
-- =====================================================================

-- 2.1. Довідник унікальних комбінацій Entity + Code
DROP TABLE IF EXISTS infectious_cases_normalized;
DROP TABLE IF EXISTS entities;

CREATE TABLE entities (
    id     SERIAL PRIMARY KEY,
    entity TEXT NOT NULL,
    code   TEXT,
    UNIQUE (entity, code)
);

INSERT INTO entities (entity, code)
SELECT DISTINCT entity, NULLIF(code, '')
FROM infectious_cases
ORDER BY entity;

-- 2.2. Таблиця показників, де замість Entity та Code використовується entity_id
CREATE TABLE infectious_cases_normalized (
    id                   SERIAL PRIMARY KEY,
    entity_id            INT NOT NULL REFERENCES entities (id),
    year                 INT NOT NULL,
    number_yaws          NUMERIC,
    polio_cases          NUMERIC,
    cases_guinea_worm    NUMERIC,
    number_rabies        NUMERIC,
    number_malaria       NUMERIC,
    number_hiv           NUMERIC,
    number_tuberculosis  NUMERIC,
    number_smallpox      NUMERIC,
    number_cholera_cases NUMERIC
);

INSERT INTO infectious_cases_normalized (
    entity_id, year,
    number_yaws, polio_cases, cases_guinea_worm, number_rabies, number_malaria,
    number_hiv, number_tuberculosis, number_smallpox, number_cholera_cases
)
SELECT
    e.id,
    ic.year::INT,
    NULLIF(ic.number_yaws, '')::NUMERIC,
    NULLIF(ic.polio_cases, '')::NUMERIC,
    NULLIF(ic.cases_guinea_worm, '')::NUMERIC,
    NULLIF(ic.number_rabies, '')::NUMERIC,
    NULLIF(ic.number_malaria, '')::NUMERIC,
    NULLIF(ic.number_hiv, '')::NUMERIC,
    NULLIF(ic.number_tuberculosis, '')::NUMERIC,
    NULLIF(ic.number_smallpox, '')::NUMERIC,
    NULLIF(ic.number_cholera_cases, '')::NUMERIC
FROM infectious_cases ic
JOIN entities e
  ON e.entity = ic.entity
 AND e.code IS NOT DISTINCT FROM NULLIF(ic.code, '');

-- Перевірка: кількість рядків має збігатися з оригінальною таблицею
SELECT
    (SELECT COUNT(*) FROM infectious_cases)            AS original_rows,
    (SELECT COUNT(*) FROM infectious_cases_normalized) AS normalized_rows,
    (SELECT COUNT(*) FROM entities)                    AS unique_entities;


-- =====================================================================
-- Завдання 3. Аналіз Number_rabies
-- =====================================================================

SELECT
    e.id,
    e.entity,
    e.code,
    AVG(n.number_rabies) AS avg_rabies,
    MIN(n.number_rabies) AS min_rabies,
    MAX(n.number_rabies) AS max_rabies,
    SUM(n.number_rabies) AS sum_rabies
FROM infectious_cases_normalized n
JOIN entities e ON e.id = n.entity_id
WHERE n.number_rabies IS NOT NULL
GROUP BY e.id, e.entity, e.code
ORDER BY avg_rabies DESC
LIMIT 10;


-- =====================================================================
-- Завдання 4. Колонка різниці в роках (вбудовані функції)
-- =====================================================================

SELECT
    n.year,
    MAKE_DATE(n.year, 1, 1)                                         AS year_start_date,
    CURRENT_DATE                                                    AS today,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, MAKE_DATE(n.year, 1, 1)))::INT AS years_diff
FROM infectious_cases_normalized n
LIMIT 10;


-- =====================================================================
-- Завдання 5. Власні функції
-- =====================================================================

-- 5.1. Різниця в роках між поточною датою та 1 січня заданого року
CREATE OR REPLACE FUNCTION years_since(input_year INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, MAKE_DATE(input_year, 1, 1)))::INT;
END;
$$;

-- Приклад: 1996 -> 1996-01-01 -> різниця в роках
SELECT years_since(1996) AS years_since_1996;

SELECT
    n.year,
    MAKE_DATE(n.year, 1, 1) AS year_start_date,
    CURRENT_DATE            AS today,
    years_since(n.year)     AS years_diff
FROM infectious_cases_normalized n
LIMIT 10;

-- 5.2. Середня кількість захворювань за період (річне значення / дільник)
CREATE OR REPLACE FUNCTION avg_cases_per_period(yearly_cases NUMERIC, divider NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    IF yearly_cases IS NULL OR divider IS NULL OR divider = 0 THEN
        RETURN NULL;
    END IF;
    RETURN yearly_cases / divider;
END;
$$;

-- Використовуються лише записи з числовим значенням кількості захворювань
SELECT
    e.entity,
    n.year,
    n.number_rabies,
    ROUND(avg_cases_per_period(n.number_rabies, 12), 4) AS avg_per_month,
    ROUND(avg_cases_per_period(n.number_rabies, 4), 4)  AS avg_per_quarter,
    ROUND(avg_cases_per_period(n.number_rabies, 2), 4)  AS avg_per_half_year
FROM infectious_cases_normalized n
JOIN entities e ON e.id = n.entity_id
WHERE n.number_rabies IS NOT NULL
LIMIT 10;
