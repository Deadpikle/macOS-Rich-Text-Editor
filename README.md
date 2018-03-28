macOS Rich Text Editor
==================

The macOS Rich Text Editor library allows for rich text editing via a native `NSTextView` You will need to implement much of the UI yourself (buttons, handling selection changes via the delegate protocol, etc.). The RTE just handles the bold/italic/bulleted lists/etc. formatting for you. The sample should give you some guidance on how this could be accomplished.

To use this library, you only need eight files:

	- RichTextEditor.h/m
	- NSFont+RichTextEditor.h/m
	- NSAttributedString+RichTextEditor.h/m
	- WZProtocolInterceptor.h/m
    
You can copy these files directly into your project, or you can choose to build and use the `.framework` output. Remember to open the `.xcworkspace` file when exploring this project.

This library is based upon Deadpikle's [iOS Rich Text Editor](https://github.com/Deadpikle/iOS-Rich-Text-Editor), which was edited from the [original iOS rich text editor](https://github.com/aryaxt/iOS-Rich-Text-Editor) by [aryaxt](https://github.com/aryaxt).

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

Original Rich Text Editor code by [aryaxt](https://github.com/aryaxt) at the [iOS Rich Text Editor repo](https://github.com/aryaxt/iOS-Rich-Text-Editor). `WZProtocolInterceptor` is from [this SO post](http://stackoverflow.com/a/18777565/3938401).
