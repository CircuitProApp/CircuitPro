protocol NormalizationRule {
    func apply(to state: inout NormalizationState)
}
