[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze orders_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze orders" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.orders", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "delivery_days", each if [order_delivered_customer_date] <> null then Duration.Days([order_delivered_customer_date] - [order_purchase_timestamp]) else null), {{"delivery_days", Int64.Type}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "is_late", each if [order_delivered_customer_date] <> null and [order_delivered_customer_date] > [order_estimated_delivery_date] then 1 else 0), {{"is_late", Int64.Type}}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "days_late", each if [order_delivered_customer_date] <> null then Duration.Days([order_delivered_customer_date] - [order_estimated_delivery_date]) else null), {{"days_late", Int64.Type}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "is_delivered", each if [order_delivered_customer_date] = null then 0 else 1), {{"is_delivered", Int64.Type}})
in
  #"Added custom 3";
shared #"Bronze orders_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "orders", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
