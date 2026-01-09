struct AssignClusterIDsRule: NormalizationRule {
    func apply(to state: inout NormalizationState) {
        // No-op: cluster IDs are not modeled in the sandbox items.
    }
}
