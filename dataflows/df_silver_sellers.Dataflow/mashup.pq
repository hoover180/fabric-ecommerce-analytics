[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Bronze sellers_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared #"Bronze sellers" = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "Bronze.sellers", ItemKind = "Table"]}[Data],
  #"Changed column type" = Table.TransformColumnTypes(#"Navigation 2", {{"seller_zip_code_prefix", Int64.Type}}),
  #"Uppercased text" = Table.TransformColumns(#"Changed column type", {{"seller_state", each Text.Upper(_), type nullable text}})
in
  #"Uppercased text";
shared #"Bronze sellers_DataDestination" = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "c811303c-173d-4678-afcc-1ed657361bd9"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"]}[Data],
  Navigation_3 = Navigation_2{[Id = "Silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "sellers", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
