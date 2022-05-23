//
//  ViewController.swift
//  firestorage
//
//  Created by Lakith Jayalath on 2021-11-16.
//

import UIKit
import Photos
import FirebaseStorage
import Firebase
import FirebaseStorageUI
import MobileCoreServices
import UniformTypeIdentifiers
import AVKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet var imageDownloaded: UIImageView!
    @IBOutlet weak var progressBar: UIProgressView!
    
    var player: AVPlayer!
    var playerViewController: AVPlayerViewController!
    
    @IBOutlet weak var playerView: UIView!

    var imagePickerController = UIImagePickerController()

    override func viewDidLoad() {
        super.viewDidLoad()
        imagePickerController.delegate = self
        
        checkPermissions()
    }

    @IBAction func uploadImageTapped(_ sender: Any) {
        self.imagePickerController.sourceType = .savedPhotosAlbum
        self.imagePickerController.mediaTypes = [UTType.movie.identifier, UTType.image.identifier]
        self.present(self.imagePickerController, animated: true, completion: nil)
//        openVideoGallery()
    }
    
    
    @IBAction func pullImageTapped(_ sender: Any) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let ref = storageRef.child("UploadPhotoOne")
        
        // Create a reference with an initial file path and name
        let pathReference = storage.reference(withPath: "myPics/demoPic.jpg")

        imageDownloaded.sd_setImage(with: pathReference, placeholderImage: nil)
    }
    
    @IBAction func pullVidTapped(_ sender: Any) {
        // Create a reference to the file you want to download
        let storage = Storage.storage()
        let storageRef = storage.reference()

        let vidRef = storageRef.child("Videos").child("test1.mp4")

        // Fetch the download URL
        vidRef.downloadURL { url, error in
            if let error = error {
                print("DEBUG: Upload: \(error.localizedDescription)")
                return
            }
            guard let videoURL = url else {
                print("DEBUG: Upload failed get URL")
                return
            }
            
            self.player = AVPlayer(url: videoURL)
            self.playerViewController = AVPlayerViewController()
            self.playerViewController.player = self.player
            self.playerViewController.view.frame = self.playerView.frame
            self.playerViewController.player?.play()
            self.playerView.addSubview(self.playerViewController.view)

        }

    }
    
    @IBAction func clearCache(sender: UIButton) {
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk()
    }

    
    func checkPermissions() {
        if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.authorized {
                                 PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) -> Void in
                                     ()
                                 })
                             }

                             if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
                             } else {
                                 PHPhotoLibrary.requestAuthorization(requestAuthroizationHandler)
                             }
    }
    
    // if the user allow to view their photos
    func requestAuthroizationHandler(status: PHAuthorizationStatus) {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized {
            print("We have access to photos")
        } else {
            print("We dont have access to photos")
        }
    }
    
    func openVideoGallery() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .savedPhotosAlbum
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = false
        present(picker, animated: true, completion: nil)
    }

    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        guard let mediaType: String = info[UIImagePickerController.InfoKey.mediaType] as? String else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        //User selects an image
        if mediaType == (UTType.image.identifier) {
            if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage, let imageData = originalImage.jpegData(compressionQuality: 0.8) {
                uploadImageToFirebaseStorage(data: imageData as NSData)
            }
            
        //User selects a movie
        } else if mediaType == (UTType.movie.identifier) {
            if let movie = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL, let absoluteURL = movie.absoluteURL{
//                uploadMovieToFirebaseStorage(url: movie)
                uploadTOFireBaseVideo(url: absoluteURL, success: {
                    success in
                    print("Success \(success)")
                }, failure: {
                    error in
                    print("Failure \(error.localizedDescription)")
                })
            }
        }
        imagePickerController.dismiss(animated: true, completion: nil)

//        if let url = info[UIImagePickerController.InfoKey.imageURL] as? URL {
//            print(url)
//            uploadToCloud(fileURL: url)
//        }
//        imagePickerController.dismiss(animated: true, completion: nil)
    }
    
    func uploadImageToFirebaseStorage(data: NSData) {
        let storageRef = Storage.storage().reference(withPath: "myPics/demoPic.jpg")
        let uploadMetadata = StorageMetadata()
        uploadMetadata.contentType = "image/jpeg"
        let uploadTask = storageRef.putData(data as Data, metadata: uploadMetadata) { (metadata, error) in
            if (error != nil) {
                print("I received an error! \(error?.localizedDescription)")
            } else {
                print("Upload complete! \(metadata)")
                print("Download URL \(metadata?.description)")
            }
        }
        uploadTask.observe(.progress) { [weak self] (snapshot) in
            guard let strongSelf = self else { return }
            guard let progress = snapshot.progress else { return }
            strongSelf.progressBar.progress = Float(progress.fractionCompleted)
            
        }
        
    }
    
    func uploadMovieToFirebaseStorage(url: NSURL) {
        let storageRef = Storage.storage().reference(withPath: "myMovies/demoMovie.mov")
        let uploadMetadata = StorageMetadata()
        uploadMetadata.contentType = "video/quicktime"
        let uploadTask = storageRef.putFile(from: url as URL, metadata: uploadMetadata) { (metadata, error) in
            if (error != nil) {
                print("I received an error! \(error?.localizedDescription)")
            } else {
                print("Upload complete! \(metadata)")
                print("Download URL \(metadata?.description)")
            }
            
        }
        uploadTask.observe(.progress) { [weak self] (snapshot) in
            guard let strongSelf = self else { return }
            guard let progress = snapshot.progress else { return }
            strongSelf.progressBar.progress = Float(progress.fractionCompleted)
            print("Uploaded \(progress.completedUnitCount) so far")
        }
    }
    
    func uploadTOFireBaseVideo(url: URL,
                                      success : @escaping (String) -> Void,
                                      failure : @escaping (Error) -> Void) {

        let name = "test1.mp4"
        let path = NSTemporaryDirectory() + name

        let dispatchgroup = DispatchGroup()

        dispatchgroup.enter()

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputurl = documentsURL.appendingPathComponent(name)
        var ur = outputurl
        self.convertVideo(toMPEG4FormatForVideo: url as URL, outputURL: outputurl) { (session) in

            ur = session.outputURL!
            dispatchgroup.leave()

        }
        dispatchgroup.wait()

        let data = NSData(contentsOf: ur as URL)

        do {

            try data?.write(to: URL(fileURLWithPath: path), options: .atomic)

        } catch {

            print(error)
        }

        let storageRef = Storage.storage().reference().child("Videos").child(name)
        if let uploadData = data as Data? {
            let uploadTask = storageRef.putData(uploadData, metadata: nil
                , completion: { (metadata, error) in
                    if let error = error {
                        failure(error)
                    }else{
                        let strPic:String = (metadata?.description)!
                        success(strPic)
                    }
            })
            uploadTask.observe(.progress) { [weak self] (snapshot) in
                guard let strongSelf = self else { return }
                guard let progress = snapshot.progress else { return }
                strongSelf.progressBar.progress = Float(progress.fractionCompleted)
                print("Uploaded \(progress.completedUnitCount) so far")
            }
        }
    }
    
    func convertVideo(toMPEG4FormatForVideo inputURL: URL, outputURL: URL, handler: @escaping (AVAssetExportSession) -> Void) {
//        try! FileManager.default.removeItem(at: outputURL as URL)
        
        do {
             let fileManager = FileManager.default
            
            // Check if file exists
            if fileManager.fileExists(atPath: outputURL.absoluteString) {
                // Delete file
                try fileManager.removeItem(at: outputURL)
            } else {
                print("File does not exist")
            }
         
        }
        catch let error as NSError {
            print("An error took place: \(error)")
        }
        
        let asset = AVURLAsset(url: inputURL as URL, options: nil)

        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.exportAsynchronously(completionHandler: {
            handler(exportSession)
        })
    }



    

    
    func uploadToCloud(fileURL: URL) {
        let storage = Storage.storage()
        
        let data = Data()
        
        let storageRef = storage.reference()
        
        let localFile = fileURL
        
        let photoRef = storageRef.child("UploadPhotoOne")
        
        let uploadTask = photoRef.putFile(from: localFile, metadata: nil) { metadata, err in
            guard let metadata = metadata else {
                print(err?.localizedDescription)
                return
            }
            print("Photo Upload")
        }
    }
    
}

