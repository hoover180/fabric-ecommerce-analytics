CREATE TABLE [dbo].[dim_sellers] (

	[seller_key] varchar(32) NOT NULL, 
	[seller_id] varchar(50) NOT NULL, 
	[seller_city] varchar(100) NULL, 
	[seller_state] varchar(2) NULL, 
	[geolocation_lat] float NULL, 
	[geolocation_lng] float NULL, 
	[total_orders] int NULL, 
	[on_time_rate] float NULL, 
	[avg_review_score] float NULL
);