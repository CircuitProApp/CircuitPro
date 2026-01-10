import AppKit

struct PreviewRL: CKRenderLayer {
    @CKContext var context

    var body: CKLayer {
        guard let tool = context.selectedTool,
              let mouseLocation = context.processedMouseLocation
        else {
            return .empty
        }

        let primitives = tool.preview(mouse: mouseLocation, context: context)
        return CKLayer { _ in primitives }
    }
}
