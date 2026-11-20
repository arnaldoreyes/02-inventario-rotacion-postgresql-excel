-- ============================================================================
-- Proyecto 2: Inventario y rotación (AdventureWorks)
-- Capa: 05_validation
-- Script: validacion_inventario.sql
-- Propósito: Batería reproducible de auditoría sobre el modelo analítico en
--            el esquema por defecto (public) para validar calidad de datos,
--            cuadre cruzado y reproducción exacta de los KPIs del tablero
--            04_presentation/tablero_inventario_adventureworks.xlsx.
--
-- Naturaleza: SOLO LECTURA (no crea, modifica ni elimina tablas ni vistas).
-- Tablas auditadas (creadas por 03_modeling/01_crear_modelo_inventario.sql):
--   - mod_productos_inventario
--   - mod_ventas_12m_mensual
--   - mod_kpis_inventario
-- ============================================================================


-- ============================================================================
-- BLOQUE 1: CALIDAD DE DATOS (catálogo, ventana 12m, duplicados, nulos, signos)
-- Por qué importa para el negocio:
--   Un producto duplicado infla el stock y el capital inmovilizado; una fecha
--   fuera de ventana distorsiona la rotación anual; y valores negativos o
--   nulos en llaves rompen los cruces en Power Query y SUMIFS en Excel.
-- ============================================================================
SELECT
    check_id,
    prueba,
    valor_observado,
    valor_esperado,
    CASE WHEN valor_observado = valor_esperado THEN 'OK' ELSE 'FALLO' END AS estado
FROM (
    SELECT
        1 AS check_id,
        'Catálogo en mod_productos_inventario (filas)' AS prueba,
        COUNT(*)::TEXT AS valor_observado,
        '295' AS valor_esperado
    FROM mod_productos_inventario

    UNION ALL
    SELECT
        2,
        'Catálogo en mod_kpis_inventario (filas)',
        COUNT(*)::TEXT,
        '295'
    FROM mod_kpis_inventario

    UNION ALL
    SELECT
        3,
        'Duplicados por product_id en mod_productos_inventario',
        (COUNT(*) - COUNT(DISTINCT product_id))::TEXT,
        '0'
    FROM mod_productos_inventario

    UNION ALL
    SELECT
        4,
        'Duplicados por product_id en mod_kpis_inventario',
        (COUNT(*) - COUNT(DISTINCT product_id))::TEXT,
        '0'
    FROM mod_kpis_inventario

    UNION ALL
    SELECT
        5,
        'Duplicados por (anio_mes, product_id) en mod_ventas_12m_mensual',
        (COUNT(*) - COUNT(DISTINCT (anio_mes || '-' || product_id)))::TEXT,
        '0'
    FROM mod_ventas_12m_mensual

    UNION ALL
    SELECT
        6,
        'Cantidad de meses distintos en mod_ventas_12m_mensual',
        COUNT(DISTINCT anio_mes)::TEXT,
        '12'
    FROM mod_ventas_12m_mensual

    UNION ALL
    SELECT
        7,
        'Rango de ventana en mod_ventas_12m_mensual',
        MIN(anio_mes) || ' a ' || MAX(anio_mes),
        '2013-07 a 2014-06'
    FROM mod_ventas_12m_mensual

    UNION ALL
    SELECT
        8,
        'Nulos en columnas obligatorias de mod_kpis_inventario',
        COUNT(*) FILTER (
            WHERE product_id IS NULL
               OR categoria IS NULL
               OR stock_actual IS NULL
               OR valor_inventario IS NULL
               OR estado_inventario IS NULL
               OR clasificacion_abc IS NULL
        )::TEXT,
        '0'
    FROM mod_kpis_inventario

    UNION ALL
    SELECT
        9,
        'Valores negativos anómalos en mod_kpis_inventario',
        COUNT(*) FILTER (
            WHERE stock_actual < 0
               OR costo_estandar < 0
               OR valor_inventario < 0
               OR unidades_vendidas_12m < 0
               OR ingresos_12m < 0
               OR costo_ventas_12m < 0
               OR unidades_faltantes_reorden < 0
               OR costo_reposicion_reorden < 0
        )::TEXT,
        '0'
    FROM mod_kpis_inventario

    UNION ALL
    SELECT
        10,
        'Valores <= 0 o negativos anómalos en mod_ventas_12m_mensual',
        COUNT(*) FILTER (
            WHERE unidades_vendidas <= 0
               OR ingresos_12m < 0
               OR costo_ventas_12m < 0
        )::TEXT,
        '0'
    FROM mod_ventas_12m_mensual
) AS checks
ORDER BY check_id;

-- Nota diagnóstica sobre nulos esperados (no son error):
--   lead_time_promedio_dias es NULL en 212 de 295 productos porque son
--   artículos fabricados internamente sin proveedor externo en pv.
SELECT
    COUNT(*)                                                                AS total_productos,
    COUNT(*) FILTER (WHERE lead_time_promedio_dias IS NULL)                 AS sin_proveedor_externo_null,
    COUNT(*) FILTER (WHERE dias_cobertura IS NULL)                          AS sin_cobertura_cero_ventas,
    COUNT(*) FILTER (WHERE rotacion_anual IS NULL)                          AS sin_rotacion_cero_stock
FROM mod_kpis_inventario;


-- ============================================================================
-- BLOQUE 2: CUADRE CRUZADO (nivel producto vs serie mensual y catálogo base)
-- Por qué importa para el negocio:
--   Garantiza que la suma de ventas mensuales (hoja Ventas_12m) cuadre al
--   centavo contra el consolidado por producto (hoja Modelo_Inventario),
--   descartando pérdidas o duplicaciones en el LEFT JOIN o SUMIFS.
-- ============================================================================
WITH mensual AS (
    SELECT
        SUM(unidades_vendidas)        AS unidades_12m,
        ROUND(SUM(ingresos_12m), 2)   AS ingresos_12m,
        ROUND(SUM(costo_ventas_12m), 2) AS costo_ventas_12m
    FROM mod_ventas_12m_mensual
),
producto_kpi AS (
    SELECT
        SUM(unidades_vendidas_12m)    AS unidades_12m,
        ROUND(SUM(ingresos_12m), 2)   AS ingresos_12m,
        ROUND(SUM(costo_ventas_12m), 2) AS costo_ventas_12m,
        SUM(stock_actual)             AS stock_total,
        ROUND(SUM(valor_inventario), 2) AS valor_inventario
    FROM mod_kpis_inventario
),
producto_base AS (
    SELECT
        SUM(stock_actual)             AS stock_total,
        ROUND(SUM(valor_inventario), 2) AS valor_inventario
    FROM mod_productos_inventario
)
SELECT
    'Unidades vendidas 12m (producto vs mensual)' AS metrica,
    p.unidades_12m::NUMERIC(14, 2)                AS valor_producto,
    m.unidades_12m::NUMERIC(14, 2)                AS valor_contraste,
    (p.unidades_12m - m.unidades_12m)::NUMERIC(14, 2) AS diferencia,
    (p.unidades_12m = m.unidades_12m)             AS coincide
FROM producto_kpi AS p
CROSS JOIN mensual AS m

UNION ALL
SELECT
    'Ingresos 12m USD (producto vs mensual)',
    p.ingresos_12m,
    m.ingresos_12m,
    p.ingresos_12m - m.ingresos_12m,
    (p.ingresos_12m = m.ingresos_12m)
FROM producto_kpi AS p
CROSS JOIN mensual AS m

UNION ALL
SELECT
    'Costo de ventas 12m USD (producto vs mensual)',
    p.costo_ventas_12m,
    m.costo_ventas_12m,
    p.costo_ventas_12m - m.costo_ventas_12m,
    (p.costo_ventas_12m = m.costo_ventas_12m)
FROM producto_kpi AS p
CROSS JOIN mensual AS m

UNION ALL
SELECT
    'Stock actual unidades (kpis vs productos_inventario)',
    p.stock_total::NUMERIC(14, 2),
    b.stock_total::NUMERIC(14, 2),
    (p.stock_total - b.stock_total)::NUMERIC(14, 2),
    (p.stock_total = b.stock_total)
FROM producto_kpi AS p
CROSS JOIN producto_base AS b

UNION ALL
SELECT
    'Valor inventario USD (kpis vs productos_inventario)',
    p.valor_inventario,
    b.valor_inventario,
    p.valor_inventario - b.valor_inventario,
    (p.valor_inventario = b.valor_inventario)
FROM producto_kpi AS p
CROSS JOIN producto_base AS b;


-- ============================================================================
-- BLOQUE 3: REPRODUCCIÓN EXACTA DE KPIs EJECUTIVOS Y DESGLOSES DEL TABLERO
-- ============================================================================

-- 3A. Tarjetas KPI de la hoja Resumen_Ejecutivo
SELECT
    ROUND(SUM(ingresos_12m), 2)                                               AS ingresos_12m_usd,
    ROUND(SUM(ingresos_12m), 0)                                               AS ingresos_12m_redondeado,
    ROUND(SUM(valor_inventario), 2)                                           AS valor_inventario_usd,
    ROUND(SUM(valor_inventario), 0)                                           AS valor_inventario_redondeado,
    SUM(stock_actual)                                                         AS stock_total_unidades,
    ROUND(
        SUM(valor_inventario) FILTER (WHERE estado_inventario = 'Stock muerto'),
        2
    )                                                                         AS stock_muerto_usd,
    ROUND(
        SUM(valor_inventario) FILTER (WHERE estado_inventario = 'Stock muerto'),
        0
    )                                                                         AS stock_muerto_redondeado,
    ROUND(
        100.0 * SUM(valor_inventario) FILTER (WHERE estado_inventario = 'Stock muerto')
        / NULLIF(SUM(valor_inventario), 0),
        1
    )                                                                         AS pct_stock_muerto,
    COUNT(*) FILTER (WHERE estado_inventario = 'Quiebre de stock')            AS productos_en_quiebre,
    ROUND(
        SUM(ingresos_12m) FILTER (WHERE estado_inventario = 'Quiebre de stock'),
        2
    )                                                                         AS ingresos_12m_en_quiebre_usd,
    ROUND(
        SUM(ingresos_12m) FILTER (WHERE estado_inventario = 'Quiebre de stock'),
        0
    )                                                                         AS ingresos_12m_en_quiebre_redondeado,
    SUM(unidades_faltantes_reorden)                                           AS unidades_faltantes_reorden,
    ROUND(SUM(costo_reposicion_reorden), 2)                                   AS costo_reposicion_usd,
    ROUND(SUM(costo_reposicion_reorden), 0)                                   AS costo_reposicion_redondeado
FROM mod_kpis_inventario;

-- 3B. Resumen por estado_inventario (contraste contra Tablas_Dinamicas)
SELECT
    estado_inventario,
    COUNT(*)                                AS cant_productos,
    SUM(stock_actual)                       AS stock_total,
    ROUND(SUM(valor_inventario), 2)         AS valor_inventario_usd,
    ROUND(SUM(ingresos_12m), 2)             AS ingresos_12m_usd,
    ROUND(SUM(costo_reposicion_reorden), 2) AS costo_reposicion_usd
FROM mod_kpis_inventario
GROUP BY estado_inventario
ORDER BY valor_inventario_usd DESC, ingresos_12m_usd DESC;

-- 3C. Distribución Pareto ABC (contraste contra Tablas_Dinamicas y gráfico ABC)
SELECT
    clasificacion_abc,
    COUNT(*)                                                                  AS cant_productos,
    ROUND(SUM(ingresos_12m), 2)                                               AS ingresos_12m_usd,
    ROUND(
        100.0 * SUM(ingresos_12m)
        / NULLIF((SELECT SUM(ingresos_12m) FROM mod_kpis_inventario), 0),
        2
    )                                                                         AS pct_ingreso_total,
    ROUND(SUM(valor_inventario), 2)                                           AS valor_inventario_usd
FROM mod_kpis_inventario
GROUP BY clasificacion_abc
ORDER BY
    CASE clasificacion_abc
        WHEN 'A' THEN 1
        WHEN 'B' THEN 2
        WHEN 'C' THEN 3
        ELSE 4
    END;

-- 3D. Resumen por categoría (contraste contra gráfico Inventario vs Ingresos)
SELECT
    categoria,
    COUNT(*)                        AS cant_productos,
    ROUND(SUM(valor_inventario), 2) AS valor_inventario_usd,
    ROUND(SUM(ingresos_12m), 2)     AS ingresos_12m_usd
FROM mod_kpis_inventario
GROUP BY categoria
ORDER BY ingresos_12m_usd DESC;

-- 3E. Serie mensual de ingresos 12m (contraste contra gráfico Evolución Mensual)
SELECT
    anio_mes,
    SUM(unidades_vendidas)        AS unidades_vendidas,
    ROUND(SUM(ingresos_12m), 2)   AS ingresos_12m_usd,
    ROUND(SUM(costo_ventas_12m), 2) AS costo_ventas_12m_usd
FROM mod_ventas_12m_mensual
GROUP BY anio_mes
ORDER BY anio_mes;
