//
//  XXTRectanglePicker.m
//  XXTouchApp
//
//  Created by Zheng on 18/10/2016.
//  Copyright © 2016 Zheng. All rights reserved.
//

#import "XXTRectanglePicker.h"
#import "XXTEImagePickerController.h"
#import "XXTENavigationController.h"
#import "XXTPixelCropView.h"
#import "XXTPixelPlaceholderView.h"
#import "XXTPositionColorModel.h"
#import "XXTPixelToolbar.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <LGAlertView/LGAlertView.h>

#import "UIColor+hexValue.h"
#import "UIColor+inverseColor.h"
#import "UINavigationController+XXTEFullscreenPopGesture.h"

#import "XXTExplorerViewController+SharedInstance.h"
#import "XXTExplorerEntryImageReader.h"
#import "XXTExplorerItemPicker.h"

#import "XXTPickerSnippetTask.h"
#import "XXTPickerFactory.h"


@interface XXTRectanglePicker () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIGestureRecognizerDelegate, LGAlertViewDelegate, XXTPixelCropViewDelegate, UIDocumentMenuDelegate, UIDocumentPickerDelegate, XXTExplorerItemPickerDelegate>
@property(nonatomic, strong) XXTPixelPlaceholderView *placeholderView;
@property(nonatomic, assign) BOOL locked;
@property(nonatomic, strong) UIButton *lockButton;
@property(nonatomic, strong) XXTPixelCropView *cropView;
@property(nonatomic, strong) XXTPixelToolbar *cropToolbar;
@end

// type
// title
// subtitle

@implementation XXTRectanglePicker {
    NSAttributedString *_pickerSubtitle;
    id _pickerResult;
    UIImage *_selectedImage;
}

@synthesize pickerTask = _pickerTask;
@synthesize pickerMeta = _pickerMeta;

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    if ([self isNavigationBarHidden]) {
        return UIStatusBarStyleDefault;
    }
#ifndef APPSTORE
    return UIStatusBarStyleLightContent;
#else
    return UIStatusBarStyleDefault;
#endif
}

- (BOOL)prefersStatusBarHidden {
    if ([self isNavigationBarHidden]) {
        return YES;
    }
    return [super prefersStatusBarHidden];
}

#pragma mark - Rotate

XXTE_START_IGNORE_PARTIAL
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    if (!self.selectedImage) {
        return;
    }
    [self setSelectedImage:self.selectedImage];
}
XXTE_END_IGNORE_PARTIAL

#pragma mark - Interactive Modal

- (BOOL)isModalInPresentation {
    return self.locked;
}

#pragma mark - View & Constraints

+ (NSString *)cachedImagePath {
    static NSString *cachedImagePath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        NSString *imagePath = [cachePath stringByAppendingPathComponent:@".XXTPixelPickerCachedImage.png"];
        cachedImagePath = imagePath;
    });
    return cachedImagePath;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.xxte_interactivePopDisabled = YES;
    
    [self setSelectedImage:nil];
    [self loadImageFromCache];

    UIBarButtonItem *rightItem = NULL;
    if ([self.pickerTask taskFinished]) {
        rightItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(taskFinished:)];
    } else {
        rightItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", nil) style:UIBarButtonItemStylePlain target:self action:@selector(taskNextStep:)];
    }
    self.navigationItem.rightBarButtonItem = rightItem;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateTipsFromSelectedStatus];
}

- (void)loadView {
    UIView *contentView = [[UIView alloc] init];
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    contentView.backgroundColor = XXTColorPlainBackground();
    self.view = contentView;

    XXTPixelCropView *cropView = [[XXTPixelCropView alloc] initWithFrame:contentView.bounds andType:(kXXTPixelCropViewType) [[self class] cropViewType]];
    cropView.hidden = YES;
    cropView.delegate = self;
    cropView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cropView.allowsRotate = NO;
    [contentView insertSubview:cropView atIndex:0];
    self.cropView = cropView;

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                 action:@selector(tripleFingerTapped:)];
    tapGesture.numberOfTapsRequired = 2;
    tapGesture.numberOfTouchesRequired = 3;
    tapGesture.delegate = self;
    [self.cropView addGestureRecognizer:tapGesture];

    [self.view addSubview:self.cropToolbar];
    [self.view addSubview:self.placeholderView];
}

- (void)updateViewConstraints {
    [super updateViewConstraints];
    NSMutableArray <NSLayoutConstraint *> *constraints = [[NSMutableArray alloc] init];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.cropToolbar
                                                        attribute:NSLayoutAttributeCenterX
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeCenterX
                                                       multiplier:1.f
                                                         constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.cropToolbar
                                                        attribute:NSLayoutAttributeTop
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.topLayoutGuide
                                                        attribute:NSLayoutAttributeBottom
                                                       multiplier:1.f
                                                         constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.cropToolbar
                                                        attribute:NSLayoutAttributeWidth
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeWidth
                                                       multiplier:1.f
                                                         constant:0.f]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.cropToolbar
                                                        attribute:NSLayoutAttributeHeight
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:nil
                                                        attribute:NSLayoutAttributeHeight
                                                       multiplier:1.f
                                                         constant:44.0]];
    [self.view addConstraints:constraints];
}

#pragma mark - Image Cache

- (void)loadImageFromCache {
    NSString *tempImagePath = nil;
    NSString *defaultPath = self.pickerMeta[@"default"];
    if (!tempImagePath) {
        if ([defaultPath isKindOfClass:[NSString class]]) {
            if (0 == access(defaultPath.UTF8String, F_OK)) {
                tempImagePath = defaultPath;
            }
        }
    }
    if (!tempImagePath) {
        tempImagePath = self.class.cachedImagePath;
    }
    if (tempImagePath && 0 == access(tempImagePath.UTF8String, R_OK)) {
        NSError *err = nil;
        NSData *imageData = [NSData dataWithContentsOfFile:tempImagePath
                                                   options:NSDataReadingMappedIfSafe
                                                     error:&err];
        if (imageData) {
            UIImage *image = [UIImage imageWithData:imageData];
            if (image) {
                [self setSelectedImage:image];
            } else {
                LGAlertView *alertView =
                [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Cannot read image data, invalid image?", nil) style:LGAlertViewStyleAlert buttonTitles:nil cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil actionHandler:nil cancelHandler:^(LGAlertView * _Nonnull alertView) {
                    [alertView dismissAnimated];
                } destructiveHandler:nil];
                [alertView showAnimated];
            }
        } else if (err) {
            LGAlertView *alertView =
            [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"Cannot load image from cache: %@", nil), [err localizedDescription]] style:LGAlertViewStyleAlert buttonTitles:nil cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil actionHandler:nil cancelHandler:^(LGAlertView * _Nonnull alertView) {
                [alertView dismissAnimated];
            } destructiveHandler:nil];
            [alertView showAnimated];
        }
    }
}

#pragma mark - Getter

+ (XXTPixelPickerType)cropViewType {
    return XXTPixelPickerTypeRect;
}

- (XXTPixelPlaceholderView *)placeholderView {
    if (!_placeholderView) {
        XXTPixelPlaceholderView *placeholderView = [[XXTPixelPlaceholderView alloc] initWithFrame:self.view.bounds];
        placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(placeholderViewTapped:)];
        [placeholderView addGestureRecognizer:tapGesture];
        _placeholderView = placeholderView;
    }
    return _placeholderView;
}

- (XXTPixelToolbar *)cropToolbar {
    if (!_cropToolbar) {
        XXTPixelToolbar *cropToolbar = [[XXTPixelToolbar alloc] init];
        cropToolbar.hidden = YES;
        cropToolbar.translatesAutoresizingMaskIntoConstraints = NO;
        cropToolbar.backgroundColor = [UIColor clearColor];
        if (@available(iOS 13.0, *)) {
            [cropToolbar setBackgroundColor:[[UIColor systemBackgroundColor] colorWithAlphaComponent:.75f]];
        } else {
            [cropToolbar setBackgroundColor:[UIColor colorWithWhite:1.f alpha:.75f]];
        }
        
        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *graphBtn = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"xxt-add-box"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:UIBarButtonItemStylePlain target:self action:@selector(changeImageButtonTapped:)];
        UIBarButtonItem *toLeftBtn = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"xxt-rotate-left"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:UIBarButtonItemStylePlain target:self action:@selector(rotateToLeftButtonTapped:)];
        UIBarButtonItem *toRightBtn = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"xxt-rotate-right"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:UIBarButtonItemStylePlain target:self action:@selector(rotateToRightButtonTapped:)];
        UIBarButtonItem *resetBtn = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"xxt-refresh"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:UIBarButtonItemStylePlain target:self action:@selector(resetButtonTapped:)];
        UIBarButtonItem *trashBtn = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:@"xxt-clear"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] style:UIBarButtonItemStylePlain target:self action:@selector(trashButtonTapped:)];

        UIButton *lockButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 30)];
        [lockButton setImage:[UIImage imageNamed:@"xxt-lock"] forState:UIControlStateNormal];
        [lockButton setImage:[UIImage imageNamed:@"xxt-unlock"] forState:UIControlStateSelected];
        [lockButton addTarget:self
                       action:@selector(lockButtonTapped:)
             forControlEvents:UIControlEventTouchUpInside];
        _lockButton = lockButton;
        UIBarButtonItem *lockBtn = [[UIBarButtonItem alloc] initWithCustomView:lockButton];

        [cropToolbar setItems:@[graphBtn, flexibleSpace, trashBtn, flexibleSpace, toLeftBtn, flexibleSpace, toRightBtn, flexibleSpace, resetBtn, flexibleSpace, lockBtn]];

        _cropToolbar = cropToolbar;
    }
    return _cropToolbar;
}

#pragma mark - Setter

- (UIImage *)selectedImage {
    return _selectedImage;
}

- (void)setSelectedImage:(UIImage *)selectedImage {
    _selectedImage = selectedImage;
    _pickerResult = nil;
    if (!selectedImage) {
        self.cropToolbar.hidden = YES;
        self.cropView.hidden = YES;
        self.placeholderView.hidden = NO;
    } else {
        self.cropView.image = selectedImage;
        self.cropToolbar.hidden = NO;
        self.cropView.hidden = NO;
        self.placeholderView.hidden = YES;
    }
    [self updateTipsFromSelectedStatus];
}

- (void)updateTipsFromSelectedStatus {
    NSString *subtitle = nil;
    if (self.pickerMeta[@"subtitle"]) {
        subtitle = self.pickerMeta[@"subtitle"];
    } else {
        if (!self.selectedImage) {
            subtitle = NSLocalizedString(@"Select an image from album.", nil);
        } else {
            switch ([[self class] cropViewType]) {
                case XXTPixelPickerTypeRect:
                    subtitle = NSLocalizedString(@"Select a rectangle area by dragging its corners.", nil);
                    break;
                case XXTPixelPickerTypePosition:
                case XXTPixelPickerTypePositionColor:
                    subtitle = NSLocalizedString(@"Select a position by tapping on image.", nil);
                    break;
                case XXTPixelPickerTypeColor:
                    subtitle = NSLocalizedString(@"Select a color by tapping on image.", nil);
                    break;
                case XXTPixelPickerTypeMultiplePositionColor:
                    subtitle = NSLocalizedString(@"Select several positions by tapping on image.", nil);
                    break;
            }
        }
    }
    [self updateSubtitle:subtitle];
}

#pragma mark - Tap Gestures

- (void)placeholderViewTapped:(id)sender {
    BOOL allowsImport = XXTEDefaultsBool(XXTExplorerAllowsImportFromAlbum, YES);
    if (allowsImport) {
        XXTE_START_IGNORE_PARTIAL
        if (@available(iOS 13.0, *)) {
            [self selectImageFromFileSystem];
        }
        else if (@available(iOS 8.0, *)) {
            UIDocumentMenuViewController *controller = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.image"] inMode:UIDocumentPickerModeImport];
            controller.delegate = self;
            [controller addOptionWithTitle:NSLocalizedString(@"Photos Library", nil)
                                     image:nil
                                     order:UIDocumentMenuOrderFirst
                                   handler:^{
                                       [self selectImageFromCameraRoll];
                                   }];
            [controller addOptionWithTitle:NSLocalizedString(@"File System", nil)
                                     image:nil
                                     order:UIDocumentMenuOrderFirst
                                   handler:^{
                                       [self selectImageFromFileSystem];
                                   }];
            controller.modalPresentationStyle = UIModalPresentationPopover;
            UIPopoverPresentationController *popoverController = controller.popoverPresentationController;
            if ([sender isKindOfClass:[UIBarButtonItem class]]) {
                UIBarButtonItem *barButtonItem = (UIBarButtonItem *)sender;
                popoverController.barButtonItem = barButtonItem;
            } else if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
                UIView *sourceView = ((UIGestureRecognizer *)sender).view;
                popoverController.sourceView = sourceView;
                popoverController.sourceRect = sourceView.frame;
                if (@available(iOS 9.0, *)) {
                    popoverController.canOverlapSourceViewRect = YES;
                }
            } else {
                return;
            }
            if (@available(iOS 13.0, *)) {
                popoverController.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                popoverController.backgroundColor = [UIColor whiteColor];
            }
            [self.navigationController presentViewController:controller animated:YES completion:nil];
        } else {
            [self selectImageFromFileSystem];
        }
        XXTE_END_IGNORE_PARTIAL
    } else {
        [self selectImageFromFileSystem];
    }
}

- (void)tripleFingerTapped:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self updateSubtitle:NSLocalizedString(@"3+2 touches to enter/exit fullscreen.", nil)];
        [self setNavigationBarHidden:![self isNavigationBarHidden] animated:YES];
    }
}

- (BOOL)isNavigationBarHidden {
    return [self.navigationController isNavigationBarHidden];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:hidden animated:animated];
}

#pragma mark - Toolbar Actions

- (void)changeImageButtonTapped:(UIBarButtonItem *)sender {
    [self placeholderViewTapped:sender];
}

- (UIImage *)processImage:(UIImage *)image byRotate:(CGFloat)radians fitSize:(BOOL)fitSize {
    size_t width = (size_t) CGImageGetWidth(image.CGImage);
    size_t height = (size_t) CGImageGetHeight(image.CGImage);
    CGRect newRect = CGRectApplyAffineTransform(CGRectMake(0.f, 0.f, width, height),
            fitSize ? CGAffineTransformMakeRotation(radians) : CGAffineTransformIdentity);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
            (size_t) newRect.size.width,
            (size_t) newRect.size.height,
            8,
            (size_t) newRect.size.width * 4,
            colorSpace,
            kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    if (!context) return nil;

    CGContextSetShouldAntialias(context, true);
    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);

    CGContextTranslateCTM(context, (CGFloat) +(newRect.size.width * 0.5), (CGFloat) +(newRect.size.height * 0.5));
    CGContextRotateCTM(context, radians);

    CGContextDrawImage(context, CGRectMake((CGFloat) -(width * 0.5), (CGFloat) -(height * 0.5), width, height), image.CGImage);
    CGImageRef imgRef = CGBitmapContextCreateImage(context);
    UIImage *img = [UIImage imageWithCGImage:imgRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imgRef);
    CGContextRelease(context);
    return img;
}

- (void)rotateToLeftButtonTapped:(UIBarButtonItem *)sender {
    if (!_selectedImage) return;
    [self setSelectedImage:[self processImage:self.selectedImage byRotate:(CGFloat) (90 * M_PI / 180) fitSize:YES]];
}

- (void)rotateToRightButtonTapped:(UIBarButtonItem *)sender {
    if (!_selectedImage) return;
    [self setSelectedImage:[self processImage:self.selectedImage byRotate:(CGFloat) (-90 * M_PI / 180) fitSize:YES]];
}

- (void)resetButtonTapped:(UIBarButtonItem *)sender {
    if (!_selectedImage || self.locked) return;
    if ([self.cropView userHasModifiedCropArea]) {
        [self.cropView resetCropRectAnimated:NO];
        [self updateSubtitle:NSLocalizedString(@"Canvas reset.", nil)];
    }
}

- (void)lockButtonTapped:(id)sender {
    if (!_selectedImage) return;
    self.locked = self.lockButton.isSelected;
    if (self.locked) {
        self.locked = NO;
        self.cropView.allowsOperation = YES;
        self.lockButton.selected = NO;
        [self updateSubtitle:NSLocalizedString(@"Canvas unlocked.", nil)];
    } else {
        self.locked = YES;
        self.cropView.allowsOperation = NO;
        self.lockButton.selected = YES;
        [self updateSubtitle:NSLocalizedString(@"Canvas locked, it cannot be moved or zoomed.", nil)];
    }
}

- (void)trashButtonTapped:(id)sender {
    LGAlertView *alertView = [[LGAlertView alloc] initWithTitle:NSLocalizedString(@"Confirm", nil) message:NSLocalizedString(@"Discard all changes and reset the canvas?", nil) style:LGAlertViewStyleAlert buttonTitles:nil cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:NSLocalizedString(@"Yes", nil) delegate:self];
    [alertView showAnimated];
}

#pragma mark - LGAlertViewDelegate

- (void)alertViewCancelled:(LGAlertView *)alertView {
    [alertView dismissAnimated];
}

- (void)alertViewDestructed:(LGAlertView *)alertView {
    _pickerResult = nil;
    [self setNavigationBarHidden:NO animated:YES];
    [self cleanCanvas];
    [alertView dismissAnimated];
}

#pragma mark - UIGestureRecognizerDelegate
#pragma mark - XXTEImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)mediaInfo {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if ([[mediaInfo objectForKey:UIImagePickerControllerMediaType] isEqualToString:(NSString *) kUTTypeImage]) {
        UIImage *originalImage = [mediaInfo objectForKey:UIImagePickerControllerOriginalImage];
        [self displayImage:originalImage needsCache:YES];
    }
}

- (void)displayImage:(UIImage *)originalImage needsCache:(BOOL)cache {
    if (cache) {
        NSError *err = nil;
        NSData *imageData = UIImagePNGRepresentation(originalImage);
        BOOL result = [imageData writeToFile:self.class.cachedImagePath
                                     options:NSDataWritingAtomic
                                       error:&err];
        if (!result) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                                message:[err localizedDescription]
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                      otherButtonTitles:nil];
            [alertView show];
        }
    }
    _pickerResult = nil;
    [self setSelectedImage:originalImage];
}

- (void)cleanCanvas {
    [self setSelectedImage:nil];
    NSError *err = nil;
    BOOL result = [[NSFileManager defaultManager] removeItemAtPath:self.class.cachedImagePath error:&err];
    if (!result) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                            message:[err localizedDescription]
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark - XXTBasePicker

- (NSString *)title {
    if (self.pickerMeta[@"title"]) {
        return self.pickerMeta[@"title"];
    } else {
        switch ([[self class] cropViewType]) {
            case XXTPixelPickerTypeRect:
                return NSLocalizedString(@"Rectangle", nil);
            case XXTPixelPickerTypePosition:
                return NSLocalizedString(@"Position", nil);
            case XXTPixelPickerTypeColor:
                return NSLocalizedString(@"Color", nil);
            case XXTPixelPickerTypePositionColor:
                return NSLocalizedString(@"Position & Color", nil);
            case XXTPixelPickerTypeMultiplePositionColor:
                return NSLocalizedString(@"Position & Color", nil);
        }
        return @"";
    }
}

+ (NSString *)pickerKeyword {
    switch ([[self class] cropViewType]) {
        case XXTPixelPickerTypeRect:
            return @"rect";
        case XXTPixelPickerTypePosition:
            return @"pos";
        case XXTPixelPickerTypeColor:
            return @"color";
        case XXTPixelPickerTypePositionColor:
            return @"poscolor";
        case XXTPixelPickerTypeMultiplePositionColor:
            return @"poscolors";
    }
    return nil;
}

- (id)pickerResult {
    if (!_pickerResult) {
        switch ([[self class] cropViewType]) {
            case XXTPixelPickerTypeRect:
                return @[ @(0), @(0), @(0), @(0), ]; // NSArray [4]
            case XXTPixelPickerTypePosition:
                return @[ @(0), @(0), ]; // NSArray [2]
            case XXTPixelPickerTypeColor:
                return @(0); // NSNumber
            case XXTPixelPickerTypePositionColor:
                return @[ @(0), @(0), @(0.0) ]; // NSArray [3]
            case XXTPixelPickerTypeMultiplePositionColor:
                return @[  ];
        }
    }
    return _pickerResult;
}

- (NSAttributedString *)pickerAttributedSubtitle {
    return _pickerSubtitle;
}

#pragma mark - Task Operations

- (void)taskFinished:(UIBarButtonItem *)sender {
    [self.pickerFactory performFinished:self];
}

- (void)taskNextStep:(UIBarButtonItem *)sender {
    [self.pickerFactory performNextStep:self];
}

- (void)updateSubtitle:(NSString *)subtitle {
    UIColor *textColor = XXTColorForeground();
    _pickerSubtitle = [[NSAttributedString alloc] initWithString:subtitle
                                                      attributes:@{
                                                              NSFontAttributeName: [UIFont fontWithName:@"Courier" size:12.f],
                                                              NSForegroundColorAttributeName: textColor,
                                                      }];
    [self.pickerFactory performUpdateStep:self];
}

- (void)updatedAttributedSubtitle:(NSAttributedString *)subtitle {
    _pickerSubtitle = subtitle;
    [self.pickerFactory performUpdateStep:self];
}

#pragma mark - XXTPixelCropViewDelegate

- (void)cropView:(XXTPixelCropView *)crop selectValueUpdated:(id)selectedValue {
    XXTPixelPickerType type = [[self class] cropViewType];
    if (type != kXXTPixelCropViewTypeRect && _locked == NO) {
        if (@available(iOS 10.0, *)) {
            static UIImpactFeedbackGenerator *feedbackGenerator = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            });
            [feedbackGenerator impactOccurred];
        }
    }
    if (type == kXXTPixelCropViewTypeRect) {
        NSAssert([selectedValue isKindOfClass:[NSValue class]], @"type == kXXTPixelCropViewTypeRect");
        CGRect cropRect = [selectedValue CGRectValue];
        _pickerResult = @[ @((int) cropRect.origin.x),
                           @((int) cropRect.origin.y),
                           @((int) cropRect.origin.x + (int) cropRect.size.width),
                           @((int) cropRect.origin.y + (int) cropRect.size.height) ];
        NSString *previewFormat = @"(x1, y1), (x2, y2) = (%d, %d), (%d, %d)";
        NSString *previewString = [NSString stringWithFormat:previewFormat,
                                                             (int) cropRect.origin.x,
                                                             (int) cropRect.origin.y,
                                                             (int) cropRect.origin.x + (int) cropRect.size.width,
                                                             (int) cropRect.origin.y + (int) cropRect.size.height];
        [self updateSubtitle:previewString];
    } else if (type == kXXTPixelCropViewTypeColor) {
        NSAssert([selectedValue isKindOfClass:[UIColor class]], @"type == kXXTPixelCropViewTypeColor");
        UIColor *selectedColor = selectedValue;
        if (!selectedColor) {
            selectedColor = [UIColor blackColor];
        }
        NSString *selectedHex = [selectedColor hexString];
        _pickerResult = [selectedColor RGBNumberValue];
        NSString *previewFormat = @"(r%d, g%d, b%d) ";
        CGFloat r = 0, g = 0, b = 0, a = 0;
        [selectedColor getRed:&r green:&g blue:&b alpha:&a];
        NSString *previewString = [NSString stringWithFormat:previewFormat, (int) (r * 255.f), (int) (g * 255.f), (int) (b * 255.f)];
        UIColor *textColor = XXTColorForeground();
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:previewString
                                                                                             attributes:@{
                                                                                                     NSFontAttributeName: [UIFont fontWithName:@"Courier" size:12.f],
                                                                                                     NSForegroundColorAttributeName: textColor
                                                                                             }];
        NSString *colorPreview = [NSString stringWithFormat:@"(■ 0x%@)", selectedHex];
        NSAttributedString *colorAttributedPreview = [[NSMutableAttributedString alloc] initWithString:colorPreview
                                                                                            attributes:@{
                                                                                                    NSFontAttributeName: [UIFont fontWithName:@"Courier-Bold" size:12.f],
                                                                                                    NSForegroundColorAttributeName: selectedColor,
                                                                                                    NSBackgroundColorAttributeName: [selectedColor inverseColor]
                                                                                            }];
        [attributedString appendAttributedString:colorAttributedPreview];
        [self updatedAttributedSubtitle:[attributedString copy]];
    } else if (type == kXXTPixelCropViewTypePosition) {
        NSAssert([selectedValue isKindOfClass:[NSValue class]], @"type == kXXTPixelCropViewTypePosition");
        CGPoint selectedPoint = [selectedValue CGPointValue];
        _pickerResult = @[ @((int) selectedPoint.x), @((int) selectedPoint.y) ];
        NSString *previewFormat = @"(x%d, y%d)";
        NSString *previewString = [NSString stringWithFormat:previewFormat, (int) selectedPoint.x, (int) selectedPoint.y];
        [self updateSubtitle:previewString];
    } else if (type == kXXTPixelCropViewTypePositionColor || type == kXXTPixelCropViewTypeMultiplePositionColor) {
        if ([selectedValue isKindOfClass:[XXTPositionColorModel class]]) {
            XXTPositionColorModel *model = selectedValue;
            CGPoint selectedPoint = model.position;
            UIColor *selectedColor = model.color;
            NSString *selectedHex = [selectedColor hexString];
            if (type == kXXTPixelCropViewTypePositionColor) {
                _pickerResult = @[ @((int) selectedPoint.x), @((int) selectedPoint.y), [selectedColor RGBNumberValue] ];
            }
            NSString *previewFormat = @"(x%d, y%d) ";
            NSString *previewString = [NSString stringWithFormat:previewFormat, (int) selectedPoint.x, (int) selectedPoint.y];
            UIColor *textColor = XXTColorForeground();
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:previewString
                                                                                                 attributes:@{
                                                                                                         NSFontAttributeName: [UIFont fontWithName:@"Courier" size:12.f],
                                                                                                         NSForegroundColorAttributeName: textColor
                                                                                                 }];
            NSString *colorPreview = [NSString stringWithFormat:@"(■ 0x%@)", selectedHex];
            NSAttributedString *colorAttributedPreview = [[NSMutableAttributedString alloc] initWithString:colorPreview
                                                                                                attributes:@{
                                                                                                        NSFontAttributeName: [UIFont fontWithName:@"Courier-Bold" size:12.f],
                                                                                                        NSForegroundColorAttributeName: selectedColor,
                                                                                                        NSBackgroundColorAttributeName: [selectedColor inverseColor]
                                                                                                }];
            [attributedString appendAttributedString:colorAttributedPreview];
            [self updatedAttributedSubtitle:[attributedString copy]];
        } else if ([selectedValue isKindOfClass:[NSArray class]]) {
            NSArray *values = (NSArray *)selectedValue;
            if (values.count == 99) {
                toastMessage(self, NSLocalizedString(@"Cannot select more points.", nil));
            }
            NSMutableArray <NSArray *> *mulArray = [[NSMutableArray alloc] init];
            NSUInteger index = 0;
            for (XXTPositionColorModel *poscolor in values) {
                index++;
                UIColor *c = [poscolor.color copy];
                if (!c) c = [UIColor blackColor];
                CGPoint p = poscolor.position;
                [mulArray addObject: @[ @((int) p.x), @((int) p.y), [c RGBNumberValue] ]];
            }
            _pickerResult = [mulArray copy];
        } else {
            NSAssert(YES, @"type == kXXTPixelCropViewTypePositionColor || type == kXXTPixelCropViewTypeMultiplePositionColor");
        }
    }
}

#pragma mark - Image Selection

- (void)selectImageFromFileSystem {
    XXTExplorerItemPicker *itemPicker = [[XXTExplorerItemPicker alloc] initWithEntryPath:[XXTExplorerViewController initialPath]];
    itemPicker.delegate = self;
    itemPicker.allowedExtensions = [XXTExplorerEntryImageReader supportedExtensions];
    XXTENavigationController *navigationController = [[XXTENavigationController alloc] initWithRootViewController:itemPicker];
    navigationController.modalPresentationStyle = UIModalPresentationCurrentContext;
    navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)selectImageFromCameraRoll {
    XXTEImagePickerController *imagePickerController = [[XXTEImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
    imagePickerController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

#pragma mark - UIDocumentMenuDelegate

XXTE_START_IGNORE_PARTIAL
- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu {
    
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    [[UINavigationBar appearanceWhenContainedIn:[UIDocumentPickerViewController class], nil] setBarTintColor:XXTColorBarTint()];
    documentPicker.delegate = self;
    if (@available(iOS 11.0, *)) {
        documentPicker.allowsMultipleSelection = NO;
    }
    documentPicker.modalPresentationStyle = UIModalPresentationCurrentContext;
    documentPicker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self.navigationController presentViewController:documentPicker animated:YES completion:^{
        blockInteractions(self, YES);
    }];
}
XXTE_END_IGNORE_PARTIAL

#pragma mark - UIDocumentPickerDelegate

XXTE_START_IGNORE_PARTIAL
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    blockInteractions(self, NO);
}
XXTE_END_IGNORE_PARTIAL

XXTE_START_IGNORE_PARTIAL
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    if (!url) return;
    NSString *imagePath = [url path];
    if (!imagePath) return;
    UIImage *originalImage = [[UIImage alloc] initWithContentsOfFile:imagePath];
    [self displayImage:originalImage needsCache:YES];
    blockInteractions(self, NO);
}
XXTE_END_IGNORE_PARTIAL

#pragma mark - XXTExplorerItemPickerDelegate

- (void)itemPickerDidCancelSelectingItem:(XXTExplorerItemPicker *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)itemPicker:(XXTExplorerItemPicker *)picker didSelectItemAtPath:(NSString *)imagePath {
    UIViewController *blockController = blockInteractions(self, YES);
    [picker dismissViewControllerAnimated:YES completion:^{
        if (!imagePath) return;
        UIImage *originalImage = [[UIImage alloc] initWithContentsOfFile:imagePath];
        [self displayImage:originalImage needsCache:YES];
        blockInteractions(blockController, NO);
    }];
}

#pragma mark - Memory

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"- [%@ dealloc]", NSStringFromClass([self class]));
#endif
}

@end
