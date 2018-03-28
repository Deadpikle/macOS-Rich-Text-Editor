//
//  RichTextEditor.h
//  RichTextEdtor
//
//  Created by Aryan Gh on 7/21/13.
//  Copyright (c) 2013 Aryan Ghassemi. All rights reserved.
//  Heavily modified for macOS by Deadpikle
//  Copyright (c) 2016 Deadpikle. All rights reserved.
//
// https://github.com/aryaxt/iOS-Rich-Text-Editor -- Original
// https://github.com/Deadpikle/macOS-Rich-Text-Editor -- Fork
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// TODO: better documentation
// TODO: Clean up, clean up, everybody do your share!

#import <Cocoa/Cocoa.h>

@class RichTextEditor;

@protocol RichTextEditorDataSource <NSObject>

@optional

- (NSUInteger)levelsOfUndo;

@end

// These values will always start from 0 and go up. If you want to add your own
// preview changes via a subclass, start from 9999 and go down (or similar) and
// override convertPreviewChangeTypeToString:withNonSpecialChangeText:
typedef NS_ENUM(NSInteger, RichTextEditorPreviewChange) {
    RichTextEditorPreviewChangeBold             = 0,
    RichTextEditorPreviewChangeItalic           = 1,
    RichTextEditorPreviewChangeUnderline        = 2,
    RichTextEditorPreviewChangeFontResize       = 3,
    RichTextEditorPreviewChangeHighlight        = 4,
    RichTextEditorPreviewChangeFontSize         = 5,
    RichTextEditorPreviewChangeFontColor        = 6,
    RichTextEditorPreviewChangeIndentIncrease   = 7,
    RichTextEditorPreviewChangeIndentDecrease   = 8,
    RichTextEditorPreviewChangeCut              = 9,
    RichTextEditorPreviewChangePaste            = 10,
    RichTextEditorPreviewChangeSpace            = 11,
    RichTextEditorPreviewChangeEnter            = 12,
    RichTextEditorPreviewChangeBullet           = 13,
    RichTextEditorPreviewChangeMouseDown        = 14,
    RichTextEditorPreviewChangeArrowKey         = 15,
    RichTextEditorPreviewChangeKeyDown          = 16,
	RichTextEditorPreviewChangeDelete           = 17,
    RichTextEditorPreviewChangeFindReplace      = 18
};

@protocol RichTextEditorDelegate <NSObject>

@required

-(void)selectionForEditor:(RichTextEditor*)editor changedTo:(NSRange)range isBold:(BOOL)isBold isItalic:(BOOL)isItalic isUnderline:(BOOL)isUnderline isInBulletedList:(BOOL)isInBulletedList textBackgroundColor:(NSColor*)textBackgroundColor textColor:(NSColor*)textColor;

@optional

- (BOOL)richTextEditor:(RichTextEditor*)editor keyDownEvent:(NSEvent*)event; // return YES if handled by delegate, NO if RTE should process it

- (BOOL)handlesUndoRedoForText;
- (void)userPerformedUndo; // TODO: remove?
- (void)userPerformedRedo; // TODO: remove?

- (void)richTextEditor:(RichTextEditor*)editor changeAboutToOccurOfType:(RichTextEditorPreviewChange)type;

@end

@interface RichTextEditor : NSTextView

@property (assign) IBOutlet id <RichTextEditorDataSource> rteDataSource;
@property (assign) IBOutlet id <RichTextEditorDelegate> rteDelegate;
@property (nonatomic, assign) CGFloat defaultIndentationSize;
@property (nonatomic, readonly) unichar lastSingleKeyPressed;

/// If YES, only pastes text as rich text if the copy operation came from this class.
/// Note: not this *object* -- this class (so other RichTextEditor boxes can paste
/// between each other). If the text did not come from a RichTextEditor box, then
/// pastes as plain text.
/// If NO, performs the default paste: operation.
/// Defaults to YES.
@property BOOL allowsRichTextPasteOnlyFromThisClass;

/// Amount to change font size on each increase/decrease font size call.
/// Defaults to 10.0f
@property CGFloat fontSizeChangeAmount;

/// Maximum font size. Defaults to 128.0f.
@property CGFloat maxFontSize;

/// Minimum font size. Defaults to 10.0f.
@property CGFloat minFontSize;

/// Pasteboard type string used when copying text from this NSTextView.
+(NSString*)pasteboardDataType;

/// Call the following methods when the user does the given action (clicks bold button, etc.)

/// Toggle bold.
- (void)userSelectedBold;

/// Toggle italic.
- (void)userSelectedItalic;

/// Toggle underline.
- (void)userSelectedUnderline;

/// Toggle bulleted list.
- (void)userSelectedBullet;

/// Increase the total indentation of the current paragraph.
- (void)userSelectedIncreaseIndent;

/// Decrease the total indentation of the current paragraph.
- (void)userSelectedDecreaseIndent;

/// Change the text background (highlight) color for the currently selected text.
- (void)userSelectedTextBackgroundColor:(NSColor*)color;

/// Change the text color for the currently selected text.
- (void)userSelectedTextColor:(NSColor*)color;

/// Perform an undo operation if one is available.
- (void)undo;

/// Perform a redo operation if one is available.
- (void)redo;

/// Change the currently selected text to the given font name.
- (void)userChangedToFontName:(NSString*)fontName;

/// Change the currently selected text to the specified font size.
- (void)userChangedToFontSize:(NSNumber*)fontSize;

/// Increases the font size of the currently selected text by self.fontSizeChangeAmount.
- (void)increaseFontSize;

/// Decreases the font size of the currently selected text by self.fontSizeChangeAmount.
- (void)decreaseFontSize;

/// Toggles whether or not the paragraphs in the currently selected text have a first
/// line head indent value of self.defaultIndentationSize.
- (void)userSelectedParagraphFirstLineHeadIndent;

/// Change the text alignment for the paragraphs in the currently selected text.
- (void)userSelectedTextAlignment:(NSTextAlignment)textAlignment;

/// Convenience method; YES if user has something selected (selection length > 0).
- (BOOL)hasSelection;

/// Changes the editor's contents to the given attributed string.
- (void)changeToAttributedString:(NSAttributedString*)string;

/// Convenience method to set the editor's border color.
- (void)setBorderColor:(NSColor*)borderColor;

/// Convenience method to set the editor's border width.
- (void)setBorderWidth:(CGFloat)borderWidth;

/// Converts the current NSAttributedString to an HTML string.
- (NSString *)htmlString;

/// Converts the provided htmlString into an NSAttributedString and then
/// sets the editor's text to the attributed string.
- (void)setHtmlString:(NSString *)htmlString;

/// Grabs the NSString used as the bulleted list prefix.
- (NSString*)bulletString;

/// Converts the provided NSAttributedString into an HTML string.
+ (NSString *)htmlStringFromAttributedText:(NSAttributedString*)text;

/// Converts the given HTML string into an NSAttributedString.
+ (NSAttributedString*)attributedStringFromHTMLString:(NSString *)htmlString;

/// Converts a given RichTextEditorPreviewChange to a human-readable string
+ (NSString *)convertPreviewChangeTypeToString:(RichTextEditorPreviewChange)changeType withNonSpecialChangeText:(BOOL)shouldReturnStringForNonSpecialType;

// // // // // // // // // // // // // // // // // // // //
// I'm not sure why you'd call these externally, but subclasses can make use of this for custom toolbar items or what have you.
// It's just easier to put these in the public header than to have a protected/subclasses-only header.
-(void)sendDelegatePreviewChangeOfType:(RichTextEditorPreviewChange)type;
-(void)sendDelegateTVChanged;

@end
