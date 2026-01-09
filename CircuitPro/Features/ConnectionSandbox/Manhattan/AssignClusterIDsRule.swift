struct AssignClusterIDsRule: ManhattanNormalizationRule {
    func apply(to state: inout ManhattanNormalizationState) {
        // No-op: cluster IDs are not modeled in the sandbox items.
    }
}
