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
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showToast = false

    var body: some View {
        ZStack {
            VStack {
                UITextViewWrapper(
                    attributedText: $attributedText,
                    isFirstResponder: true,
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
        //.navigationBarBackButtonHidden(true)
        .onDisappear {
            save() // dismiss 時に保存
        }
    }
    
    func showCopyToast() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
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
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showToast = false

    var body: some View {
        ZStack {
            VStack {
                // 入力欄
                UITextViewWrapper(attributedText: $attributedText, isFirstResponder: true, onCopy: showCopyToast)
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
                    save()
                }
            }
        
    }
    
    func showCopyToast() {
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast = false }
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


