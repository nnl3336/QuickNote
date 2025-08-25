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
                        ZStack {
                            Color.clear
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
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNote = note }
                    }
                    .onDelete { indexSet in
                        indexSet.map { filteredNotes[$0] }.forEach(viewContext.delete)
                        try? viewContext.save()
                    }
                }
            }
            .toolbar {
                Button(action: {
                    attributedText = NSMutableAttributedString(string: "") // 初期化
                    showingAddNote = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .fullScreenCover(item: $selectedNote) { note in
                NoteEditorView(note: note)
                    .environment(\.managedObjectContext, viewContext)
            }

            .fullScreenCover(isPresented: $showingAddNote) {
                NoteEditorView(attributedText: $attributedText)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

struct NoteEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var note: Note? = nil           // 編集時のみ
    @Binding var attributedText: NSMutableAttributedString

    @State private var keyboardHeight: CGFloat = 0

    // 編集用イニシャライザ
    init(note: Note) {
        self.note = note
        if let data = note.attributedContent,
           let attr = try? NSAttributedString(data: data,
                                              options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                              documentAttributes: nil) {
            _attributedText = .constant(NSMutableAttributedString(attributedString: attr))
        } else {
            _attributedText = .constant(NSMutableAttributedString(string: note.content ?? ""))
        }
    }

    // 新規用イニシャライザ
    init(attributedText: Binding<NSMutableAttributedString>) {
        self.note = nil
        _attributedText = attributedText
    }

    private var title: String { note == nil ? "新しいメモ" : "メモを編集" }

    var body: some View {
        NavigationView {
            VStack {
                UITextViewWrapper(attributedText: $attributedText, isFirstResponder: true)
                    .frame(minHeight: 100, maxHeight: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)

                Spacer().frame(height: keyboardHeight)
            }
            .padding()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
                if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation { keyboardHeight = frame.height }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation { keyboardHeight = 0 }
            }
        }
    }

    private func save() {
        if let note = note {
            // 編集
            note.attributedContent = try? attributedText.data(
                from: NSRange(location: 0, length: attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            note.content = attributedText.string
        } else {
            // 新規作成
            let newNote = Note(context: viewContext)
            newNote.content = attributedText.string
            newNote.attributedContent = try? attributedText.data(
                from: NSRange(location: 0, length: attributedText.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            newNote.date = Date()
        }

        do {
            try viewContext.save()
        } catch {
            print("保存エラー: \(error)")
        }
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

