CREATE TABLE [dbo].[fact_orders] (

	[order_item_key] varchar(32) NOT NULL, 
	[order_id] varchar(50) NOT NULL, 
	[order_item_id] int NOT NULL, 
	[customer_key] varchar(32) NOT NULL, 
	[seller_key] varchar(32) NOT NULL, 
	[product_key] varchar(32) NOT NULL, 
	[order_date_key] int NULL, 
	[delivery_date_key] int NULL, 
	[estimated_delivery_date_key] int NULL, 
	[price] decimal(10,2) NULL, 
	[freight_value] decimal(10,2) NULL, 
	[payment_value] decimal(10,2) NULL, 
	[review_score] smallint NULL, 
	[delivery_days] int NULL, 
	[days_late] int NULL, 
	[is_late] smallint NULL, 
	[is_delivered] smallint NULL, 
	[order_status] varchar(20) NULL
);