[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze customers_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze customers" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.customers", ItemKind = "Table"]}[Data],
  #"Uppercased text" = Table.TransformColumns(#"Navigation 2", {{"customer_state", each Text.Upper(_), type nullable text}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Uppercased text", "has_zip", each if [customer_zip_code_prefix] = null then false else true), {{"has_zip", type logical}})
in
  #"Added custom";
shared #"Bronze customers_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "."]}[Data],
  Navigation_2 = Navigation_1{[lakehouseName = "ecommerce_lakehouse"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "customers", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
