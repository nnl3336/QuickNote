//
//  ContentView.swift
//  QuickNote
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI

// MARK: - ContentView
struct ContentView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext

    func makeUIViewController(context: Context) -> UINavigationController {
        let notesVC = NotesViewController()
        notesVC.viewContext = viewContext
        let nav = UINavigationController(rootViewController: notesVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // 特に更新処理は不要
    }
}




//


