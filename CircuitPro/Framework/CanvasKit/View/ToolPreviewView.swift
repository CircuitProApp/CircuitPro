import AppKit

struct ToolPreviewView: CKView {
    @CKContext var context

    var body: some CKView {
        if let tool = context.selectedTool,
           let mouseLocation = context.processedMouseLocation {
            tool.preview(mouse: mouseLocation, context: context)
        } else {
            CKEmpty()
        }
    }
}
