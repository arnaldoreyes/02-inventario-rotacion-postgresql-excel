-- ============================================================================
-- Proyecto 2: Inventario y rotación (AdventureWorks)
-- Capa: 02_staging
-- Script: 02_crear_tablas_staging.sql
-- Propósito: Construir las 4 tablas limpias y tipadas de staging en el esquema
--            por defecto (public) a partir de las tablas crudas cargadas en
--            la Fase 1.
--
-- Decisiones de negocio y diseño:
--   1. Se trabaja en public sin esquemas adicionales para mantener consultas
--      directas y simples en PostgreSQL y Power Query.
--   2. Cada tabla incluye DROP TABLE IF EXISTS antes de CREATE TABLE AS para
--      poder re-ejecutar el script de forma idempotente sin duplicar datos.
--   3. Se homogeniza la llave de producto como product_id (INT) en las 4
--      tablas para facilitar los cruces en 03_modeling.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. stg_productos
-- Por qué importa para el negocio:
--   AdventureWorks incluye 504 artículos, pero solo 295 son productos
--   terminados destinados a la venta (finishedgoodsflag = 'True'). Los demás
--   son piezas internas de fabricación sin precio de venta. Aquí filtramos
--   esos 295 productos, incorporamos su categoría y subcategoría mediante
--   LEFT JOIN (para no perder ningún producto) y convertimos costos, precios,
--   parámetros oficiales de stock y fechas a sus tipos reales.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS stg_productos;

CREATE TABLE stg_productos AS
SELECT
    p.productid::INT                                      AS product_id,
    TRIM(p.name)                                          AS nombre_producto,
    TRIM(p.productnumber)                                 AS codigo_producto,
    COALESCE(NULLIF(TRIM(c.name), ''), 'Sin categoría')   AS categoria,
    COALESCE(NULLIF(TRIM(s.name), ''), 'Sin subcategoría') AS subcategoria,
    NULLIF(TRIM(p.color), '')                             AS color,
    p.safetystocklevel::INT                               AS stock_seguridad_oficial,
    p.reorderpoint::INT                                   AS punto_reorden_oficial,
    p.standardcost::NUMERIC(12, 2)                        AS costo_estandar,
    p.listprice::NUMERIC(12, 2)                           AS precio_lista,
    p.daystomanufacture::INT                              AS dias_fabricacion,
    NULLIF(TRIM(p.sellstartdate), '')::DATE               AS fecha_inicio_venta,
    NULLIF(TRIM(p.sellenddate), '')::DATE                 AS fecha_fin_venta
FROM product AS p
LEFT JOIN subcat AS s
    ON p.productsubcategoryid = s.productsubcategoryid
LEFT JOIN cat AS c
    ON s.productcategoryid = c.productcategoryid
WHERE p.finishedgoodsflag = 'True';


-- ----------------------------------------------------------------------------
-- 2. stg_inventario
-- Por qué importa para el negocio:
--   En la tabla cruda inv un producto aparece repetido por cada almacén o
--   ubicación (locationid). Si cruzáramos inv sin agrupar, duplicaríamos
--   productos y ventas. Aquí consolidamos el stock total disponible por
--   producto y contamos en cuántas ubicaciones está distribuido.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS stg_inventario;

CREATE TABLE stg_inventario AS
SELECT
    productid::INT             AS product_id,
    SUM(quantity::INT)         AS stock_actual,
    COUNT(DISTINCT locationid) AS ubicaciones_almacen
FROM inv
GROUP BY productid::INT;


-- ----------------------------------------------------------------------------
-- 3. stg_ventas
-- Por qué importa para el negocio:
--   El detalle de líneas de venta (sod) no tiene fecha propia; depende de la
--   cabecera de orden (soh). Aquí unimos ambas tablas por salesorderid,
--   tipamos cantidades e importes y marcamos explícitamente qué líneas caen
--   dentro de la ventana comparable de 12 meses (2013-07-01 a 2014-06-30)
--   para el cálculo de rotación y demanda diaria.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS stg_ventas;

CREATE TABLE stg_ventas AS
SELECT
    d.salesorderid::INT                  AS sales_order_id,
    d.salesorderdetailid::INT            AS sales_order_detail_id,
    h.orderdate::DATE                    AS fecha_orden,
    d.productid::INT                     AS product_id,
    d.orderqty::INT                      AS unidades_vendidas,
    d.unitprice::NUMERIC(12, 2)          AS precio_unitario,
    d.unitpricediscount::NUMERIC(12, 4)  AS descuento_unitario,
    d.linetotal::NUMERIC(14, 2)          AS ingreso_linea,
    CASE
        WHEN h.orderdate::DATE BETWEEN DATE '2013-07-01' AND DATE '2014-06-30'
        THEN TRUE
        ELSE FALSE
    END                                  AS en_ventana_12m
FROM sod AS d
INNER JOIN soh AS h
    ON d.salesorderid = h.salesorderid;


-- ----------------------------------------------------------------------------
-- 4. stg_proveedores_producto
-- Por qué importa para el negocio:
--   Un producto puede ser suministrado por más de un proveedor en pv. Aquí
--   resumimos a 1 fila por product_id para obtener cantidad de proveedores,
--   lead time promedio y mínimo (en días) y unidades actualmente en camino
--   (onorderqty), evitando duplicar filas al cruzar con el catálogo.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS stg_proveedores_producto;

CREATE TABLE stg_proveedores_producto AS
SELECT
    productid::INT                                      AS product_id,
    COUNT(DISTINCT businessentityid)                    AS cant_proveedores,
    ROUND(AVG(averageleadtime::NUMERIC), 1)             AS lead_time_promedio_dias,
    MIN(averageleadtime::INT)                           AS lead_time_min_dias,
    SUM(COALESCE(NULLIF(TRIM(onorderqty), '')::INT, 0)) AS unidades_en_camino
FROM pv
GROUP BY productid::INT;


-- ============================================================================
-- Verificación final: conteo de filas de las 4 tablas stg_* creadas
-- ============================================================================
SELECT 'stg_productos'            AS tabla, COUNT(*) AS filas FROM stg_productos
UNION ALL
SELECT 'stg_inventario'           AS tabla, COUNT(*) AS filas FROM stg_inventario
UNION ALL
SELECT 'stg_ventas'               AS tabla, COUNT(*) AS filas FROM stg_ventas
UNION ALL
SELECT 'stg_proveedores_producto' AS tabla, COUNT(*) AS filas FROM stg_proveedores_producto
ORDER BY tabla;
