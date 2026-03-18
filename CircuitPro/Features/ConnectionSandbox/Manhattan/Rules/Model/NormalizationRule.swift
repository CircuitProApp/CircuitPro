protocol NormalizationRule {
    func apply(to state: inout WireNormalizationState)
}
