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

// Text editing architecture guide: https://developer.apple.com/library/mac/documentation/TextFonts/Conceptual/CocoaTextArchitecture/TextEditing/TextEditing.html#//apple_ref/doc/uid/TP40009459-CH3-SW1

#import "RichTextEditor.h"
#import <QuartzCore/QuartzCore.h>
#import "NSFont+RichTextEditor.h"
#import "NSAttributedString+RichTextEditor.h"
#import "WZProtocolInterceptor.h"
#import  <objc/runtime.h>

typedef NS_ENUM(NSInteger, ParagraphIndentation) {
    ParagraphIndentationIncrease,
    ParagraphIndentationDecrease
};

@interface RichTextEditor () <NSTextViewDelegate> {
}

// Gets set to YES when the user starts changing attributes when there is no text selection (selecting bold, italic, etc)
// Gets set to NO  when the user changes selection or starts typing
@property (nonatomic, assign) BOOL typingAttributesInProgress;

@property float currSysVersion;

@property NSInteger MAX_INDENT;
@property BOOL isInTextDidChange;

@property NSString *BULLET_STRING;

@property NSUInteger levelsOfUndo;
@property NSUInteger previousCursorPosition;

@property BOOL inBulletedList;
@property BOOL justDeletedBackward;

@property (nonatomic) NSRange lastAnchorPoint;
@property BOOL shouldEndColorChangeOnLeft;

@property WZProtocolInterceptor *delegate_interceptor;

@end

@implementation RichTextEditor

+(NSString*)pasteboardDataType {
	return @"macOSRichTextEditor57";
}

#pragma mark - Initialization -

- (id)init {
    if (self = [super init]) {
        [self commonInitialization];
    }
	
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInitialization];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if (self = [super initWithCoder:aDecoder]) {
		[self commonInitialization];
	}
	
	return self;
}

- (id)delegate {
    return self.delegate_interceptor.receiver;
}

- (void)setDelegate:(id)newDelegate {
    [super setDelegate:nil];
	self.delegate_interceptor.receiver = newDelegate;
    [super setDelegate:(id)self.delegate_interceptor];
}

- (void)commonInitialization {
    // Prevent the use of self.delegate = self
    // http://stackoverflow.com/questions/3498158/intercept-objective-c-delegate-messages-within-a-subclass
    Protocol *p = objc_getProtocol("NSTextViewDelegate");
    self.delegate_interceptor = [[WZProtocolInterceptor alloc] initWithInterceptedProtocol:p];
    [self.delegate_interceptor setMiddleMan:self];
    [super setDelegate:(id)self.delegate_interceptor];
	self.allowsRichTextPasteOnlyFromThisClass = YES;
	
    self.borderColor = [NSColor lightGrayColor];
    self.borderWidth = 1.0;
    
    self.shouldEndColorChangeOnLeft = NO;
    
	self.typingAttributesInProgress = NO;
    self.isInTextDidChange = NO;
    self.fontSizeChangeAmount = 6.0f;
    self.maxFontSize = 128.0f;
    self.minFontSize = 10.0f;
    
    self.levelsOfUndo = 10;
    
    self.BULLET_STRING = @"•\u00A0"; // bullet is \u2022
    
    // Instead of hard-coding the default indentation size, which can make bulleted lists look a little
    // odd when increasing/decreasing their indent, use a \t character width instead
    // The old defaultIndentationSize was 15
    // TODO: readjust this defaultIndentationSize when font size changes? Might make things weird.
	NSDictionary *dictionary = [self dictionaryAtIndex:self.selectedRange.location];
    CGSize expectedStringSize = [@"\t" sizeWithAttributes:dictionary];
	self.defaultIndentationSize = expectedStringSize.width;
    self.MAX_INDENT = self.defaultIndentationSize * 10;

    if (self.rteDataSource && [self.rteDataSource respondsToSelector:@selector(levelsOfUndo)]) {
        [[self undoManager] setLevelsOfUndo:[self.rteDataSource levelsOfUndo]];
    }
    else {
        [[self undoManager] setLevelsOfUndo:self.levelsOfUndo];
    }
    
    // http://stackoverflow.com/questions/26454037/uitextview-text-selection-and-highlight-jumping-in-ios-8
    self.layoutManager.allowsNonContiguousLayout = NO;
    self.selectedRange = NSMakeRange(0, 0);
    if ([[self.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
        [self.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
    }
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    if ([replacementString isEqualToString:@"\n"]) {
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeEnter];
        self.inBulletedList = [self isInBulletedList];
    }
    if ([replacementString isEqualToString:@" "]) {
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeSpace];
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementString:)]) {
        return [self.delegate textView:textView shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
    }
    return YES;
}

// http://stackoverflow.com/questions/2484072/how-can-i-make-the-tab-key-move-focus-out-of-a-nstextview
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector {
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView:doCommandBySelector:)]) {
        return [self.delegate textView:aTextView doCommandBySelector:aSelector];
    }
    if (aSelector == @selector(insertTab:)) {
        if ([self isInEmptyBulletedListItem]) {
            [self userSelectedIncreaseIndent];
            return YES;
        }
    }
    else if (aSelector == @selector(insertBacktab:)) {
        if ([self isInEmptyBulletedListItem]) {
            [self userSelectedDecreaseIndent];
            return YES;
        }
    }
	else if (aSelector == @selector(deleteForward:)) {
		// Do something against DELETE key
		[self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeDelete];
	}
	else if (aSelector == @selector(deleteBackward:)) {
		// Do something against BACKSPACE key
		[self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeDelete];
	}
    return NO;
}

-(void)deleteBackward:(id)sender {
    self.justDeletedBackward = YES;
    [super deleteBackward:sender];
}

// https://stackoverflow.com/a/23667851/3938401
- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
    if (charRange.length == 0) {
        self.lastAnchorPoint = charRange;
    }
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:charRange];
    charRange = [self adjustSelectedRangeForBulletsWithStart:rangeOfCurrentParagraph Previous:NSMakeRange(NSNotFound, 0) andCurrent:charRange isMouseClick:YES];
    [super setSelectedRange:charRange affinity:affinity stillSelecting:stillSelectingFlag];
}

// https://stackoverflow.com/a/23667851/3938401
- (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange {
    
    if (newSelectedCharRange.length != 0) {
        int anchorStart = (int)self.lastAnchorPoint.location;
        int selectionStart = (int)newSelectedCharRange.location;
        int selectionLength = (int)newSelectedCharRange.length;
        
        /*
         If mouse selects left, and then a user arrows right, or the opposite, anchor point flips.
         */
        int difference = anchorStart - selectionStart;
        if (difference > 0 && difference != selectionLength) {
            if (oldSelectedCharRange.location == newSelectedCharRange.location) {
                // We were selecting left via mouse, but now we are selecting to the right via arrows
                anchorStart = selectionStart;
            }
            else {
                // We were selecting right via mouse, but now we are selecting to the left via arrows
                anchorStart = selectionStart + selectionLength;
            }
            self.lastAnchorPoint = NSMakeRange(anchorStart, 0);
        }
        
        // Evaluate Selection Direction
        if (anchorStart == selectionStart) {
            if (oldSelectedCharRange.length < newSelectedCharRange.length) {
                // Bigger
                //NSLog(@"Will select right in overall right selection");
            }
            else {
                // Smaller
                //NSLog(@"Will select left in overall right selection");
            }
            self.shouldEndColorChangeOnLeft = NO;
        }
        else {
            self.shouldEndColorChangeOnLeft = YES;
            if (oldSelectedCharRange.length < newSelectedCharRange.length) {
                // Bigger
                //NSLog(@"Will select left in overall left selection");
            }
            else {
                // Smaller
                //NSLog(@"Will select right in overall left selection");
            }
        }
        NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:oldSelectedCharRange];
        newSelectedCharRange = [self adjustSelectedRangeForBulletsWithStart:rangeOfCurrentParagraph Previous:oldSelectedCharRange andCurrent:newSelectedCharRange isMouseClick:NO];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(textView:willChangeSelectionFromCharacterRange:toCharacterRange:)]) {
        return [self.delegate textView:textView willChangeSelectionFromCharacterRange:oldSelectedCharRange toCharacterRange:newSelectedCharRange];
    }
    return newSelectedCharRange;
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    [self setNeedsLayout:YES];
    [self scrollRangeToVisible:self.selectedRange]; // fixes issue with cursor moving to top via keyboard and RTE not scrolling
    [self sendDelegateTypingAttrsUpdate];
    if (self.delegate && [self.delegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.delegate textViewDidChangeSelection:notification];
    }
}

- (void)textDidChange:(NSNotification *)notification {
    if (!self.isInTextDidChange) {
        self.isInTextDidChange = YES;
		[self applyBulletListIfApplicable];
        [self deleteBulletListWhenApplicable];
        self.isInTextDidChange = NO;
    }
    self.justDeletedBackward = NO;
    if (self.delegate && [self.delegate respondsToSelector:@selector(textDidChange:)]) {
        [self.delegate textDidChange:notification];
    }
}

- (BOOL)isInBulletedList {
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:self.selectedRange];
    return [[[self.attributedString string] substringFromIndex:rangeOfCurrentParagraph.location] hasPrefix:self.BULLET_STRING];
}

-(BOOL)isInEmptyBulletedListItem {
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:self.selectedRange];
    return [[[self.attributedString string] substringFromIndex:rangeOfCurrentParagraph.location] isEqualToString:self.BULLET_STRING];
}

- (void)paste:(id)sender {
	[self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangePaste];
	if (self.allowsRichTextPasteOnlyFromThisClass) {
		if ([[NSPasteboard generalPasteboard] dataForType:[RichTextEditor pasteboardDataType]]) {
			[super paste:sender]; // just call paste so we don't have to bother doing the check again
		}
		else {
			[self pasteAsPlainText:self];
		}
	}
	else {
		[super paste:sender];
	}
}

- (void)pasteAsRichText:(id)sender {
	BOOL hasCopyDataFromThisClass = [[NSPasteboard generalPasteboard] dataForType:[RichTextEditor pasteboardDataType]] != nil;
	if (self.allowsRichTextPasteOnlyFromThisClass) {
		if (hasCopyDataFromThisClass) {
			[super pasteAsRichText:sender];
		}
		else {
			[self pasteAsPlainText:sender];
		}
	}
	else {
		[super pasteAsRichText:sender];
	}
}

- (void)pasteAsPlainText:(id)sender {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangePaste];
	// Apparently paste as "plain" text doesn't ignore background and foreground colors...
	NSMutableDictionary *typingAttributes = [self.typingAttributes mutableCopy];
	[typingAttributes removeObjectForKey:NSBackgroundColorAttributeName];
	[typingAttributes removeObjectForKey:NSForegroundColorAttributeName];
	self.typingAttributes = typingAttributes;
	[super pasteAsPlainText:sender];
}

- (void)cut:(id)sender {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeCut];
    [super cut:sender];
}

-(void)copy:(id)sender {
	[super copy:sender];
	NSPasteboard *currentPasteboard = [NSPasteboard generalPasteboard];
	[currentPasteboard setData:[@"" dataUsingEncoding:NSUTF8StringEncoding] forType:[RichTextEditor pasteboardDataType]];
}

#pragma mark -

- (void)sendDelegateTypingAttrsUpdate {
    if (self.rteDelegate) {
        NSDictionary *attributes = [self typingAttributes];
        NSFont *font = [attributes objectForKey:NSFontAttributeName];
        NSColor *fontColor = [attributes objectForKey:NSForegroundColorAttributeName];
        NSColor *backgroundColor = [attributes objectForKey:NSBackgroundColorAttributeName]; // may want NSBackgroundColorAttributeName
        BOOL isInBulletedList = [self isInBulletedList];
        [self.rteDelegate selectionForEditor:self changedTo:[self selectedRange] isBold:[font isBold] isItalic:[font isItalic] isUnderline:[self isCurrentFontUnderlined] isInBulletedList:isInBulletedList textBackgroundColor:backgroundColor textColor:fontColor];
    }
}

-(void)sendDelegateTVChanged {
    if (self.delegate && [self.delegate respondsToSelector:@selector(textDidChange:)]) {
        [self.delegate textDidChange:[NSNotification notificationWithName:@"textDidChange:" object:self]];
    }
}

-(void)sendDelegatePreviewChangeOfType:(RichTextEditorPreviewChange)type {
    if (self.rteDelegate && [self.rteDelegate respondsToSelector:@selector(richTextEditor:changeAboutToOccurOfType:)]) {
        [self.rteDelegate richTextEditor:self changeAboutToOccurOfType:type];
    }
}

-(void)userSelectedBold {
    NSFont *font = [[self typingAttributes] objectForKey:NSFontAttributeName];
    if (!font) {
        font = [NSFont systemFontOfSize:12.0f];
    }
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeBold];
    [self applyFontAttributesToSelectedRangeWithBoldTrait:[NSNumber numberWithBool:![font isBold]] italicTrait:nil fontName:nil fontSize:nil];
    [self sendDelegateTypingAttrsUpdate];
    [self sendDelegateTVChanged];
}

-(void)userSelectedItalic {
    NSFont *font = [[self typingAttributes] objectForKey:NSFontAttributeName];
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeItalic];
    [self applyFontAttributesToSelectedRangeWithBoldTrait:nil italicTrait:[NSNumber numberWithBool:![font isItalic]] fontName:nil fontSize:nil];
    [self sendDelegateTypingAttrsUpdate];
    [self sendDelegateTVChanged];
}

-(void)userSelectedUnderline {
    NSNumber *existingUnderlineStyle;
	if (![self isCurrentFontUnderlined]) {
        existingUnderlineStyle = [NSNumber numberWithInteger:NSUnderlineStyleSingle];
	}
	else {
        existingUnderlineStyle = [NSNumber numberWithInteger:NSUnderlineStyleNone];
	}
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeUnderline];
    [self applyAttributesToSelectedRange:existingUnderlineStyle forKey:NSUnderlineStyleAttributeName];
    [self sendDelegateTypingAttrsUpdate];
    [self sendDelegateTVChanged];
}

-(void)userSelectedIncreaseIndent {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeIndentIncrease];
    [self userSelectedParagraphIndentation:ParagraphIndentationIncrease];
    [self sendDelegateTVChanged];
}

-(void)userSelectedDecreaseIndent {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeIndentDecrease];
    [self userSelectedParagraphIndentation:ParagraphIndentationDecrease];
    [self sendDelegateTVChanged];
}

-(void)userSelectedTextBackgroundColor:(NSColor*)color {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeHighlight];
    NSRange selectedRange = [self selectedRange];
	if (color) {
        [self applyAttributesToSelectedRange:color forKey:NSBackgroundColorAttributeName];
	}
	else {
        [self removeAttributeForKeyFromSelectedRange:NSBackgroundColorAttributeName];
	}
    if (self.shouldEndColorChangeOnLeft) {
        [self setSelectedRange:NSMakeRange(selectedRange.location, 0)];
    }
    else {
        [self setSelectedRange:NSMakeRange(selectedRange.location + selectedRange.length, 0)];
    }
    [self sendDelegateTVChanged];
}

-(void)userSelectedTextColor:(NSColor*)color {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontColor];
    if (color) {
        [self applyAttributesToSelectedRange:color forKey:NSForegroundColorAttributeName];
    }
    else {
        [self removeAttributeForKeyFromSelectedRange:NSForegroundColorAttributeName];
    }
    [self sendDelegateTVChanged];
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

- (void)setFont:(NSFont *)font {
	[super setFont:font];
}

#pragma mark - Public Methods -

- (void)setHtmlString:(NSString *)htmlString {
    NSMutableAttributedString *attr = [[RichTextEditor attributedStringFromHTMLString:htmlString] mutableCopy];
    if (attr) {
        if ([attr.string hasSuffix:@"\n"]) {
            [attr replaceCharactersInRange:NSMakeRange(attr.length - 1, 1) withString:@""];
        }
        [self setAttributedString:attr];
    }
}

- (NSString *)htmlString {
    return [RichTextEditor htmlStringFromAttributedText:self.attributedString];
}

- (void)changeToAttributedString:(NSAttributedString*)string {
    [self setAttributedString:string];
}

+(NSString *)htmlStringFromAttributedText:(NSAttributedString*)text {
	NSData *data = [text dataFromRange:NSMakeRange(0, text.length)
                    documentAttributes:
                        @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                        NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                    error:nil];
	
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+(NSAttributedString*)attributedStringFromHTMLString:(NSString *)htmlString {
    @try {
        NSError *error;
        NSData *data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
        NSAttributedString *str =
        [[NSAttributedString alloc] initWithData:data
                                         options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                   NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]}
                              documentAttributes:nil error:&error];
        if (!error)
            return str;
        return nil;
    }
    @catch (NSException *e) {
        return nil;
    }
}

- (void)setBorderColor:(NSColor *)borderColor {
    self.layer.borderColor = borderColor.CGColor;
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    self.layer.borderWidth = borderWidth;
}

- (void)userChangedToFontSize:(NSNumber*)fontSize {
	[self applyFontAttributesToSelectedRangeWithBoldTrait:nil italicTrait:nil fontName:nil fontSize:fontSize];
}

- (void)userChangedToFontName:(NSString*)fontName {
	[self applyFontAttributesToSelectedRangeWithBoldTrait:nil italicTrait:nil fontName:fontName fontSize:nil];
}

- (BOOL)isCurrentFontUnderlined {
    NSDictionary *dictionary = [self typingAttributes];
    NSNumber *existingUnderlineStyle = [dictionary objectForKey:NSUnderlineStyleAttributeName];
    
    if (!existingUnderlineStyle || existingUnderlineStyle.intValue == NSUnderlineStyleNone) {
        return NO;
    }
    return YES;
}

// try/catch blocks on undo/redo because it doesn't work right with bulleted lists when BULLET_STRING has more than 1 character
- (void)undo {
    @try {
        BOOL shouldUseUndoManager = YES;
        if ([self.rteDelegate respondsToSelector:@selector(handlesUndoRedoForText)] &&
            [self.rteDelegate respondsToSelector:@selector(userPerformedUndo)]) {
            if ([self.rteDelegate handlesUndoRedoForText]) {
                [self.rteDelegate userPerformedUndo];
                shouldUseUndoManager = NO;
            }
        }
        if (shouldUseUndoManager && [[self undoManager] canUndo]) {
            [[self undoManager] undo];
        }
    }
    @catch (NSException *e) {
        [[self undoManager] removeAllActions];
    }
}

- (void)redo {
    @try {
        BOOL shouldUseUndoManager = YES;
        if ([self.rteDelegate respondsToSelector:@selector(handlesUndoRedoForText)] &&
            [self.rteDelegate respondsToSelector:@selector(userPerformedRedo)]) {
            if ([self.rteDelegate handlesUndoRedoForText]) {
                [self.rteDelegate userPerformedRedo];
                shouldUseUndoManager = NO;
            }
        }
        if (shouldUseUndoManager && [[self undoManager] canRedo])
            [[self undoManager] redo];
    }
    @catch (NSException *e) {
        [[self undoManager] removeAllActions];
    }
}

- (void)userSelectedParagraphIndentation:(ParagraphIndentation)paragraphIndentation {
    self.isInTextDidChange = YES;
    __block NSDictionary *dictionary;
    __block NSMutableParagraphStyle *paragraphStyle;
    NSRange currSelectedRange = self.selectedRange;
	[self enumarateThroughParagraphsInRange:self.selectedRange withBlock:^(NSRange paragraphRange){
        dictionary = [self dictionaryAtIndex:paragraphRange.location];
        paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        if (!paragraphStyle) {
			paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }

		if (paragraphIndentation == ParagraphIndentationIncrease &&
            paragraphStyle.headIndent < self.MAX_INDENT && paragraphStyle.firstLineHeadIndent < self.MAX_INDENT) {
			paragraphStyle.headIndent += self.defaultIndentationSize;
			paragraphStyle.firstLineHeadIndent += self.defaultIndentationSize;
		}
		else if (paragraphIndentation == ParagraphIndentationDecrease) {
			paragraphStyle.headIndent -= self.defaultIndentationSize;
			paragraphStyle.firstLineHeadIndent -= self.defaultIndentationSize;
			
            if (paragraphStyle.headIndent < 0) {
				paragraphStyle.headIndent = 0; // this is the right cursor placement
            }

            if (paragraphStyle.firstLineHeadIndent < 0) {
				paragraphStyle.firstLineHeadIndent = 0; // this affects left cursor placement
            }
		}
		[self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:paragraphRange];
    }];
    [self setSelectedRange:currSelectedRange];
    self.isInTextDidChange = NO;
    // Old iOS code
    // Following 2 lines allow the user to insta-type after indenting in a bulleted list
    //NSRange range = NSMakeRange(self.selectedRange.location+self.selectedRange.length, 0);
    //[self setSelectedRange:range];
    // Check to see if the current paragraph is blank. If it is, manually get the cursor to move with a weird hack.
    
    // After NSTextStorage changes, these don't seem necessary
   /* NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:self.selectedRange];
	BOOL currParagraphIsBlank = [[self.attributedString.string substringWithRange:rangeOfCurrentParagraph] isEqualToString:@""] ? YES: NO;
    if (currParagraphIsBlank)
    {
       // [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:rangeOfCurrentParagraph];
    } */
}

// Manually ensures that the cursor is shown in the correct location. Ugly work around and weird but it works (at least in iOS 7 / OS X 10.11.2).
// Basically what I do is add a " " with the correct indentation then delete it. For some reason with that
// and applying that attribute to the current typing attributes it moves the cursor to the right place.
// Would updating the typing attributes also work instead? That'd certainly be cleaner...
-(void)setIndentationWithAttributes:(NSDictionary*)attributes paragraphStyle:(NSMutableParagraphStyle*)paragraphStyle atRange:(NSRange)range {
    NSMutableAttributedString *space = [[NSMutableAttributedString alloc] initWithString:@" " attributes:attributes];
    [space addAttributes:[NSDictionary dictionaryWithObject:paragraphStyle forKey:NSParagraphStyleAttributeName] range:NSMakeRange(0, 1)];
    [self.textStorage insertAttributedString:space atIndex:range.location];
    [self setSelectedRange:NSMakeRange(range.location, 1)];
    [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:NSMakeRange(self.selectedRange.location+self.selectedRange.length-1, 1)];
    [self setSelectedRange:NSMakeRange(range.location, 0)];
    [self.textStorage deleteCharactersInRange:NSMakeRange(range.location, 1)];
    [self applyAttributeToTypingAttribute:paragraphStyle forKey:NSParagraphStyleAttributeName];
}

- (void)userSelectedParagraphFirstLineHeadIndent {
	[self enumarateThroughParagraphsInRange:self.selectedRange withBlock:^(NSRange paragraphRange){
		NSDictionary *dictionary = [self dictionaryAtIndex:paragraphRange.location];
		NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
		
        if (!paragraphStyle) {
			paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
		
		if (paragraphStyle.headIndent == paragraphStyle.firstLineHeadIndent) {
			paragraphStyle.firstLineHeadIndent += self.defaultIndentationSize;
		}
		else {
			paragraphStyle.firstLineHeadIndent = paragraphStyle.headIndent;
		}
		
		[self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:paragraphRange];
	}];
}

- (void)userSelectedTextAlignment:(NSTextAlignment)textAlignment {
	[self enumarateThroughParagraphsInRange:self.selectedRange withBlock:^(NSRange paragraphRange){
		NSDictionary *dictionary = [self dictionaryAtIndex:paragraphRange.location];
		NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
		
        if (!paragraphStyle) {
			paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
		
		paragraphStyle.alignment = textAlignment;
		
		[self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:paragraphRange];
        [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:paragraphRange];
	}];
}

-(void)setAttributedString:(NSAttributedString*)attributedString {
    [self.textStorage setAttributedString:attributedString];
}

// http://stackoverflow.com/questions/5810706/how-to-programmatically-add-bullet-list-to-nstextview might be useful to look at some day (or maybe not)
- (void)userSelectedBullet {
    //NSLog(@"[RTE] Bullet code called");
    if (!self.isEditable) {
        return;
    }
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeBullet];
	NSRange initialSelectedRange = self.selectedRange;
	NSArray *rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:self.selectedRange];
	NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:self.selectedRange];
	BOOL firstParagraphHasBullet = [[self.attributedString.string substringFromIndex:rangeOfCurrentParagraph.location] hasPrefix:self.BULLET_STRING];
    
    NSRange rangeOfPreviousParagraph = [self.attributedString firstParagraphRangeFromTextRange:NSMakeRange(rangeOfCurrentParagraph.location-1, 0)];
    NSDictionary *prevParaDict = [self dictionaryAtIndex:rangeOfPreviousParagraph.location];
    NSMutableParagraphStyle *prevParaStyle = [prevParaDict objectForKey:NSParagraphStyleAttributeName];
	
	__block NSInteger rangeOffset = 0;
    __block BOOL mustDecreaseIndentAfterRemovingBullet = NO;
    __block BOOL isInBulletedList = self.inBulletedList;
	[self enumarateThroughParagraphsInRange:self.selectedRange withBlock:^(NSRange paragraphRange){
		NSRange range = NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length);
		NSDictionary *dictionary = [self dictionaryAtIndex:MAX((int)range.location-1, 0)];
		NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
		
        if (!paragraphStyle) {
			paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
		
		BOOL currentParagraphHasBullet = [[self.attributedString.string substringFromIndex:range.location] hasPrefix:self.BULLET_STRING];
		
        if (firstParagraphHasBullet != currentParagraphHasBullet) {
			return;
        }
		if (currentParagraphHasBullet) {
            // User hit the bullet button and is in a bulleted list so we should get rid of the bullet
			range = NSMakeRange(range.location, range.length - self.BULLET_STRING.length);
            
            [self.textStorage deleteCharactersInRange:NSMakeRange(range.location, self.BULLET_STRING.length)];
			
			paragraphStyle.firstLineHeadIndent = 0;
			paragraphStyle.headIndent = 0;
			
			rangeOffset = rangeOffset - self.BULLET_STRING.length;
            mustDecreaseIndentAfterRemovingBullet = YES;
            isInBulletedList = NO;
		}
		else {
            // We are adding a bullet
			range = NSMakeRange(range.location, range.length + self.BULLET_STRING.length);
			
			NSMutableAttributedString *bulletAttributedString = [[NSMutableAttributedString alloc] initWithString:self.BULLET_STRING attributes:nil];
            // The following code attempts to remove any underline from the bullet string, but it doesn't work right. I don't know why.
          /*  NSFont *prevFont = [dictionary objectForKey:NSFontAttributeName];
            NSFont *bulletFont = [NSFont fontWithName:[prevFont familyName] size:[prevFont pointSize]];
            
            NSMutableDictionary *bulletDict = [dictionary mutableCopy];
            [bulletDict setObject:bulletFont forKey:NSFontAttributeName];
            [bulletDict removeObjectForKey:NSStrikethroughStyleAttributeName];
            [bulletDict setValue:NSUnderlineStyleNone forKey:NSUnderlineStyleAttributeName];
            [bulletDict removeObjectForKey:NSStrokeColorAttributeName];
            [bulletDict removeObjectForKey:NSStrokeWidthAttributeName];
            dictionary = bulletDict;*/
            
            [bulletAttributedString setAttributes:dictionary range:NSMakeRange(0, self.BULLET_STRING.length)];
			
            [self.textStorage insertAttributedString:bulletAttributedString atIndex:range.location];
			
			CGSize expectedStringSize = [self.BULLET_STRING sizeWithAttributes:dictionary];
            
            // See if the previous paragraph has a bullet
            NSString *previousParagraph = [self.attributedString.string substringWithRange:rangeOfPreviousParagraph];
            BOOL doesPrefixWithBullet = [previousParagraph hasPrefix:self.BULLET_STRING];
            
            // Look at the previous paragraph to see what the firstLineHeadIndent should be for the
            // current bullet
            // if the previous paragraph has a bullet, use that paragraph's indent
            // if not, then use defaultIndentation size
            if (!doesPrefixWithBullet) {
                paragraphStyle.firstLineHeadIndent = self.defaultIndentationSize;
            }
            else {
                paragraphStyle.firstLineHeadIndent = prevParaStyle.firstLineHeadIndent;
            }
            
			paragraphStyle.headIndent = expectedStringSize.width + paragraphStyle.firstLineHeadIndent;
			
			rangeOffset = rangeOffset + self.BULLET_STRING.length;
            isInBulletedList = YES;
		}
        [self.textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
	}];
	
	// If paragraph is empty move cursor to front of bullet, so the user can start typing right away
    NSRange rangeForSelection;
	if (rangeOfParagraphsInSelectedText.count == 1 && rangeOfCurrentParagraph.length == 0 && isInBulletedList) {
        rangeForSelection = NSMakeRange(rangeOfCurrentParagraph.location + self.BULLET_STRING.length, 0);
	}
	else {
		if (initialSelectedRange.length == 0) {
            rangeForSelection = NSMakeRange(initialSelectedRange.location+rangeOffset, 0);
		}
		else {
			NSRange fullRange = [self fullRangeFromArrayOfParagraphRanges:rangeOfParagraphsInSelectedText];
            rangeForSelection = NSMakeRange(fullRange.location, fullRange.length+rangeOffset);
		}
    }
    if (mustDecreaseIndentAfterRemovingBullet) {
        // remove the extra indentation added by the bullet
        [self userSelectedParagraphIndentation:ParagraphIndentationDecrease];
    }
	self.selectedRange = rangeForSelection;
    
    if (!self.isInTextDidChange) {
        [self sendDelegateTVChanged];
    }
}

// modified from https://stackoverflow.com/a/4833778/3938401
- (void)changeToFont:(NSFont*)font {
    NSTextStorage *textStorage = self.textStorage;
    [textStorage beginEditing];
    [textStorage enumerateAttributesInRange: NSMakeRange(0, textStorage.length)
                                    options: 0
                                 usingBlock: ^(NSDictionary *attributesDictionary,
                                               NSRange range,
                                               BOOL *stop) {
         NSFont *currFont = [attributesDictionary objectForKey:NSFontAttributeName];
         if (currFont) {
             NSFont *fontToChangeTo = [font fontWithBoldTrait:currFont.isBold andItalicTrait:currFont.isItalic];
             if (fontToChangeTo) {
                 [textStorage removeAttribute:NSFontAttributeName range:range];
                 [textStorage addAttribute:NSFontAttributeName value:fontToChangeTo range:range];
             }
         }
     }];
    [textStorage endEditing];
}

#pragma mark - Private Methods -

- (void)enumarateThroughParagraphsInRange:(NSRange)range withBlock:(void (^)(NSRange paragraphRange))block{
	NSArray *rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:self.selectedRange];
	
	for (int i = 0; i < rangeOfParagraphsInSelectedText.count; i++) {
		NSValue *value = [rangeOfParagraphsInSelectedText objectAtIndex:i];
		NSRange paragraphRange = [value rangeValue];
		block(paragraphRange);
	}
    rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:self.selectedRange];
	NSRange fullRange = [self fullRangeFromArrayOfParagraphRanges:rangeOfParagraphsInSelectedText];
    if (fullRange.location + fullRange.length > [self.attributedString length]) {
        fullRange.length = 0;
        fullRange.location = [self.attributedString length]-1;
    }
	[self setSelectedRange:fullRange];
}

- (NSRange)fullRangeFromArrayOfParagraphRanges:(NSArray *)paragraphRanges {
    if (!paragraphRanges.count) {
		return NSMakeRange(0, 0);
    }
	
	NSRange firstRange = [[paragraphRanges objectAtIndex:0] rangeValue];
	NSRange lastRange = [[paragraphRanges lastObject] rangeValue];
	return NSMakeRange(firstRange.location, lastRange.location + lastRange.length - firstRange.location);
}

- (NSFont *)fontAtIndex:(NSInteger)index {
    return [[self dictionaryAtIndex:index] objectForKey:NSFontAttributeName];
}

- (BOOL)hasText {
    return self.string.length > 0;
}

- (NSDictionary *)dictionaryAtIndex:(NSInteger)index {
    if (![self hasText] || index == self.attributedString.string.length) {
        return self.typingAttributes; // end of string, use whatever we're currently using
    }
    else {
        return [self.attributedString attributesAtIndex:index effectiveRange:nil];
    }
}

- (void)updateTypingAttributes {
    // http://stackoverflow.com/questions/11835497/nstextview-not-applying-attributes-to-newly-inserted-text
    NSArray *selectedRanges = self.selectedRanges;
    if (selectedRanges && selectedRanges.count > 0 && [self hasText]) {
        NSValue *firstSelectionRangeValue = [selectedRanges objectAtIndex:0];
        if (firstSelectionRangeValue) {
            NSRange firstCharacterOfSelectedRange = [firstSelectionRangeValue rangeValue];
            if (firstCharacterOfSelectedRange.location >= self.textStorage.length) {
                firstCharacterOfSelectedRange.location = self.textStorage.length - 1;
            }
            NSDictionary *attributesDictionary = [self.textStorage attributesAtIndex:firstCharacterOfSelectedRange.location effectiveRange: NULL];
            [self setTypingAttributes: attributesDictionary];
        }
    }
}

- (void)applyAttributeToTypingAttribute:(id)attribute forKey:(NSString *)key {
	NSMutableDictionary *dictionary = [self.typingAttributes mutableCopy];
	[dictionary setObject:attribute forKey:key];
	[self setTypingAttributes:dictionary];
}

- (void)applyAttributes:(id)attribute forKey:(NSString *)key atRange:(NSRange)range {
	// If any text selected apply attributes to text
	if (range.length > 0) {
        // Workaround for when there is only one paragraph,
		// sometimes the attributedString is actually longer by one then the displayed text,
		// and this results in not being able to set to lef align anymore.
        if (range.length == self.textStorage.length - 1 && range.length == self.string.length) {
            ++range.length;
        }
        
        [self.textStorage addAttributes:[NSDictionary dictionaryWithObject:attribute forKey:key] range:range];
        
        // Have to update typing attributes because the selection won't change after these attributes have changed.
        [self updateTypingAttributes];
	}
	else {
        // If no text is selected apply attributes to typingAttribute
		self.typingAttributesInProgress = YES;
		[self applyAttributeToTypingAttribute:attribute forKey:key];
	}
}

- (void)removeAttributeForKey:(NSString *)key atRange:(NSRange)range {
	NSRange initialRange = self.selectedRange;
    [self.textStorage removeAttribute:key range:range];
	[self setSelectedRange:initialRange];
}

- (void)removeAttributeForKeyFromSelectedRange:(NSString *)key {
	[self removeAttributeForKey:key atRange:self.selectedRange];
}

- (void)applyAttributesToSelectedRange:(id)attribute forKey:(NSString *)key {
	[self applyAttributes:attribute forKey:key atRange:self.selectedRange];
}

- (void)applyFontAttributesToSelectedRangeWithBoldTrait:(NSNumber *)isBold italicTrait:(NSNumber *)isItalic fontName:(NSString *)fontName fontSize:(NSNumber *)fontSize {
	[self applyFontAttributesWithBoldTrait:isBold italicTrait:isItalic fontName:fontName fontSize:fontSize toTextAtRange:self.selectedRange];
}

- (void)applyFontAttributesWithBoldTrait:(NSNumber *)isBold italicTrait:(NSNumber *)isItalic fontName:(NSString *)fontName fontSize:(NSNumber *)fontSize toTextAtRange:(NSRange)range {
	// If any text selected apply attributes to text
	if (range.length > 0) {
        [self.textStorage beginEditing];
		[self.textStorage enumerateAttributesInRange:range
											 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
										  usingBlock:^(NSDictionary *dictionary, NSRange range, BOOL *stop){
											  
											  NSFont *newFont = [self fontwithBoldTrait:isBold
																			italicTrait:isItalic
																			   fontName:fontName
																			   fontSize:fontSize
																		 fromDictionary:dictionary];
											  
                                              if (newFont) {
                                                  [self.textStorage addAttributes:[NSDictionary dictionaryWithObject:newFont forKey:NSFontAttributeName] range:range];
                                              }
										  }];
        [self.textStorage endEditing];
        [self setSelectedRange:range];
        [self updateTypingAttributes];
	}
	else {
        // If no text is selected apply attributes to typingAttribute
		self.typingAttributesInProgress = YES;
		NSFont *newFont = [self fontwithBoldTrait:isBold
									  italicTrait:isItalic
										 fontName:fontName
										 fontSize:fontSize
								   fromDictionary:self.typingAttributes];
        if (newFont) {
            [self applyAttributeToTypingAttribute:newFont forKey:NSFontAttributeName];
        }
	}
}

-(BOOL)hasSelection {
    return self.selectedRange.length > 0;
}

// By default, if this function is called with nothing selected, it will resize all text.
-(void)changeFontSizeWithOperation:(CGFloat(^)(CGFloat currFontSize))operation {
    [self.textStorage beginEditing];
    NSRange range = self.selectedRange;
    if (range.length == 0) {
        range = NSMakeRange(0, self.textStorage.length);
    }
    [self.textStorage enumerateAttributesInRange:range
                                         options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                      usingBlock:^(NSDictionary *dictionary, NSRange range, BOOL *stop){
                                          // Get current font size
                                          NSFont *currFont = [dictionary objectForKey:NSFontAttributeName];
                                          if (currFont) {
                                              CGFloat currFontSize = currFont.pointSize;
                                              
                                              CGFloat nextFontSize = operation(currFontSize);
                                              if ((currFontSize < nextFontSize && nextFontSize <= self.maxFontSize) || // sizing up
                                                  (currFontSize > nextFontSize && self.minFontSize <= nextFontSize)) { // sizing down
                                              
                                                  NSFont *newFont = [self fontwithBoldTrait:[NSNumber numberWithBool:[currFont isBold]]
                                                                                italicTrait:[NSNumber numberWithBool:[currFont isItalic]]
                                                                                   fontName:currFont.fontName
                                                                                   fontSize:[NSNumber numberWithFloat:nextFontSize]
                                                                             fromDictionary:dictionary];
                                                  
                                                  if (newFont) {
                                                      [self.textStorage addAttributes:[NSDictionary dictionaryWithObject:newFont forKey:NSFontAttributeName] range:range];
                                                  }
                                              }
                                          }
                                      }];
    [self.textStorage endEditing];
    [self updateTypingAttributes];
}

- (void)decreaseFontSize {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontSize];
    if (self.selectedRange.length == 0) {
        NSMutableDictionary *typingAttributes = [self.typingAttributes mutableCopy];
        NSFont *font = [typingAttributes valueForKey:NSFontAttributeName];
        CGFloat nextFontSize = font.pointSize - self.fontSizeChangeAmount;
        if (nextFontSize < self.minFontSize)
            nextFontSize = self.minFontSize;
        NSFont *nextFont = [[NSFontManager sharedFontManager] convertFont:font toSize:nextFontSize];
        [typingAttributes setValue:nextFont forKey:NSFontAttributeName];
        self.typingAttributes = typingAttributes;
    }
    else {
        [self changeFontSizeWithOperation:^CGFloat (CGFloat currFontSize) {
            return currFontSize - self.fontSizeChangeAmount;
        }];
        [self sendDelegateTVChanged]; // only send if the actual text changes -- if no text selected, no text has actually changed
    }
}

- (void)increaseFontSize {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontSize];
    if (self.selectedRange.length == 0) {
        NSMutableDictionary *typingAttributes = [self.typingAttributes mutableCopy];
        NSFont *font = [typingAttributes valueForKey:NSFontAttributeName];
        CGFloat nextFontSize = font.pointSize + self.fontSizeChangeAmount;
        if (nextFontSize > self.maxFontSize) {
            nextFontSize = self.maxFontSize;
        }
        NSFont *nextFont = [[NSFontManager sharedFontManager] convertFont:font toSize:nextFontSize];
        [typingAttributes setValue:nextFont forKey:NSFontAttributeName];
        self.typingAttributes = typingAttributes;
    }
    else {
        [self changeFontSizeWithOperation:^CGFloat (CGFloat currFontSize) {
            return currFontSize + self.fontSizeChangeAmount;
        }];
        [self sendDelegateTVChanged]; // only send if the actual text changes -- if no text selected, no text has actually changed
    }
}

// TODO: Fix this function. You can't create a font that isn't bold from a dictionary that has a bold attribute currently, since if you send isBold 0 [nil], it'll use the dictionary, which is bold!
// In other words, this function has logical errors
// Returns a font with given attributes. For any missing parameter takes the attribute from a given dictionary
- (NSFont *)fontwithBoldTrait:(NSNumber *)isBold italicTrait:(NSNumber *)isItalic fontName:(NSString *)fontName fontSize:(NSNumber *)fontSize fromDictionary:(NSDictionary *)dictionary {
	NSFont *newFont = nil;
	NSFont *font = [dictionary objectForKey:NSFontAttributeName];
	BOOL newBold = (isBold) ? isBold.intValue : [font isBold];
	BOOL newItalic = (isItalic) ? isItalic.intValue : [font isItalic];
	CGFloat newFontSize = (fontSize) ? fontSize.floatValue : font.pointSize;
	
	if (fontName) {
		newFont = [NSFont fontWithName:fontName size:newFontSize boldTrait:newBold italicTrait:newItalic];
	}
	else {
		newFont = [font fontWithBoldTrait:newBold italicTrait:newItalic andSize:newFontSize];
	}
	
	return newFont;
}

/**
 * Does not allow cursor to be right beside the bullet point. This method also does not allow selection of the bullet point itself.
 * It uses the previousCursorPosition property to save the previous cursor location.
 *
 * @param beginRange The beginning position of the paragraph
 * @param previousRange The previous cursor position before the new change. Only used for keyboard change events
 * @param currentRange The current cursor position after the new change
 * @param isMouseClick A boolean to check whether the requested change is a mouse event or a keyboard event
 */
- (NSRange)adjustSelectedRangeForBulletsWithStart:(NSRange)beginRange Previous:(NSRange)previousRange andCurrent:(NSRange)currentRange isMouseClick:(BOOL)isMouseClick {
    NSUInteger previous = self.previousCursorPosition;
    NSUInteger begin = beginRange.location;
    NSUInteger current = currentRange.location;
    NSRange finalRange = currentRange;
    if (self.justDeletedBackward) {
        return finalRange;
    }
    
    BOOL currentParagraphHasBulletInFront = [[self.attributedString.string substringFromIndex:begin] hasPrefix:self.BULLET_STRING];
    if (currentParagraphHasBulletInFront) {
        if (!isMouseClick && (current == begin + 1)) { // select bullet point when using keyboard arrow keys
            if (previousRange.location > current) {
                finalRange = NSMakeRange(begin, currentRange.length + 1);
            }
            else if (previousRange.location < current) {
                finalRange = NSMakeRange(current + 1, currentRange.length - 1);
            }
        }
        else {
            if ((current == begin && (previous > current || previous < current)) ||
                (current == (begin + 1) && (previous < current || current == previous))) { // cursor moved from in bullet to front of bullet
                finalRange = currentRange.length >= 1 ? NSMakeRange(begin, finalRange.length + 1) : NSMakeRange(begin + 2, 0);
            }
            else if (current == (begin + 1) && previous > current) { // cursor moved from in bullet to beside of bullet
                BOOL isNewLocationValid = (begin - 1) > [self.attributedString.string length] ? NO : YES;
                finalRange = currentRange.length >= 1 ? NSMakeRange(begin, finalRange.length + 1) : NSMakeRange(isNewLocationValid ? begin - 1 : begin + 2, 0);
            }
            else if ((current == begin) && (begin == previous) && isMouseClick) {
                finalRange = currentRange.length >= 1 ? NSMakeRange(begin, finalRange.length + 1) : NSMakeRange(begin + 2, 0);
            }
        }
    }
    
    NSRange endingStringRange = [[self.attributedString.string substringWithRange:currentRange] rangeOfString:@"\n\u2022" options:NSBackwardsSearch];
    NSUInteger currentRangeAddedProperties = currentRange.location + currentRange.length;
    NSUInteger previousRangeAddedProperties = previousRange.location + previousRange.length;
    BOOL currentParagraphHasBulletAtTheEnd = (endingStringRange.length + endingStringRange.location + currentRange.location) == currentRangeAddedProperties;
    if (currentParagraphHasBulletAtTheEnd) {
        if (isMouseClick) {
            if (previousRange.length > current) {
                finalRange = NSMakeRange(current, currentRange.length + 1);
            }
            else if (previousRange.length < current) {
                finalRange = NSMakeRange(current, currentRange.length - 1);
            }
        }
        else {
            if (previousRangeAddedProperties < currentRangeAddedProperties) {
                finalRange = NSMakeRange(current, currentRange.length + 1);
            }
            else if (previousRangeAddedProperties > currentRangeAddedProperties) {
                finalRange = NSMakeRange(current, currentRange.length - 1);
            }
        }
    }
    
    self.previousCursorPosition = finalRange.location;
    return finalRange;
}

- (void)applyBulletListIfApplicable {
	NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:self.selectedRange];
    if (rangeOfCurrentParagraph.location == 0) {
        return; // there isn't a previous paragraph, so forget it. The user isn't in a bulleted list.
    }
	NSRange rangeOfPreviousParagraph = [self.attributedString firstParagraphRangeFromTextRange:NSMakeRange(rangeOfCurrentParagraph.location - 1, 0)];
    if (!self.inBulletedList) { // fixes issue with backspacing into bullet list adding a bullet
        //NSLog(@"[RTE] NOT in a bulleted list.");
		BOOL currentParagraphHasBullet = ([[self.attributedString.string substringFromIndex:rangeOfCurrentParagraph.location]
                                           hasPrefix:self.BULLET_STRING]) ? YES : NO;
		BOOL previousParagraphHasBullet = ([[self.attributedString.string substringFromIndex:rangeOfPreviousParagraph.location]
                                            hasPrefix:self.BULLET_STRING]) ? YES : NO;
        BOOL isCurrParaBlank = [[self.attributedString.string substringWithRange:rangeOfCurrentParagraph] isEqualToString:@""];
        // if we don't check to see if the current paragraph is blank, bad bugs happen with
        // the current paragraph where the selected range doesn't let the user type O_o
        if (previousParagraphHasBullet && !currentParagraphHasBullet && isCurrParaBlank) {
            // Fix the indentation. Here is the use case for this code:
            /*
             ---
                • bullet
             
             |
             ---
             Where | is the cursor on a blank line. User hits backspace. Without fixing the 
             indentation, the cursor ends up indented at the same indentation as the bullet.
             */
            NSDictionary *dictionary = [self dictionaryAtIndex:rangeOfCurrentParagraph.location];
            NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
            paragraphStyle.firstLineHeadIndent = 0;
            paragraphStyle.headIndent = 0;
            [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:rangeOfCurrentParagraph];
            [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:rangeOfCurrentParagraph];
        }
        return;
    }
    if (rangeOfCurrentParagraph.length != 0) {
		return;
    }
    if (!self.justDeletedBackward && [[self.attributedString.string substringFromIndex:rangeOfPreviousParagraph.location] hasPrefix:self.BULLET_STRING]) {
        [self userSelectedBullet];
    }
}

- (void)removeBulletIndentation:(NSRange)firstParagraphRange {
    NSRange rangeOfParagraph = [self.attributedString firstParagraphRangeFromTextRange:firstParagraphRange];
    NSDictionary *dictionary = [self dictionaryAtIndex:rangeOfParagraph.location];
    NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
    paragraphStyle.firstLineHeadIndent = 0;
    paragraphStyle.headIndent = 0;
    [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:rangeOfParagraph];
    [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:firstParagraphRange];
}

- (void)deleteBulletListWhenApplicable {
	NSRange range = self.selectedRange;
	// TODO: Clean up this code since a lot of it is "repeated"
	if (range.location > 0) {
        NSString *checkString = self.BULLET_STRING;
        if (checkString.length > 1) {
            // chop off last letter and use that
            checkString = [checkString substringToIndex:checkString.length - 1];
        }
        //else return;
        NSUInteger checkStringLength = [checkString length];
        if (![self.attributedString.string isEqualToString:self.BULLET_STRING]) {
            if (((int)(range.location-checkStringLength) >= 0 &&
                 [[self.attributedString.string substringFromIndex:range.location-checkStringLength] hasPrefix:checkString])) {
                [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeBullet];
                //NSLog(@"[RTE] Getting rid of a bullet due to backspace while in empty bullet paragraph.");
                // Get rid of bullet string
                [self.textStorage deleteCharactersInRange:NSMakeRange(range.location-checkStringLength, checkStringLength)];
                NSRange newRange = NSMakeRange(range.location-checkStringLength, 0);
                self.selectedRange = newRange;
                
                // Get rid of bullet indentation
                [self removeBulletIndentation:newRange];
            }
            else {
                // User may be needing to get out of a bulleted list due to hitting enter (return)
                NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:self.selectedRange];
                NSInteger prevParaLocation = rangeOfCurrentParagraph.location-1;
                if (prevParaLocation >= 0) {
                    NSRange rangeOfPreviousParagraph = [self.attributedString firstParagraphRangeFromTextRange:NSMakeRange(rangeOfCurrentParagraph.location-1, 0)];
                    // If the following if statement is true, the user hit enter on a blank bullet list
                    // Basically, there is now a bullet ' ' \n bullet ' ' that we need to delete (' ' == space)
                    // Since it gets here AFTER it adds a new bullet
                    if ([[self.attributedString.string substringWithRange:rangeOfPreviousParagraph] hasSuffix:self.BULLET_STRING]) {
                        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeBullet];
                        //NSLog(@"[RTE] Getting rid of bullets due to user hitting enter.");
                        NSRange rangeToDelete = NSMakeRange(rangeOfPreviousParagraph.location, rangeOfPreviousParagraph.length+rangeOfCurrentParagraph.length+1);
                        [self.textStorage deleteCharactersInRange:rangeToDelete];
                        NSRange newRange = NSMakeRange(rangeOfPreviousParagraph.location, 0);
                        self.selectedRange = newRange;
                        // Get rid of bullet indentation
                        [self removeBulletIndentation:newRange];
                    }
                }                
            }
        }
	}
}

- (void)mouseDown:(NSEvent *)theEvent {
	_lastSingleKeyPressed = 0;
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeMouseDown];
    [super mouseDown:theEvent];
}

- (NSString*)bulletString {
    return self.BULLET_STRING;
}

+ (NSString *)convertPreviewChangeTypeToString:(RichTextEditorPreviewChange)changeType withNonSpecialChangeText:(BOOL)shouldReturnStringForNonSpecialType {
	switch (changeType) {
		case RichTextEditorPreviewChangeBold:
			return NSLocalizedString(@"Bold", @"");
		case RichTextEditorPreviewChangeCut:
			return NSLocalizedString(@"Cut", @"");
		case RichTextEditorPreviewChangePaste:
			return NSLocalizedString(@"Paste", @"");
		case RichTextEditorPreviewChangeBullet:
			return NSLocalizedString(@"Bulleted List", @"");
		case RichTextEditorPreviewChangeItalic:
			return NSLocalizedString(@"Italic", @"");
		case RichTextEditorPreviewChangeFontResize:
		case RichTextEditorPreviewChangeFontSize:
			return NSLocalizedString(@"Font Resize", @"");
		case RichTextEditorPreviewChangeFontColor:
			return NSLocalizedString(@"Font Color", @"");
		case RichTextEditorPreviewChangeHighlight:
			return NSLocalizedString(@"Text Highlight", @"");
		case RichTextEditorPreviewChangeUnderline:
			return NSLocalizedString(@"Underline", @"");
		case RichTextEditorPreviewChangeIndentDecrease:
		case RichTextEditorPreviewChangeIndentIncrease:
			return NSLocalizedString(@"Text Indent", @"");
		case RichTextEditorPreviewChangeKeyDown:
			if (shouldReturnStringForNonSpecialType)
				return NSLocalizedString(@"Key Down", @"");
            break;
		case RichTextEditorPreviewChangeEnter:
			if (shouldReturnStringForNonSpecialType)
				return NSLocalizedString(@"Enter [Return] Key", @"");
            break;
		case RichTextEditorPreviewChangeSpace:
			if (shouldReturnStringForNonSpecialType)
				return NSLocalizedString(@"Space", @"");
            break;
		case RichTextEditorPreviewChangeDelete:
			if (shouldReturnStringForNonSpecialType)
				return NSLocalizedString(@"Delete", @"");
            break;
		case RichTextEditorPreviewChangeArrowKey:
			if (shouldReturnStringForNonSpecialType)
				return NSLocalizedString(@"Arrow Key Movement", @"");
            break;
		case RichTextEditorPreviewChangeMouseDown:
			if (shouldReturnStringForNonSpecialType)
				return NSLocalizedString(@"Mouse Down", @"");
            break;
        case RichTextEditorPreviewChangeFindReplace:
            return NSLocalizedString(@"Find & Replace", @"");
		default:
			break;
	}
	return @"";
}

#pragma mark - Keyboard Shortcuts

// http://stackoverflow.com/questions/970707/cocoa-keyboard-shortcuts-in-dialog-without-an-edit-menu
- (void)keyDown:(NSEvent*)event {
    NSString *key = event.charactersIgnoringModifiers;
    if (key.length > 0) {
        NSUInteger enabledShortcuts = RichTextEditorShortcutAll;
        if (self.rteDataSource && [self.rteDataSource respondsToSelector:@selector(enabledKeyboardShortcuts)]) {
            enabledShortcuts = [self.rteDataSource enabledKeyboardShortcuts];
        }
        
        unichar keyChar = 0;
        bool shiftKeyDown = event.modifierFlags & NSShiftKeyMask;
        bool commandKeyDown = event.modifierFlags & NSCommandKeyMask;
        keyChar = [key characterAtIndex:0];
		_lastSingleKeyPressed = keyChar;
        if (keyChar == NSLeftArrowFunctionKey || keyChar == NSRightArrowFunctionKey ||
            keyChar == NSUpArrowFunctionKey || keyChar == NSDownArrowFunctionKey) {
			[self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeArrowKey];
			[super keyDown:event];
        }
        else if ((keyChar == 'b' || keyChar == 'B') && commandKeyDown && !shiftKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutBold)) {
            [self userSelectedBold];
        }
        else if ((keyChar == 'i' || keyChar == 'I') && commandKeyDown && !shiftKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutItalic)) {
            [self userSelectedItalic];
        }
        else if ((keyChar == 'u' || keyChar == 'U') && commandKeyDown && !shiftKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutUnderline)) {
            [self userSelectedUnderline];
        }
        else if (keyChar == '>' && shiftKeyDown && commandKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutIncreaseFontSize)) {
            [self increaseFontSize];
        }
        else if (keyChar == '<' && shiftKeyDown && commandKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutDecreaseFontSize)) {
            [self decreaseFontSize];
        }
        else if (keyChar == 'L' && shiftKeyDown && commandKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutBulletedList)) {
            [self userSelectedBullet];
        }
        else if (keyChar == 'N' && shiftKeyDown && commandKeyDown && [self isInBulletedList] &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutLeaveBulletedList)) {
            [self userSelectedBullet];
        }
        else if (keyChar == 'T' && shiftKeyDown && commandKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutDecreaseIndent)) {
            [self userSelectedDecreaseIndent];
        }
        else if (keyChar == 't' && commandKeyDown && !shiftKeyDown &&
                 (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutIncreaseIndent)) {
            [self userSelectedIncreaseIndent];
        }
        else if (!([self.rteDelegate respondsToSelector:@selector(richTextEditor:keyDownEvent:)] && [self.rteDelegate richTextEditor:self keyDownEvent:event])) {
            [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeKeyDown];
            [super keyDown:event];
        }
    }
    else {
        [super keyDown:event];
    }
}

@end
