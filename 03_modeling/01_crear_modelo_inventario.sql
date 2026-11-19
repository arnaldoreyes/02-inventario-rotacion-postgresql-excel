-- ============================================================================
-- Proyecto 2: Inventario y rotación (AdventureWorks)
-- Capa: 03_modeling
-- Script: 01_crear_modelo_inventario.sql
-- Propósito: Construir las 3 tablas analíticas del modelo de inventario en el
--            esquema por defecto (public) a partir de las 4 tablas stg_*.
--
-- Tablas que construye (idempotente con DROP TABLE IF EXISTS):
--   1. mod_productos_inventario  (295 filas: catálogo + stock + proveedores)
--   2. mod_ventas_12m_mensual    (ventas mensuales de la ventana 2013-07 a 2014-06)
--   3. mod_kpis_inventario       (295 filas: cobertura, rotación, reorden y ABC)
--
-- Limitaciones declaradas:
--   - El costo de ventas se aproxima con costo_estandar (no costo real FIFO/LIFO).
--   - El stock actual es una foto (no serie histórica); la rotación usa el
--     valor del stock actual como aproximación del inventario promedio.
--   - Ventana analítica comparable: 12 meses (2013-07-01 a 2014-06-30).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. mod_productos_inventario (1 fila por producto terminado = 295 filas)
-- Por qué importa para el negocio:
--   Reúne en una sola tabla maestra la ficha del producto, su stock actual
--   consolidado, cuánto dinero está invertido en ese stock (valor_inventario),
--   los umbrales oficiales de reposición y los datos de proveedores.
--   Se usa LEFT JOIN desde stg_productos para NO perder productos sin stock
--   o fabricados internamente (sin proveedor externo en pv).
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mod_productos_inventario;

CREATE TABLE mod_productos_inventario AS
SELECT
    p.product_id,
    p.nombre_producto,
    p.codigo_producto,
    p.categoria,
    p.subcategoria,
    p.costo_estandar,
    p.precio_lista,
    COALESCE(i.stock_actual, 0)::INT                           AS stock_actual,
    ROUND(COALESCE(i.stock_actual, 0) * p.costo_estandar, 2)   AS valor_inventario,
    p.punto_reorden_oficial                                    AS punto_reorden,
    p.stock_seguridad_oficial                                  AS stock_seguridad,
    pv.lead_time_promedio_dias,
    COALESCE(pv.unidades_en_camino, 0)::INT                    AS unidades_en_camino
FROM stg_productos AS p
LEFT JOIN stg_inventario AS i
    ON p.product_id = i.product_id
LEFT JOIN stg_proveedores_producto AS pv
    ON p.product_id = pv.product_id;


-- ----------------------------------------------------------------------------
-- 2. mod_ventas_12m_mensual (ventas mensuales 2013-07 a 2014-06)
-- Por qué importa para el negocio:
--   Resume la demanda real de los últimos 12 meses comparables a nivel
--   mes–producto. Esta tabla alimentará tanto los KPIs de rotación/cobertura
--   como las series mensuales y tablas dinámicas del libro de Excel.
--   El INNER JOIN con stg_productos asegura que solo entren productos
--   terminados y trae el costo_estandar para calcular el costo de ventas.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mod_ventas_12m_mensual;

CREATE TABLE mod_ventas_12m_mensual AS
SELECT
    DATE_TRUNC('month', v.fecha_orden)::DATE                  AS mes_fecha,
    TO_CHAR(v.fecha_orden, 'YYYY-MM')                         AS anio_mes,
    v.product_id,
    SUM(v.unidades_vendidas)::INT                             AS unidades_vendidas,
    ROUND(SUM(v.ingreso_linea), 2)                            AS ingresos_12m,
    ROUND(SUM(v.unidades_vendidas * p.costo_estandar), 2)     AS costo_ventas_12m
FROM stg_ventas AS v
INNER JOIN stg_productos AS p
    ON v.product_id = p.product_id
WHERE v.en_ventana_12m = TRUE
GROUP BY
    DATE_TRUNC('month', v.fecha_orden)::DATE,
    TO_CHAR(v.fecha_orden, 'YYYY-MM'),
    v.product_id;


-- ----------------------------------------------------------------------------
-- 3. mod_kpis_inventario (1 fila por producto terminado = 295 filas)
-- Por qué importa para el negocio:
--   Es la tabla operativa central para responder las preguntas de negocio:
--     - Cobertura (días): para cuántos días alcanza el stock actual al ritmo
--       de venta diaria de los últimos 12 meses (foto de hoy).
--     - Rotación anual (veces): cuántas veces se vendió/repuso el valor del
--       inventario en 12 meses (costo_ventas_12m / valor_inventario).
--     - Estado y reorden: clasifica cada producto según riesgo de quiebre,
--       necesidad de pedido o stock muerto, y estima el costo de reposición.
--     - Clasificación ABC (Pareto): identifica el grupo 'A' (productos que
--       concentran hasta el 80 % de los ingresos) para priorizar control.
--
-- Cómo leer las CTEs y la función ventana de este bloque:
--   - ventas_12m_por_producto: suma los 12 meses a 1 fila por producto.
--   - base_kpis: cruza con mod_productos_inventario vía LEFT JOIN (para no
--     perder los productos con cero ventas) y calcula cobertura, rotación y
--     estado_inventario.
--   - con_reorden_y_abc:
--       * Calcula las unidades faltantes para alcanzar el punto de reorden.
--       * Usa dos funciones ventana (OVER) para el ABC sin colapsar filas:
--           1) SUM(ingresos_12m) OVER (ORDER BY ingresos_12m DESC, product_id)
--              suma los ingresos acumulados ordenando de mayor a menor venta
--              (product_id sirve de desempate para que el acumulado sea exacto).
--           2) SUM(ingresos_12m) OVER ()
--              calcula el ingreso total de los 295 productos en cada fila.
--         Al dividir (1) / (2) obtenemos pct_acumulado_ingresos (0 a 1):
--         <= 0.80 es clase 'A', <= 0.95 es 'B' y el resto con ventas es 'C'.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mod_kpis_inventario;

CREATE TABLE mod_kpis_inventario AS
WITH ventas_12m_por_producto AS (
    SELECT
        product_id,
        SUM(unidades_vendidas)::INT     AS unidades_vendidas_12m,
        ROUND(SUM(ingresos_12m), 2)     AS ingresos_12m,
        ROUND(SUM(costo_ventas_12m), 2) AS costo_ventas_12m
    FROM mod_ventas_12m_mensual
    GROUP BY product_id
),
base_kpis AS (
    SELECT
        m.product_id,
        m.nombre_producto,
        m.codigo_producto,
        m.categoria,
        m.subcategoria,
        m.costo_estandar,
        m.precio_lista,
        m.stock_actual,
        m.valor_inventario,
        m.punto_reorden,
        m.stock_seguridad,
        m.lead_time_promedio_dias,
        m.unidades_en_camino,
        COALESCE(v.unidades_vendidas_12m, 0)                      AS unidades_vendidas_12m,
        COALESCE(v.ingresos_12m, 0)::NUMERIC(14, 2)               AS ingresos_12m,
        COALESCE(v.costo_ventas_12m, 0)::NUMERIC(14, 2)           AS costo_ventas_12m,
        ROUND(COALESCE(v.unidades_vendidas_12m, 0) / 365.0, 4)    AS venta_diaria_promedio,
        CASE
            WHEN COALESCE(v.unidades_vendidas_12m, 0) > 0
            THEN ROUND(
                m.stock_actual / (COALESCE(v.unidades_vendidas_12m, 0) / 365.0),
                1
            )
            ELSE NULL
        END                                                       AS dias_cobertura,
        CASE
            WHEN m.valor_inventario > 0
            THEN ROUND(COALESCE(v.costo_ventas_12m, 0) / m.valor_inventario, 2)
            ELSE NULL
        END                                                       AS rotacion_anual,
        CASE
            WHEN m.stock_actual > 0 AND COALESCE(v.unidades_vendidas_12m, 0) = 0
                THEN 'Stock muerto'
            WHEN m.stock_actual = 0 AND COALESCE(v.unidades_vendidas_12m, 0) = 0
                THEN 'Sin stock ni ventas'
            WHEN m.stock_actual = 0 AND COALESCE(v.unidades_vendidas_12m, 0) > 0
                THEN 'Quiebre de stock'
            WHEN m.stock_actual > 0 AND m.stock_actual <= m.punto_reorden
                THEN 'Reordenar'
            ELSE 'OK'
        END                                                       AS estado_inventario
    FROM mod_productos_inventario AS m
    LEFT JOIN ventas_12m_por_producto AS v
        ON m.product_id = v.product_id
),
con_reorden_y_abc AS (
    SELECT
        b.*,
        CASE
            WHEN b.estado_inventario IN ('Quiebre de stock', 'Reordenar')
            THEN GREATEST(b.punto_reorden - b.stock_actual, 0)
            ELSE 0
        END                                                       AS unidades_faltantes_reorden,
        CASE
            WHEN b.ingresos_12m = 0 THEN NULL
            ELSE ROUND(
                SUM(b.ingresos_12m) OVER (ORDER BY b.ingresos_12m DESC, b.product_id)
                / NULLIF(SUM(b.ingresos_12m) OVER (), 0),
                4
            )
        END                                                       AS pct_acumulado_ingresos
    FROM base_kpis AS b
)
SELECT
    product_id,
    nombre_producto,
    codigo_producto,
    categoria,
    subcategoria,
    costo_estandar,
    precio_lista,
    stock_actual,
    valor_inventario,
    punto_reorden,
    stock_seguridad,
    lead_time_promedio_dias,
    unidades_en_camino,
    unidades_vendidas_12m,
    ingresos_12m,
    costo_ventas_12m,
    venta_diaria_promedio,
    dias_cobertura,
    rotacion_anual,
    estado_inventario,
    unidades_faltantes_reorden,
    ROUND(unidades_faltantes_reorden * costo_estandar, 2)         AS costo_reposicion_reorden,
    pct_acumulado_ingresos,
    CASE
        WHEN ingresos_12m = 0              THEN 'Sin ventas'
        WHEN pct_acumulado_ingresos <= 0.80 THEN 'A'
        WHEN pct_acumulado_ingresos <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                           AS clasificacion_abc
FROM con_reorden_y_abc;


-- ============================================================================
-- Consultas de verificación (ejecutar cada bloque en pgAdmin 4)
-- ============================================================================

-- Verificación 1: Conteo de filas de las 3 tablas mod_*
SELECT 'mod_productos_inventario' AS tabla, COUNT(*) AS filas FROM mod_productos_inventario
UNION ALL
SELECT 'mod_ventas_12m_mensual'   AS tabla, COUNT(*) AS filas FROM mod_ventas_12m_mensual
UNION ALL
SELECT 'mod_kpis_inventario'      AS tabla, COUNT(*) AS filas FROM mod_kpis_inventario
ORDER BY tabla;

-- Verificación 2: Resumen agrupado por estado_inventario
SELECT
    estado_inventario,
    COUNT(*)                        AS cant_productos,
    SUM(stock_actual)               AS stock_total,
    ROUND(SUM(valor_inventario), 2) AS valor_inventario_usd,
    ROUND(SUM(ingresos_12m), 2)     AS ingresos_12m_usd
FROM mod_kpis_inventario
GROUP BY estado_inventario
ORDER BY valor_inventario_usd DESC;

-- Verificación 3: Resumen agrupado por clasificacion_abc
SELECT
    clasificacion_abc,
    COUNT(*)                                                                  AS cant_productos,
    ROUND(SUM(ingresos_12m), 2)                                               AS ingresos_12m_usd,
    ROUND(
        100.0 * SUM(ingresos_12m)
        / NULLIF((SELECT SUM(ingresos_12m) FROM mod_kpis_inventario), 0),
        2
    )                                                                         AS pct_ingreso_total
FROM mod_kpis_inventario
GROUP BY clasificacion_abc
ORDER BY
    CASE clasificacion_abc
        WHEN 'A' THEN 1
        WHEN 'B' THEN 2
        WHEN 'C' THEN 3
        ELSE 4
    END;
