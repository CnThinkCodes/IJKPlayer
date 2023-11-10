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

static inline double dMin(double a, double b) {
    return ((a) > (b)) ? (b) : (a);
}

static inline double dMax(double a, double b) {
    return ((a) > (b)) ? (a) : (b);
}

static inline double DClip(double val, double low, double high)
{
    val = dMax(val, low);
    val = dMin(val, high);
    return val;
}
static inline double dClip(double val, double low, double high)
{
    val = dMax(val, low);
    val = dMin(val, high);
    return val;
}


static inline double PQforward(double value)
{
    double a1 = (2610.0) / (4096.0 * 4.0);
    double a2 = (2523.0 * 128.0) / 4096.0;
    double b1 = (3424.0) / 4096.0;
    double b2 = (2413.0 * 32.0) / 4096.0;
    double b3 = (2392.0 * 32.0) / 4096.0;
    value = dClip(value, 0, 1.0);
    double tempValue = pow(value, (1.0 / a2));
    return (pow(dMax(0.0, (tempValue - b1)) / (b2 - b3 * tempValue), (1.0 / a1)));
}
static inline double PQinverse(double value)
{
    double a1 = (2610.0) / (4096.0 * 4.0);
    double a2 = (2523.0 * 128.0) / 4096.0;
    double b1 = (3424.0) / 4096.0;
    double b2 = (2413.0 * 32.0) / 4096.0;
    double b3 = (2392.0 * 32.0) / 4096.0;
    value = dClip(value, 0, 1.0);
    double tempValue = pow(value, a1);
    return (float)(pow(((b2 * (tempValue)+b1) / (1.0 + b3 * (tempValue))), a2));
}



int initHDRVividMetadata(AVDynamicHDRVivid* sideMetadata, IJKHDRVividMetadata *vividMetadata);


void InitParams(double max_display_luminance, IJKHDRVividMetadata *metadata, double MasterDisplay, IJKHDRVividCurve* curve, float* GTMcurve2);


void InitCurve(IJKHDRVividCurve* curve);

void calc_curveLUT(double m_maxEtemp_store, double m_maxEtemp, double m_inputMaxEtemp, IJKHDRVividMetadata *metadata, IJKHDRVividCurve* curve, float* GTMcurve22);

double saturation_modify(double Y_PQ, double m_maxEtemp, double m_inputMaxEtemp, double MasterDisplay, IJKHDRVividMetadata* metadata, IJKHDRVividCurve* tone_mapping_param);

double getB(double smCoef, double Y_PQ, double m_inputMaxE, IJKHDRVividMetadata* metadata, IJKHDRVividCurve* tone_mapping_param);

#endif /* hdrvivid_process_h */
