//
//  RichTextEditor.h
//  RichTextEdtor
//
//  Created by Aryan Gh on 7/21/13.
//  Copyright (c) 2013 Aryan Ghassemi. All rights reserved.
//
// https://github.com/aryaxt/iOS-Rich-Text-Editor
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

#import <Cocoa/Cocoa.h>
//#import "RichTextEditorToolbar.h"

@class RichTextEditor;
@protocol RichTextEditorDataSource <NSObject>
@optional
- (NSArray *)fontSizeSelectionForRichTextEditor:(RichTextEditor *)richTextEditor;
- (NSArray *)fontFamilySelectionForRichTextEditor:(RichTextEditor *)richTextEditor;
//- (RichTextEditorToolbarPresentationStyle)presentationStyleForRichTextEditor:(RichTextEditor *)richTextEditor;
//- (UIModalPresentationStyle)modalPresentationStyleForRichTextEditor:(RichTextEditor *)richTextEditor;
//- (UIModalTransitionStyle)modalTransitionStyleForRichTextEditor:(RichTextEditor *)richTextEditor;
//- (RichTextEditorFeature)featuresEnabledForRichTextEditor:(RichTextEditor *)richTextEditor;
- (BOOL)shouldDisplayToolbarForRichTextEditor:(RichTextEditor *)richTextEditor;
- (BOOL)shouldDisplayRichTextOptionsInMenuControllerForRichTextEditor:(RichTextEditor *)richTextEditor;
//- (UIViewController <RichTextEditorColorPicker> *)colorPickerForRichTextEditor:(RichTextEditor *)richTextEditor withAction:(RichTextEditorColorPickerAction)action;
//- (UIViewController <RichTextEditorFontPicker> *)fontPickerForRichTextEditor:(RichTextEditor *)richTextEditor;
//- (UIViewController <RichTextEditorFontSizePicker> *)fontSizePickerForRichTextEditor:(RichTextEditor *)richTextEditor;
-(NSUInteger)levelsOfUndo;
-(BOOL)handlesUndoRedoForText;
-(void)userPerformedUndo;
-(void)userPerformedRedo;
@end

@protocol RichTextEditorDelegate <NSObject>
@required
-(void)userSelectionChanged:(NSRange)range isBold:(BOOL)isBold isItalic:(BOOL)isItalic isUnderline:(BOOL)isUnderline isInBulletedList:(BOOL)isInBulletedList textBackgroundColor:(NSColor*)textBackgroundColor textColor:(NSColor*)textColor;
@end

typedef enum {
    ParagraphIndentationIncrease,
    ParagraphIndentationDecrease
} ParagraphIndentation;

@interface RichTextEditor : NSTextView <NSTextViewDelegate>

@property (assign) IBOutlet id <RichTextEditorDataSource> rteDataSource;
@property (assign) IBOutlet id <RichTextEditorDelegate> rteDelegate;
@property (nonatomic, assign) CGFloat defaultIndentationSize;
@property  BOOL userInBulletList;

-(void)userSelectedBold;
-(void)userSelectedItalic;
-(void)userSelectedUnderline;
-(void)userSelectedBullet;
-(void)userSelectedIncreaseIndent;
-(void)userSelectedDecreaseIndent;
-(void)userSelectedTextBackgroundColor:(NSColor*)color;
-(void)userSelectedTextColor:(NSColor*)color;
// TODO: text background color, text color

- (void)setBorderColor:(NSColor*)borderColor;
- (void)setBorderWidth:(CGFloat)borderWidth;
- (NSString *)htmlString;
- (void)setHtmlString:(NSString *)htmlString;
- (void)changeToAttributedString:(NSAttributedString*)string;
+ (NSString *)htmlStringFromAttributedText:(NSAttributedString*)text;
+ (NSAttributedString*)attributedStringFromHTMLString:(NSString *)htmlString;
- (void)removeTextObserverForDealloc;

@end
