//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Raúl Carrancá on 02/05/22.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0, 0), in: geometry))
                )
                .gesture(doubleTapToZoom(in: geometry.size).exclusively(before: singleTapGestureOnBackground()))
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        ZStack {
                            // selection and delete icon for emojis
                            if selectedEmojis.contains(emoji) {
                                ZStack {
                                    Image(systemName: "rectangle")
                                        .font(.system(size: fontSizeForSelectionSymbol(for: emoji)))
                                        .foregroundColor(.gray)
                                        .scaleEffect(zoomScale)
                                        .position(positionSelectionOn(for: emoji, in: geometry))
                                    Button(action: {
                                        for emoji in selectedEmojis {
                                            document.removeEmoji(emoji)
                                        }
                                        selectedEmojis.removeAll()
                                    }, label: {
                                        Image(systemName: "minus.rectangle")
                                    })
                                        .font(.system(size: fontSize(for: emoji)))
                                        .foregroundColor(.red)
                                        .scaleEffect(zoomScale)
                                        .position(positionForDeleteSymbol(for: emoji, in: geometry))
                                }
                            }
                            Text(emoji.text)
                                .font(.system(size: fontSize(for: emoji)))
                                .scaleEffect(zoomScale)
                                .position(selectedEmojis.contains(emoji) ? positionSelectionOn(for: emoji, in: geometry) : position(for: emoji, in: geometry))
                        }
                        .gesture(singleTapGesture(on: emoji).simultaneously(with: emojiPanGesture()))
                    }
                }
            }
            .clipped() // forces the view to stay within its given size so backgroung doesn't overlap with pallete
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                drop(providers: providers, at: location, in: geometry)
            }
            //.gesture(panGesture()) not recomended to use more than one .gesture on one given View
            .gesture(panGesture().simultaneously(with: zoomGesture()))
        }
    }
    
    // MARK: - Drag and Drop
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    // MARK: - Positioning/Sizing Emoji
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
   private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x) / zoomScale,
            y: (location.y - panOffset.height - center.y) / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    // MARK: - Zooming
    
    @State private var steadyStateZoomScale: CGFloat = 1 // zoom scale at the end of gesture
    @GestureState private var gestureZoomScale: CGFloat = 1 // dynamic zoom scale while gesture is being performed
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, _ in
                //if no selection is done, perform normal zoomin on whole document
                if selectedEmojis.isEmpty {
                    gestureZoomScale = latestGestureScale
                // else scale emojis by gesture scale
                } else {
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: latestGestureScale)
                    }
                }
            }
            .onEnded { gestureScaleAtEnd in
                //if no selection is done, perform normal zoomin on whole document
                if selectedEmojis.isEmpty {
                    steadyStateZoomScale *= gestureScaleAtEnd
                // else remove all selected emojis after ending scale gesture
                } else {
                    selectedEmojis.removeAll()
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0  {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    // MARK: - Panning
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, _ in
                gesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    // MARK: - Emoji selection
    @State private var selectedEmojis: Set<EmojiArtModel.Emoji> = Set.init()
    
    private func singleTapGesture(on emoji: EmojiArtModel.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation {
                    selectedEmojis.toggleSelection(of: emoji)
                }
            }
    }
    
    private func singleTapGestureOnBackground() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                withAnimation {
                    selectedEmojis.removeAll()
                }
            }
    }
    
    // moves position of delete symbol to upper right corner of selected emojis
    private func positionForDeleteSymbol(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinatesDeleteSymbol((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertFromEmojiCoordinatesDeleteSymbol(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x + 50) * zoomScale + emojiPanOffset.width + panOffset.width,
            y: center.y + CGFloat(location.y - 20) * zoomScale + emojiPanOffset.height + panOffset.height
        )
    }
    
    private func fontSizeForSelectionSymbol(for emoji: EmojiArtModel.Emoji) -> CGFloat {
         CGFloat(emoji.size + 20)
     }
    
    // MARK: - Emoji Panning
    
    @State private var emojiSteadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var emojiGesturePanOffset: CGSize = CGSize.zero
    
    private var emojiPanOffset: CGSize {
        (emojiSteadyStatePanOffset + emojiGesturePanOffset) * zoomScale
    }
    
    private func emojiPanGesture() -> some Gesture {
        DragGesture()
            .updating($emojiGesturePanOffset) { latestDragGestureValue, emojiGesturePanOffset, _ in
                emojiGesturePanOffset = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                // update new position on model for each selected emoji
                for emoji in selectedEmojis {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale)
                }
                selectedEmojis.removeAll()
                emojiSteadyStatePanOffset = CGSize.zero
            }
    }
    
    private func positionSelectionOn(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinatesSelectionOn((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertFromEmojiCoordinatesSelectionOn(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) * zoomScale + emojiPanOffset.width + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + emojiPanOffset.height + panOffset.height
        )
    }
    
    // MARK: - Palette
    
    var palette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testEmojis = "⭕️😀😷🦠💉👻👀🐶🌲🌎🌞🔥🍎⚽️🚗🚓🚲🛩🚁🚀🛸🏠⌚️🎁🗝🔐❤️⛔️❌❓✅⚠️🎶➕➖🏳️"
}

struct ScrollingEmojisView: View {
    let emojis: String

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
