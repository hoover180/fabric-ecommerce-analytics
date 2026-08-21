CREATE TABLE [Gold].[gold_quality_log] (

	[check_name] varchar(100) NOT NULL, 
	[result] varchar(10) NOT NULL, 
	[detail] varchar(200) NULL, 
	[run_timestamp] datetime2(6) NOT NULL
);