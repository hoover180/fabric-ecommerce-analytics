CREATE TABLE [dbo].[dim_products] (

	[product_key] varchar(32) NOT NULL, 
	[product_id] varchar(50) NOT NULL, 
	[product_category_english] varchar(100) NULL, 
	[product_weight_g] int NULL, 
	[product_length_cm] int NULL, 
	[product_height_cm] int NULL, 
	[product_width_cm] int NULL
);