//
//  NYTPhotoViewController.m
//  NYTPhotoViewer
//
//  Created by Brian Capps on 2/11/15.
//
//

#import "NYTPhotoViewController.h"
#import "NYTPhoto.h"
#import "NYTScalingImageView.h"

#ifdef ANIMATED_GIF_SUPPORT
#if SWIFT_PACKAGE
  #import "PINRemoteImage.h"
  #import "PINAnimatedImageView.h"
#else
  #import <PINRemoteImage/PINRemoteImage.h>
  #import <PINRemoteImage/PINAnimatedImageView.h>
#endif
#endif

NSString * const NYTPhotoViewControllerPhotoImageUpdatedNotification = @"NYTPhotoViewControllerPhotoImageUpdatedNotification";

@interface NYTPhotoViewController () <UIScrollViewDelegate>

@property (nonatomic, nullable) id <NYTPhoto> photo;
@property (nonatomic, nullable) UIView *interstitialView;
@property (nonatomic) NSUInteger photoViewItemIndex;

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (nonatomic) NYTScalingImageView *scalingImageView;
@property (nonatomic) UIView *loadingView;
@property (nonatomic) NSNotificationCenter *notificationCenter;
@property (nonatomic) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;

@end

@implementation NYTPhotoViewController

#pragma mark - NSObject

- (void)dealloc {
    _scalingImageView.delegate = nil;
    
    [_notificationCenter removeObserver:self];
}

#pragma mark - UIViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithPhoto:nil itemIndex:0 loadingView:nil notificationCenter:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self commonInitWithPhoto:nil itemIndex:0 loadingView:nil notificationCenter:nil];
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.notificationCenter addObserver:self selector:@selector(photoImageUpdatedWithNotification:) name:NYTPhotoViewControllerPhotoImageUpdatedNotification object:nil];
    
    self.scalingImageView.frame = self.view.bounds;
    [self.view addSubview:self.scalingImageView];
    
    [self.view addSubview:self.loadingView];
    [self.loadingView sizeToFit];
    
    [self.view addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:self.longPressGestureRecognizer];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.scalingImageView.frame = self.view.bounds;
    
    [self.loadingView sizeToFit];
    self.loadingView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

#pragma mark - NYTPhotoViewController

- (instancetype)initWithPhoto:(id <NYTPhoto>)photo itemIndex:(NSUInteger)itemIndex loadingView:(UIView *)loadingView notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        [self commonInitWithPhoto:photo itemIndex:itemIndex loadingView:loadingView notificationCenter:notificationCenter];
    }
    
    return self;
}

- (void)commonInitWithPhoto:(id <NYTPhoto>)photo itemIndex:(NSUInteger)itemIndex loadingView:(UIView *)loadingView notificationCenter:(NSNotificationCenter *)notificationCenter {
    _photo = photo;
    _interstitialView = nil;
    _photoViewItemIndex = itemIndex;
    
    if (photo.imageData) {
        _scalingImageView = [[NYTScalingImageView alloc] initWithImageData:photo.imageData frame:CGRectZero];
    }
    else {
        UIImage *photoImage = photo.image ?: photo.placeholderImage;
        _scalingImageView = [[NYTScalingImageView alloc] initWithImage:photoImage frame:CGRectZero];
        
        if (!photoImage) {
            [self setupLoadingView:loadingView];
        }
    }
    
    _scalingImageView.delegate = self;

    _notificationCenter = notificationCenter;

    [self setupGestureRecognizers];
}

- (void)setupLoadingView:(UIView *)loadingView {
    self.loadingView = loadingView;
    if (!loadingView) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityIndicator startAnimating];
        self.loadingView = activityIndicator;
    }
}

- (void)photoImageUpdatedWithNotification:(NSNotification *)notification {
    id <NYTPhoto> photo = notification.object;
    if ([photo conformsToProtocol:@protocol(NYTPhoto)] && [photo isEqual:self.photo]) {
        [self updateImage:photo.image imageData:photo.imageData];
    }
}

- (void)updateImage:(UIImage *)image imageData:(NSData *)imageData {
    if (imageData) {
        [self.scalingImageView updateImageData:imageData];
    }
    else {
        [self.scalingImageView updateImage:image];
    }
    
    if (imageData || image) {
        [self.loadingView removeFromSuperview];
    } else {
        [self.view addSubview:self.loadingView];
    }
}

#pragma mark - Gesture Recognizers

- (void)setupGestureRecognizers {
    self.doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTapWithGestureRecognizer:)];
    self.doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWithGestureRecognizer:)];
}

- (void)didDoubleTapWithGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    CGPoint touchPoint = [recognizer locationInView:self.scalingImageView.imageView];
    
    // 控制下面的zoomScale的大小，来放大、缩小图片
    CGFloat minimumZoomScale = self.scalingImageView.minimumZoomScale;
    CGFloat maximumZoomScale = self.scalingImageView.maximumZoomScale;
    
    // 设置默认放大比例
    BOOL maximumZooming = YES;
    CGFloat newZoomScale = fmin(maximumZoomScale, minimumZoomScale * 3.0);

    // 长图自动放大到最大，宽度充满屏幕
    if (self.scalingImageView.isVerticalLongImage) {
        newZoomScale = maximumZoomScale;
    }
    
    // 图片已经放大，则还原图片
    if (self.scalingImageView.zoomScale > self.scalingImageView.minimumZoomScale) {
        maximumZooming = NO;
        newZoomScale = minimumZoomScale;
    }
    
//    // 超大图二次放大
//    if (maximumZooming) {
//        if (fabs(self.scalingImageView.zoomScale - zoomScale) <= 0.01 && zoomScale < maximumZoomScale) {
//            zoomScale = maximumZoomScale;
//        }
//    }
    
    CGSize scrollViewSize = self.scalingImageView.bounds.size;
    
    CGFloat width = scrollViewSize.width / newZoomScale;
    CGFloat height = scrollViewSize.height / newZoomScale;
    CGFloat originX = touchPoint.x - (width / 2.0);
    CGFloat originY = touchPoint.y - (height / 2.0);
    
    if (self.scalingImageView.isVerticalLongImage && maximumZooming) {
        originX = 0.0;
        originY = 0.0;
    }
    CGRect rectToZoomTo = CGRectMake(originX, originY, width, height);
    
    [self.scalingImageView zoomToRect:rectToZoomTo animated:YES];
}

- (void)didLongPressWithGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(photoViewController:didLongPressWithGestureRecognizer:)]) {
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            [self.delegate photoViewController:self didLongPressWithGestureRecognizer:recognizer];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.scalingImageView.imageView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    scrollView.panGestureRecognizer.enabled = YES;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    // There is a bug, especially prevalent on iPhone 6 Plus, that causes zooming to render all other gesture recognizers ineffective.
    // This bug is fixed by disabling the pan gesture recognizer of the scroll view when it is not needed.
    if (scrollView.zoomScale == scrollView.minimumZoomScale) {
        scrollView.panGestureRecognizer.enabled = NO;
    }
}

@end
