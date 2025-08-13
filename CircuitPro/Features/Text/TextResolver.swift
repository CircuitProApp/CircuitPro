import Foundation

struct TextResolver {
    static func resolve(
        from symbol: Symbol,
        and instance: SymbolInstance,
        componentName: String,
        reference: String,
        properties: [Property.Resolved]
    ) -> [ResolvedText] {
        
        let overrideMap = Dictionary(
            uniqueKeysWithValues: instance.textOverrides.map { ($0.definitionID, $0) }
        )

        let definitionTexts = symbol.textDefinitions.compactMap {
            $0.resolve(
                with: overrideMap[$0.id],
                componentName: componentName,
                reference: reference,
                properties: properties
            )
        }

 //       let instanceTexts = instance.textInstances.compactMap {
//            $0.resolve(
//                with: , // Instance texts can't be overridden
//                componentName: componentName,
//                reference: reference,
//                properties: properties
//            )
            
//        }

        return definitionTexts
    }
}
