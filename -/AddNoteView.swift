//
//  AddNoteView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/26.
//

import SwiftUI

// MARK: - AddNoteView
struct AddNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var attributedText: NSMutableAttributedString
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showToast = false

    @State private var isCancelling = false
    
    var body: some View {
        ZStack {
            VStack {
                UITextViewWrapper(
                    attributedText: $attributedText,
                    onCopy: showCopyToast // ← これでコピー時に呼ばれる
                )
                    .padding()
                Spacer()
            }
            
            
            if showToast {
                VStack {
                    Spacer()
                    Text("コピーしました")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.opacity)
                        .padding(.bottom, 50)
                }
            }
        }
        .navigationTitle("新しいメモ")   // ← NavigationView は外側に任せる
        .toolbar {
            /*ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 戻る
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                }
            }*/
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    isCancelling = true
                    Task {
                        await save()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
//                        save()
                    dismiss()
                }
                .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        //.navigationBarBackButtonHidden(true)
        .onDisappear {
            Task {
                await save()
            }
        }
    }
    
    func showCopyToast() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
        }
    }
    
    private func save() async {
        guard !isCancelling else {
            // 保存せずに閉じる場合
            dismiss()
            return
        }
        
        // 空なら保存せずに閉じる
        if attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await MainActor.run { dismiss() }
            return
        }

        let note = Note(context: viewContext)
        note.content = attributedText.string
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        note.date = Date()

        do {
            try await viewContext.perform {
                try viewContext.save()
            }
        } catch {
            print("保存エラー: \(error)")
        }

        await MainActor.run { dismiss() }
    }
}
