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

// Make sure to call removeTextObserverForDealloc before going away (forever) from the screen with the RTE (TODO: We should find a better way for this and fix it!)

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

typedef NS_ENUM(NSInteger, ParagraphIndentation) {
    ParagraphIndentationIncrease,
    ParagraphIndentationDecrease
};

@interface RichTextEditor : NSTextView

@property (assign) IBOutlet id <RichTextEditorDataSource> rteDataSource;
@property (assign) IBOutlet id <RichTextEditorDelegate> rteDelegate;
@property (nonatomic, assign) CGFloat defaultIndentationSize;
@property (nonatomic, readonly) unichar lastSingleKeyPressed;

// If YES, only pastes text as rich text if the copy operation came from this class.
// Note: not this *object* -- this class (so other RichTextEditor boxes can paste
// between each other). If the text did not come from a RichTextEditor box, then
// pastes as plain text.
// If NO, performs the default paste: operation.
// Defaults to YES.
@property BOOL allowsRichTextPasteOnlyFromThisClass;

+(NSString*)pasteboardDataType;

// call these methods when the user does the given action (clicks bold button, etc.)
- (void)userSelectedBold;
- (void)userSelectedItalic;
- (void)userSelectedUnderline;
- (void)userSelectedBullet;
- (void)userSelectedIncreaseIndent;
- (void)userSelectedDecreaseIndent;
- (void)userSelectedTextBackgroundColor:(NSColor*)color;
- (void)userSelectedTextColor:(NSColor*)color;

- (void)undo;
- (void)redo;

- (void)userChangedToFontName:(NSString*)fontName;
- (void)userChangedToFontSize:(NSNumber*)fontSize;

- (void)increaseFontSize;
- (void)decreaseFontSize;

- (void)userSelectedParagraphFirstLineHeadIndent;
- (void)userSelectedTextAlignment:(NSTextAlignment)textAlignment;

- (BOOL)hasSelection; // convenience method; YES if user has something selected

- (void)changeToAttributedString:(NSAttributedString*)string;

- (void)setBorderColor:(NSColor*)borderColor;
- (void)setBorderWidth:(CGFloat)borderWidth;

- (NSString *)htmlString;
- (void)setHtmlString:(NSString *)htmlString;

- (NSString*)bulletString;

+ (NSString *)htmlStringFromAttributedText:(NSAttributedString*)text;
+ (NSAttributedString*)attributedStringFromHTMLString:(NSString *)htmlString;

+ (NSString *)convertPreviewChangeTypeToString:(RichTextEditorPreviewChange)changeType withNonSpecialChangeText:(BOOL)shouldReturnStringForNonSpecialType;

// I'm not sure why you'd call these externally, but subclasses can make use of this for custom toolbar items or what have you.
// It's just easier to put these in the public header than to have a protected/subclasses-only header.
-(void)sendDelegatePreviewChangeOfType:(RichTextEditorPreviewChange)type;
-(void)sendDelegateTVChanged;

@end
