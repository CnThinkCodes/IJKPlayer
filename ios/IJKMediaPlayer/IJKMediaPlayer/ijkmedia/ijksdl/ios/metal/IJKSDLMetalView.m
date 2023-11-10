//
//  IJKSDLMetalView.m
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/25.
//  Copyright © 2023 bilibili. All rights reserved.
//

#import "IJKSDLMetalView.h"
#include "ijksdl/ijksdl_timer.h"
#include "ijksdl/ios/ijksdl_ios.h"
#include "ijksdl/ijksdl_gles2.h"
#include "IJKSDLMetalRender.h"

typedef NS_ENUM(NSInteger, IJKSDLGLViewApplicationState) {
    IJKSDLGLViewApplicationUnknownState = 0,
    IJKSDLGLViewApplicationForegroundState = 1,
    IJKSDLGLViewApplicationBackgroundState = 2
};


@interface IJKSDLMetalView()

@property(atomic,strong) NSRecursiveLock *glActiveLock;

@property(atomic) BOOL glActivePaused;

@end

@implementation IJKSDLMetalView{
    GLint           _backingWidth;
    GLint           _backingHeight;

    int             _frameCount;
    
    int64_t         _lastFrameTime;

    int                 _rendererGravity;
    
    IJKSDLMetalRender   *_renderer;

    BOOL            _isRenderBufferInvalidated;

    int             _tryLockErrorCount;
    BOOL            _didSetupGL;
    BOOL            _didStopGL;
    BOOL            _didLockedDueToMovedToWindow;
    BOOL            _shouldLockWhileBeingMovedToWindow;
    NSMutableArray *_registeredNotifications;

    IJKSDLGLViewApplicationState _applicationState;
}

@synthesize isThirdGLView              = _isThirdGLView;
@synthesize scaleFactor                = _scaleFactor;
@synthesize fps                        = _fps;

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _tryLockErrorCount = 0;
        _shouldLockWhileBeingMovedToWindow = YES;
        self.glActiveLock = [[NSRecursiveLock alloc] init];
        _registeredNotifications = [[NSMutableArray alloc] init];
        [self registerApplicationObservers];

        _didSetupGL = NO;
        if ([self isApplicationActive] == YES)
            [self setupGLOnce];
        
        self.backgroundColor = UIColor.blackColor;
    }

    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow{
    if (!_shouldLockWhileBeingMovedToWindow) {
        [super willMoveToWindow:newWindow];
        return;
    }
    if (newWindow && !_didLockedDueToMovedToWindow) {
        [self lockGLActive];
        _didLockedDueToMovedToWindow = YES;
    }
    [super willMoveToWindow:newWindow];
}

- (void)didMoveToWindow{
    [super didMoveToWindow];
    if (self.window && _didLockedDueToMovedToWindow) {
        [self unlockGLActive];
        _didLockedDueToMovedToWindow = NO;
    }
}

- (BOOL)setupGL{
    if (_didSetupGL)
        return YES;

    _scaleFactor = [[UIScreen mainScreen] scale];
    if (_scaleFactor < 0.1f){
        _scaleFactor = 1.0f;
    }
       
    _didSetupGL = YES;
    return _didSetupGL;
}

- (BOOL)setupGLOnce{
    if (_didSetupGL)
        return YES;

    if (![self tryLockGLActive])
        return NO;

    BOOL didSetupGL = [self setupGL];
    [self unlockGLActive];
    return didSetupGL;
}

- (BOOL)isApplicationActive{
    switch (_applicationState) {
        case IJKSDLGLViewApplicationForegroundState:
            return YES;
        case IJKSDLGLViewApplicationBackgroundState:
            return NO;
        default: {
            UIApplicationState appState = [UIApplication sharedApplication].applicationState;
            switch (appState) {
                case UIApplicationStateActive:
                    return YES;
                case UIApplicationStateInactive:
                case UIApplicationStateBackground:
                default:
                    return NO;
            }
        }
    }
}

- (void)dealloc{
    [self lockGLActive];

    _didStopGL = YES;

    [self unregisterApplicationObservers];

    [self unlockGLActive];
}

- (void)setScaleFactor:(CGFloat)scaleFactor{
    _scaleFactor = scaleFactor;
    [self invalidateRenderBuffer];
}

- (void)layoutSubviews{
    [super layoutSubviews];
    if (self.window.screen != nil) {
        _scaleFactor = self.window.screen.scale;
    }
//    [self invalidateRenderBuffer];
}

- (void)setContentMode:(UIViewContentMode)contentMode{
    [super setContentMode:contentMode];
    switch (contentMode) {
        case UIViewContentModeScaleToFill:
            _renderer.renderingResizingMode = IJKSDLMetalRenderingResizingModeScale;
            break;
        case UIViewContentModeScaleAspectFit:
            _renderer.renderingResizingMode = IJKSDLMetalRenderingResizingModeAspect;
            break;
        case UIViewContentModeScaleAspectFill:
            _renderer.renderingResizingMode = IJKSDLMetalRenderingResizingModeAspectFill;
            break;
        default:
            _renderer.renderingResizingMode = IJKSDLMetalRenderingResizingModeAspect;
            break;
    }
//    [self invalidateRenderBuffer];
}

- (BOOL)setupRenderer: (SDL_VoutOverlay *)overlay{
    if (overlay == nil)
        return _renderer != nil;

    if (!_renderer.isVaild /*|| _renderer.inputFormat != overlay->format*/){
        _renderer = [IJKSDLMetalRender rendererWithOverlay:overlay metalView:self];
         
        if (!_renderer.isVaild)
            return NO;

        [self setContentMode:self.contentMode];
    }
    

    return YES;
}

- (void)invalidateRenderBuffer{
    NSLog(@"invalidateRenderBuffer\n");
    [self lockGLActive];

    _isRenderBufferInvalidated = YES;

    if ([[NSThread currentThread] isMainThread]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            if (_isRenderBufferInvalidated)
                [self display:nil];
        });
    } else {
        [self display:nil];
    }

    [self unlockGLActive];
}

- (void)display_pixels:(IJKOverlay *)overlay {
    return;
}

- (void)display:(SDL_VoutOverlay *)overlay{
    if (_didSetupGL == NO)
        return;

    if ([self isApplicationActive] == NO)
        return;

    if (![self tryLockGLActive]) {
        if (0 == (_tryLockErrorCount % 100)) {
            NSLog(@"IJKSDLGLView:display: unable to tryLock GL active: %d\n", _tryLockErrorCount);
        }
        _tryLockErrorCount++;
        return;
    }

    _tryLockErrorCount = 0;
    
    [self displayInternal:overlay];

    [self unlockGLActive];
}

// NOTE: overlay could be NULl
- (void)displayInternal:(SDL_VoutOverlay *)overlay{
    if (![self setupRenderer:overlay]) {
        if (!overlay && !_renderer) {
            NSLog(@"IJKSDLGLView: setupDisplay not ready\n");
        } else {
            NSLog(@"IJKSDLGLView: setupDisplay failed\n");
        }
        return;
    }
    
    // 不知道有用吗
//    [self.layer setContentsScale:_scaleFactor];

    if (![_renderer display:overlay])
        ALOGE("[EGL] IJK_GLES2_render failed\n");

    int64_t current = (int64_t)SDL_GetTickHR();
    int64_t delta   = (current > _lastFrameTime) ? current - _lastFrameTime : 0;
    if (delta <= 0) {
        _lastFrameTime = current;
    } else if (delta >= 1000) {
        _fps = ((CGFloat)_frameCount) * 1000 / delta;
        _frameCount = 0;
        _lastFrameTime = current;
    } else {
        _frameCount++;
    }
}

#pragma mark AppDelegate
- (void)lockGLActive{
    [self.glActiveLock lock];
}

- (void)unlockGLActive{
    [self.glActiveLock unlock];
}

- (BOOL)tryLockGLActive{
    if (![self.glActiveLock tryLock])
        return NO;

    /*-
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive &&
        [UIApplication sharedApplication].applicationState != UIApplicationStateInactive) {
        [self.appLock unlock];
        return NO;
    }
     */

    if (self.glActivePaused) {
        [self.glActiveLock unlock];
        return NO;
    }
    
    return YES;
}

- (void)toggleGLPaused:(BOOL)paused{
    [self lockGLActive];
    if (!self.glActivePaused && paused) {
        // TODO
    }
    self.glActivePaused = paused;
    [self unlockGLActive];
}

- (void)registerApplicationObservers{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillEnterForegroundNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationDidBecomeActiveNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillResignActiveNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationDidEnterBackgroundNotification];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [_registeredNotifications addObject:UIApplicationWillTerminateNotification];
}

- (void)unregisterApplicationObservers{
    for (NSString *name in _registeredNotifications) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:name
                                                      object:nil];
    }
}

- (void)applicationWillEnterForeground{
    NSLog(@"IJKSDLGLView:applicationWillEnterForeground: %d", (int)[UIApplication sharedApplication].applicationState);
    [self setupGLOnce];
    _applicationState = IJKSDLGLViewApplicationForegroundState;
    [self toggleGLPaused:NO];
}

- (void)applicationDidBecomeActive{
    NSLog(@"IJKSDLGLView:applicationDidBecomeActive: %d", (int)[UIApplication sharedApplication].applicationState);
    [self setupGLOnce];
    [self toggleGLPaused:NO];
}

- (void)applicationWillResignActive{
    NSLog(@"IJKSDLGLView:applicationWillResignActive: %d", (int)[UIApplication sharedApplication].applicationState);
    [self toggleGLPaused:YES];
    glFinish();
}

- (void)applicationDidEnterBackground{
    NSLog(@"IJKSDLGLView:applicationDidEnterBackground: %d", (int)[UIApplication sharedApplication].applicationState);
    _applicationState = IJKSDLGLViewApplicationBackgroundState;
    [self toggleGLPaused:YES];
    glFinish();
}

- (void)applicationWillTerminate{
    NSLog(@"IJKSDLGLView:applicationWillTerminate: %d", (int)[UIApplication sharedApplication].applicationState);
    [self toggleGLPaused:YES];
}

#pragma mark snapshot

- (UIImage*)snapshot{
    [self lockGLActive];

    UIImage *image = [self snapshotInternal];

    [self unlockGLActive];

    return image;
}

- (UIImage*)snapshotInternal{
    if (isIOS7OrLater()) {
        return [self snapshotInternalOnIOS7AndLater];
    }
    
    return nil;
}

- (UIImage*)snapshotInternalOnIOS7AndLater{
    if (CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        return nil;
    }
    
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
    // Render our snapshot into the image context
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];

    // Grab the image from the context
    UIImage *complexViewImage = UIGraphicsGetImageFromCurrentImageContext();
    // Finish using the context
    UIGraphicsEndImageContext();

    return complexViewImage;
}

- (void)setShouldLockWhileBeingMovedToWindow:(BOOL)shouldLockWhileBeingMovedToWindow{
    _shouldLockWhileBeingMovedToWindow = shouldLockWhileBeingMovedToWindow;
}

#pragma mark - override
- (void)setBackgroundColor:(UIColor *)backgroundColor{
    [super setBackgroundColor:backgroundColor];
    
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    [backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
    
    _clearColor = MTLClearColorMake(red, green, blue, alpha);
}

@end
