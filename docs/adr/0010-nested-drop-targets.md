# Follow Flutter hit testing for nested targets

Route each incoming batch to one target. The innermost target that accepts at least one item receives the full batch, including rejected items. If no target accepts any item, the deepest target under the pointer receives an all-rejected result. Do not split one batch across targets. Accepted and rejected items retain source order.
