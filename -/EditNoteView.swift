//
//  EditNoteView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/26.
//

import SwiftUI
import Combine

// MARK: - EditNoteView
struct EditNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var note: Note
    @State private var attributedText = NSMutableAttributedString()
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardWillShow: AnyCancellable?
    @State private var keyboardWillHide: AnyCancellable?
    
    @State private var didSave = false // 保存済みかフラグ
    
    private var bottomPadding: CGFloat { keyboardHeight > 0 ? keyboardHeight : 0 }
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showToast = false

    @State private var isCancelling = false

    var body: some View {
        ZStack {
            VStack {
                // 入力欄
                UITextViewWrapper(attributedText: $attributedText,
                                  onCopy: showCopyToast)
                //.frame(minHeight: 100, maxHeight: .infinity)
                    .padding()
                //.background(Color(UIColor.secondarySystemBackground))
                //.cornerRadius(8)
                
                // キーボード分のスペース
                //Spacer().frame(height: bottomPadding)
            }
            //.padding()
            //.ignoresSafeArea(.keyboard, edges: .bottom)
            
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
            .navigationTitle("メモを編集")
            .toolbar {
                /*
                 ToolbarItem(placement: .navigationBarLeading) {
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
                                await back()
                            }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
//                        save()
                        Task {
                                await back()
                            }
                    }
                    .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            //.navigationBarBackButtonHidden(true)
            .onAppear {
                if let data = note.attributedContent,
                   let attr = try? NSAttributedString(data: data,
                                                     options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                                     documentAttributes: nil) {
                    self.attributedText = NSMutableAttributedString(attributedString: attr)
                } else {
                    self.attributedText = NSMutableAttributedString(string: note.content ?? "")
                }
                startKeyboardObserver()
            }
            .onDisappear {
                stopKeyboardObserver()
                
                // 保存していなければ自動保存
                if !didSave && !attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task {
                            await back()
                        }
                }
            }
        
    }
    
    func showCopyToast() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
        }
    }
    
    private func back() async {
        guard !isCancelling else {
            // 保存せずに閉じる場合
            dismiss()
            return
        }
        
        // 空なら削除 or 何もしないで閉じる
        if attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 既存ノートなら削除
            if viewContext.registeredObjects.contains(note) {
                viewContext.delete(note)
                try? viewContext.save()
            }
            await MainActor.run { dismiss() }
            return
        }
        
        // 🔹 新規作成か既存編集かを判定して処理
        let targetNote: Note
        if viewContext.registeredObjects.contains(note) {
            // 既存ノートを編集
            targetNote = note
        } else {
            // 新規作成
            targetNote = Note(context: viewContext)
        }
        
        // 更新内容を反映
        targetNote.content = attributedText.string
        targetNote.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        
        do {
            try await viewContext.perform {
                try viewContext.save()
            }
        } catch {
            print("保存エラー: \(error)")
        }
        
        await MainActor.run { dismiss() }
    }


    


    private func startKeyboardObserver() {
        keyboardWillShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
            .sink { height in withAnimation { self.keyboardHeight = height } }
        keyboardWillHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { _ in withAnimation { self.keyboardHeight = 0 } }
    }
    
    private func stopKeyboardObserver() {
        keyboardWillShow?.cancel()
        keyboardWillHide?.cancel()
    }
}

