import Foundation

protocol ResolvableText {
    func resolve(
        with override: TextOverride?,
        componentName: String,
        reference: String,
        properties: [Property.Resolved]
    ) -> ResolvedText?
}
