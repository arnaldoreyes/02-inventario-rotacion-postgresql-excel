-- ============================================================================
-- Proyecto 2: Inventario y rotación (AdventureWorks)
-- Capa: 02_staging
-- Script: 01_perfilado_datos.sql
-- Propósito: Perfilar las 9 tablas crudas cargadas en el esquema por defecto
--            (public) antes de construir las vistas limpias stg_*.
--
-- Naturaleza: SOLO LECTURA (no crea, modifica ni elimina tablas ni vistas).
-- Nota de ejecución: En pgAdmin 4 puedes seleccionar y ejecutar cada consulta
--                    por separado para revisar cada bloque de resultados.
-- ============================================================================


-- ============================================================================
-- 1. Rango de fechas y estados en soh (cabecera de pedidos de venta)
-- Por qué importa para el negocio:
--   Antes de medir rotación debemos verificar qué periodo cubre el historial,
--   si existen pedidos cancelados o incompletos (status) y confirmar que la
--   ventana de 12 meses (2013-07 a 2014-06) tiene volumen comparable.
-- ============================================================================

-- 1A. Fecha mínima, fecha máxima y total de órdenes agrupado por status
SELECT
    status,
    COUNT(*)       AS total_ordenes,
    MIN(orderdate) AS fecha_minima,
    MAX(orderdate) AS fecha_maxima
FROM soh
GROUP BY status
ORDER BY status;

-- 1B. Conteo mensual de órdenes para revisar la evolución y la ventana 12m
SELECT
    LEFT(orderdate, 7) AS anio_mes,
    COUNT(*)           AS total_ordenes,
    CASE
        WHEN LEFT(orderdate, 7) BETWEEN '2013-07' AND '2014-06' THEN 'Sí'
        ELSE 'No'
    END                AS en_ventana_12m
FROM soh
GROUP BY LEFT(orderdate, 7)
ORDER BY anio_mes;


-- ============================================================================
-- 2. Perfil de productos en product (catálogo maestro)
-- Por qué importa para el negocio:
--   AdventureWorks mezcla piezas internas/componentes con productos terminados
--   destinados a la venta (finishedgoodsflag = 'True'). Además, productos sin
--   costo estándar o sin subcategoría distorsionan el cálculo de rotación si
--   no se detectan a tiempo.
-- ============================================================================
SELECT
    finishedgoodsflag,
    COUNT(*) AS total_productos,
    SUM(
        CASE
            WHEN NULLIF(TRIM(standardcost), '') IS NULL
              OR NULLIF(TRIM(standardcost), '')::NUMERIC = 0
            THEN 1 ELSE 0
        END
    ) AS sin_costo_estandar_o_cero,
    SUM(
        CASE
            WHEN NULLIF(TRIM(listprice), '') IS NULL
              OR NULLIF(TRIM(listprice), '')::NUMERIC = 0
            THEN 1 ELSE 0
        END
    ) AS sin_precio_lista_o_cero,
    SUM(
        CASE
            WHEN NULLIF(TRIM(productsubcategoryid), '') IS NULL
            THEN 1 ELSE 0
        END
    ) AS sin_subcategoria
FROM product
GROUP BY finishedgoodsflag
ORDER BY finishedgoodsflag;


-- ============================================================================
-- 3. Perfil de inventario en inv (foto actual de stock por almacén)
-- Por qué importa para el negocio:
--   Un mismo producto puede estar repartido en varios almacenes (locationid).
--   Aquí comprobamos el tamaño de la foto de inventario, los extremos de stock
--   y si existen filas con cantidad cero o negativa.
-- ============================================================================
SELECT
    COUNT(*)                                           AS total_filas,
    COUNT(DISTINCT productid)                          AS productos_distintos,
    COUNT(DISTINCT locationid)                         AS ubicaciones_distintas,
    MIN(quantity::INT)                                 AS stock_minimo,
    MAX(quantity::INT)                                 AS stock_maximo,
    SUM(quantity::INT)                                 AS unidades_totales_stock,
    SUM(CASE WHEN quantity::INT <= 0 THEN 1 ELSE 0 END) AS filas_con_stock_cero_o_negativo
FROM inv;


-- ============================================================================
-- 4. Cruce rápido de cobertura de catálogo (product vs inv vs sod)
-- Por qué importa para el negocio:
--   Queremos saber cuántos productos terminados (finishedgoodsflag = 'True')
--   tienen inventario registrado, cuántos registran al menos una venta y
--   cuántos tienen stock parado en almacén con cero ventas (riesgo de stock
--   muerto).
--
-- Nota técnica sobre las CTEs:
--   Se usan dos CTEs (tablas temporales solo para esta consulta) para resumir
--   inv y sod a nivel de 1 fila por productid antes del LEFT JOIN. Así
--   evitamos multiplicar las filas del catálogo product al cruzar.
-- ============================================================================
WITH inv_por_producto AS (
    SELECT
        productid,
        SUM(quantity::INT) AS stock_total
    FROM inv
    GROUP BY productid
),
sod_por_producto AS (
    SELECT DISTINCT
        productid
    FROM sod
)
SELECT
    COUNT(*)                                                                 AS productos_terminados,
    SUM(CASE WHEN i.productid IS NOT NULL THEN 1 ELSE 0 END)                 AS existen_en_inv,
    SUM(CASE WHEN s.productid IS NOT NULL THEN 1 ELSE 0 END)                 AS con_al_menos_una_venta_en_sod,
    SUM(
        CASE
            WHEN COALESCE(i.stock_total, 0) > 0
             AND s.productid IS NULL
            THEN 1 ELSE 0
        END
    )                                                                        AS con_stock_en_inv_y_cero_ventas
FROM product AS p
LEFT JOIN inv_por_producto AS i
    ON p.productid = i.productid
LEFT JOIN sod_por_producto AS s
    ON p.productid = s.productid
WHERE p.finishedgoodsflag = 'True';


-- ============================================================================
-- 5. Proveedores por producto en pv (relación producto–proveedor y lead time)
-- Por qué importa para el negocio:
--   El punto de reorden y la alerta de quiebre dependen del tiempo de entrega
--   del proveedor (averageleadtime, en días). Si un producto tiene más de un
--   proveedor, deberemos definir una regla clara de agregación en el modelo
--   para no duplicar filas al cruzar.
--
-- Nota técnica sobre la CTE:
--   La CTE proveedores_por_producto agrupa primero por productid para contar
--   cuántos proveedores distintos tiene cada producto y sus extremos de lead
--   time; luego la consulta externa entrega el resumen global en una sola fila.
-- ============================================================================
WITH proveedores_por_producto AS (
    SELECT
        productid,
        COUNT(*)                         AS filas_pv,
        COUNT(DISTINCT businessentityid) AS cant_proveedores,
        MIN(averageleadtime::INT)        AS lead_time_min,
        MAX(averageleadtime::INT)        AS lead_time_max
    FROM pv
    GROUP BY productid
)
SELECT
    SUM(filas_pv)                                               AS total_filas_pv,
    COUNT(productid)                                            AS productos_distintos_en_pv,
    SUM(CASE WHEN cant_proveedores > 1 THEN 1 ELSE 0 END)       AS productos_con_mas_de_1_proveedor,
    MIN(lead_time_min)                                          AS lead_time_minimo_dias,
    MAX(lead_time_max)                                          AS lead_time_maximo_dias
FROM proveedores_por_producto;
