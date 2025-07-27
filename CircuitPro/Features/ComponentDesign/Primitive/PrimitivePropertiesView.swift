//
//  PrimitivePropertiesView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/27/25.
//

import SwiftUI

struct PrimitivePropertiesView: View {
    // 1. Binding to the selected primitive
    @Binding var primitive: AnyPrimitive

    var body: some View {
        // 2. Show a read-only summary based on the concrete primitive
        switch primitive {
        case .rectangle(let rect):
            rectangleSummary(rect)
        case .circle(let circ):
            circleSummary(circ)
        case .line(let line):
            lineSummary(line)
        default:
            Text("Unsupported primitive")
                .foregroundStyle(.secondary)
        }
    }

    // 3. Rectangle summary
    private func rectangleSummary(_ rect: RectanglePrimitive) -> some View {
        VStack(alignment: .leading) {

            HStack {
                // Derived binding for position.x
                DoubleField(title: "x", value: Binding(
                    get: { rect.position.x },
                    set: { newValue in
                        if case .rectangle(var r) = primitive {
                            r.position.x = newValue
                            primitive = .rectangle(r)
                        }
                    }
                ))
                DoubleField(title: "y", value: Binding(
                    get: { rect.position.y },
                    set: { newValue in
                        if case .rectangle(var r) = primitive {
                            r.position.y = newValue
                            primitive = .rectangle(r)
                        }
                    }
                ))
            }
            
            HStack {
                // Derived binding for position.x
                DoubleField(title: "width", value: Binding(
                    get: { rect.size.width },
                    set: { newValue in
                        if case .rectangle(var r) = primitive {
                            r.size.width = newValue
                            primitive = .rectangle(r)
                        }
                    }
                ))
                DoubleField(title: "height", value: Binding(
                    get: { rect.size.height },
                    set: { newValue in
                        if case .rectangle(var r) = primitive {
                            r.size.height = newValue
                            primitive = .rectangle(r)
                        }
                    }
                ))
            }
            
            DoubleField(title: "stroke width", value: Binding(
                get: { rect.strokeWidth },
                set: { newValue in
                    if case .rectangle(var r) = primitive {
                        r.strokeWidth = newValue
                        primitive = .rectangle(r)
                    }
                }
            ))
            DoubleField(title: "corner radius", value: Binding(
                get: { rect.cornerRadius },
                set: { newValue in
                    if case .rectangle(var r) = primitive {
                        r.cornerRadius = newValue
                        primitive = .rectangle(r)
                    }
                }
            ))
            Toggle("Filled", isOn: Binding(get: {
                rect.filled
            }, set: { newValue in
                if case .rectangle(var r) = primitive {
                    r.filled = newValue
                    primitive = .rectangle(r)
                }
            }))

            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }


    // 4. Circle summary
    private func circleSummary(_ circ: CirclePrimitive) -> some View {
        VStack(alignment: .leading) {
            Text("Center: (\(circ.position.x.formatted()), \(circ.position.y.formatted()))")
            Text("Radius: \(circ.radius.formatted())")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
    }
    
    private func lineSummary(_ line: LinePrimitive) -> some View {
        VStack(alignment: .leading) {
            HStack {
                // Derived binding for position.x
                DoubleField(title: "startpoint x", value: Binding(
                    get: { line.start.x },
                    set: { newValue in
                        if case .line(var l) = primitive {
                            l.start.x = newValue
                            primitive = .line(l)
                        }
                    }
                ))
                DoubleField(title: "startpoint y", value: Binding(
                    get: { line.start.y },
                    set: { newValue in
                        if case .line(var l) = primitive {
                            l.start.y = newValue
                            primitive = .line(l)
                        }
                    }
                ))
            }
            HStack {
                // Derived binding for position.x
                DoubleField(title: "endpoint x", value: Binding(
                    get: { line.end.x },
                    set: { newValue in
                        if case .line(var l) = primitive {
                            l.end.x = newValue
                            primitive = .line(l)
                        }
                    }
                ))
                DoubleField(title: "endpoint y", value: Binding(
                    get: { line.end.y },
                    set: { newValue in
                        if case .line(var l) = primitive {
                            l.end.y = newValue
                            primitive = .line(l)
                        }
                    }
                ))
            }
        }
    }
}
