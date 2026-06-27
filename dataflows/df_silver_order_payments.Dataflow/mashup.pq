[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze order_payments_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze order_payments" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.order_payments", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"payment_value", type number}, {"payment_installments", Int64.Type}, {"payment_sequential", Int64.Type}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "payment_type_valid", each if List.Contains({"credit_card", "boleto", "voucher", "debit_card"}, [payment_type]) then 1 else 0), {{"payment_type_valid", Int64.Type}})
in
  #"Added custom";
shared #"Bronze order_payments_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "."]}[Data],
  Navigation_2 = Navigation_1{[lakehouseName = "ecommerce_lakehouse"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "order_payments", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
