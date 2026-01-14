import AppKit

struct HandleView: CKView {
    
    @CKContext var context
    
    var body: some CKView {
        CKCircle(radius: 5 / context.magnification)
            .fill(CKColor.white)
            .stroke(.blue, width: 1 / context.magnification)
    }
}
