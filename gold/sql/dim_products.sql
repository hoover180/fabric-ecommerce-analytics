-- =============================================================
-- Table: dim_products
-- Grain: One row per product (product_id)
-- Source: Silver.products (English category joined at Silver layer)
-- Surrogate key: product_key (MD5 hash of product_id)
-- SCD Type: 1 (overwrite on reload)
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

DROP TABLE IF EXISTS dbo.dim_products;

CREATE TABLE dbo.dim_products (
    product_key                 VARCHAR(32)     NOT NULL,
    product_id                  VARCHAR(50)     NOT NULL,
    product_category_english    VARCHAR(100)    NULL,
    product_weight_g            INTEGER         NULL,
    product_length_cm           INTEGER         NULL,
    product_height_cm           INTEGER         NULL,
    product_width_cm            INTEGER         NULL
);

INSERT INTO dbo.dim_products (
    product_key, product_id, product_category_english,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm
)
SELECT
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', product_id), 2))    AS product_key,
    product_id,
    product_category_english,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM ecommerce_lakehouse.Silver.products;