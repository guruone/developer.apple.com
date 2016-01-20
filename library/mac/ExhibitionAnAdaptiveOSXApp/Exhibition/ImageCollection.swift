/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Contains the `ImageCollection` class, which is a collection of `ImageFile`s.
*/

import Cocoa

/**
    `ImageCollection` represents a directory on the file system that contains images.
    It creates and vends `ImageFile`s for each of those image files in the directory.
*/
class ImageCollection {
    // MARK: Notifications

    static let imagesDidChangeNotification = "ImageCollectionImagesDidChangeNotification"

    // MARK: Properties

    /// The name of the `ImageCollection`. Defaults to the referenced directory name.
    var name: String

    /**
        The `ImageFiles` contained in the collection. Populated asynchronously 
        and posts an `imagesDidChangeNotification` on updates.
    */
    private(set) var images = [ImageFile]()

    /// The directory URL referenced by the collection.
    private(set) var rootURL: NSURL

    /// Private mapping from URL to `ImageFile` used when updating with the referenced directory.
    private var imagesByURL = [NSURL: ImageFile]()

    /**
        Private backing for the table view icon. When the backing is nil, `tableViewIcon`
        returns the default collection image.
    */
    private var _tableViewIcon: NSImage?

    /**
        The image used as the icon in table view representations. Returns a standard
        icon by default. Setting nil will return to the default, never returns nil.
    */
    var tableViewIcon: NSImage {
        get {
            return _tableViewIcon ?? NSImage(named: "FolderTemplate")!
        }

        set(newTableViewIcon) {
            _tableViewIcon = newTableViewIcon
        }
    }

    // MARK: Initalizers

    init(rootURL: NSURL) {
        self.rootURL = rootURL

        name = rootURL.lastPathComponent ?? "/"
        
        refreshOnBackgroundThread()
    }

    // MARK: Image List Manipulation

    private func addImageFile(imageFile: ImageFile) {
        insertImageFile(imageFile, atIndex: images.count)
    }

    private func insertImageFile(imageFile: ImageFile, atIndex index: Int) {
        images.insert(imageFile, atIndex: index)

        imagesByURL[imageFile.URL] = imageFile
        
        NSNotificationCenter.defaultCenter().postNotificationName(ImageCollection.imagesDidChangeNotification, object: self)
    }

    private func removeImageFileAtIndex(index: Int) {
        let imageFile = images[index]

        removeImageFile(imageFile)
    }

    private func removeImageFile(imageFile: ImageFile) {
        images.removeAtIndex(images.indexOf(imageFile)!)
        
        imagesByURL.removeValueForKey(imageFile.URL)
        
        NSNotificationCenter.defaultCenter().postNotificationName(ImageCollection.imagesDidChangeNotification, object: self)
    }

    // MARK: ImageFile Fetching

    /// The operation queue all `ImageFile`s use to load their thumbnails.
    private static var imageFileFetchingQueue: NSOperationQueue = {
        let queue = NSOperationQueue()
       
        queue.name = "ImageCollection Image Fetching Queue"
        
        return queue
    }()

    func refreshOnBackgroundThread() {
        ImageCollection.imageFileFetchingQueue.addOperationWithBlock(refreshImageFiles)
    }

    private func refreshImageFiles() {
        let resourceValueKeys = [
            NSURLIsRegularFileKey, 
            NSURLTypeIdentifierKey, 
            NSURLContentModificationDateKey
        ]
    
        let options: NSDirectoryEnumerationOptions = [.SkipsSubdirectoryDescendants, .SkipsPackageDescendants]
        
        // Create an enumerator to enumerate all of the immediate files in the referenced directory.
        guard let directoryEnumerator = NSFileManager.defaultManager().enumeratorAtURL(rootURL, includingPropertiesForKeys: resourceValueKeys, options: options, errorHandler: { url, error in
            print("`directoryEnumerator` error: \(error).")
            return true
        }) else { return }
            
        var addedURLs = [NSURL]()
        var filesToRemove = images
        var filesChanged = [ImageFile]()
        
        for case let url as NSURL in directoryEnumerator {
            do {
                let resourceValues = try url.resourceValuesForKeys(resourceValueKeys)
                
                // Verify the URL is a file and not a directory or symlink.
                guard let isRegularFileResourceValue = resourceValues[NSURLIsRegularFileKey] as? NSNumber else { continue }

                guard isRegularFileResourceValue.boolValue else { continue }
                
                // Verify the URL is an image.
                guard let fileType = resourceValues[NSURLTypeIdentifierKey] as? String else { continue }
                guard UTTypeConformsTo(fileType, "public.image") else { continue }
                
                // Verify that it has a modification date.
                guard let modificationDate = resourceValues[NSURLContentModificationDateKey] as? NSDate else { continue }
                
                if let existingFile = imagesByURL[url] {
                    // This URL is in the collection, check if it needs updating.
                    if modificationDate.compare(existingFile.dateLastUpdated) == .OrderedDescending {
                        filesChanged.append(existingFile)
                    }
                
                    let existingFileIndex = filesToRemove.indexOf(existingFile)!
                    filesToRemove.removeAtIndex(existingFileIndex)
                }
                else {
                    // This URL is new, put it in our the list of added URLs
                    addedURLs.append(url)
                }
            } 
            catch {
                print("Unexpected error occured: \(error).")
            }
        }


        for imageFile in filesToRemove {
            removeImageFile(imageFile)
        }

        // Regenerate all changed files.
        for imageFile in filesChanged {
            removeImageFile(imageFile)

            addedURLs += [imageFile.URL]
        }

        // Update the image on the main queue.
        NSOperationQueue.mainQueue().addOperationWithBlock {
            for URL in addedURLs {
                let imageFile = ImageFile(URL: URL)
                
                self.addImageFile(imageFile)
            }
        }
    }
}

// `ImageCollections`s are equivalent if their URLs are equivalent.
extension ImageCollection: Hashable {
    var hashValue: Int {
        return rootURL.hashValue
    }
}

func ==(lhs: ImageCollection, rhs: ImageCollection) -> Bool {
    return lhs.rootURL == rhs.rootURL
}
