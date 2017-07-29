//
//  XUIEditTextCell.m
//  XXTExplorer
//
//  Created by Zheng on 29/07/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "XUIEditTextCell.h"

@interface XUIEditTextCell () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *xui_textField;

@end

@implementation XUIEditTextCell

@synthesize xui_value = _xui_value;

+ (BOOL)xibBasedLayout {
    return YES;
}

+ (BOOL)layoutNeedsTextLabel {
    return NO;
}

+ (BOOL)layoutNeedsImageView {
    return NO;
}

+ (BOOL)checkEntry:(NSDictionary *)cellEntry withError:(NSError **)error {
    return YES;
}

- (void)setupCell {
    [super setupCell];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.xui_textField.delegate = self;
    self.xui_textField.clearButtonMode = UITextFieldViewModeWhileEditing;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)setXui_keyboard:(NSString *)xui_keyboard {
    _xui_keyboard = xui_keyboard;
    if ([xui_keyboard isEqualToString:@"numbers"]) {
        self.xui_textField.keyboardType = UIKeyboardTypeNumberPad;
    }
    else if ([xui_keyboard isEqualToString:@"phone"]) {
        self.xui_textField.keyboardType = UIKeyboardTypePhonePad;
    }
    else {
        self.xui_textField.keyboardType = UIKeyboardTypeDefault;
    }
}

- (void)setXui_autoCaps:(NSString *)xui_autoCaps {
    _xui_autoCaps = xui_autoCaps;
    if ([xui_autoCaps isEqualToString:@"sentences"]) {
        self.xui_textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    }
    else if ([xui_autoCaps isEqualToString:@"words"]) {
        self.xui_textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }
    else if ([xui_autoCaps isEqualToString:@"all"]) {
        self.xui_textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }
    else {
        self.xui_textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
}

- (void)setXui_placeholder:(NSString *)xui_placeholder {
    _xui_placeholder = xui_placeholder;
    self.xui_textField.placeholder = xui_placeholder;
}

- (void)setXui_bestGuess:(NSString *)xui_bestGuess {
    _xui_bestGuess = xui_bestGuess;
    self.xui_textField.text = xui_bestGuess;
}

- (void)setXui_noAutoCorrect:(NSNumber *)xui_noAutoCorrect {
    _xui_noAutoCorrect = xui_noAutoCorrect;
    BOOL noAutoCorrect = [xui_noAutoCorrect boolValue];
    self.xui_textField.autocorrectionType = noAutoCorrect ? UITextAutocorrectionTypeNo : UITextAutocorrectionTypeYes;
}

- (void)setXui_isIP:(NSNumber *)xui_isIP {
    _xui_isIP = xui_isIP;
    self.xui_textField.keyboardType = UIKeyboardTypeDecimalPad;
}

- (void)setXui_isURL:(NSNumber *)xui_isURL {
    _xui_isURL = xui_isURL;
    self.xui_textField.keyboardType = UIKeyboardTypeURL;
}

- (void)setXui_isEmail:(NSNumber *)xui_isEmail {
    _xui_isEmail = xui_isEmail;
    self.xui_textField.keyboardType = UIKeyboardTypeEmailAddress;
}

- (void)setXui_isNumeric:(NSNumber *)xui_isNumeric {
    _xui_isNumeric = xui_isNumeric;
    self.xui_textField.keyboardType = UIKeyboardTypeNumberPad;
}

- (void)setXui_isDecimalPad:(NSNumber *)xui_isDecimalPad {
    _xui_isDecimalPad = xui_isDecimalPad;
    self.xui_textField.keyboardType = UIKeyboardTypeDecimalPad;
}

- (void)setXui_alignment:(NSString *)xui_alignment {
    _xui_alignment = xui_alignment;
    if ([xui_alignment isEqualToString:@"left"]) {
        self.xui_textField.textAlignment = NSTextAlignmentLeft;
    }
    else if ([xui_alignment isEqualToString:@"center"]) {
        self.xui_textField.textAlignment = NSTextAlignmentCenter;
    }
    else if ([xui_alignment isEqualToString:@"right"]) {
        self.xui_textField.textAlignment = NSTextAlignmentRight;
    }
    else if ([xui_alignment isEqualToString:@"natural"]) {
        self.xui_textField.textAlignment = NSTextAlignmentNatural;
    }
    else if ([xui_alignment isEqualToString:@"justified"]) {
        self.xui_textField.textAlignment = NSTextAlignmentJustified;
    }
    else {
        self.xui_textField.textAlignment = NSTextAlignmentNatural;
    }
}

- (void)setXui_enabled:(NSNumber *)xui_enabled {
    [super setXui_enabled:xui_enabled];
    BOOL enabled = [xui_enabled boolValue];
    self.xui_textField.enabled = enabled;
}

@end
