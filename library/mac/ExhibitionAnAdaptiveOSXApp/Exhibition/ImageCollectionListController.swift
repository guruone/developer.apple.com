/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Contains the `ImageCollectionListController` view controller subclass, which displays a list of `ImageCollection`s.
*/

import Cocoa

/**
    `ImageCollectionListController` displays a list of `ImageCollection`s in an
    `NSOutlineView`. It can be given a selection handler to report when an 
    `ImageCollection` is selected.
*/
class ImageCollectionListController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    // MARK: Properties
    
    @IBOutlet var outlineView: NSOutlineView!

    override var nibName: String {
        return "ImageCollectionListController"
    }
    
    /// The identifier used for collection rows in the outline view
    static let collectionCellIdentifier = "DataCell"

    // MARK: Image Collection Management

    var imageCollectionSelectionHandler: ([ImageCollection] -> Void)?

    var imageCollections = [ImageCollection]() {
        didSet {
            guard viewLoaded else { return }

            reloadOutlineAndSelectFirstItemIfNecessary()
        }
    }

    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        reloadOutlineAndSelectFirstItemIfNecessary()
    }

    func reloadOutlineAndSelectFirstItemIfNecessary() {
        let oldSelection = outlineView.selectedRowIndexes

        outlineView.reloadData()

        if oldSelection.count == 0 {
            /*
                If the outline view didn't already have a selection, select the
                first `ImageCollection` (if one exists).
            */
            guard !imageCollections.isEmpty else { return }

            let firstIndexSet = NSIndexSet(index: 0)

            outlineView.selectRowIndexes(firstIndexSet, byExtendingSelection: false)

            /*
                Programmatically changing the selection doesn't send a notification (it only
                happens when the user changes it). So, explicitly handle the new selection.
            */
            handleSelectionChanged()
        }
        else {
            // If there was an old selection, restore that old selection.
            outlineView.selectRowIndexes(oldSelection, byExtendingSelection: false)
        }
    }

    // MARK: OutlineView Data Source / Delegate

    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        return imageCollections[index]
    }

    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        // The root item has each collection as its children.
        if item == nil {
            return imageCollections.count
        }
        
        return 0
    }

    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        guard let collection = item as? ImageCollection else { return nil }

        let view = outlineView.makeViewWithIdentifier(ImageCollectionListController.collectionCellIdentifier, owner: self) as! NSTableCellView

        view.textField?.stringValue = collection.name
        view.imageView?.image = collection.tableViewIcon
        
        /*
            Turn on `translatesAutoresizingMaskIntoConstraints` so the outline view
            can manage the size and position of the views, specifically when the
            'Sidebar Icon Size' changes. With this on, the source nib must not be
            adding any runtime constraints to these views.
        */
        view.textField?.translatesAutoresizingMaskIntoConstraints = true
        view.imageView?.translatesAutoresizingMaskIntoConstraints = true
        
        return view
    }

    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return false
    }

    func outlineView(outlineView: NSOutlineView, isGroupItem item: AnyObject) -> Bool {
        return false
    }

    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        return item is ImageCollection
    }
    
    func outlineViewSelectionDidChange(notification: NSNotification) {
        guard outlineView == notification.object as? NSOutlineView else { return }

        handleSelectionChanged()
    }

    private func handleSelectionChanged() {
        guard let imageCollectionSelectionHandler = imageCollectionSelectionHandler else { return }

        let selectedRows = outlineView.selectedRowIndexes

        // Of the selected rows, get the ones that represent an `ImageCollection`.
        let imageCollections = selectedRows.flatMap { row in
            /*
                If the row doesn't represent an image collection, the result will
                be filtered out.
            */
            return outlineView.itemAtRow(row) as? ImageCollection
        }

        imageCollectionSelectionHandler(imageCollections)
    }

    // MARK: IBActions

    @IBAction func showOpenPanelToAddImageCollection(sender: AnyObject?) {
        /// Show an `NSOpenPanel` to select a directory to create an `ImageCollection`.
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false

        func modalCompletionHandler(modalResponse: NSModalResponse) {
            // Check that the response was OK, rather than Cancel.
            if modalResponse == NSFileHandlingPanelOKButton {
                /*
                    For every URL selected, create an `ImageCollection` and add
                    that to the list of displayed collections.
                */
                imageCollections += openPanel.URLs.map { ImageCollection(rootURL: $0) }
            }
        }

        if let sheetParent = view.window {
            openPanel.beginSheetModalForWindow(sheetParent, completionHandler: modalCompletionHandler)
        }
        else {
            openPanel.beginWithCompletionHandler(modalCompletionHandler)
        }
    }
}

