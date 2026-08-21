[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze order_reviews_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze order_reviews" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.order_reviews", ItemKind = "Table"]}[Data],
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "review_score_clean", each try Number.From([review_score]) otherwise null), {{"review_score_clean", Int64.Type}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "review_score_valid", each if [review_score_clean] = null then 0 else 1), {{"review_score_valid", Int64.Type}}),
  #"Removed columns" = Table.RemoveColumns(#"Added custom 1", {"review_score"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"review_score_clean", "review_score"}})
in
  #"Renamed columns";
shared #"Bronze order_reviews_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "order_reviews", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
