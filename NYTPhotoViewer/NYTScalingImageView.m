//
//  NYTScalingImageView.m
//  NYTPhotoViewer
//
//  Created by Harrison, Andrew on 7/23/13.
//  Copyright (c) 2015 The New York Times Company. All rights reserved.
//

#import "NYTScalingImageView.h"

#import "tgmath.h"

#ifdef ANIMATED_GIF_SUPPORT
#if SWIFT_PACKAGE
  #import "PINRemoteImage.h"
  #import "PINAnimatedImageView.h"
#else
  #import <PINRemoteImage/PINRemoteImage.h>
  #import <PINRemoteImage/PINAnimatedImageView.h>
#endif
#endif

CGFloat kFLAnimatedImageViewPreferredZoomScale = 5.0;

@interface NYTScalingImageView ()

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

#ifdef ANIMATED_GIF_SUPPORT
@property (nonatomic) PINAnimatedImageView *imageView;
#else
@property (nonatomic) UIImageView *imageView;
#endif

@property (nonatomic, assign) UIEdgeInsets contentInsetStored;
@end

@implementation NYTScalingImageView

#pragma mark - UIView

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithImage:[UIImage new] frame:frame];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self commonInitWithImage:nil imageData:nil];
    }

    return self;
}

- (void)didAddSubview:(UIView *)subview {
    [super didAddSubview:subview];
    [self centerScrollViewContents];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self updateZoomScale];
    [self centerScrollViewContents];
}

#pragma mark - NYTScalingImageView

- (instancetype)initWithImage:(UIImage *)image frame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self commonInitWithImage:image imageData:nil];
    }
    
    return self;
}

- (instancetype)initWithImageData:(NSData *)imageData frame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self commonInitWithImage:nil imageData:imageData];
    }
    
    return self;
}

- (void)commonInitWithImage:(UIImage *)image imageData:(NSData *)imageData {
    [self setupInternalImageViewWithImage:image imageData:imageData];
    [self setupImageScrollView];
    [self updateZoomScale];
}

#pragma mark - Setup

- (void)setupInternalImageViewWithImage:(UIImage *)image imageData:(NSData *)imageData {
    UIImage *imageToUse = image ?: [UIImage imageWithData:imageData];

#ifdef ANIMATED_GIF_SUPPORT
    self.imageView = [[PINAnimatedImageView alloc] initWithAnimatedImage:[[PINCachedAnimatedImage alloc] initWithAnimatedImageData:imageData]];
#else
    self.imageView = [[UIImageView alloc] initWithImage:imageToUse];
#endif
    [self updateImage:imageToUse imageData:imageData];
    
    [self addSubview:self.imageView];
}

- (void)updateImage:(UIImage *)image {
    [self updateImage:image imageData:nil];
}

- (void)updateImageData:(NSData *)imageData {
    [self updateImage:nil imageData:imageData];
}

- (void)updateImage:(UIImage *)image imageData:(NSData *)imageData {
#ifdef DEBUG
#ifndef ANIMATED_GIF_SUPPORT
    if (imageData != nil) {
        NSLog(@"[NYTPhotoViewer] Warning! You're providing imageData for a photo, but NYTPhotoViewer was compiled without animated GIF support. You should use native UIImages for non-animated photos. See the NYTPhoto protocol documentation for discussion.");
    }
#endif // ANIMATED_GIF_SUPPORT
#endif // DEBUG

    UIImage *imageToUse = image ?: [UIImage imageWithData:imageData];

    // Remove any transform currently applied by the scroll view zooming.
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.image = imageToUse;
    
#ifdef ANIMATED_GIF_SUPPORT
    // It's necessarry to first assign the UIImage so calulations for layout go right (see above)
    self.imageView.animatedImage = [[PINCachedAnimatedImage alloc] initWithAnimatedImageData:imageData];
#endif
    
    self.imageView.frame = CGRectMake(0, 0, imageToUse.size.width, imageToUse.size.height);
    
    self.contentSize = imageToUse.size;
    
    [self updateZoomScale];
    [self centerScrollViewContents];
}

- (void)setupImageScrollView {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    self.bouncesZoom = YES;
    self.decelerationRate = UIScrollViewDecelerationRateFast;
}

- (void)updateZoomScale {
#ifdef ANIMATED_GIF_SUPPORT
    if (self.imageView.animatedImage || self.imageView.image) {
        CGSize imageSize = self.imageView.animatedImage ? self.imageView.animatedImage.size : self.imageView.image.size;
#else
    if (self.imageView.image) {
        CGSize imageSize = self.imageView.image.size;
#endif
        CGRect scrollViewFrame = self.bounds;
        
        CGFloat scaleWidth = scrollViewFrame.size.width / imageSize.width;
        CGFloat scaleHeight = scrollViewFrame.size.height / imageSize.height;

        CGFloat minimumScale = MIN(scaleWidth, scaleHeight);
        CGFloat maximumScale = MAX(minimumScale, self.maximumZoomScale);
        
        if (self.isVerticalLongImage) {
            maximumScale = MAX(minimumScale, scaleWidth);
        }
        
        // 原始图片宽高大于屏幕则maximumScale等于1，原始图片宽高小雨屏幕则maximumScale大于1
        // 如果图片太小，放大效果不明显，为其设置一个最大的放大比例
        if (maximumScale / minimumScale < kFLAnimatedImageViewPreferredZoomScale) {
            maximumScale = minimumScale * kFLAnimatedImageViewPreferredZoomScale;
        }
        
        self.minimumZoomScale = minimumScale;
        self.maximumZoomScale = maximumScale;

        self.zoomScale = self.minimumZoomScale;

        // scrollView.panGestureRecognizer.enabled is on by default and enabled by
        // viewWillLayoutSubviews in the container controller so disable it here
        // to prevent an interference with the container controller's pan gesture.
        //
        // This is enabled in scrollViewWillBeginZooming so panning while zoomed-in
        // is unaffected.
        self.panGestureRecognizer.enabled = NO;
    }
}

- (BOOL)isVerticalLongImage {
    return (self.imageView.image.size.height / self.imageView.image.size.width) >= 4.0;
}

/*
 // 备忘，使用 setContentSize： 方法，maximumZooming状态在 setContentSize：前后是不变的
 */
- (void)setContentSize:(CGSize)contentSize {
    BOOL maximumZooming = self.zoomScale >= self.maximumZoomScale;
    if (self.isVerticalLongImage && !maximumZooming) {
        self.contentInset = self.contentInsetStored; // restore
    }
    
    [super setContentSize:contentSize];
    
    if (self.isVerticalLongImage && maximumZooming) {
        // 图片四周有缩进，长图放大后，把缩进去除，以使垂直滚动时不显示水平方向上的缩进黑边
        self.contentInset = UIEdgeInsetsZero;
    }
}

/*
 // 备忘，使用 zoomToRect： 方法，enlarging状态在 zoomToRect：前后是变化的
- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated {
    BOOL enlarging = self.zoomScale >= self.minimumZoomScale + 0.01;
    if (self.isVerticalLongImage && enlarging) {
        self.contentInset = self.contentInsetStored; // restore
    }
    
    [super zoomToRect:rect animated:animated];
    
    enlarging = !enlarging;
    
    if (self.isVerticalLongImage && enlarging) {
        // 图片四周有缩进，长图放大后，把缩进去除，以使垂直滚动时不显示水平方向上的缩进黑边
        self.contentInsetStored = self.contentInset;
        self.contentInset = UIEdgeInsetsZero;
    }
}
*/

#pragma mark - Centering

- (void)centerScrollViewContents {
    CGFloat horizontalInset = 0;
    CGFloat verticalInset = 0;
    
    if (self.contentSize.width < CGRectGetWidth(self.bounds)) {
        horizontalInset = (CGRectGetWidth(self.bounds) - self.contentSize.width) * 0.5;
    }
    
    if (self.contentSize.height < CGRectGetHeight(self.bounds)) {
        verticalInset = (CGRectGetHeight(self.bounds) - self.contentSize.height) * 0.5;
    }
    
    if (self.window.screen.scale < 2.0) {
        horizontalInset = __tg_floor(horizontalInset);
        verticalInset = __tg_floor(verticalInset);
    }
    
    // Use `contentInset` to center the contents in the scroll view. Reasoning explained here: http://petersteinberger.com/blog/2013/how-to-center-uiscrollview/
    self.contentInset = UIEdgeInsetsMake(verticalInset, horizontalInset, verticalInset, horizontalInset);
    self.contentInsetStored = self.contentInset;
}

@end
