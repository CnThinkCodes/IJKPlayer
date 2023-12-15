//
//  hdrvivid_process.h
//  IJKMediaFramework
//
//  Created by hejianyuan on 2023/11/6.
//  Copyright © 2023 bilibili. All rights reserved.
//

#ifndef hdrvivid_process_h
#define hdrvivid_process_h

#include <stdio.h>
#include "IJKHDRVividDataDefine.h"
#include "libavutil/hdr_dynamic_vivid_metadata.h"

static inline float dMin(float a, float b) {
    return ((a) > (b)) ? (b) : (a);
}

static inline float dMax(float a, float b) {
    return ((a) > (b)) ? (a) : (b);
}

static inline float DClip(float val, float low, float high)
{
    val = dMax(val, low);
    val = dMin(val, high);
    return val;
}
static inline float dClip(float val, float low, float high)
{
    val = dMax(val, low);
    val = dMin(val, high);
    return val;
}


static inline float PQforward(float value)
{
    float a1 = (2610.0) / (4096.0 * 4.0);
    float a2 = (2523.0 * 128.0) / 4096.0;
    float b1 = (3424.0) / 4096.0;
    float b2 = (2413.0 * 32.0) / 4096.0;
    float b3 = (2392.0 * 32.0) / 4096.0;
    value = dClip(value, 0, 1.0);
    float tempValue = pow(value, (1.0 / a2));
    return (pow(dMax(0.0, (tempValue - b1)) / (b2 - b3 * tempValue), (1.0 / a1)));
}

static inline float PQinverse(float value)
{
    float a1 = (2610.0) / (4096.0 * 4.0);
    float a2 = (2523.0 * 128.0) / 4096.0;
    float b1 = (3424.0) / 4096.0;
    float b2 = (2413.0 * 32.0) / 4096.0;
    float b3 = (2392.0 * 32.0) / 4096.0;
    value = dClip(value, 0, 1.0);
    float tempValue = pow(value, a1);
    return (float)(pow(((b2 * (tempValue)+b1) / (1.0 + b3 * (tempValue))), a2));
}



int initHDRVividMetadata(AVDynamicHDRVivid* sideMetadata, IJKHDRVividMetadata *vividMetadata);


void InitParams(float max_display_luminance, IJKHDRVividMetadata *metadata, float MasterDisplay, IJKHDRVividCurve* curve, float* GTMcurve2, IJKMetalProcessMode mode);


void InitCurve(IJKHDRVividCurve* curve);

void calc_curveLUT(float m_maxEtemp_store, float m_maxEtemp, float m_inputMaxEtemp, IJKHDRVividMetadata *metadata, IJKHDRVividCurve* curve, float* GTMcurve22);

float saturation_modify(float Y_PQ, float m_maxEtemp, float m_inputMaxEtemp, float MasterDisplay, IJKHDRVividMetadata* metadata, IJKHDRVividCurve* tone_mapping_param);

float getB(float smCoef, float Y_PQ, float m_inputMaxE, IJKHDRVividMetadata* metadata, IJKHDRVividCurve* tone_mapping_param);

#endif /* hdrvivid_process_h */
