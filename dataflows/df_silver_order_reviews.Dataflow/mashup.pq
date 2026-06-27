[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze order_reviews_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze order_reviews" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "3495450c-33ef-49d4-8a7f-28b3e585e76f"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "711ad228-eb05-4584-b246-c30b0c4209a8"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.order_reviews", ItemKind = "Table"]}[Data],
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Navigation 2", "review_score_clean", each try Number.From([review_score]) otherwise null), {{"review_score_clean", Int64.Type}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom 1", "review_score_valid ", each if [review_score_clean] = null then 0
  else if [review_score_clean] >= 1 and [review_score_clean] <= 5 then 1
  else 0), {{"review_score_valid ", Int64.Type}}),
  #"Removed columns" = Table.RemoveColumns(#"Added custom", {"review_score"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"review_score_clean", "review_score"}})
in
  #"Renamed columns";
shared #"Bronze order_reviews_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "."]}[Data],
  Navigation_2 = Navigation_1{[lakehouseName = "ecommerce_lakehouse"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "order_reviews", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
