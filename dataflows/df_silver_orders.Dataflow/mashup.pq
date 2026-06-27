[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze orders_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze orders" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "Bronze.orders", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 3", "delivery_days", each Duration.Days([order_delivered_customer_date] - [order_purchase_timestamp])), {{"delivery_days", Int64.Type}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "is_late", each if [order_delivered_customer_date] <> null and [order_delivered_customer_date] > [order_estimated_delivery_date] then 1 else 0), {{"is_late", Int64.Type}}),
  #"Added custom 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "days_late", each if [order_delivered_customer_date] <> null then Duration.Days([order_delivered_customer_date] - [order_estimated_delivery_date]) else null), {{"days_late", Int64.Type}}),
  #"Added custom 3" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 2", "is_delivered", each if [order_delivered_customer_date] = null then 0 else 1), {{"is_delivered", Int64.Type}})
in
  #"Added custom 3";
shared #"Bronze orders_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "orders", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
