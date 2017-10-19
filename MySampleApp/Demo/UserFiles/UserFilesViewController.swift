//
//  UserFilesViewController.swift
//  MySampleApp
//
//
// Copyright 2017 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to 
// copy, distribute and modify it.
//
// Source code generated from template: aws-my-sample-app-ios-swift v0.19
//

import UIKit
import WebKit
import MobileCoreServices
import AWSMobileHubContentManager
import AWSAuthCore
import AWSAuthUI
import AWSFacebookSignIn
import AVFoundation
import AVKit

import ObjectiveC

let UserFilesPublicDirectoryName = "public"
let UserFilesPrivateDirectoryName = "private"
let UserFilesProtectedDirectoryName = "protected"
let UserFilesUploadsDirectoryName = "uploads"
private var cellAssociationKey: UInt8 = 0

class UserFilesViewController: UITableViewController {
    
    @IBOutlet weak var pathLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    var prefix: String!
    
    fileprivate var manager: AWSUserFileManager!
    fileprivate var contents: [AWSContent]?
    fileprivate var dateFormatter: DateFormatter!
    fileprivate var marker: String?
    fileprivate var didLoadAllContents: Bool!
    fileprivate var segmentedControlSelected: Int = 0;
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        manager = AWSUserFileManager.defaultUserFileManager()
        
        // Sets up the UIs.
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(UserFilesViewController.showContentManagerActionOptions(_:)))
        
        // Sets up the date formatter.
        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current
        
        tableView.estimatedRowHeight = tableView.rowHeight
        tableView.rowHeight = UITableViewAutomaticDimension
        didLoadAllContents = false
        
        if let prefix = prefix {
            print("Prefix already initialized to \(prefix)")
        } else {
            self.prefix = "\(UserFilesPublicDirectoryName)/"
        }
        refreshContents()
        updateUserInterface()
        loadMoreContents()
        
    }
    
    fileprivate func updateUserInterface() {
        DispatchQueue.main.async {
            if let prefix = self.prefix {
                var pathText = "\(prefix)"
                var startFrom = prefix.startIndex
                var offset = 0
                let maxPathTextLength = 50
                
                if prefix.hasPrefix(UserFilesPublicDirectoryName) {
                    startFrom = UserFilesPublicDirectoryName.endIndex
                } else if prefix.hasPrefix(UserFilesPrivateDirectoryName) {
                    let userId = AWSIdentityManager.default().identityId!
                    startFrom = UserFilesPrivateDirectoryName.endIndex
                    offset = userId.characters.count + 1
                } else if prefix.hasPrefix(UserFilesProtectedDirectoryName) {
                    startFrom = UserFilesProtectedDirectoryName.endIndex
                } else if prefix.hasPrefix(UserFilesUploadsDirectoryName) {
                    startFrom = UserFilesUploadsDirectoryName.endIndex
                }
                
                startFrom = prefix.characters.index(startFrom, offsetBy: offset + 1)
                pathText = "\(prefix.substring(from: startFrom))"
                
                if pathText.characters.count > maxPathTextLength {
                    pathText = "...\(pathText.substring(from: pathText.characters.index(pathText.endIndex, offsetBy: -maxPathTextLength)))"
                }
                self.pathLabel.text = "\(pathText)"
            } else {
                self.pathLabel.text = "/"
            }
            self.segmentedControl.selectedSegmentIndex = self.segmentedControlSelected
            self.tableView.reloadData()
        }
    }
    
    func onSignIn (_ success: Bool) {
        // handle successful sign in
        if (success) {
            if let mainViewController = self.navigationController?.viewControllers[0] as? MainViewController {
                mainViewController.setupRightBarButtonItem()
                mainViewController.updateTheme()
            }
        } else {
            // handle cancel operation from user
        }
    }
    
    
    // MARK:- Content Manager user action methods
    
    @IBAction func changeDirectory(_ sender: UISegmentedControl) {
        manager = AWSUserFileManager.defaultUserFileManager()
        switch(sender.selectedSegmentIndex) {
        case 0: //Public Directory
            prefix = "\(UserFilesPublicDirectoryName)/"
            break
        case 1: //Private Directory
            if (AWSSignInManager.sharedInstance().isLoggedIn) {
                let userId = AWSIdentityManager.default().identityId!
                prefix = "\(UserFilesPrivateDirectoryName)/\(userId)/"
            } else {
                sender.selectedSegmentIndex = self.segmentedControlSelected
                    let alertController = UIAlertController(title: "Info", message: "Private user file storage is only available to users who are signed-in. Would you like to sign in?", preferredStyle: .alert)
                    let signInAction = UIAlertAction(title: "Sign In", style: .default, handler: {[weak self](action: UIAlertAction) -> Void in
                        guard let strongSelf = self else { return }
                        let config = AWSAuthUIConfiguration()
                        config.enableUserPoolsUI = true
                        config.addSignInButtonView(class: AWSFacebookSignInButton.self)
                        config.canCancel = true
                        AWSAuthUIViewController.presentViewController(with: strongSelf.navigationController!,
                                                                      configuration: config,
                                                                      completionHandler: { (provider: AWSSignInProvider, error: Error?) in
                                                                        if error != nil {
                                                                            print("Error occurred: \(error)")
                                                                        } else {
                                                                            strongSelf.onSignIn(true)
                                                                        }
                        })
                        })
                    alertController.addAction(signInAction)
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    present(alertController, animated: true, completion: nil)
            }
            break
        case 2: // Protected Directory
            if AWSSignInManager.sharedInstance().isLoggedIn {
                let userId = AWSIdentityManager.default().identityId!
                prefix = "\(UserFilesProtectedDirectoryName)/\(userId)/";
            } else {
                prefix = "\(UserFilesProtectedDirectoryName)/";
            }
            break
        case 3: // Uploads Directory
            prefix = "\(UserFilesUploadsDirectoryName)/"
            break
        default:
            break
        }
        segmentedControlSelected = sender.selectedSegmentIndex
        contents = []
        loadMoreContents()
    }
    
    func showContentManagerActionOptions(_ sender: AnyObject) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let uploadObjectAction = UIAlertAction(title: "Upload", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.showImagePicker()
            })
        alertController.addAction(uploadObjectAction)
        
        let createFolderAction = UIAlertAction(title: "New Folder", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.askForDirectoryName()
            })
        alertController.addAction(createFolderAction)
        let refreshAction = UIAlertAction(title: "Refresh", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.refreshContents()
            })
        alertController.addAction(refreshAction)
        let downloadObjectsAction = UIAlertAction(title: "Download Recent", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.downloadObjectsToFillCache()
            })
        alertController.addAction(downloadObjectsAction)
        let changeLimitAction = UIAlertAction(title: "Set Cache Size", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.showDiskLimitOptions()
            })
        alertController.addAction(changeLimitAction)
        let removeAllObjectsAction = UIAlertAction(title: "Clear Cache", style: .destructive, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.manager.clearCache()
            self.updateUserInterface()
            })
        alertController.addAction(removeAllObjectsAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func refreshContents() {
        marker = nil
        loadMoreContents()
    }
    
    fileprivate func loadMoreContents() {
        let uploadsDirectory = "\(UserFilesUploadsDirectoryName)/"
        if prefix == uploadsDirectory {
            updateUserInterface()
            return
        }
        manager.listAvailableContents(withPrefix: prefix, marker: marker) {[weak self] (contents: [AWSContent]?, nextMarker: String?, error: Error?) in
            guard let strongSelf = self else { return }
            if let error = error {
                strongSelf.showSimpleAlertWithTitle("Error", message: "Failed to load the list of contents.", cancelButtonTitle: "OK")
                print("Failed to load the list of contents. \(error)")
            }
            if let contents = contents, contents.count > 0 {
                strongSelf.contents = contents
                if let nextMarker = nextMarker, !nextMarker.isEmpty {
                    strongSelf.didLoadAllContents = false
                } else {
                    strongSelf.didLoadAllContents = true
                }
                strongSelf.marker = nextMarker
            } else {
                strongSelf.checkUserProtectedFolder()
            }
            strongSelf.updateUserInterface()
        }
    }
    
    fileprivate func showDiskLimitOptions() {
        let alertController = UIAlertController(title: "Disk Cache Size", message: nil, preferredStyle: .actionSheet)
        for number: Int in [1, 5, 20, 50, 100] {
            let byteLimitOptionAction = UIAlertAction(title: "\(number) MB", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
                self.manager.maxCacheSize = UInt(number) * 1024 * 1024
                self.updateUserInterface()
                })
            alertController.addAction(byteLimitOptionAction)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func downloadObjectsToFillCache() {
        manager.listRecentContents(withPrefix: prefix) {[weak self] (contents: [AWSContent]?, error: Error?) in
            guard let strongSelf = self else { return }
            
            contents?.forEach({ (content: AWSContent) in
                if !content.isCached && !content.isDirectory {
                    strongSelf.downloadContent(content, pinOnCompletion: false)
                }
            })
        }
    }
    
    // MARK:- Content user action methods
    
    fileprivate func showActionOptionsForContent(_ rect: CGRect, content: AWSContent) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if alertController.popoverPresentationController != nil {
            alertController.popoverPresentationController?.sourceView = self.view
            alertController.popoverPresentationController?.sourceRect = CGRect(x: rect.midX, y: rect.midY, width: 1.0, height: 1.0)
        }
        if content.isCached {
            let openAction = UIAlertAction(title: "Open", style: .default, handler: {(action: UIAlertAction) -> Void in
                DispatchQueue.main.async {
                    self.openContent(content)
                }
            })
            alertController.addAction(openAction)
        }
        
        // Allow opening of remote files natively or in browser based on their type.
        let openRemoteAction = UIAlertAction(title: "Open Remote", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.openRemoteContent(content)
            
            })
        alertController.addAction(openRemoteAction)
        
        // If the content hasn't been downloaded, and it's larger than the limit of the cache,
        // we don't allow downloading the contentn.
        if content.knownRemoteByteCount + 4 * 1024 < self.manager.maxCacheSize {
            // 4 KB is for local metadata.
            var title = "Download"
            
            if let downloadedDate = content.downloadedDate, let knownRemoteLastModifiedDate = content.knownRemoteLastModifiedDate, knownRemoteLastModifiedDate.compare(downloadedDate) == .orderedDescending {
                title = "Download Latest Version"
            }
            let downloadAction = UIAlertAction(title: title, style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
                self.downloadContent(content, pinOnCompletion: false)
                })
            alertController.addAction(downloadAction)
        }
        let downloadAndPinAction = UIAlertAction(title: "Download & Pin", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.downloadContent(content, pinOnCompletion: true)
            })
        alertController.addAction(downloadAndPinAction)
        if content.isCached {
            if content.isPinned {
                let unpinAction = UIAlertAction(title: "Unpin", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
                    content.unPin()
                    self.updateUserInterface()
                    })
                alertController.addAction(unpinAction)
            } else {
                let pinAction = UIAlertAction(title: "Pin", style: .default, handler: {[unowned self](action: UIAlertAction) -> Void in
                    content.pin()
                    self.updateUserInterface()
                    })
                alertController.addAction(pinAction)
            }
            let removeAction = UIAlertAction(title: "Delete Local Copy", style: .destructive, handler: {[unowned self](action: UIAlertAction) -> Void in
                content.removeLocal()
                self.updateUserInterface()
                })
            alertController.addAction(removeAction)
        }
        
        let removeFromRemoteAction = UIAlertAction(title: "Delete Remote File", style: .destructive, handler: {[unowned self](action: UIAlertAction) -> Void in
            self.confirmForRemovingContent(content)
            })
        
        alertController.addAction(removeFromRemoteAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func downloadContent(_ content: AWSContent, pinOnCompletion: Bool) {
        content.download(with: .ifNewerExists, pinOnCompletion: pinOnCompletion, progressBlock: {[weak self] (content: AWSContent, progress: Progress) in
            guard let strongSelf = self else { return }
            if strongSelf.contents!.contains( where: {$0 == content} ) {
                strongSelf.tableView.reloadData()
            }
        }) {[weak self] (content: AWSContent?, data: Data?, error: Error?) in
            guard let strongSelf = self else { return }
            if let error = error {
                print("Failed to download a content from a server. \(error)")
                strongSelf.showSimpleAlertWithTitle("Error", message: "Failed to download a content from a server.", cancelButtonTitle: "OK")
            }
            strongSelf.updateUserInterface()
        }
    }
    
    fileprivate func openContent(_ content: AWSContent) {
        if content.isAudioVideo() { // Video and sound files
            let directories: [AnyObject] = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true) as [AnyObject]
            let cacheDirectoryPath = directories.first as! String
            
            let movieURL: URL = URL(fileURLWithPath: "\(cacheDirectoryPath)/\(content.key.getLastPathComponent())")
            
            try? content.cachedData.write(to: movieURL, options: [.atomic])
            
            let player = AVPlayer(url: movieURL)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            self.present(playerViewController, animated: true) {
                playerViewController.player!.play()
            }
        } else if content.isImage() { // Image files
            // Image files
            let storyboard = UIStoryboard(name: "UserFiles", bundle: nil)
            let imageViewController = storyboard.instantiateViewController(withIdentifier: "UserFilesImageViewController") as! UserFilesImageViewController
            imageViewController.image = UIImage(data: content.cachedData)
            imageViewController.title = content.key
            navigationController?.pushViewController(imageViewController, animated: true)
        } else {
            showSimpleAlertWithTitle("Sorry!", message: "We can only open image, video, and sound files.", cancelButtonTitle: "OK")
        }
    }
    
    fileprivate func openRemoteContent(_ content: AWSContent) {
        content.getRemoteFileURL {[weak self] (url: URL?, error: Error?) in
            guard let strongSelf = self else { return }
            guard let url = url else {
                print("Error getting URL for file. \(error)")
                return
            }
            if content.isAudioVideo() { // Open Audio and Video files natively in app.
                let player = AVPlayer(url: url)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                strongSelf.present(playerViewController, animated: true) {
                    playerViewController.player!.play()
                }
            } else { // Open other file types like PDF in web browser.
                //UIApplication.sharedApplication().openURL(url)
                let storyboard: UIStoryboard = UIStoryboard(name: "UserFiles", bundle: nil)
                let webViewController: UserFilesWebViewController = storyboard.instantiateViewController(withIdentifier: "UserFilesWebViewController") as! UserFilesWebViewController
                webViewController.url = url
                webViewController.title = content.key
                strongSelf.navigationController?.pushViewController(webViewController, animated: true)
            }
        }
    }
    
    fileprivate func confirmForRemovingContent(_ content: AWSContent) {
        let alertController = UIAlertController(title: "Confirm", message: "Do you want to delete the content from the server? This cannot be undone.", preferredStyle: .alert)
        let okayAction = UIAlertAction(title: "Yes", style: .default) {[weak self] (action: UIAlertAction) in
            guard let strongSelf = self else { return }
            strongSelf.removeContent(content)
        }
        alertController.addAction(okayAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func removeContent(_ content: AWSContent) {
        content.removeRemoteContent {[weak self] (content: AWSContent?, error: Error?) in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to delete an object from the remote server. \(error)")
                    strongSelf.showSimpleAlertWithTitle("Error", message: "Failed to delete an object from the remote server.", cancelButtonTitle: "OK")
                } else {
                    strongSelf.showSimpleAlertWithTitle("Object Deleted", message: "The object has been deleted successfully.", cancelButtonTitle: "OK")
                    strongSelf.refreshContents()
                }
            }
        }
    }
    
    // MARK:- Content uploads
    
    fileprivate func showImagePicker() {
        let imagePickerController: UIImagePickerController = UIImagePickerController()
        imagePickerController.mediaTypes =  [kUTTypeImage as String, kUTTypeMovie as String]
        imagePickerController.delegate = self
        present(imagePickerController, animated: true, completion: nil)
    }
    
    fileprivate func askForFilename(_ data: Data) {
        let alertController = UIAlertController(title: "File Name", message: "Please specify the file name.", preferredStyle: .alert)
        alertController.addTextField(configurationHandler: nil)
        let doneAction = UIAlertAction(title: "Done", style: .default) {[unowned self] (action: UIAlertAction) in
            let specifiedKey = alertController.textFields!.first!.text!
            if specifiedKey.characters.count == 0 {
                self.showSimpleAlertWithTitle("Error", message: "The file name cannot be empty.", cancelButtonTitle: "OK")
                return
            } else {
                let key: String = "\(self.prefix!)\(specifiedKey)"
                self.uploadWithData(data, forKey: key)
            }
        }
        alertController.addAction(doneAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func askForDirectoryName() {
        let alertController: UIAlertController = UIAlertController(title: "Directory Name", message: "Please specify the directory name.", preferredStyle: .alert)
        alertController.addTextField(configurationHandler: nil)
        let doneAction = UIAlertAction(title: "Done", style: .default) {[unowned self] (action: UIAlertAction) in
            let specifiedKey = alertController.textFields!.first!.text!
            guard specifiedKey.characters.count != 0 else {
                self.showSimpleAlertWithTitle("Error", message: "The directory name cannot be empty.", cancelButtonTitle: "OK")
                return
            }
            
            let key = "\(self.prefix!)\(specifiedKey)/"
            self.createFolderForKey(key)
        }
        alertController.addAction(doneAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func uploadLocalContent(_ localContent: AWSLocalContent) {
        localContent.uploadWithPin(onCompletion: false, progressBlock: {[weak self] (content: AWSLocalContent, progress: Progress) in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                // Update the upload UI if it is a new upload and the table is not yet updated
                if(strongSelf.tableView.numberOfRows(inSection: 0) == 0 || strongSelf.tableView.numberOfRows(inSection: 0) < strongSelf.manager.uploadingContents.count) {
                    strongSelf.updateUploadUI()
                } else {
                    strongSelf.tableView.reloadData()
                }
            }
            }, completionHandler: {[weak self] (content: AWSLocalContent?, error: Error?) in
            guard let strongSelf = self else { return }
            strongSelf.updateUploadUI()
            if let error = error {
                print("Failed to upload an object. \(error)")
                strongSelf.showSimpleAlertWithTitle("Error", message: "Failed to upload an object.", cancelButtonTitle: "OK")
            } else {
                if localContent.key.hasPrefix(UserFilesUploadsDirectoryName) {
                    strongSelf.showSimpleAlertWithTitle("File upload", message: "File upload completed successfully for \(localContent.key).", cancelButtonTitle: "Okay")
                }
                strongSelf.refreshContents()
            }
        })
        updateUploadUI()
    }
    
    fileprivate func uploadWithData(_ data: Data, forKey key: String) {
        let localContent = manager.localContent(with: data, key: key)
        uploadLocalContent(localContent)
    }
    
    fileprivate func createFolderForKey(_ key: String) {
        let localContent = manager.localContent(with: nil, key: key)
        uploadLocalContent(localContent)
    }
    
    fileprivate func updateUploadUI() {
        DispatchQueue.main.async {
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return manager.uploadingContents.count
        }
        if let contents = self.contents {
            if isPrefixUploadsFolder() { // Uploads folder is write-only and table view show only one cell with that info
                return 1
            } else if isPrefixUserProtectedFolder() { // the first cell of the table view is the .. folder
                return contents.count + 1
            } else {
                return contents.count
            }
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "UserFilesUploadCell", for: indexPath) as! UserFilesUploadCell
            if indexPath.row < manager.uploadingContents.count {
                let localContent: AWSLocalContent = manager.uploadingContents[indexPath.row]
                cell.localContent = localContent
            }
            cell.prefix = prefix
            
            return cell
        }
        
        let cell: UserFilesCell = tableView.dequeueReusableCell(withIdentifier: "UserFilesCell", for: indexPath) as! UserFilesCell
        
        var content: AWSContent? = nil
        if isPrefixUserProtectedFolder() {
            if indexPath.row > 0 && indexPath.row < contents!.count + 1 {
                content = contents![indexPath.row - 1]
            }
        } else {
            if indexPath.row < contents!.count {
                content = contents![indexPath.row]
            }
        }
        cell.prefix = prefix
        cell.content = content
        
        if isPrefixUserProtectedFolder() && indexPath.row == 0 {
            cell.fileNameLabel.text = ".."
            cell.accessoryType = .disclosureIndicator
            cell.detailLabel.text = "This is a folder"
        } else if isPrefixUploadsFolder() {
            cell.fileNameLabel.text = "This folder is write only"
            cell.accessoryType = .disclosureIndicator
            cell.detailLabel.text = ""
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let contents = self.contents, indexPath.row == contents.count - 1, !didLoadAllContents {
            loadMoreContents()
        }
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Process only if it is a listed file. Ignore actions for files that are uploading.
        if indexPath.section != 0 {
            var content: AWSContent?
            
            if isPrefixUploadsFolder() {
                showImagePicker()
                return
            } else if !isPrefixUserProtectedFolder() {
                content = contents![indexPath.row]
            } else {
                if indexPath.row > 0 {
                    content = contents![indexPath.row - 1]
                } else {
                    let storyboard: UIStoryboard = UIStoryboard(name: "UserFiles", bundle: nil)
                    let viewController: UserFilesViewController = storyboard.instantiateViewController(withIdentifier: "UserFiles") as! UserFilesViewController
                    viewController.prefix = "\(UserFilesProtectedDirectoryName)/"
                    viewController.segmentedControlSelected = self.segmentedControlSelected
                    navigationController?.pushViewController(viewController, animated: true)
                    return
                }
            }
            if content!.isDirectory {
                let storyboard: UIStoryboard = UIStoryboard(name: "UserFiles", bundle: nil)
                let viewController: UserFilesViewController = storyboard.instantiateViewController(withIdentifier: "UserFiles") as! UserFilesViewController
                viewController.prefix = content!.key
                viewController.segmentedControlSelected = self.segmentedControlSelected
                navigationController?.pushViewController(viewController, animated: true)
            } else {
                let rowRect = tableView.rectForRow(at: indexPath);
                showActionOptionsForContent(rowRect, content: content!)
            }
        }
    }
}

// MARK:- UIImagePickerControllerDelegate

extension UserFilesViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        dismiss(animated: true, completion: nil)
        
        let mediaType = info[UIImagePickerControllerMediaType] as! NSString
        // Handle image uploads
        if mediaType.isEqual(to: kUTTypeImage as String) {
            let image: UIImage = info[UIImagePickerControllerOriginalImage] as! UIImage
            askForFilename(UIImagePNGRepresentation(image)!)
        }
        // Handle Video Uploads
        if mediaType.isEqual(to: kUTTypeMovie as String) {
            let videoURL: URL = info[UIImagePickerControllerMediaURL] as! URL
            askForFilename(try! Data(contentsOf: videoURL))
        }
    }
}

class UserFilesCell: UITableViewCell {
    
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var keepImageView: UIImageView!
    @IBOutlet weak var downloadedImageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    
    var prefix: String?
    
    var content: AWSContent! {
        didSet {
            if self.content == nil {
                fileNameLabel.text = ""
                downloadedImageView.isHidden = true
                keepImageView.isHidden = true
                detailLabel.text = ""
                accessoryType = .disclosureIndicator
                progressView.isHidden = true
                detailLabel.textColor = UIColor.black
                return
            }
            var displayFilename: String = self.content.key
            if let prefix = self.prefix {
                if displayFilename.characters.count > prefix.characters.count {
                    displayFilename = displayFilename.substring(from: prefix.endIndex)
                }
            }
            fileNameLabel.text = displayFilename
            downloadedImageView.isHidden = !content.isCached
            keepImageView.isHidden = !content.isPinned
            var contentByteCount: UInt = content.fileSize
            if contentByteCount == 0 {
                contentByteCount = content.knownRemoteByteCount
            }
            
            if content.isDirectory {
                detailLabel.text = "This is a folder"
                accessoryType = .disclosureIndicator
            } else {
                detailLabel.text = contentByteCount.aws_stringFromByteCount()
                accessoryType = .none
            }
            
            if let downloadedDate = content.downloadedDate, let knownRemoteLastModifiedDate = content.knownRemoteLastModifiedDate, knownRemoteLastModifiedDate.compare(downloadedDate) == .orderedDescending {
                detailLabel.text = "\(detailLabel.text!) - New Version Available"
                detailLabel.textColor = UIColor.blue
            } else {
                detailLabel.textColor = UIColor.black
            }
            
            if content.status == .running {
                progressView.progress = Float(content.progress.fractionCompleted)
                progressView.isHidden = false
            } else {
                progressView.isHidden = true
            }
        }
    }
}

class UserFilesImageViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var image: UIImage!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        imageView.image = image
    }
}

class UserFilesWebViewController: UIViewController, UIWebViewDelegate {
    
    @IBOutlet weak var webView: UIWebView!
    var url: URL!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        webView.delegate = self
        webView.dataDetectorTypes = UIDataDetectorTypes()
        webView.scalesPageToFit = true
        webView.loadRequest(URLRequest(url: url))
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        print("The URL content failed to load \(error)")
        webView.loadHTMLString("<html><body><h1>Cannot Open the content of the URL.</h1></body></html>", baseURL: nil)
    }
}

class UserFilesUploadCell: UITableViewCell {
    
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    var prefix: String?
    
    var localContent: AWSLocalContent! {
        didSet {
            var displayFilename: String = localContent.key
            if self.prefix != nil && displayFilename.hasPrefix(self.prefix!) {
                displayFilename = displayFilename.substring(from: self.prefix!.endIndex)
            }
            fileNameLabel.text = displayFilename
            progressView.progress = Float(localContent.progress.fractionCompleted)
        }
    }
}

// MARK: - Utility

extension UserFilesViewController {
    fileprivate func showSimpleAlertWithTitle(_ title: String, message: String, cancelButtonTitle cancelTitle: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    fileprivate func checkUserProtectedFolder() {
        let userId = AWSIdentityManager.default().identityId!
        if isPrefixUserProtectedFolder() {
            let localContent = self.manager.localContent(with: nil, key: "\(UserFilesProtectedDirectoryName)/\(userId)/")
            localContent.uploadWithPin(onCompletion: false, progressBlock: {(content: AWSLocalContent?, progress: Progress?) in
            }, completionHandler: {[weak self](content: AWSContent?, error: Error?) in
                guard let strongSelf = self else { return }
                strongSelf.updateUploadUI()
                if let error = error {
                    print("Failed to load the list of contents. \(error)")
                    strongSelf.showSimpleAlertWithTitle("Error", message: "Failed to load the list of contents.", cancelButtonTitle: "OK")
                }
                strongSelf.updateUserInterface()
            })
        }
    }
    
    fileprivate func isPrefixUserProtectedFolder() -> Bool {
        let userId = AWSIdentityManager.default().identityId!
        let protectedUserDirectory = "\(UserFilesProtectedDirectoryName)/\(userId)/"
        return AWSSignInManager.sharedInstance().isLoggedIn && protectedUserDirectory == prefix
    }
    
    fileprivate func isPrefixUploadsFolder() -> Bool {
        let uploadsDirectory = "\(UserFilesUploadsDirectoryName)/"
        return uploadsDirectory == prefix
    }
}

extension AWSContent {
    fileprivate func isAudioVideo() -> Bool {
        let lowerCaseKey = self.key.lowercased()
        return lowerCaseKey.hasSuffix(".mov")
            || lowerCaseKey.hasSuffix(".mp4")
            || lowerCaseKey.hasSuffix(".mpv")
            || lowerCaseKey.hasSuffix(".3gp")
            || lowerCaseKey.hasSuffix(".mpeg")
            || lowerCaseKey.hasSuffix(".aac")
            || lowerCaseKey.hasSuffix(".mp3")
    }
    
    fileprivate func isImage() -> Bool {
        let lowerCaseKey = self.key.lowercased()
        return lowerCaseKey.hasSuffix(".jpg")
            || lowerCaseKey.hasSuffix(".png")
            || lowerCaseKey.hasSuffix(".jpeg")
    }
}

extension UInt {
    fileprivate func aws_stringFromByteCount() -> String {
        if self < 1024 {
            return "\(self) B"
        }
        if self < 1024 * 1024 {
            return "\(self / 1024) KB"
        }
        if self < 1024 * 1024 * 1024 {
            return "\(self / 1024 / 1024) MB"
        }
        return "\(self / 1024 / 1024 / 1024) GB"
    }
}

extension String {
    fileprivate func getLastPathComponent() -> String {
        let nsstringValue: NSString = self as NSString
        return nsstringValue.lastPathComponent
    }
}