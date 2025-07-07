//
//  FeedbackFormView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/7/25.
//

import SwiftUI
import AppKit

struct FeedbackFormView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIssueType: FeedbackIssueType = .bug
    @State private var message: String = ""
    
    var additionalContext: String?

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
            .frame(maxWidth: 300)

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
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }

    func sendEmail() {
        let to = "george@circuitpro.app"
        let subject = "Feedback: \(selectedIssueType.label)"
        let body =
"""
Issue Type: \(selectedIssueType.label)

Additional Context: \(additionalContext ?? "N/A") 

\(message)
"""
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}
