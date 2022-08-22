//
//  PaletteManager.swift
//  EmojiArt
//
//  Created by Raúl Carrancá on 05/08/22.
//

import SwiftUI

struct PaletteManager: View {
    @EnvironmentObject var store: PaletteStore
    //@Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        // NavigationLinks work only inside of a NavigationView!
        NavigationView {
            List {
                ForEach(store.palettes) { palette in
                    NavigationLink(destination: PaletteEditor(palette: $store.palettes[palette])) {
                        VStack(alignment: .leading) {
                            Text(palette.name)//.font(editMode == .active ? .largeTitle : .body)
                            Text(palette.emojis)
                        }
                        // relevant for assignment 6: otherwise NavigationLink is overwritten by onTapGesture
                        .gesture(editMode == .active ? tap(on: palette) : nil)
                    }
                }
                .onDelete(perform: { indexSet in store.palettes.remove(atOffsets: indexSet) })
                .onMove(perform: { indexSet, newOffset in store.palettes.move(fromOffsets: indexSet, toOffset: newOffset) })
            }
            .navigationTitle("Manage Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .dismissable { presentationMode.wrappedValue.dismiss() }
            .toolbar {
                ToolbarItem { EditButton() }
            }
            //.environment(\.colorScheme, .dark)
            .environment(\.editMode, $editMode)
        }
    }
    
    // relevant for assignment 6
    func tap(on palette: Palette) -> some Gesture {
        TapGesture().onEnded {
            //some code
            
        }
    }
}

struct PaletteManager_Previews: PreviewProvider {
    static var previews: some View {
        PaletteManager()
            .environmentObject(PaletteStore.init(named: "Preview"))
    }
}
