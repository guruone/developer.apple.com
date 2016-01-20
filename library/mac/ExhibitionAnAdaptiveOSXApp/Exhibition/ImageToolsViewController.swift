/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Contains the `ImageToolsViewController` class, which manages the UI of a stack of tools buttons.
*/


import Cocoa

/**
    `ImageToolsViewController` manages a list of tool controls. The controls can be
    detached from the tool stack once their contained view becomes too small and 
    displayed in an overflow menu.
*/
class ImageToolsViewController: NSViewController, NSStackViewDelegate {
    // MARK: Properties

    @IBOutlet var stackView: NSStackView!

    /**
        The button shown when the tool stack is too small to present all of its
        buttons. Clicking on the overflow button shows a menu with representations 
        of the detached buttons.
    */
    lazy var overflowRevealButton: NSButton = {
        let overflowRevealButton = NSButton()

        overflowRevealButton.bezelStyle = .ShadowlessSquareBezelStyle
        
        overflowRevealButton.translatesAutoresizingMaskIntoConstraints = false
        
        overflowRevealButton.attributedTitle = NSAttributedString(string: "...", attributes: [
            NSFontAttributeName: NSFont.boldSystemFontOfSize(13.0)
        ])
        
        overflowRevealButton.alphaValue = 0.75
        
        overflowRevealButton.target = self
        
        overflowRevealButton.action = "popUpOverflowMenu:"
        
        return overflowRevealButton
    }()

    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        stackView.detachesHiddenViews = true
    }


    // MARK: Overflow Menu

    /**
        Creates a menu for the detached views in the stack. The title, target, 
        and action of the menu items match the associated buttons. If there were 
        no detached items, returns nil.
    */
    var overflowMenu: NSMenu? {
        let detachedButtons = stackView.detachedViews.flatMap { $0 as? NSButton }

        if !detachedButtons.isEmpty {
            let menu = NSMenu(title: "Detached Items")

            /*
                Do not use auto-validation, the menu items will have the same 
                enabled state as their represented button.
            */
            menu.autoenablesItems = false

            /* 
                Add a menu item for each detached button, transferring the applicable
                button state to the menu item.
            */
            for button in detachedButtons {
                if let menuItem = menu.addItemWithTitle(button.title, action: button.action, keyEquivalent: button.keyEquivalent) {
                    menuItem.target = button.target
                    menuItem.enabled = button.enabled
                    menuItem.representedObject = button
                }
            }

            return menu
        }

        return nil
    }

    @objc private func popUpOverflowMenu(sender: AnyObject?) {
        // Show the overflow menu (if we one exists) underneath the overflow button.
        let popUpMenuLocation = NSPoint(x: overflowRevealButton.bounds.minX, y: overflowRevealButton.bounds.maxY)
        
        overflowMenu?.popUpMenuPositioningItem(nil, atLocation: popUpMenuLocation, inView: overflowRevealButton)
    }


    // MARK: NSStackView Delegate

    func stackView(stackView: NSStackView, willDetachViews views: [NSView]) {
        /*
            If the stack view did not previously have any detached views, these 
            are the first, so the overflow button needs to be added and constrained.
        */
        if stackView.detachedViews.isEmpty {
            /*
                Add the overflow button (not as an arranged subview), and constraints 
                to position it on the trailing edge of the stack view.
            */
            stackView.addSubview(overflowRevealButton)

            overflowRevealButton.trailingAnchor.constraintEqualToAnchor(stackView.trailingAnchor).active = true
            
            overflowRevealButton.topAnchor.constraintEqualToAnchor(stackView.topAnchor).active = true
            
            overflowRevealButton.bottomAnchor.constraintEqualToAnchor(stackView.bottomAnchor).active = true
        }
    }

    func stackView(stackView: NSStackView, didReattachViews views: [NSView]) {
        /*
            If the stack view no longer has any detached views, these were the last, 
            so the overflow button needs to be removed.
        */
        if stackView.detachedViews.isEmpty {
            // Removing the overflow button will also remove constraints associated with it.
            overflowRevealButton.removeFromSuperview()
        }
    }

}
