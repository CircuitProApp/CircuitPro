//
//  FeedbackFormView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI
import AppKit

enum FeedbackIssueType: Displayable {
    case bug
    case featureRequest
    case uiIssue
    case performance
    case other
    
    var label: String {
        switch self {
        case .bug: return "Bug"
        case .featureRequest: return "Feature Request"
        case .uiIssue: return "UI Issue"
        case .performance: return "Performance"
        case .other: return "Other"
        }
    }
}

struct FeedbackFormView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIssueType: FeedbackIssueType = .bug
    @State private var message: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Send Feedback")
                .font(.title)
                .bold()

            Picker("Issue Type", selection: $selectedIssueType) {
                ForEach(FeedbackIssueType.allCases, id: \.self) { type in
                    Text(type.label)
                }
            }
            .pickerStyle(.menu)

            Text("Message:")
            TextEditor(text: $message)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 150)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(.rect(cornerRadius: 10))

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Send") {
                    sendEmail()
                    dismiss()
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }

    func sendEmail() {
        let to = "george@circuitpro.app"
        let subject = "Feedback: \(selectedIssueType)"
        let body =
"""
Issue Type: \(selectedIssueType)

\(message)
"""
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}
