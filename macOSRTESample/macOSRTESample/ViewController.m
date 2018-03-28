//
//  ViewController.m
//  macOSRTESample
//
//  Created by School of Computing Macbook on 3/28/18.
//  Copyright © 2018 Pikle Productions. All rights reserved.
//

#import "ViewController.h"
#import <macOSRichTextEditor/RichTextEditor.h>

@interface NSImage (Tint)

- (NSImage *)imageTintedWithColor:(NSColor *)tint;

@end

@implementation NSImage (Tint)

// https://stackoverflow.com/a/16138027/3938401
- (NSImage *)imageTintedWithColor:(NSColor *)tint {
    NSImage *image = [self copy];
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    return image;
}

@end

@interface ViewController () <RichTextEditorDelegate>

@property (unsafe_unretained) IBOutlet RichTextEditor *richTextEditor;

@property (weak) IBOutlet NSButton *boldButton;
@property (weak) IBOutlet NSButton *italicButton;
@property (weak) IBOutlet NSButton *underlineButton;
@property (weak) IBOutlet NSButton *bulletedListButton;
@property (weak) IBOutlet NSButton *decreaseIndentButton;
@property (weak) IBOutlet NSButton *increaseIndentButton;

-(IBAction)toggleBold:(id)sender;
-(IBAction)toggleItalic:(id)sender;
-(IBAction)toggleUnderline:(id)sender;

-(IBAction)toggleBulletedList:(id)sender;

-(IBAction)decreaseIndent:(id)sender;
-(IBAction)increaseIndent:(id)sender;

-(IBAction)decreaseFontSize:(id)sender;
-(IBAction)increaseFontSize:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.richTextEditor.rteDelegate = self;
}

-(IBAction)toggleBold:(id)sender {
    [self.richTextEditor userSelectedBold];
}

-(IBAction)toggleItalic:(id)sender {
    [self.richTextEditor userSelectedItalic];
}

-(IBAction)toggleUnderline:(id)sender {
    [self.richTextEditor userSelectedUnderline];
}

-(IBAction)toggleBulletedList:(id)sender {
    [self.richTextEditor userSelectedBullet];
}

-(IBAction)decreaseIndent:(id)sender {
    [self.richTextEditor userSelectedDecreaseIndent];
}

-(IBAction)increaseIndent:(id)sender {
    [self.richTextEditor userSelectedIncreaseIndent];
}

-(IBAction)decreaseFontSize:(id)sender {
    [self.richTextEditor decreaseFontSize];
}

-(IBAction)increaseFontSize:(id)sender {
    [self.richTextEditor increaseFontSize];
}

- (void)richTextEditor:(RichTextEditor*)editor changeAboutToOccurOfType:(RichTextEditorPreviewChange)type {
    NSLog(@"User just edited the RTE by performing this operation: %@", [RichTextEditor convertPreviewChangeTypeToString:type withNonSpecialChangeText:YES]);
}

-(void)selectionForEditor:(RichTextEditor*)editor changedTo:(NSRange)range isBold:(BOOL)isBold isItalic:(BOOL)isItalic isUnderline:(BOOL)isUnderline isInBulletedList:(BOOL)isInBulletedList textBackgroundColor:(NSColor*)textBackgroundColor textColor:(NSColor*)textColor {
    if (isBold) {
        self.boldButton.image = [[NSImage imageNamed:@"bold"] imageTintedWithColor:NSColor.blueColor];
    }
    else {
        self.boldButton.image = [[NSImage imageNamed:@"bold"] imageTintedWithColor:NSColor.blackColor];
    }
    if (isItalic) {
        self.italicButton.image = [[NSImage imageNamed:@"italic"] imageTintedWithColor:NSColor.blueColor];
    }
    else {
        self.italicButton.image = [[NSImage imageNamed:@"italic"] imageTintedWithColor:NSColor.blackColor];
    }
    if (isUnderline) {
        self.underlineButton.image = [[NSImage imageNamed:@"underline"] imageTintedWithColor:NSColor.blueColor];
    }
    else {
        self.underlineButton.image = [[NSImage imageNamed:@"underline"] imageTintedWithColor:NSColor.blackColor];
    }
    if (isInBulletedList) {
        self.bulletedListButton.image = [[NSImage imageNamed:@"bulleted-list"] imageTintedWithColor:NSColor.blueColor];
    }
    else {
        self.bulletedListButton.image = [[NSImage imageNamed:@"bulleted-list"] imageTintedWithColor:NSColor.blackColor];
    }
    
}

@end
