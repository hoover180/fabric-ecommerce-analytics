[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze order_items_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze order_items" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.order_items", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Bronze order_items_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "order_items", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
