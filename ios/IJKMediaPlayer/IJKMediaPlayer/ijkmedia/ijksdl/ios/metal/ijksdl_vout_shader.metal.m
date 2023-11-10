//
//  ijksdl_vout_shader.metal
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/10/25.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include "ijksdl/gles2/internal.h"
#import <Foundation/Foundation.h>

//static const char g_shader[] = IJK_GLES_STRING(
//using namespace metal;
//
//typedef struct {
//    vector_float4 position;
//    vector_float2 textureCoordinate;
//} IJKSDLMetalVertex;
//
//typedef struct {
//    float4 vertexPosition [[ position ]];
//    float2 textureCoor;
//} RasterizerData;
//
//vertex RasterizerData vertexShader(uint vertexId [[ vertex_id ]],
//    constant IJKSDLMetalVertex *vertexArray [[ buffer(0) ]]) {
//    RasterizerData out;
//    out.vertexPosition = vertexArray[vertexId].position;
//    out.textureCoor = vertexArray[vertexId].textureCoordinate;
//    return out;
//}
//
//fragment float4 fragmentShader(RasterizerData input [[ stage_in ]],
//                               texture2d <float> yTexture [[ texture(0) ]],
//                               texture2d <float> uTexture [[ texture(1) ]],
//                               texture2d <float> vTexture [[ texture(2) ]]) {
//    constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
//    float4 yColor = yTexture.sample(textureSampler, input.textureCoor);
//    float4 uColor = uTexture.sample(textureSampler, input.textureCoor);
//    float4 vColor = vTexture.sample(textureSampler, input.textureCoor);
//
//    float3 yuv_l;
//    float3 yuv_h;
//    float3 yuv;
//    float3 rgb;
//
//    yuv_l.x = yColor.r;
//    yuv_h.x = yColor.g;
//    yuv_l.y = uColor.r;
//    yuv_h.y = uColor.g;
//    yuv_l.z = vColor.r;
//    yuv_h.z = vColor.g;
//
//    float3x3 um3_ColorConversion = float3x3(
//        1.164384,   1.164384,   1.164384,
//        0.0,       -0.187326,   2.14177,
//        1.67867,   -0.65042,    0.0
//    );
//
//    yuv = (yuv_l * 255.0 + yuv_h * 255.0 * 256.0) / (1023.0) - float3(16.0 / 255.0, 0.5, 0.5);
//    rgb = um3_ColorConversion * yuv;
//
//    return float4(rgb, 1.f);
//}
//
//
//);


static const char g_shader[] = IJK_GLES_STRING(
using namespace metal;
                                               
typedef struct {
    vector_float4 position;
    vector_float2 textureCoordinate;
} IJKSDLMetalVertex;

typedef struct {
    float4 vertexPosition [[ position ]];
    float2 textureCoor;
} RasterizerData;

vertex RasterizerData vertexShader(uint vertexId [[ vertex_id ]],
    constant IJKSDLMetalVertex *vertexArray [[ buffer(0) ]]) {
    RasterizerData out;
    out.vertexPosition = vertexArray[vertexId].position;
    out.textureCoor = vertexArray[vertexId].textureCoordinate;
    return out;
}

fragment float4 fragmentShader(RasterizerData input [[ stage_in ]],
                                texture2d <half> yTexture [[ texture(0) ]],
                                texture2d <half> uTexture [[ texture(1) ]],
                                texture2d <half> vTexture [[ texture(2) ]]) {
    constexpr sampler textureSampler (mag_filter::nearest, min_filter::nearest);
    half4 yColor = yTexture.sample(textureSampler, input.textureCoor);
    half4 uColor = uTexture.sample(textureSampler, input.textureCoor);
    half4 vColor = vTexture.sample(textureSampler, input.textureCoor);
    
    float3 rgb;

                                    
    uint3 yuv_l;
    uint3 yuv_h;
                                    
    yuv_l.x = yColor.r;
    yuv_h.x = yColor.g;
    yuv_l.y = uColor.r;
    yuv_h.y = uColor.g;
    yuv_l.z = vColor.r;
    yuv_h.z = vColor.g;
   
    uint y = yuv_h.x * 256 + yuv_l.x;
    uint u = yuv_h.y * 256 + yuv_l.y;
    uint v = yuv_h.z * 256 + yuv_l.z;
    
    float r = float(y - 64) * 1.164384                             - float(v - 512) * -1.67867;
    float g = float(y - 64) * 1.164384 - float(u - 512) * 0.187326 - float(v - 512) * 0.65042;
    float b = float(y - 64) * 1.164384 - float(u - 512) * -2.14177;
    
    rgb.r = r;
    rgb.g = g;
    rgb.b = b;
                                    
    
    uint normalize = 1;
    if (normalize == 1) {
        rgb.r = r / 1024.0;
        rgb.g = g / 1024.0;
        rgb.b = b / 1024.0;
    }
                                    rgb.r = 87;
                                    rgb.g = 0.5;
                                    rgb.b = 0.5;
    return float4(rgb, 1.f);
}


                                    
);

NSString *metalSourceIncludeHeaders(NSArray <NSString *> *includes){
    if(includes.count == 0) return @"";
    NSMutableString *statements = [NSMutableString string];
    
    [includes enumerateObjectsUsingBlock:^(NSString * _Nonnull include, NSUInteger idx, BOOL * _Nonnull stop) {
        [statements appendString:@"#include <"];
        [statements appendString:include];
        [statements appendString:@">\n"];
    }];

    return [statements copy];
}

NSString *metalSourceImportHeaders(NSArray <NSString *> *imports){
    if(imports.count == 0) return @"";
    NSMutableString *statements = [NSMutableString string];
    
    [imports enumerateObjectsUsingBlock:^(NSString * _Nonnull headerFileName, NSUInteger idx, BOOL * _Nonnull stop) {
        [statements appendString:@"#import "];
        [statements appendString:@"\""];
        [statements appendString:headerFileName];
        [statements appendString:@"\""];
        [statements appendString:@" \n"];
    }];

    return [statements copy];
}


NSString* IJK_METAL_SHADER_STRING(){
    NSString *includes = metalSourceIncludeHeaders(@[@"metal_stdlib", @"simd/simd.h"]);
//    NSString *imports  = metalSourceImportHeaders(@[@"ijksdl_vout_shader.h"]);
    return [NSString stringWithFormat:@"%@\n%s", includes, g_shader];
}






