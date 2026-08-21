[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared #"Bronze product_category_translation" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.product_category_translation", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze products_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze products" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.products", ItemKind = "Table"]}[Data],
  #"Merged queries" = Table.NestedJoin(#"Navigation 2", {"product_category_name"}, #"Bronze product_category_translation", {"product_category_name"}, "Bronze product_category_translation", JoinKind.LeftOuter),
  #"Expanded Bronze product_category_translation" = Table.ExpandTableColumn(#"Merged queries", "Bronze product_category_translation", {"product_category_name_english"}, {"product_category_name_english"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded Bronze product_category_translation", {{"product_category_name_english", "product_category_english"}, {"product_name_lenght", "product_name_length"}, {"product_description_lenght", "product_description_length"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"product_weight_g", Int64.Type}, {"product_length_cm", Int64.Type}, {"product_height_cm", Int64.Type}, {"product_width_cm", Int64.Type}, {"product_photos_qty", Int64.Type}})
in
  #"Changed column type";
shared #"Bronze products_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "products", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
