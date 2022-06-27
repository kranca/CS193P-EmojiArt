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
            pallette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        //.scaleEffect(selectedEmojis.isEmpty ? zoomScale : steadyStateZoomScale)
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
                                    Button(action: {
                                        for emoji in selectedEmojis {
                                            document.removeEmoji(emoji)
                                        }
                                        selectedEmojis.removeAll()
                                    }, label: {
                                        Image(systemName: "minus.rectangle")
                                    })
                                    .font(.system(size: fontSize(for: emoji)))
                                    .scaleEffect(zoomScale)
                                    .position(positionForDeleteSymbol(for: emoji, in: geometry))
                                    Rectangle.init()
                                        .stroke(lineWidth: 10.0)
                                        .size(geometry.size)
                                        .scale(0.08)
                                        .scaleEffect(zoomScale)
                                        .position(position(for: emoji, in: geometry))
                                        //.position(selectedEmojis.isEmpty ? position(for: emoji, in: geometry) : positionSelectionOn(for: emoji, in: geometry))
                                }
                            }
                            Text(emoji.text)
                                .font(.system(size: fontSize(for: emoji)))
                                .scaleEffect(zoomScale)
                                //.scaleEffect(selectedEmojis.contains(emoji) ? zoomScale : steadyStateZoomScale)
                                .position(position(for: emoji, in: geometry))
                                //.position(selectedEmojis.isEmpty ? position(for: emoji, in: geometry) : positionSelectionOn(for: emoji, in: geometry))
                        }
                        .gesture(singleTapGesture(on: emoji))
                    }
                    
                }
            }
            .clipped() // forces the view to stay within its given size so backgroung doesn't overlap with pallete
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(zoomGesture().simultaneously(with: panGesture()))
            //.gesture(panGesture()) not recomended to use more than one .gesture on one given View
        }
    }
    
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
                    document.addEmoji(String(emoji),
                                      at: convertToEmojiCoordinates(location, in: geometry),
                                      size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
    private func positionSelectionOn(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinatesSelectionOn((emoji.x, emoji.y), in: geometry)
    }
    
    // moves position of delete symbol to upper right corner of selected emojis
    private func positionForDeleteSymbol(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinatesSelectionOn((emoji.x + 35, emoji.y - 20), in: geometry)
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
    
    private func convertFromEmojiCoordinatesSelectionOn(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint(
            x: center.x + CGFloat(location.x) + panOffset.width,
            y: center.y + CGFloat(location.y) + panOffset.height
        )
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffsetInOut, _ in
                gesturePanOffsetInOut = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 { // if let image = image to check that image is not nil
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            // recenter
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
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
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, ourGestureStateInOut, transaction in
                ourGestureStateInOut = latestGestureScale
            }
            .onEnded { gestureScaleAtEnd in
                steadyStateZoomScale *= gestureScaleAtEnd
            }
    }
    
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
    
    var pallette: some View {
        ScrollingEmojisView(emojis: testEmojis)
            .font(.system(size: defaultEmojiFontSize))
//            .onDrop(of: [.plainText], isTargeted: nil) { providers, _ in
//                document.removeEmoji(providers)
//            }
    }
    
    let testEmojis = "⭕️😄👽🕶🌎🌪☕️🏀🎲🛩🧨🚽📌✅⚠️🔴🔈🏴‍☠️🕸🐶🐐🌈"
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

struct EmojiArtDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        EmojiArtDocumentView(document: EmojiArtDocument())
    }
}
