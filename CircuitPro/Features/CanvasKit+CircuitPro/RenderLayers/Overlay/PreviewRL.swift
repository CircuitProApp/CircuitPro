import AppKit

struct PreviewRL: CKView {
    @CKContext var context

    var body: some CKView {
        if let tool = context.selectedTool,
           let mouseLocation = context.processedMouseLocation {
            let primitives = tool.preview(mouse: mouseLocation, context: context)
            CKGroup(primitives: primitives)
        } else {
            CKEmpty()
        }
    }
}
