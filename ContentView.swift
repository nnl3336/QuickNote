//
//  ContentView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)]
    ) private var notes: FetchedResults<Note>
    
    @State private var searchText: String = ""
    @State private var showingAddNote = false
    
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
                        VStack(alignment: .leading) {
                            Text(note.content ?? "")
                                .font(.body)
                            Text(note.date ?? Date(), style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { filteredNotes[$0] }.forEach(viewContext.delete)
                        try? viewContext.save()
                    }
                }
            }
            .navigationTitle("メモ")
            .toolbar {
                Button(action: { showingAddNote = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddNote) {
                AddNoteView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

// MARK: - 追加画面（UITextView対応）
struct AddNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var noteText: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                UITextViewWrapper(text: $noteText, isFirstResponder: true)
                    .frame(height: 200)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("新しいメモ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveNote() }
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        let note = Note(context: viewContext)
        note.content = noteText
        note.date = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("保存エラー: \(error)")
        }
    }
}


