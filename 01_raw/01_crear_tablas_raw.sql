-- ============================================================================
-- Proyecto 2: Inventario y rotación (AdventureWorks)
-- Capa: 01_raw
-- Script: 01_crear_tablas_raw.sql
-- Propósito: Limpiar el esquema raw previo (si existe) y crear las 9 tablas
--            de aterrizaje en texto plano directamente en el esquema por
--            defecto (public).
--
-- Decisiones de diseño:
--   1. Todas las columnas se definen como TEXT para garantizar que los CSV
--      entren sin errores de tipado ni pérdida de información original.
--      El tipado, limpieza de nulos y normalización se hacen en 02_staging.
--   2. Los nombres de columna conservan exactamente los encabezados de cada
--      CSV en minúsculas y sin comillas (espejo 1:1 de la fuente).
--   3. El script es idempotente: elimina y recrea las tablas si ya existen.
-- ============================================================================

-- Limpieza del esquema raw creado anteriormente (si existe)
DROP SCHEMA IF EXISTS raw CASCADE;

-- ----------------------------------------------------------------------------
-- 1. cat (origen: 01_raw/entrada/cat.csv — 4 columnas, 4 filas esperadas)
--    Tabla AdventureWorks: Production.ProductCategory
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS cat;

CREATE TABLE cat (
    productcategoryid TEXT,
    name              TEXT,
    rowguid           TEXT,
    modifieddate      TEXT
);

-- ----------------------------------------------------------------------------
-- 2. inv (origen: 01_raw/entrada/inv.csv — 7 columnas, 1.069 filas esperadas)
--    Tabla AdventureWorks: Production.ProductInventory
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS inv;

CREATE TABLE inv (
    productid    TEXT,
    locationid   TEXT,
    shelf        TEXT,
    bin          TEXT,
    quantity     TEXT,
    rowguid      TEXT,
    modifieddate TEXT
);

-- ----------------------------------------------------------------------------
-- 3. product (origen: 01_raw/entrada/product.csv — 25 columnas, 504 filas)
--    Tabla AdventureWorks: Production.Product
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS product;

CREATE TABLE product (
    productid             TEXT,
    name                  TEXT,
    productnumber         TEXT,
    makeflag              TEXT,
    finishedgoodsflag     TEXT,
    color                 TEXT,
    safetystocklevel      TEXT,
    reorderpoint          TEXT,
    standardcost          TEXT,
    listprice             TEXT,
    size                  TEXT,
    sizeunitmeasurecode   TEXT,
    weightunitmeasurecode TEXT,
    weight                TEXT,
    daystomanufacture     TEXT,
    productline           TEXT,
    class                 TEXT,
    style                 TEXT,
    productsubcategoryid  TEXT,
    productmodelid        TEXT,
    sellstartdate         TEXT,
    sellenddate           TEXT,
    discontinueddate      TEXT,
    rowguid               TEXT,
    modifieddate          TEXT
);

-- ----------------------------------------------------------------------------
-- 4. pv (origen: 01_raw/entrada/pv.csv — 11 columnas, 460 filas esperadas)
--    Tabla AdventureWorks: Purchasing.ProductVendor
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS pv;

CREATE TABLE pv (
    productid        TEXT,
    businessentityid TEXT,
    averageleadtime  TEXT,
    standardprice    TEXT,
    lastreceiptcost  TEXT,
    lastreceiptdate  TEXT,
    minorderqty      TEXT,
    maxorderqty      TEXT,
    onorderqty       TEXT,
    unitmeasurecode  TEXT,
    modifieddate     TEXT
);

-- ----------------------------------------------------------------------------
-- 5. sod (origen: 01_raw/entrada/sod.csv — 11 columnas, 121.317 filas)
--    Tabla AdventureWorks: Sales.SalesOrderDetail
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS sod;

CREATE TABLE sod (
    salesorderid          TEXT,
    salesorderdetailid    TEXT,
    carriertrackingnumber TEXT,
    orderqty              TEXT,
    productid             TEXT,
    specialofferid        TEXT,
    unitprice             TEXT,
    unitpricediscount     TEXT,
    linetotal             TEXT,
    rowguid               TEXT,
    modifieddate          TEXT
);

-- ----------------------------------------------------------------------------
-- 6. soh (origen: 01_raw/entrada/soh.csv — 26 columnas, 31.465 filas)
--    Tabla AdventureWorks: Sales.SalesOrderHeader
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS soh;

CREATE TABLE soh (
    salesorderid           TEXT,
    revisionnumber         TEXT,
    orderdate              TEXT,
    duedate                TEXT,
    shipdate               TEXT,
    status                 TEXT,
    onlineorderflag        TEXT,
    salesordernumber       TEXT,
    purchaseordernumber    TEXT,
    accountnumber          TEXT,
    customerid             TEXT,
    salespersonid          TEXT,
    territoryid            TEXT,
    billtoaddressid        TEXT,
    shiptoaddressid        TEXT,
    shipmethodid           TEXT,
    creditcardid           TEXT,
    creditcardapprovalcode TEXT,
    currencyrateid         TEXT,
    subtotal               TEXT,
    taxamt                 TEXT,
    freight                TEXT,
    totaldue               TEXT,
    comment                TEXT,
    rowguid                TEXT,
    modifieddate           TEXT
);

-- ----------------------------------------------------------------------------
-- 7. subcat (origen: 01_raw/entrada/subcat.csv — 5 columnas, 37 filas)
--    Tabla AdventureWorks: Production.ProductSubcategory
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS subcat;

CREATE TABLE subcat (
    productsubcategoryid TEXT,
    productcategoryid    TEXT,
    name                 TEXT,
    rowguid              TEXT,
    modifieddate         TEXT
);

-- ----------------------------------------------------------------------------
-- 8. vendor (origen: 01_raw/entrada/vendor.csv — 8 columnas, 104 filas)
--    Tabla AdventureWorks: Purchasing.Vendor
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS vendor;

CREATE TABLE vendor (
    businessentityid        TEXT,
    accountnumber           TEXT,
    name                    TEXT,
    creditrating            TEXT,
    preferredvendorstatus   TEXT,
    activeflag              TEXT,
    purchasingwebserviceurl TEXT,
    modifieddate            TEXT
);

-- ----------------------------------------------------------------------------
-- 9. vva (origen: 01_raw/entrada/vva.csv — 9 columnas, 104 filas)
--    Tabla AdventureWorks: Purchasing.vVendorWithAddresses
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS vva;

CREATE TABLE vva (
    businessentityid  TEXT,
    name              TEXT,
    addresstype       TEXT,
    addressline1      TEXT,
    addressline2      TEXT,
    city              TEXT,
    stateprovincename TEXT,
    postalcode        TEXT,
    countryregionname TEXT
);
