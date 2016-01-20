/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Contains the `ImageListController` view controller subclass that displays the images in an `ImageCollection`.
*/

import Cocoa

/**
    `ImageListController` displays the `ImageFiles` in a given `ImageCollection` in 
    an `NSCollectionView. It can be given a selection handler to report when an 
    `ImageFile` is selected.
*/
class ImageListController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    // MARK: Properties

    override var nibName: String {
        return "ImageListController"
    }
    
    private static let imageCollectionViewItemIdentifier = "ImageItem"

    @IBOutlet var collectionView: NSCollectionView!

    // MARK: Image File / Collection Management

    var imageSelectionHandler: (ImageFile? -> Void)?

    var imageCollections = [ImageCollection]() {
        didSet {
            // Observe the new collections for changes, and unobserve the old collections.
            for collection in oldValue {
                NSNotificationCenter.defaultCenter().removeObserver(self, name: ImageCollection.imagesDidChangeNotification, object: collection)
            }

            for collection in imageCollections {
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "imageCollectionDidChange:", name: ImageCollection.imagesDidChangeNotification, object: collection)
            }

            guard viewLoaded else { return }

            reloadCollectionViewAndSelectFirstItemIfNecessary()
        }
    }

    @objc func imageCollectionDidChange(notification: NSNotification) {
        reloadCollectionViewAndSelectFirstItemIfNecessary()
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    // MARK: Life Cycle

    override func viewDidLoad() {
        // Tell the CollectionView to use the ImageCollectionViewItem nib for its items.
        let nib = NSNib(nibNamed: "ImageCollectionViewItem", bundle: nil)

        collectionView.registerNib(nib, forItemWithIdentifier: ImageListController.imageCollectionViewItemIdentifier)
        
        collectionView.dataSource = self
        collectionView.delegate = self

        // Create a grid layout that is somewhat flexible for the various widths it might have.
        let gridLayout = NSCollectionViewGridLayout()
        gridLayout.minimumItemSize = NSSize(width: 100, height: 100)
        gridLayout.maximumItemSize = NSSize(width: 175, height: 175)
        gridLayout.minimumInteritemSpacing = 10
        gridLayout.margins = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collectionView.collectionViewLayout = gridLayout

        reloadCollectionViewAndSelectFirstItemIfNecessary()

        super.viewDidLoad()
    }

    private func reloadCollectionViewAndSelectFirstItemIfNecessary() {
        collectionView.reloadData()

        // If the `collectionView` has no selection, attempt to select the first available item.
        guard collectionView.selectionIndexPaths.isEmpty else { return }
        
        // Get the collections that contain images.
        let populatedCollections = imageCollections.filter { !$0.images.isEmpty }

        // Find the first `ImageCollection` that actually has images displayed.
        guard let firstPopulatedCollection = populatedCollections.first else { return }

        /*
            Get the index path to that collection's first image -- section is the 
            index of the collection, item index is 0.
        */
        let firstPopulatedIndex = imageCollections.indexOf(firstPopulatedCollection)!

        // Programmatically change the selection, and handle the changed selection.
        collectionView.selectionIndexPaths = [
            NSIndexPath(forItem: 0, inSection: firstPopulatedIndex)
        ]

        handleSelectionChanged()
    }


    // MARK: Collection View Data Source / Delegate

    func numberOfSectionsInCollectionView(collectionView: NSCollectionView) -> Int {
        return imageCollections.count
    }

    func collectionView(collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageCollections[section].images.count
    }

    func collectionView(collectionView: NSCollectionView, itemForRepresentedObjectAtIndexPath indexPath: NSIndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItemWithIdentifier(ImageListController.imageCollectionViewItemIdentifier, forIndexPath: indexPath)

        if let imageItem = item as? ImageCollectionViewItem {
            // The section maps to the index of the `ImageCollection`.
            let imageCollection = imageCollections[indexPath.section]

            imageItem.imageFile = imageCollection.images[indexPath.item]
        }
    
        return item
    }

    func collectionView(collectionView: NSCollectionView, didSelectItemsAtIndexPaths indexPaths: Set<NSIndexPath>) {
        handleSelectionChanged()
    }

    func collectionView(collectionView: NSCollectionView, didDeselectItemsAtIndexPaths indexPaths: Set<NSIndexPath>) {
        handleSelectionChanged()
    }

    private func handleSelectionChanged() {
        guard let imageSelectionHandler = imageSelectionHandler else { return }

        /*
            The collection view does not support multiple selection, so just check 
            the first index.
        */
        let selectedImage: ImageFile?

        if let selectedIndexPath = collectionView.selectionIndexPaths.first
           where selectedIndexPath.section != -1 && selectedIndexPath.item != -1 {
            // There is a selected index path, get the image at that path.
            selectedImage = imageCollections[selectedIndexPath.section].images[selectedIndexPath.item]
        }
        else {
            /*
                There is no selected index path -- the collection view supports
                empty selection, there is no selected image.
            */
            selectedImage = nil
        }

        imageSelectionHandler(selectedImage)
    }
}
