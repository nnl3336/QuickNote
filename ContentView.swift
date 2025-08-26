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
        NavigationStack {
            ZStack {
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
                // 右下の追加ボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(
                            destination: AddNoteView(attributedText: $attributedText)
                                .environment(\.managedObjectContext, viewContext)
                        ) {
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            // 新規作成用に毎回初期化
                            attributedText = NSMutableAttributedString(string: "")
                        })
                        .padding()
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
            /*.fullScreenCover(item: $selectedNote) { note in
                EditNoteView(note: note)
                    .environment(\.managedObjectContext, viewContext)
            }

            .fullScreenCover(isPresented: $showingAddNote) {
                AddNoteView(attributedText: $attributedText)
                    .environment(\.managedObjectContext, viewContext)
            }*/
        }
    }

}


struct NoteEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var note: Note // 非オプショナルで渡す（新規作成は外側で Note(context:) を作る）
    @State private var attributedText = NSMutableAttributedString()
    
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardWillShow: AnyCancellable?
    @State private var keyboardWillHide: AnyCancellable?
    
    @State private var showToast = false
    @State private var isCancelling = false
    @State private var didSave = false
    
    private var bottomPadding: CGFloat { keyboardHeight > 0 ? keyboardHeight : 0 }
    
    var body: some View {
        ZStack {
            VStack {
                UITextViewWrapper(
                    attributedText: $attributedText,
                    onCopy: showCopyToast
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
        .navigationTitle(note.content?.isEmpty ?? true ? "新しいメモ" : "メモを編集")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    isCancelling = true
                    Task { await back() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await saveAndHideKeyboard() } // キーボードだけ閉じる保存
                }
                .disabled(attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            読み込み内容をセット()
            startKeyboardObserver()
        }
        .onDisappear {
            stopKeyboardObserver()
            if !didSave && !attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { await back() }
            }
        }
    }
    
    // MARK: - ノート内容を読み込み
    private func 読み込み内容をセット() {
        if let data = note.attributedContent,
           let attr = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
           ) {
            self.attributedText = NSMutableAttributedString(attributedString: attr)
        } else {
            self.attributedText = NSMutableAttributedString(string: note.content ?? "")
        }
    }
    
    // MARK: - コピー時トースト表示
    private func showCopyToast() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { showToast = false }
        }
    }
    
    // MARK: - 保存してキーボードを閉じる
    private func saveAndHideKeyboard() async {
        let trimmed = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        note.content = trimmed
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        note.date = Date()
        
        do {
            try await viewContext.perform { try viewContext.save() }
        } catch {
            print("保存エラー: \(error)")
        }
        
        // キーボードだけ閉じる
        await MainActor.run { hideKeyboard() }
        didSave = true
    }
    
    // MARK: - 保存して閉じる／キャンセル処理
    private func back() async {
        guard !isCancelling else {
            await MainActor.run { dismiss() }
            return
        }
        
        let trimmed = attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            // 空なら削除（既存ノート）
            if viewContext.registeredObjects.contains(note) {
                viewContext.delete(note)
                try? viewContext.save()
            }
            await MainActor.run { dismiss() }
            return
        }
        
        note.content = trimmed
        note.attributedContent = try? attributedText.data(
            from: NSRange(location: 0, length: attributedText.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        note.date = Date()
        
        do {
            try await viewContext.perform { try viewContext.save() }
        } catch {
            print("保存エラー: \(error)")
        }
        
        didSave = true
        await MainActor.run { dismiss() }
    }
    
    // MARK: - キーボード監視
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
    
    // MARK: - キーボードを閉じる
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
