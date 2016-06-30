//
//  RichTextEditor.h
//  RichTextEdtor
//
//  Created by Aryan Gh on 7/21/13.
//  Copyright (c) 2013 Aryan Ghassemi. All rights reserved.
//  Heavily modified for iOS and OS X by Deadpikle
//  Copyright (c) 2016 Deadpikle. All rights reserved.
//
// https://github.com/aryaxt/iOS-Rich-Text-Editor -- Original
// https://github.com/Deadpikle/iOS-and-Mac-OS-X-Rich-Text-Editor -- Fork
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
- (NSArray *)fontSizeSelectionForRichTextEditor:(RichTextEditor *)richTextEditor;
- (NSArray *)fontFamilySelectionForRichTextEditor:(RichTextEditor *)richTextEditor;
- (BOOL)shouldDisplayToolbarForRichTextEditor:(RichTextEditor *)richTextEditor;
- (BOOL)shouldDisplayRichTextOptionsInMenuControllerForRichTextEditor:(RichTextEditor *)richTextEditor;
- (NSUInteger)levelsOfUndo;
@end

@protocol RichTextEditorDelegate <NSObject>

@required

-(void)userSelectionChanged:(NSRange)range isBold:(BOOL)isBold isItalic:(BOOL)isItalic isUnderline:(BOOL)isUnderline isInBulletedList:(BOOL)isInBulletedList textBackgroundColor:(NSColor*)textBackgroundColor textColor:(NSColor*)textColor;

@optional

/**
 *  
 *
 *  @param affectedCharRange <#affectedCharRange description#>
 *  @param replacementString <#replacementString description#>
 *
 *  @return return YES if handled by delegate, NO if RTE should process it
 */
-(BOOL)previewTextChangeForRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
-(void)textViewChanged:(NSNotification *)notification; // TODO: remove in favor of normal delegate
-(BOOL)richTextEditor:(RichTextEditor*)editor keyDownEvent:(NSEvent*)event; // return YES if handled by delegate, NO if RTE should process it

- (BOOL)handlesUndoRedoForText;
- (void)userPerformedUndo; // TODO: remove?
- (void)userPerformedRedo; // TODO: remove?

@end

typedef NS_ENUM(NSInteger, ParagraphIndentation) {
    ParagraphIndentationIncrease,
    ParagraphIndentationDecrease
};

@interface RichTextEditor : NSTextView

@property (assign) IBOutlet id <RichTextEditorDataSource> rteDataSource;
@property (assign) IBOutlet id <RichTextEditorDelegate> rteDelegate;
@property (nonatomic, assign) CGFloat defaultIndentationSize;

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

- (void)userSelectedPageBreak:(NSString*)pageBreakString;

- (NSString *)htmlString;
- (void)setHtmlString:(NSString *)htmlString;
+ (NSString *)htmlStringFromAttributedText:(NSAttributedString*)text;
+ (NSAttributedString*)attributedStringFromHTMLString:(NSString *)htmlString;

@end
