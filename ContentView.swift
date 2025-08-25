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
    
    @State private var newNoteText: String = ""
    @State private var searchText: String = ""
    
    // NSPredicate で検索対応
    private var fetchRequest: FetchRequest<Note>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)]
    ) private var notes: FetchedResults<Note>


    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return Array(notes)
        } else {
            return notes.filter { $0.content?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    
    init() {
        fetchRequest = FetchRequest<Note>(
            entity: Note.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Note.date, ascending: false)],
            predicate: nil
        )
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                TextField("検索", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchText) { newValue in
                        //updatePredicate()
                    }
                    .textInputAutocapitalization(.never)
                
                // 新規メモ
                HStack {
                    TextField("新しいメモ", text: $newNoteText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: addNote) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                    .disabled(newNoteText.isEmpty)
                }
                .padding()
                
                // メモリスト
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
                        // filteredNotes は配列なので削除対象を notes から特定
                        indexSet.map { filteredNotes[$0] }.forEach(viewContext.delete)
                        
                        do {
                            try viewContext.save()
                        } catch {
                            print("削除エラー: \(error)")
                        }
                    }
                }

            }
            .navigationTitle("メモ")
        }
    }
    
    /*private func updatePredicate() {
        if searchText.isEmpty {
            fetchRequest.nsPredicate = nil
        } else {
            fetchRequest.nsPredicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
        }
    }*/
    
    private func addNote() {
        let note = Note(context: viewContext)
        note.content = newNoteText
        note.date = Date()
        
        do {
            try viewContext.save()
            newNoteText = ""
            //updatePredicate() // 検索中でも新しいメモが反映される
        } catch {
            print("保存エラー: \(error)")
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        offsets.map { notes[$0] }.forEach(viewContext.delete)
        
        do {
            try viewContext.save()
        } catch {
            print("削除エラー: \(error)")
        }
    }
}
