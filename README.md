macOS Rich Text Editor
==================

The macOS Rich Text Editor library allows for rich text editing via a native `NSTextView` You will need to implement much of the UI yourself (buttons, handling selection changes via the delegate protocol, etc.). The RTE just handles the bold/italic/bulleted lists/etc. formatting for you. The sample should give you some guidance on how this could be accomplished.

-You only need 8 files:

	- RichTextEditor.h/m
	- NSFont+RichTextEditor.h/m
	- NSAttributedString+RichTextEditor.h/m
	- WZProtocolInterceptor.h/m

Based upon the Rich Text Editor [here](https://github.com/Deadpikle/iOS-Rich-Text-Editor), which was edited from the original code [here](https://github.com/aryaxt/iOS-Rich-Text-Editor).

### TODO

- [ ] Tab/spaces consistency
- [x] Starting bracket for function/conditional on same line as function name or conditional instead of next line
- [x] Create an example with a working GUI
- [ ] Show how to call/use from Swift 4
- [ ] Get this on Cocoapods
- [x] Framework output (Carthage too?)

### Features:

- Bold
- Italic
- Underline
- Font
- Font size
- Text background color
- Text foreground color
- Text alignment
- Paragraph indent/outdent
- Bulleted lists

#### Keyboard Shortcuts

| Shortcut  | Action |
| ------------- | ------------- |
| ⌘ + B  | Toggle bold  |
| ⌘ + I  | Toggle italic  |
| ⌘ + U  | Toggle underline  |
| ⌘ + ⇧ + >  | Increase font size |
| ⌘ + ⇧ + <  | Decrease font size |
| ⌘ + ⇧ + L  | Toggle bulleted list |
| ⌘ + ⇧ + N  | If in bulleted list, leave bulleted list |
| ⌘ + ⇧ + T  | Decrease indent |
| ⌘ + T  | Increase indent |

#### Scaling Text [TODO: move to Wiki]

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


Credits
-------------------------

Original Rich Text Editor code by aryaxt at [iOS Rich Text Editor](https://github.com/aryaxt/iOS-Rich-Text-Editor). `WZProtocolInterceptor` is from [here](http://stackoverflow.com/a/18777565/3938401).
