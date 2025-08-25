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
                Button(action: { showingAddNote = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddNote) {
                AddNoteView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $selectedNote) { note in
                EditNoteView(note: note)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

// MARK: - AddNoteView
struct AddNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var attributedText = NSMutableAttributedString()
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardWillShow: AnyCancellable?
    @State private var keyboardWillHide: AnyCancellable?
    
    private var bottomPadding: CGFloat { keyboardHeight > 0 ? keyboardHeight : 0 }
    
    var body: some View {
        NavigationView {
            VStack {
                UITextViewWrapper(attributedText: $attributedText, isFirstResponder: true)
                    .frame(minHeight: 100, maxHeight: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                Spacer().frame(height: bottomPadding)
            }
            .padding()
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("新しいメモ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { startKeyboardObserver() }
            .onDisappear { stopKeyboardObserver() }
        }
    }
    
    private func save() {
        let note = Note(context: viewContext)
        // 装飾付きテキストをDataで保存（必要なら）
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        // 検索用プレーンテキスト
        note.content = attributedText.string
        note.date = Date()
        try? viewContext.save()
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

// MARK: - EditNoteView
struct EditNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var note: Note
    @State private var attributedText = NSMutableAttributedString()
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardWillShow: AnyCancellable?
    @State private var keyboardWillHide: AnyCancellable?
    
    private var bottomPadding: CGFloat { keyboardHeight > 0 ? keyboardHeight : 0 }
    
    var body: some View {
        NavigationView {
            VStack {
                UITextViewWrapper(attributedText: $attributedText, isFirstResponder: true)
                    .frame(minHeight: 100, maxHeight: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                Spacer().frame(height: bottomPadding)
            }
            .padding()
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
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
            .onDisappear { stopKeyboardObserver() }
        }
    }
    
    private func save() {
        // 装飾付きテキスト
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        // 検索用テキスト
        note.content = attributedText.string
        note.date = Date()
        try? viewContext.save()
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
        textView.dataDetectorTypes = [.link]
        textView.delegate = context.coordinator
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
    }
}
