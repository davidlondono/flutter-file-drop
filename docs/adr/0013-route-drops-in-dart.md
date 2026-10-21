# Capture native drops at the host view and route in Dart

Each platform will capture incoming drag events at its Flutter host view or window and send drag positions and item handles to Dart. Dart will route those events to registered `DropTarget` bounds through Flutter hit testing. The package will not create a native overlay view for each target.

This keeps target selection consistent across platforms and supports nested targets. The innermost target that accepts at least one item receives the full batch. If no target accepts any item, the deepest target under the pointer receives an all-rejected result. Do not split one batch across targets.
