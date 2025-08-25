//
//  ContentView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI
import CoreData
import Combine

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)]
    ) private var notes: FetchedResults<Note>
    
    @State private var searchText: String = ""
    @State private var showingAddNote = false
    @State private var selectedNote: Note? = nil
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return Array(notes)
        } else {
            return notes.filter { $0.content?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }
    
    @State private var attributedText = NSMutableAttributedString()

    
    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                TextField("検索", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .textInputAutocapitalization(.never)
                
                // メモリスト
                List {
                    ForEach(filteredNotes) { note in
                        NavigationLink(destination:
                            EditNoteView(note: note)
                                .environment(\.managedObjectContext, viewContext)
                        ) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(note.content ?? "")
                                        .font(.body)
                                        .lineLimit(1)
                                    Text(note.date ?? Date(), style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { filteredNotes[$0] }.forEach(viewContext.delete)
                        try? viewContext.save()
                    }
                }

            }
            .toolbar {
                NavigationLink(
                    destination: AddNoteView(attributedText: $attributedText)
                        .environment(\.managedObjectContext, viewContext),
                    label: {
                        Image(systemName: "plus")
                    }
                )
                .simultaneousGesture(TapGesture().onEnded {
                    // 新規作成用に毎回初期化
                    attributedText = NSMutableAttributedString(string: "")
                })
            }
            .fullScreenCover(item: $selectedNote) { note in
                EditNoteView(note: note)
                    .environment(\.managedObjectContext, viewContext)
            }

            .fullScreenCover(isPresented: $showingAddNote) {
                AddNoteView(attributedText: $attributedText)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

// MARK: - AddNoteView
struct AddNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var attributedText: NSMutableAttributedString
    
    var body: some View {
        VStack {
            UITextViewWrapper(attributedText: $attributedText, isFirstResponder: true)
                .padding()
            Spacer()
        }
        .navigationTitle("新しいメモ")   // ← NavigationView は外側に任せる
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { dismiss() }
                    .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onDisappear {
            save() // dismiss 時に保存
        }
    }
    
    private func save() {
        // 空なら保存せずに閉じる
        if attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dismiss()
            return
        }

        let note = Note(context: viewContext)
        note.content = attributedText.string  // 検索用プレーンテキスト
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        note.date = Date()
        
        do {
            try viewContext.save()
        } catch {
            print("保存エラー: \(error)")
        }
        
        dismiss()
    }
}

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
    
    var body: some View {
            VStack {
                // 入力欄
                UITextViewWrapper(attributedText: $attributedText, isFirstResponder: true)
                    //.frame(minHeight: 100, maxHeight: .infinity)
                    .padding()
                    //.background(Color(UIColor.secondarySystemBackground))
                    //.cornerRadius(8)
                
                // キーボード分のスペース
                //Spacer().frame(height: bottomPadding)
            }
            //.padding()
            //.ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("メモを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
//                        save()
                        dismiss()
                    }
                    .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
                    save()
                }
            }
        
    }
    
    private func save() {
        // 空なら削除
        if attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewContext.delete(note)
            try? viewContext.save()
            attributedText = NSMutableAttributedString(string: "") // ← 初期化
            dismiss()
            return
        }

        // リンク付きに補正
        let refreshed = NSMutableAttributedString.withLinkDetection(from: attributedText.string)
        attributedText = refreshed
        
        // 装飾付きテキストを保存
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        note.content = attributedText.string
        // date は更新しない

        do {
            try viewContext.save()
            didSave = true
        } catch {
            print("保存エラー: \(error)")
        }

        // 🔹 保存後に初期化しておく
        attributedText = NSMutableAttributedString(string: "")
        
        dismiss()
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

// MARK: - UITextViewWrapper
struct UITextViewWrapper: UIViewRepresentable {
    @Binding var attributedText: NSMutableAttributedString
    var isFirstResponder: Bool = false
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]   // 自動リンク検出
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.backgroundColor = .clear
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UITextViewWrapper
        init(_ parent: UITextViewWrapper) { self.parent = parent }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
        }
        
        func textView(_ textView: UITextView,
                      shouldInteractWith URL: URL,
                      in characterRange: NSRange,
                      interaction: UITextItemInteraction) -> Bool {
            // http または https のリンクのみ開く
            if URL.absoluteString.lowercased().hasPrefix("http://") ||
               URL.absoluteString.lowercased().hasPrefix("https://") {
                UIApplication.shared.open(URL)
            }
            return false // デフォルト処理はキャンセル
        }
    }
}

