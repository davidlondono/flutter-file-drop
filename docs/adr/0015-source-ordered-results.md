# Preserve source order in drop results

`DropResult.items` will contain one accepted or rejected outcome for each source item, in original source order. Rejected outcomes include their item and typed rejection reasons. `accepted` and `rejected` convenience views will be available.
