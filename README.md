RichTextEditor -- Mac OS X
==================
**NOTE: This repo is in real need of some help. Code needs cleaned up, it doesn't support numbered lists, and the implementation for bulleted lists could be reworked (although the current implementation appears to be working OK overall). I haven't gotten the chance to do this myself. Please help!**

MAC NOTES:
-The Mac version has no toolbar or things like that. You will need to implement much of the UI yourself (buttons, handling selection changes via the delegate protocol, etc.). The RTE just handles the bold/italic/bulleted lists/etc. for you. Some day, in a perfect world, I'll update this with a proper example. Rest assured, however, that I (Deadpikle) am using this code in a presentation software package for speaker notes rich text editing, and it works rather well.
-You only need 6 files:

	- RichTextEditor.h/m
	- NSFont+RichTextEditor.h/m
	- NSAttributedString+RichTextEditor.h/m

-The Mac version is improved over the iOS version. It uses NSTextStorage instead of replacing the entire attributed string, which fixes several problems and also increases performance. It also has more features overall. Eventually, these updates should propagate to the iOS version (someone want to make a pull request and perform those updates? We'd have to drop < iOS 6 support...).

-Forked by Deadpikle for additional fixes and features. Readme updates TODO. There have been many enhancements and improvements. Please bug me for an updated README if I forget, which I probably will. The code is by no means perfectly clean, but it does function! Be wary of using the stock undo/redo with bulleted lists —- it often fails. Also, I have no idea how CocoaPods updates with forks work, so if someone needs me to do that, please point me in the right direction…-

Scaling Text [TODO: move to Wiki]

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



RichTextEditor for iPhone &amp; iPad

Features:
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

![alt tag](https://raw.github.com/aryaxt/iOS-Rich-Text-Editor/master/ipadScreenShot.png)

![alt tag](https://raw.github.com/aryaxt/iOS-Rich-Text-Editor/master/iphoneScreenshot.png)


Custom Font Size Selection
-------------------------
Font size selection can be customized by implementing the following data source method

```objective-c
- (NSArray *)fontSizeSelectionForRichTextEditor:(RichTextEditor *)richTextEditor
{
	// pas an array of NSNumbers
	return @[@5, @10, @20, @30];
}
```

Custom Font Family Selection
-------------------------
Font family selection can be customized by implementing the following data source method

```objective-c
- (NSArray *)fontFamilySelectionForRichTextEditor:(RichTextEditor *)richTextEditor
{
	// pas an array of Strings
  // Can be taken from [UIFont familyNames]
	return @[@"Helvetica", @"Arial", @"Marion", @"Papyrus"];
}
```

Presentation Style
-------------------------
You can switch between popover, or modal (presenting font-picker, font-size-picker, color-picker dialogs) by implementing the following data source method
```objective-c
- (RichTextEditorToolbarPresentationStyle)presentarionStyleForRichTextEditor:(RichTextEditor *)richTextEditor
{
  // RichTextEditorToolbarPresentationStyleModal Or RichTextEditorToolbarPresentationStylePopover
	return RichTextEditorToolbarPresentationStyleModal;
}
```

Modal Presentation Style
-------------------------
When presentarionStyleForRichTextEditor is a modal, modal-transition-style & modal-presentation-style can be configured
```objective-c
- (UIModalPresentationStyle)modalPresentationStyleForRichTextEditor:(RichTextEditor *)richTextEditor
{
	return UIModalPresentationFormSheet;
}

- (UIModalTransitionStyle)modalTransitionStyleForRichTextEditor:(RichTextEditor *)richTextEditor
{
	return UIModalTransitionStyleFlipHorizontal;
}
```

Customizing Features
-------------------------
Features can be turned on/off by iplementing the following data source method
```objective-c
- (RichTextEditorFeature)featuresEnabledForRichTextEditor:(RichTextEditor *)richTextEditor
{
   return RichTextEditorFeatureFont |
          RichTextEditorFeatureFontSize |
          RichTextEditorFeatureBold |
          RichTextEditorFeatureParagraphIndentation;
}
```

Enable/Disable RichText Toolbar
-------------------------
You can hide the rich text toolbar by implementing the following method. This method gets called everytime textView becomes first responder.
This can be usefull when you don't want the toolbar, instead you want to use the basic features (bold, italic, underline, strikeThrough), thoguht the UIMeMenuController
```objective-c
- (BOOL)shouldDisplayToolbarForRichTextEditor:(RichTextEditor *)richTextEditor
{
   return YES;
}
```

Enable/Disable UIMenuController Options
-------------------------
On default the UIMenuController options (bold, italic, underline, strikeThrough) are turned off. You can implement the follwing method if you want these features to be available through the UIMenuController along with copy/paste/selectAll etc.
```objective-c
- (BOOL)shouldDisplayRichTextOptionsInMenuControllerForRichTextrEditor:(RichTextEditor *)richTextEdiotor
{
   return YES;
}
```

Credits
-------------------------
iPhone popover by werner77
https://github.com/werner77/WEPopover
