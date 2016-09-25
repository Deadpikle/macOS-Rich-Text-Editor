macOS Rich Text Editor
==================
**NOTE: This repo is in real need of some help. Code needs cleaned up, it doesn't support numbered lists, and the implementation for bulleted lists could be reworked (although the current implementation appears to be working OK overall). I haven't gotten the chance to do this myself. Please help!**

You will need to implement much of the UI yourself (buttons, handling selection changes via the delegate protocol, etc.). The RTE just handles the bold/italic/bulleted lists/etc. for you. Some day, in a perfect world, I'll update this with a proper example. Rest assured, however, that I (Deadpikle) am using this code in a presentation software package for speaker notes rich text editing, and it works rather well.

-You only need 8 files:

	- RichTextEditor.h/m
	- NSFont+RichTextEditor.h/m
	- NSAttributedString+RichTextEditor.h/m
	- WZProtocolInterceptor.h/m

Based upon the Rich Text Editor at [here](https://github.com/Deadpikle/iOS-Rich-Text-Editor), which was edited from the original code [here](https://github.com/aryaxt/iOS-Rich-Text-Editor).

### TODO

- [ ] Create an example
- [ ] Show how to call/use from Swift 3
- [ ] Get this on Cocoapods

####Scaling Text [TODO: move to Wiki]

If you want to scale text, you can use code similar to the following (based on http://stackoverflow.com/a/14113905/3938401):
```
// http://stackoverflow.com/a/14113905/3938401
@interface ...
@property CGFloat scaleFactor;
@end

@implementation ...

-(void)viewDidLoad {
    self.scaleFactor = 1.0f;
    ...
}

- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag {
    CGFloat oldScaleFactor = self.scaleFactor;
    if (self.scaleFactor != newScaleFactor) {
        NSSize curDocFrameSize, newDocBoundsSize;
        NSView *clipView = [self.notesTextView superview];
        self.scaleFactor = newScaleFactor;
        // Get the frame. The frame must stay the same.
        curDocFrameSize = [clipView frame].size;
        // The new bounds will be frame divided by scale factor
        newDocBoundsSize.width = curDocFrameSize.width / self.scaleFactor;
        newDocBoundsSize.height = curDocFrameSize.height / self.scaleFactor;
    }
    self.scaleFactor = newScaleFactor;
    [self scaleChanged:oldScaleFactor newScale:newScaleFactor];
}

- (void)scaleChanged:(CGFloat)oldScale newScale:(CGFloat)newScale {
    CGFloat scaler = newScale / oldScale;
    [self.notesTextView scaleUnitSquareToSize:NSMakeSize(scaler, scaler)];
    // For some reason, even after ensuring the layout and displaying, the wrapping doesn't update until text is messed
    // with. This workaround "fixes" that. Since we need it anyway, I removed the ensureLayoutForTextContainer:
    // (from the SO post) and the documentation-implied [self.notesTextView display] calls.
    [[self.notesTextView textStorage] appendAttributedString:[[NSAttributedString alloc] initWithString:@""]];
}

@end
```

### Features:

- Bold
- Italic
- Underline
- StrikeThrough
- Font
- Font size
- Text background color
- Text foregroud color
- Text alignment
- Paragraph Indent/Outdent


Credits
-------------------------
Original Rich Text Editor code by aryaxt at [iOS Rich Text Editor](https://github.com/aryaxt/iOS-Rich-Text-Editor).
