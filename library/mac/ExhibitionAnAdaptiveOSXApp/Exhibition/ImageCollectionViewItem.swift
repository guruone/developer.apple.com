/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Contains the `ImageCollectionViewItem` class, which is a collection view item that displays an `ImageFile`'s thumbnail.
                Also contains `DoubleActionImageView`, which is an image view subclass that has a double click action.
*/

import Cocoa

/**
    The KVO context used for all `ImageCollectionViewItem` instances. This provides
    a stable address to use as the context parameter for the KVO observation methods.
*/
private var imageCollectionViewItemKVOContext = 0

/**
    `ImageCollectionViewItem` is a collection view item that displays `ImageFile`s.
    They display their selection and take into consideration the active state of 
    their containing `collectionView`. Double clicking on the item displays a 
    `StandaloneImageWindowController` with the represented `ImageFile`.
*/
class ImageCollectionViewItem: NSCollectionViewItem {
    // MARK: Properties

    var imageFile: ImageFile? {
        didSet {
            guard viewLoaded else { return }

            updateImageViewWithImageFile(imageFile)
        }
    }

    override var selected: Bool {
        didSet {
            updateAppearanceFromKeyState()
        }
    }

    override var highlightState: NSCollectionViewItemHighlightState {
        didSet {
            updateAppearanceFromKeyState()
        }
    }

    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        /*
            If the set image view is a `DoubleActionImageView`, set the `doubleAction` 
            to be the double click handler.
        */
        if let imageView = imageView as? DoubleActionImageView {
            imageView.doubleAction = "handleDoubleClickInImageView:"
            imageView.target = self
        }

        updateImageViewWithImageFile(imageFile)

        view.layer?.cornerRadius = 2.0

        /*
            Watch for when the containing `collectionView` changes in order to 
            observe its `firstResponder`. Include the old and new `collectionView` 
            in the change dictionary to be able to unobserve the old one.
        */
        addObserver(self, forKeyPath: "collectionView", options: [.Initial, .Old, .New], context: &imageCollectionViewItemKVOContext)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Observe the window for `keyWindow` state changes.
        if let window = view.window {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowDidChangeKeyState:", name: NSWindowDidBecomeKeyNotification, object: window)

            NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowDidChangeKeyState:", name: NSWindowDidResignKeyNotification, object: window)
        }

        // Update the selection appearance now that the item is in a window
        updateAppearanceFromKeyState()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        // Stop observing the window for `keyWindow` state changes.
        if let window = view.window {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidBecomeKeyNotification, object: window)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowDidResignKeyNotification, object: window)
        }
    }

    deinit {
        // Stop observing for containing `collectionView` changes.
        self.removeObserver(self, forKeyPath: "collectionView", context: &imageCollectionViewItemKVOContext)


        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func updateImageViewWithImageFile(imageFile: ImageFile?) {
        if let imageFile = imageFile {
            /*
                Fetch the `ImageFile`'s image representation and update set it 
                on the image view.
            */
            imageFile.fetchThumbnailWithCompletionHandler { thumbnail in
                /*
                    Verify that the loaded image representation is from the currently
                    set `ImageFile`.
                */
                if self.imageFile == imageFile {
                    self.imageView?.image = thumbnail
                }
            }
        }
        else {
            imageView?.image = nil
        }
    }

    // MARK: Key Appearance Updating

    private func updateAppearanceFromKeyState() {
        /*
            If the containing collection view is the first responder in a window 
            that is key, then its items have a key appearance.
        */
        let hasKeyAppearance = collectionView.firstResponder && (collectionView.window?.keyWindow ?? false)

        /*
            If the item has key appearance, it uses the user's set selection color, 
            otherwise uses the standard inactive selection color.
        */
        let baseHighlightColor = hasKeyAppearance ? NSColor.alternateSelectedControlColor() : NSColor.secondarySelectedControlColor()

        let backgroundColor: CGColor

        switch highlightState {
            case .ForSelection:
                backgroundColor = baseHighlightColor.colorWithAlphaComponent(0.4).CGColor

            case .AsDropTarget:
                backgroundColor = baseHighlightColor.colorWithAlphaComponent(1.0).CGColor

            default:
                if selected {
                    backgroundColor = baseHighlightColor.colorWithAlphaComponent(0.8).CGColor
                }
                else {
                    backgroundColor = NSColor.clearColor().CGColor
                }
            }
        
        view.layer?.backgroundColor = backgroundColor
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String: AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard context == &imageCollectionViewItemKVOContext else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }

        if object === collectionView && keyPath == "isFirstResponder" {
            /*
                If the item's collection view changed first responder state, the 
                selection appearance may have changed.
            */
            updateAppearanceFromKeyState()
        }
        else if object === self && keyPath == "collectionView" {
            if let oldCollectionView = change?[NSKeyValueChangeOldKey] as? NSCollectionView {
                // Stop observing the containing collection view for first responder changes.
                oldCollectionView.removeObserver(self, forKeyPath: "isFirstResponder", context: &imageCollectionViewItemKVOContext)
            }

            if let newCollectionView = change?[NSKeyValueChangeNewKey] as? NSCollectionView {
                // Observe the containing collection view for `firstResponder` state changes.
                newCollectionView.addObserver(self, forKeyPath: "isFirstResponder", options: .New, context: &imageCollectionViewItemKVOContext)
            }
        }
    }

    @objc private func windowDidChangeKeyState(notification: NSNotification) {
        // When the window changes key state, the selection appearance may have changed.
        updateAppearanceFromKeyState()
    }

    // MARK: IBActions

    @IBAction func handleDoubleClickInImageView(sender: AnyObject?) {
        // On double click, show a new standalone window for the set `image`.
        if let imageFile = imageFile {
            StandaloneImageWindowController.showStandaloneImage(imageFile)
        }
    }
}

/**
     An `NSImageView` subclass with a `doubleAction` that fires on double clicks.
*/
class DoubleActionImageView: NSImageView {
    // MARK: Properties

    var doubleAction: Selector?

    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    // MARK: Event Handling

    override func mouseDown(event: NSEvent) {
        if let doubleAction = doubleAction where event.clickCount == 2 {
            NSApp.sendAction(doubleAction, to: target, from: self)
        }
        else {
            super.mouseDown(event)
        }
    }
}
