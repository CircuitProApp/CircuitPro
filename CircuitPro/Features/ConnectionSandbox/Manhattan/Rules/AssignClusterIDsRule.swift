struct AssignClusterIDsRule: NormalizationRule {
    func apply(to state: inout WireNormalizationState) {
        // No-op: cluster IDs are not modeled in the sandbox items.
    }
}
