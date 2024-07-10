//
//  IJKSDLMetalRender.m
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/25.
//  Copyright © 2023 bilibili. All rights reserved.
//

#import "IJKSDLMetalRender.h"
#import "IJKMediaPlayback.h"
#import "IJKSDLMetalView.h"
#import <AVFoundation/AVFoundation.h>
#import "ijksdl_vout_shader.h"
#import "hdrvivid_process.h"
#include "ijksdl_vout_overlay_ffmpeg.h"


@import simd;
@import MetalKit;

#define _CFToString(obj) ((__bridge NSString *)obj)


@interface IJKSDLMetalRender()

@property (nonatomic, weak) IJKSDLMetalView *mtkView;

@property (nonatomic, weak) CAMetalLayer *mtkLayer;

@property (nonatomic, weak) id <MTLDevice> device;

@property (nonatomic, strong) id <MTLRenderPipelineState> pipelineState;

@property (nonatomic, strong) id<MTLComputePipelineState> computePipelineState;

@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;

@property (nonatomic, strong) id <MTLBuffer> vertices;

@property (nonatomic, assign) NSUInteger numVertices;

@property (nonatomic, strong) id <MTLTexture> texture;

@property (nonatomic, assign) vector_uint2 viewportSize;

@property (nonatomic, assign) MTLClearColor clearColor;

@property (nonatomic, assign) BOOL valid;

@property (nonatomic, assign) CVPixelBufferPoolRef pixelBufferPool;

@property (nonatomic, assign) CVMetalTextureCacheRef metalTextureCache;

// sizeof(IJKHDRVividMetadata)
@property (nonatomic, strong) id <MTLBuffer> vividMetaDataBuffer;

// sizeof(IJKHDRVividCurve);
@property (nonatomic, strong) id <MTLBuffer> vividCurveBuffer;

// sizeof(IJKHDRVividCurve);
@property (nonatomic, strong) id <MTLBuffer> renderConfigBuffer;

@property (nonatomic, strong) NSLock *dsipalyLock;


@end

@implementation IJKSDLMetalRender{
    float _curHeadroom;
    float _maxHeadroom;
    // 计算内核调度参数
    MTLSize _threadgroupSize;
    MTLSize _threadgroupCount;
}

+ (instancetype)rendererWithOverlay:(SDL_VoutOverlay *)overlay metalView:(IJKSDLMetalView *)metalView{
    IJKSDLMetalRender *render = [[self alloc] initWithMetalKitView:metalView];
    [render setupMetalEnv];
    return render;
}

- (instancetype)initWithMetalKitView:(IJKSDLMetalView *)mtkView{
    if(self = [super init]){
        self.mtkView = mtkView;
        self.dsipalyLock = [[NSLock alloc] init];
    }
    return self;
}

#pragma mark - public
- (void)setRenderingResizingMode:(IJKSDLMetalRenderingResizingMode)renderingResizingMode{
    _renderingResizingMode = renderingResizingMode;
}

- (BOOL)isVaild{
    return _valid;
}

#pragma mark - metal

- (void)setupMetalEnv{
    if(_valid){
        return;
    }
    
    @synchronized (self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            do {
                if(![self setupMTKView]) break;
                if(![self setupCommandQueue]) break;
                if(![self setupTextureCache]) break;
                if(![self setupPineline]) break;
                _valid = YES;
            } while (0);
        });
       
    }
}

- (BOOL)setupMTKView{
    if(_mtkView == nil){
        return NO;
    }
    
    self.mtkView.delegate = self;
    self.mtkView.device = MTLCreateSystemDefaultDevice();
    self.device = self.mtkView.device;
    self.mtkLayer = (CAMetalLayer *)self.mtkView.layer;
    
    self.viewportSize = (vector_uint2){
        self.mtkView.drawableSize.width,
        self.mtkView.drawableSize.height
    };
    
    self.EDR = YES;
    
    if (@available(iOS 16.0, *)) {
        if(self.EDR){
            self.mtkLayer.wantsExtendedDynamicRangeContent = YES;
            self.mtkLayer.pixelFormat = MTLPixelFormatRGBA16Float;
            // self.mtkLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearSRGB);
            self.mtkLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020_sRGBGamma);
            
            _curHeadroom = UIScreen.mainScreen.currentEDRHeadroom;
            _maxHeadroom = UIScreen.mainScreen.potentialEDRHeadroom;
            
            self.mtkLayer.EDRMetadata = [CAEDRMetadata HLGMetadata];
        }else{
            self.EDR = NO;
        }
    }
    
    if(!self.EDR){
        _curHeadroom = 1;
        _maxHeadroom = 1;
        self.mtkLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
        self.mtkLayer.pixelFormat = MTLPixelFormatRGBA16Float;
    }
    
    return YES;
}

- (BOOL)setupCommandQueue{
    self.commandQueue = [self.device newCommandQueue];
    return YES;
}


- (BOOL)setupPineline{
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
   
    NSError *error;
    
    NSString *source = IJK_METAL_SHADER_STRING();
    MTLCompileOptions *options = [[MTLCompileOptions alloc] init];
//    id <MTLLibrary> library = [self.device newLibraryWithSource:source options:options error:&error];
    
    id <MTLLibrary> library = [_device newDefaultLibrary];
    if(error){
        NSLog(@"Failed to compile shader: %@", error);
        return NO;
    }
    
    id<MTLFunction> kernelFunction = [library newFunctionWithName:@"initCUVAParams"];
    // 创建计算管道状态
    _computePipelineState = [self.device newComputePipelineStateWithFunction:kernelFunction
                                                                   error:&error];
    if(!_computePipelineState){
        NSLog(@"Failed to create compute pipeline state, error %@", error);
        return NO;
    }
    
    _threadgroupSize = MTLSizeMake(1, 1, 1);
    _threadgroupCount.width  = 1;
    _threadgroupCount.height = 1;
    _threadgroupCount.depth = 1;
    
    // 着色器
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertexShader"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    
    if(_pipelineState == nil || error){
        return NO;
    }
    
    // IJKHDRVividMetadata
    _vividMetaDataBuffer = [self.device newBufferWithLength:sizeof(IJKHDRVividMetadata) options:MTLResourceStorageModeShared];
    
    // IJKHDRVividCurve
    _vividCurveBuffer = [self.device newBufferWithLength:sizeof(IJKHDRVividCurve) options:MTLResourceStorageModeShared];
    
    return YES;
}



- (BOOL)setupTextureCache{
    CVReturn ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, self.device, NULL, &_metalTextureCache);
    if(ret != kCVReturnSuccess){
        return NO;
    };
    
    return YES;
}


#pragma mark - PixelBuffer
- (BOOL)setupCVPixelBufferPool:(SDL_VoutOverlay *)overlay{
    if(!_pixelBufferPool) {
        NSMutableDictionary *pixelBufferAttributes = [[NSMutableDictionary alloc] init];
//        if(frame->color_range == AVCOL_RANGE_MPEG) {
//            pixelBufferAttributes[_CFToString(kCVPixelBufferPixelFormatTypeKey)] = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
//        } else {
//            pixelBufferAttributes[_CFToString(kCVPixelBufferPixelFormatTypeKey)] = @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
//        }
        
        pixelBufferAttributes[_CFToString(kCVPixelBufferPixelFormatTypeKey)] = @(kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange);
        
    
        pixelBufferAttributes[_CFToString(kCVPixelBufferMetalCompatibilityKey)] = @(TRUE);
        pixelBufferAttributes[_CFToString(kCVPixelBufferWidthKey)] = @(overlay->w);
        pixelBufferAttributes[_CFToString(kCVPixelBufferHeightKey)] = @(overlay->h);
        /// bytes per row(alignment)
        pixelBufferAttributes[_CFToString(kCVPixelBufferBytesPerRowAlignmentKey)] = @(overlay->pitches[0]);
//        pixelBufferAttributes[_CFToString(kCVPixelBufferIOSurfacePropertiesKey)] = @{};
        CVReturn cvRet = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                NULL,
                                (__bridge  CFDictionaryRef)pixelBufferAttributes,
                                &(_pixelBufferPool));
        if(cvRet != kCVReturnSuccess) {
            NSLog(@"create cv buffer pool failed: %d", cvRet);
            return NO;
        }
    }
    return YES;
}


#pragma mark - MTKViewDelegate
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size{
    self.viewportSize = (vector_uint2){
        size.width,
        size.height
    };
}

- (void)drawInMTKView:(nonnull MTKView *)view{
    
}

#pragma mark - public
- (void)requestRenderEnvironment{
    
}

//overlay_format = SDL_FCC_I444P10LE;
//overlay_format = SDL_FCC_I420P10LE;

- (BOOL)display:(SDL_VoutOverlay *)overlay{
    if(!_valid) return NO;
    
    [self.dsipalyLock lock];
    
    id <MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    // 渲染
    MTLRenderPassDescriptor *passDescriptor = _mtkView.currentRenderPassDescriptor;
    if (!passDescriptor) {
        [commandBuffer commit];
        [self.dsipalyLock unlock];
        return NO;
    }

    IJKHDRVividRenderConfig renderConfig;
    memset(&renderConfig, 0, sizeof(IJKHDRVividRenderConfig));

    IJKHDRVividMetadata *metaData = overlay->metaData;

    if(metaData){
        renderConfig.metadataFlag = YES;
        if(overlay->vividCure){
            renderConfig.cureFlag = YES;
        } else {
            renderConfig.calcCureInGPU = YES;
        }
    }
        
    renderConfig.processMode = _EDR ?IJKMetalPostprocessHDR :IJKMetalPostprocessSDR;
    renderConfig.maxHeadRoom = _maxHeadroom;
    renderConfig.currentHeadRoom = _curHeadroom;
    
    switch (overlay->format) {
        case SDL_FCC_I444P10LE:
            renderConfig.pixelFormatType = IJKMetalPixelFormatTypeYUV444P10LE;
            break;
        case SDL_FCC_I420P10LE:
            renderConfig.pixelFormatType = IJKMetalPixelFormatTypeYUV420P10LE;
            break;
        case SDL_FCC_VIDEOTOOLBOX:
            renderConfig.pixelFormatType = IJKMetalPixelFormatTypeCVPixelBuffer;
            break;
        default:
            renderConfig.pixelFormatType = IJKMetalPixelFormatTypeUnknow;
            break;
    }
    

    if(renderConfig.metadataFlag){
        if(_EDR){
            renderConfig.GPUProcessFun = IJKMetalGPUProcessPQHDR;
        }else{
            renderConfig.GPUProcessFun = IJKMetalGPUProcessPQSDR;
        }
    }else{
        renderConfig.GPUProcessFun = IJKMetalGPUProcessHLGSDR;
    }
    
    // 配置Buffer
    _renderConfigBuffer = [_device newBufferWithBytes:&renderConfig length:sizeof(IJKHDRVividRenderConfig) options:MTLResourceStorageModeShared];
    
    if(renderConfig.calcCureInGPU){
        // 计算
        //创建一个命令编码器
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        //创建一个命令编码器
        [computeEncoder setComputePipelineState:_computePipelineState];
        //设置输入buffer

        ((IJKHDRVividMetadata *)overlay->metaData)->_max_display_luminance = 625.f;
        ((IJKHDRVividMetadata *)overlay->metaData)->_masterDisplay = PQinverse(625.f / 10000.0);
        
        _vividMetaDataBuffer = [_device newBufferWithBytes:overlay->metaData length:sizeof(IJKHDRVividMetadata) options:MTLResourceStorageModeShared];
        _vividCurveBuffer = [_device newBufferWithLength:sizeof(IJKHDRVividCurve) options:MTLResourceStorageModeShared];
        [computeEncoder setBuffer:_vividMetaDataBuffer offset:0 atIndex:0];
        [computeEncoder setBuffer:_vividCurveBuffer offset:0 atIndex:1];
        [computeEncoder setBuffer:_renderConfigBuffer offset:0 atIndex:2];

        //将计算函数调度输入为线程组大小的倍数
        [computeEncoder dispatchThreadgroups:_threadgroupCount
                       threadsPerThreadgroup:_threadgroupSize];
        //结束编码
        [computeEncoder endEncoding];
        
    }
    
    if(renderConfig.metadataFlag && renderConfig.cureFlag){
        _vividMetaDataBuffer = [_device newBufferWithBytes:overlay->metaData length:sizeof(IJKHDRVividMetadata) options:MTLResourceStorageModeShared];
        _vividCurveBuffer = [_device newBufferWithBytes:overlay->vividCure length:sizeof(IJKHDRVividCurve) options:MTLResourceStorageModeShared];
     
    }
    
    // ClearColor
    passDescriptor.colorAttachments[0].clearColor = _mtkView->_clearColor;
    
    static id<MTLTexture> Y_MTL_Texture = nil, U_MTL_Texture = nil, V_MTL_Texture = nil;
    if (overlay->format == SDL_FCC_I444P10LE) {
        if(Y_MTL_Texture == nil || Y_MTL_Texture.width != overlay->w || Y_MTL_Texture.height != overlay->h){
            MTLTextureDescriptor *Y_textureDesc = [[MTLTextureDescriptor alloc] init];
            Y_textureDesc.pixelFormat = MTLPixelFormatR16Unorm;
            Y_textureDesc.width = overlay->w;
            Y_textureDesc.height = overlay->h;
            Y_MTL_Texture = [_device newTextureWithDescriptor:Y_textureDesc];
        }
        
        MTLRegion Y_region = {
            {0, 0, 0},
            {overlay->pitches[0]/2, overlay->h, 1}
        };
        [Y_MTL_Texture replaceRegion:Y_region mipmapLevel:0 withBytes:overlay->pixels[0] bytesPerRow:overlay->pitches[0]];
        
        
        if(U_MTL_Texture == nil || U_MTL_Texture.width != overlay->w || U_MTL_Texture.height != overlay->h){
            MTLTextureDescriptor *U_textureDesc = [[MTLTextureDescriptor alloc] init];
            U_textureDesc.pixelFormat = MTLPixelFormatR16Unorm;
            U_textureDesc.width = overlay->w;
            U_textureDesc.height = overlay->h;
            U_MTL_Texture = [_device newTextureWithDescriptor:U_textureDesc];
        }
        
        MTLRegion U_region = {
            {0, 0, 0},
            {overlay->pitches[1]/2, overlay->h, 1}
        };
        [U_MTL_Texture replaceRegion:U_region mipmapLevel:0 withBytes:overlay->pixels[1] bytesPerRow:overlay->pitches[1]];
        
        
        if(V_MTL_Texture == nil || V_MTL_Texture.width != overlay->w || V_MTL_Texture.height !=  overlay->h){
            MTLTextureDescriptor *V_textureDesc = [[MTLTextureDescriptor alloc] init];
            V_textureDesc.pixelFormat = MTLPixelFormatR16Unorm;
            V_textureDesc.width = overlay->w;
            V_textureDesc.height = overlay->h;
            V_MTL_Texture = [_device newTextureWithDescriptor:V_textureDesc];
        }
        
        MTLRegion V_region = {
            {0, 0, 0},
            {overlay->pitches[2]/2, overlay->h, 1}
        };
        [V_MTL_Texture replaceRegion:V_region mipmapLevel:0 withBytes:overlay->pixels[2] bytesPerRow:overlay->pitches[2]];
    }else if(overlay->format == SDL_FCC_I420P10LE){
        if(Y_MTL_Texture == nil || Y_MTL_Texture.width != overlay->w || Y_MTL_Texture.height != overlay->h){
            MTLTextureDescriptor *Y_textureDesc = [[MTLTextureDescriptor alloc] init];
            Y_textureDesc.pixelFormat = MTLPixelFormatR16Unorm;
            Y_textureDesc.width = overlay->w;
            Y_textureDesc.height = overlay->h;
            Y_MTL_Texture = [_device newTextureWithDescriptor:Y_textureDesc];
        }
        
        MTLRegion Y_region = {
            {0, 0, 0},
            {overlay->pitches[0]/2, overlay->h, 1}
        };
        [Y_MTL_Texture replaceRegion:Y_region mipmapLevel:0 withBytes:overlay->pixels[0] bytesPerRow:overlay->pitches[0]];
        
    
        if(U_MTL_Texture == nil || U_MTL_Texture.width != overlay->w/2 || U_MTL_Texture.height != overlay->h/2){
            MTLTextureDescriptor *U_textureDesc = [[MTLTextureDescriptor alloc] init];
            U_textureDesc.pixelFormat = MTLPixelFormatRG16Unorm;
            U_textureDesc.width = overlay->w/2;
            U_textureDesc.height = overlay->h/2;
            U_MTL_Texture = [_device newTextureWithDescriptor:U_textureDesc];
        }
        
        MTLRegion U_region = {
            {0, 0, 0},
            {overlay->pitches[1]/2, overlay->h/2, 1}
        };
        [U_MTL_Texture replaceRegion:U_region mipmapLevel:0 withBytes:overlay->pixels[1] bytesPerRow:overlay->pitches[1]];
        
        
        if(V_MTL_Texture == nil || V_MTL_Texture.width != overlay->w/2 || V_MTL_Texture.height !=  overlay->h/2){
            MTLTextureDescriptor *V_textureDesc = [[MTLTextureDescriptor alloc] init];
            V_textureDesc.pixelFormat = MTLPixelFormatR16Unorm;
            V_textureDesc.width = overlay->w/2;
            V_textureDesc.height = overlay->h/2;
            V_MTL_Texture = [_device newTextureWithDescriptor:V_textureDesc];
        }
        
        MTLRegion V_region = {
            {0, 0, 0},
            {overlay->pitches[2]/2, overlay->h/2, 1}
        };
        [V_MTL_Texture replaceRegion:V_region mipmapLevel:0 withBytes:overlay->pixels[2] bytesPerRow:overlay->pitches[2]];
    }else if(overlay->format == SDL_FCC_VIDEOTOOLBOX){
        AVFrame *videoFrame = overlay->func_get_linked_frame(overlay);
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)videoFrame->data[3];
        CVMetalTextureRef metalTexture = NULL;
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        size_t count = CVPixelBufferGetPlaneCount(pixelBuffer);
        Boolean isPlanar = CVPixelBufferIsPlanar(pixelBuffer);
        

        if (count != 2) {
            NSLog(@"error Planar cout not 2: t[%lu]", count);
            return NO;
        }
        
        size_t y_width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t y_height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        
        if(Y_MTL_Texture == nil || Y_MTL_Texture.width != y_width || Y_MTL_Texture.height != y_height){
            MTLTextureDescriptor *Y_textureDesc = [[MTLTextureDescriptor alloc] init];
            Y_textureDesc.pixelFormat = MTLPixelFormatR16Unorm;
            Y_textureDesc.width = y_width;
            Y_textureDesc.height = y_height;
            Y_MTL_Texture = [_device newTextureWithDescriptor:Y_textureDesc];
        }
        
        MTLRegion Y_region = {
            {0, 0, 0},
            {y_width, y_height, 1}
        };
        
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        
        [Y_MTL_Texture replaceRegion:Y_region
                         mipmapLevel:0
                           withBytes:CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
                         bytesPerRow:CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)];
        
        
        size_t uv_width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t uv_height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        
        if(U_MTL_Texture == nil || U_MTL_Texture.width != uv_width || U_MTL_Texture.height != uv_height){
            MTLTextureDescriptor *U_textureDesc = [[MTLTextureDescriptor alloc] init];
            U_textureDesc.pixelFormat = MTLPixelFormatRG16Unorm;
            U_textureDesc.width = uv_width;
            U_textureDesc.height = uv_height;
            U_MTL_Texture = [_device newTextureWithDescriptor:U_textureDesc];
        }
        
        MTLRegion U_region = {
            {0, 0, 0},
            {uv_width , uv_height, 1}
        };
        
        
        [U_MTL_Texture replaceRegion:U_region
                         mipmapLevel:0
                           withBytes:CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
                         bytesPerRow:CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)];
        
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

        
    
//
//        CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _metalTextureCache, pixelBuffer, NULL, MTLPixelFormatRGBA16Uint, width, height, 0, &metalTexture);
        
//        CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _metalTextureCache, pixelBuffer, NULL, MTLPixelFormatRGBA16Uint, width, height, 0, &metalTexture);
//        
//
//        if (ret != kCVReturnSuccess) {
//            return NO;
//        }
//        FULL_MTL_Texture = nil;
//        FULL_MTL_Texture = CVMetalTextureGetTexture(metalTexture);
//        
//        CFRelease(metalTexture);
//
//        if (FULL_MTL_Texture == nil) {
//            CVMetalTextureCacheFlush(_metalTextureCache, 0);
//            return NO;
//        }
        
      
        
    }else{
        NSLog(@"无法播放");
        return NO;
    }
    
    [self setupVertex:passDescriptor width:overlay->w hight:overlay->h];
    
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    [renderEncoder setViewport:(MTLViewport){0, 0, self.viewportSize.x, self.viewportSize.y, -1, 1}];
    // 映射.metal文件的方法
    [renderEncoder setRenderPipelineState:self.pipelineState];
    // 设置顶点数据
    [renderEncoder setVertexBuffer:self.vertices offset:0 atIndex:0];
        
    // 设置纹理数据
    [renderEncoder setFragmentTexture:Y_MTL_Texture atIndex:0];
    
    [renderEncoder setFragmentTexture:U_MTL_Texture atIndex:1];
    
    [renderEncoder setFragmentTexture:V_MTL_Texture atIndex:2];
        
    [renderEncoder setFragmentBuffer:_vividMetaDataBuffer offset:0 atIndex:0];
    
    [renderEncoder setFragmentBuffer:_vividCurveBuffer offset:0 atIndex:1];
    
    [renderEncoder setFragmentBuffer:_renderConfigBuffer offset:0 atIndex:2];

    // 开始绘制
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:self.numVertices];
    // 结束渲染
    [renderEncoder endEncoding];
    
//    __weak __typeof(self)weakSelf = self;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
//        [Y_MTL_Texture setPurgeableState:MTLPurgeableStateEmpty];
//        [U_MTL_Texture setPurgeableState:MTLPurgeableStateEmpty];
//        [V_MTL_Texture setPurgeableState:MTLPurgeableStateEmpty];
         
        
        [self.dsipalyLock unlock];
    }];
    
    // 提交
    [commandBuffer presentDrawable:_mtkView.currentDrawable];
    [commandBuffer commit];
    
    return YES;
}


- (void)setupVertex:(MTLRenderPassDescriptor *)renderPassDescriptor width:(float)width hight:(float)hight {
    if (self.vertices) {
        return;
    }
    float heightScaling = 1.0;
    float widthScaling = 1.0;
    CGSize drawableSize = CGSizeMake(renderPassDescriptor.colorAttachments[0].texture.width, renderPassDescriptor.colorAttachments[0].texture.height);
    CGRect bounds = CGRectMake(0, 0, drawableSize.width, drawableSize.height);
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(width, hight), bounds);
    
    
    switch (_renderingResizingMode) {
        case IJKSDLMetalRenderingResizingModeScale: {
            widthScaling = 1.0;
            heightScaling = 1.0;
        };
            break;
        case IJKSDLMetalRenderingResizingModeAspect:
        {
            widthScaling = insetRect.size.width / drawableSize.width;
            heightScaling = insetRect.size.height / drawableSize.height;
        };
            break;
        case IJKSDLMetalRenderingResizingModeAspectFill:
        {
            widthScaling = drawableSize.height / insetRect.size.height;
            heightScaling = drawableSize.width / insetRect.size.width;
        };
            break;
    }
    
    IJKSDLMetalVertex vertices[] = {
        // 顶点坐标 x, y, z, w  --- 纹理坐标 x, y
        { {-widthScaling,  heightScaling, 0.0, 1.0}, {0.0, 0.0} },
        { { widthScaling,  heightScaling, 0.0, 1.0}, {1.0, 0.0} },
        { {-widthScaling, -heightScaling, 0.0, 1.0}, {0.0, 1.0} },
        { { widthScaling, -heightScaling, 0.0, 1.0}, {1.0, 1.0} },
    };
        
    self.vertices = [_device newBufferWithBytes:vertices length:sizeof(vertices) options:MTLResourceStorageModeShared];
    self.numVertices = sizeof(vertices) / sizeof(IJKSDLMetalVertex);
}

@end
