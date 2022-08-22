//
//  Camera.swift
//  EmojiArt
//
//  Created by Raúl Carrancá on 22/08/22.
//

import SwiftUI

struct Camera: UIViewControllerRepresentable {
    var handlePickedImage: (UIImage?) -> Void
    
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(handlePickedImage: handlePickedImage)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true // allows zooming by pinching to use part of the image instead of the whole image
        picker.delegate = context.coordinator // is the thing that gets called back, the object that gets sent to message when a photo is taken or when cancel is pressed. context.coordinator is created with makeCoordinator func
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // nothing to do when var body is rebuilding
    }
    
    // UIImagePickerControllerDelegate notifies the delegate when the user picks an Image or cancels
    // Coordinator needs to inherit from NSObject, most things in UIKit inherit from NSObject
    // Any UIImagePickerController implementation needs UINavigationControllerDelegate
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var handlePickedImage: (UIImage?) -> Void
        
        init(handlePickedImage: @escaping (UIImage?) -> Void) {
            self.handlePickedImage = handlePickedImage
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            handlePickedImage(nil)
        }
        
        // gives the taken picture in info dictionary with InfoKeys editedImage or originalImage
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            handlePickedImage((info[.editedImage] ?? info[.originalImage]) as? UIImage) // as? so if this line was to fail it would be just like handlePickedImage(nil)
        }
    }
}
