-- =====================================================================
-- Modelo en estrella · Hyrox Dobles Bilbao 2026
-- Motor: DuckDB
--
-- Grano de la tabla de hechos: una fila por pareja participante.
-- Los parciales se almacenan como texto HH:MM:SS (formato original de la
-- web de resultados) y se convierten a segundos en la vista final, que es
-- la que consume Power BI.
-- =====================================================================


-- =====================================================================
-- DIMENSIONES
-- =====================================================================

-- Evento
-- En este dataset contiene una sola fila (Bilbao, 2026, Doubles Men).
-- Se mantiene como dimensión para poder incorporar más competiciones
-- sin modificar el modelo.
DROP TABLE IF EXISTS dim_evento;
CREATE TABLE dim_evento (
    id_evento  INTEGER PRIMARY KEY,
    evento     VARCHAR NOT NULL,
    "año"      INTEGER NOT NULL,
    modalidad  VARCHAR NOT NULL
);


-- Categoría
-- Grupos de edad de la competición (16-24, 25-29, 30-34, ...).
DROP TABLE IF EXISTS dim_categoria;
CREATE TABLE dim_categoria (
    id_categoria INTEGER PRIMARY KEY,
    grupo_edad   VARCHAR NOT NULL
);


-- Atleta
-- El grano es la PAREJA, no el atleta individual: la modalidad de dobles
-- compite y puntúa como una unidad, por lo que separar a los dos miembros
-- en filas distintas rompería la relación 1:1 con la tabla de hechos.
DROP TABLE IF EXISTS dim_atleta;
CREATE TABLE dim_atleta (
    id_atleta      INTEGER PRIMARY KEY,
    nombres_pareja VARCHAR NOT NULL,
    atleta_1       VARCHAR,
    atleta_2       VARCHAR
);


-- =====================================================================
-- TABLA DE HECHOS
-- =====================================================================

DROP TABLE IF EXISTS fact_resultado;
CREATE TABLE fact_resultado (
    id_resultado            INTEGER PRIMARY KEY,

    -- Claves foráneas
    id_atleta               INTEGER NOT NULL REFERENCES dim_atleta(id_atleta),
    id_evento               INTEGER NOT NULL REFERENCES dim_evento(id_evento),
    id_categoria            INTEGER NOT NULL REFERENCES dim_categoria(id_categoria),

    -- Clasificación
    pos_general             INTEGER,
    pos_categoria           INTEGER,

    -- Tiempo total: texto para visualización, numérico para cálculos
    tiempo_total            VARCHAR,   -- HH:MM:SS
    tiempo_segundos         BIGINT,    -- métrica base de todos los cálculos
    tiempo_minutos          DOUBLE,

    -- Parciales en orden de carrera: 8 tramos de 1 km alternados
    -- con las 8 estaciones de trabajo funcional (HH:MM:SS)
    running_1               VARCHAR,
    "1000m_skierg"          VARCHAR,
    running_2               VARCHAR,
    "50m_sled_push"         VARCHAR,
    running_3               VARCHAR,
    "50m_sled_pull"         VARCHAR,
    running_4               VARCHAR,
    "80m_burpee_broad_jump" VARCHAR,
    running_5               VARCHAR,
    "1000m_row"             VARCHAR,
    running_6               VARCHAR,
    "200m_farmers_carry"    VARCHAR,
    running_7               VARCHAR,
    "100m_sandbag_lunges"   VARCHAR,
    running_8               VARCHAR,
    wall_balls              VARCHAR,

    -- Métricas agregadas
    roxzone_time            VARCHAR,   -- tiempo total en zona de transición
    run_total               VARCHAR,   -- suma de los 8 tramos de carrera
    best_run_lap            VARCHAR    -- tramo de carrera más rápido
);


-- =====================================================================
-- VISTAS
-- =====================================================================

-- Convierte los parciales de HH:MM:SS a segundos enteros.
-- Es la capa que consume Power BI: evita hacer el parseo en DAX y permite
-- agregar, promediar y comparar estaciones directamente.
CREATE OR REPLACE VIEW v_splits_segundos AS
SELECT
    id_resultado, id_atleta, id_evento, id_categoria,
    pos_general, pos_categoria, tiempo_segundos, tiempo_minutos,

    -- Estaciones
    CAST(SPLIT_PART("1000m_skierg", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("1000m_skierg", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("1000m_skierg", ':', 3) AS INT) AS skierg_seg,

    CAST(SPLIT_PART("50m_sled_push", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("50m_sled_push", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("50m_sled_push", ':', 3) AS INT) AS sled_push_seg,

    CAST(SPLIT_PART("50m_sled_pull", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("50m_sled_pull", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("50m_sled_pull", ':', 3) AS INT) AS sled_pull_seg,

    CAST(SPLIT_PART("80m_burpee_broad_jump", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("80m_burpee_broad_jump", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("80m_burpee_broad_jump", ':', 3) AS INT) AS burpee_seg,

    CAST(SPLIT_PART("1000m_row", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("1000m_row", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("1000m_row", ':', 3) AS INT) AS row_seg,

    CAST(SPLIT_PART("200m_farmers_carry", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("200m_farmers_carry", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("200m_farmers_carry", ':', 3) AS INT) AS farmers_carry_seg,

    CAST(SPLIT_PART("100m_sandbag_lunges", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("100m_sandbag_lunges", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("100m_sandbag_lunges", ':', 3) AS INT) AS sandbag_lunges_seg,

    CAST(SPLIT_PART("wall_balls", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("wall_balls", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("wall_balls", ':', 3) AS INT) AS wall_balls_seg,

    -- Carrera
    CAST(SPLIT_PART("running_1", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("running_1", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("running_1", ':', 3) AS INT) AS running_1_seg,

    CAST(SPLIT_PART("run_total", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("run_total", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("run_total", ':', 3) AS INT) AS run_total_seg,

    -- Transiciones
    CAST(SPLIT_PART("roxzone_time", ':', 1) AS INT) * 3600 +
    CAST(SPLIT_PART("roxzone_time", ':', 2) AS INT) * 60 +
    CAST(SPLIT_PART("roxzone_time", ':', 3) AS INT) AS roxzone_seg

FROM fact_resultado;


-- =====================================================================
-- CONSULTAS DE VALIDACIÓN
-- =====================================================================

-- Top 10 parejas por tiempo total
SELECT a.nombres_pareja, a.atleta_1, a.atleta_2,
       c.grupo_edad, f.pos_general, f.tiempo_total
FROM fact_resultado f
JOIN dim_atleta a    ON f.id_atleta    = a.id_atleta
JOIN dim_categoria c ON f.id_categoria = c.id_categoria
ORDER BY f.tiempo_segundos
LIMIT 10;

-- Parejas y tiempo medio por grupo de edad
SELECT c.grupo_edad,
       COUNT(*)                          AS parejas,
       ROUND(AVG(f.tiempo_minutos), 1)   AS media_minutos
FROM fact_resultado f
JOIN dim_categoria c ON f.id_categoria = c.id_categoria
GROUP BY c.grupo_edad
ORDER BY c.grupo_edad;

-- Media por estación, en minutos (sobre la vista de segundos)
SELECT ROUND(AVG(skierg_seg)         / 60, 2) AS media_skierg_min,
       ROUND(AVG(sled_push_seg)      / 60, 2) AS media_sled_push_min,
       ROUND(AVG(sled_pull_seg)      / 60, 2) AS media_sled_pull_min,
       ROUND(AVG(burpee_seg)         / 60, 2) AS media_burpee_min,
       ROUND(AVG(row_seg)            / 60, 2) AS media_row_min,
       ROUND(AVG(farmers_carry_seg)  / 60, 2) AS media_farmers_min,
       ROUND(AVG(sandbag_lunges_seg) / 60, 2) AS media_lunges_min,
       ROUND(AVG(wall_balls_seg)     / 60, 2) AS media_wall_balls_min
FROM v_splits_segundos;