CREATE TABLE [Gold].[dim_customers] (

	[customer_key] varchar(32) NOT NULL, 
	[customer_unique_id] varchar(50) NOT NULL, 
	[customer_city] varchar(100) NULL, 
	[customer_state] varchar(2) NULL, 
	[customer_state_country] varchar(40) NULL, 
	[geolocation_lat] float NULL, 
	[geolocation_lng] float NULL
);