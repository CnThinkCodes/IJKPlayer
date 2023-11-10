//
//  IJKSampleBufferDisplayView.h
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/20.
//  Copyright © 2023 bilibili. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IJKSDLGLViewProtocol.h"
#include "ijksdl/ijksdl_vout.h"

@interface IJKSampleBufferDisplayView : UIView <IJKSDLGLViewProtocol>

- (id)initWithFrame:(CGRect)frame;

- (void)display: (SDL_VoutOverlay *) overlay;

- (UIImage*)snapshot;

@end

