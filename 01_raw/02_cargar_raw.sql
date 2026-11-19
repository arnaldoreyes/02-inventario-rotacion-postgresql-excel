-- ============================================================================
-- Proyecto 2: Inventario y rotación (AdventureWorks)
-- Capa: 01_raw
-- Script: 02_cargar_raw.sql
-- Propósito: Cargar los 9 CSV de 01_raw/entrada/ en las tablas del esquema por
--            defecto (public) y verificar que el conteo real coincida con
--            01_raw/sources.md.
--
-- Requisitos de ejecución:
--   1. Ejecutar desde la raíz del repositorio usando psql (cliente).
--   2. Se usa \copy (lado cliente) y NUNCA COPY (lado servidor), porque el
--      servicio de PostgreSQL corre como NT AUTHORITY\NetworkService y no
--      tiene permisos de lectura sobre la carpeta Documentos del usuario.
--   3. Cada tabla se limpia con TRUNCATE antes de cargar para permitir
--      re-ejecuciones sin duplicar registros.
-- ============================================================================

-- Detener inmediatamente si ocurre cualquier error durante la carga
\set ON_ERROR_STOP on

\echo '==> Cargando cat...'
TRUNCATE TABLE cat;
\copy cat FROM '01_raw/entrada/cat.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando inv...'
TRUNCATE TABLE inv;
\copy inv FROM '01_raw/entrada/inv.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando product...'
TRUNCATE TABLE product;
\copy product FROM '01_raw/entrada/product.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando pv...'
TRUNCATE TABLE pv;
\copy pv FROM '01_raw/entrada/pv.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando sod...'
TRUNCATE TABLE sod;
\copy sod FROM '01_raw/entrada/sod.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando soh...'
TRUNCATE TABLE soh;
\copy soh FROM '01_raw/entrada/soh.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando subcat...'
TRUNCATE TABLE subcat;
\copy subcat FROM '01_raw/entrada/subcat.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando vendor...'
TRUNCATE TABLE vendor;
\copy vendor FROM '01_raw/entrada/vendor.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

\echo '==> Cargando vva...'
TRUNCATE TABLE vva;
\copy vva FROM '01_raw/entrada/vva.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- ============================================================================
-- Verificación de conteos: real cargado vs. esperado en 01_raw/sources.md
-- Nota: se usa una CTE (tabla temporal de la consulta) llamada "conteos" para
-- reunir el COUNT(*) de cada tabla y compararlo contra su valor esperado.
-- ============================================================================
\echo '==> Resumen de control de filas cargadas:'

WITH conteos AS (
    SELECT 'cat'     AS tabla, COUNT(*) AS filas_cargadas,      4::BIGINT AS filas_esperadas FROM cat
    UNION ALL
    SELECT 'inv'     AS tabla, COUNT(*) AS filas_cargadas,   1069::BIGINT AS filas_esperadas FROM inv
    UNION ALL
    SELECT 'product' AS tabla, COUNT(*) AS filas_cargadas,    504::BIGINT AS filas_esperadas FROM product
    UNION ALL
    SELECT 'pv'      AS tabla, COUNT(*) AS filas_cargadas,    460::BIGINT AS filas_esperadas FROM pv
    UNION ALL
    SELECT 'sod'     AS tabla, COUNT(*) AS filas_cargadas, 121317::BIGINT AS filas_esperadas FROM sod
    UNION ALL
    SELECT 'soh'     AS tabla, COUNT(*) AS filas_cargadas,  31465::BIGINT AS filas_esperadas FROM soh
    UNION ALL
    SELECT 'subcat'  AS tabla, COUNT(*) AS filas_cargadas,     37::BIGINT AS filas_esperadas FROM subcat
    UNION ALL
    SELECT 'vendor'  AS tabla, COUNT(*) AS filas_cargadas,    104::BIGINT AS filas_esperadas FROM vendor
    UNION ALL
    SELECT 'vva'     AS tabla, COUNT(*) AS filas_cargadas,    104::BIGINT AS filas_esperadas FROM vva
)
SELECT
    tabla,
    filas_cargadas,
    filas_esperadas,
    (filas_cargadas = filas_esperadas) AS coincide
FROM conteos
ORDER BY tabla;
