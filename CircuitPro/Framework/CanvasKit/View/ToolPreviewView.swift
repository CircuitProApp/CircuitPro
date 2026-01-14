import AppKit

struct ToolPreviewView: CKView {
    @CKContext var context
    @CKEnvironment var environment

    var body: some CKView {
        if let tool = context.selectedTool,
           let mouseLocation = environment.processedMouseLocation {
            tool.preview(mouse: mouseLocation, context: context, environment: environment)
        } else {
            CKEmpty()
        }
    }
}
