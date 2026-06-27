[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze products_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze products" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.products", ItemKind = "Table"]}[Data],
  #"Merged queries" = Table.NestedJoin(#"Navigation 2", {"product_category_name"}, #"Bronze product_category_translation", {"product_category_name"}, "Bronze product_category_translation", JoinKind.LeftOuter),
  #"Expanded Bronze product_category_translation" = Table.ExpandTableColumn(#"Merged queries", "Bronze product_category_translation", {"product_category_name_english"}, {"product_category_name_english"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded Bronze product_category_translation", {{"product_category_name_english", "product_category_english"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"product_weight_g", Int64.Type}, {"product_length_cm", Int64.Type}, {"product_height_cm", Int64.Type}, {"product_width_cm", Int64.Type}, {"product_photos_qty", Int64.Type}})
in
  #"Changed column type";
shared #"Bronze product_category_translation" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.product_category_translation", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared #"Bronze products_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "products", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
