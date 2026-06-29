CREATE TABLE [dbo].[dim_date] (

	[date_key] int NOT NULL, 
	[full_date] date NOT NULL, 
	[year] smallint NOT NULL, 
	[quarter] smallint NOT NULL, 
	[quarter_name] varchar(10) NOT NULL, 
	[month] smallint NOT NULL, 
	[month_name] varchar(20) NOT NULL, 
	[month_year] varchar(10) NOT NULL, 
	[week_of_year] smallint NOT NULL, 
	[day_of_month] smallint NOT NULL, 
	[day_of_week] smallint NOT NULL, 
	[day_name] varchar(20) NOT NULL, 
	[is_weekend] bit NOT NULL, 
	[is_month_end] bit NOT NULL, 
	[year_offset] smallint NOT NULL
);