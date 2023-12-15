//
//  IJKHDRVividDataDefine.h
//  IJKMediaPlayer
//
//  Created by hejianyuan on 2023/11/7.
//  Copyright © 2023 bilibili. All rights reserved.
//

#ifndef IJKHDRVividDataDefine_h
#define IJKHDRVividDataDefine_h

#define CURVELEN 512
#define system_start_code_BIT        8
#define minimum_maxrgb_BIT           12
#define average_maxrgb_BIT           12
#define variance_maxrgb_BIT          12
#define maximum_maxrgb_BIT           12
#define tone_mapping_mode_BIT        1
#define tone_mapping_param_num_BIT   1
#define targeted_system_display_BIT  12
#define Base_flag_BIT                1
#define Base_param_m_p_BIT           14
#define Base_param_m_m_BIT           6
#define Base_param_m_a_BIT           10
#define Base_param_m_b_BIT           10
#define Base_param_m_n_BIT           6
#define Base_param_K1_BIT            2
#define Base_param_K2_BIT            2
#define Base_param_K3_BIT            4
#define Base_param_Delta_mode_BIT    3
#define Base_param_Delta_BIT         7
#define P3Spline_flag_BIT            1
#define P3Spline_num_BIT             1
#define P3Spline_TH_mode_BIT         2
#define P3Spline_TH_MB_BIT           8
#define P3Spline_TH_OFFSET_BIT       2
#define P3Spline_TH1_BIT             12
#define P3Spline_TH2_BIT             10
#define P3Spline_TH3_BIT             10
#define P3Spline_Strength_BIT        8
#define color_saturation_BIT         1
#define color_saturation_num_BIT     3
#define color_saturation_gain_BIT    8
#define HDRVIVID_METADATA_BASE_S      13
#define HDRVIVID_METADATA_BASE_B      10

#define SPEC_MIN(a,b) (((a)<(b))?(a):(b))

typedef enum IJKMetalProcessMode{
    IJKMetalPreprocess = 0,
    IJKMetalPostprocessHDR,
    IJKMetalPostprocessSDR
}IJKMetalProcessMode;

typedef enum IJKMetalGPUProcessFun{
    IJKMetalGPUProcessUnknow,
    IJKMetalGPUProcessPQHDR,
    IJKMetalGPUProcessHLGHDR,
    IJKMetalGPUProcessPQSDR,
    IJKMetalGPUProcessHLGSDR,
    IJKMetalGPUProcessStaticHLGHDR
}IJKMetalGPUProcessFun;


typedef struct IJKHDRVividMetadata{
    unsigned int system_start_code;
    unsigned int minimum_maxrgb;
    unsigned int average_maxrgb;
    unsigned int variance_maxrgb;
    unsigned int maximum_maxrgb;
    unsigned int tone_mapping_mode;
    unsigned int tone_mapping_param_num;
    unsigned int targeted_system_display_maximum_luminance[2];
    unsigned int Base_flag[4];
    unsigned int Base_param_m_p[2];
    unsigned int Base_param_m_m[2];
    unsigned int Base_param_m_a[2];
    unsigned int Base_param_m_b[2];
    unsigned int Base_param_m_n[2];
    unsigned int Base_param_K1[2];
    unsigned int Base_param_K2[2];
    unsigned int Base_param_K3[2];
    unsigned int base_param_Delta_mode[2];
    unsigned int base_param_Delta[2];
    unsigned int P3Spline_flag[2];
    unsigned int P3Spline_num[2];
    unsigned int P3Spline_TH_mode[2][4];
    unsigned int P3Spline_TH_MB[2][4];
    unsigned int P3Spline_TH[2][4][3];
    unsigned int P3Spline_Strength[2][4];
    unsigned int color_saturation_mapping_flag;
    unsigned int color_saturation_num;
    unsigned int color_saturation_gain[16];
    
    float _max_display_luminance;
    float _masterDisplay;
}IJKHDRVividMetadata;


typedef struct IJKHDRVividCurve{
    float m_p;
    float m_m;
    float m_a;
    float m_b;
    float m_n;
    float K1;
    float K2;
    float K3;
    unsigned int base_param_Delta_mode;
    int curve_mintiao;
    float TH1, TH2, TH3;
    float md1, mc1, mb1, ma1;
    float md2, mc2, mb2, ma2;
    float DARKcurble_S1;
    float Light_S1;
    float DARKcurble_offset;
    int curve_mintiao_high_area;
    float TH1_HIGH, TH2_HIGH, TH3_HIGH;
    float md1_high, mc1_high, mb1_high, ma1_high;
    float md2_high, mc2_high, mb2_high, ma2_high;
    int high_area_flag;
    float curve_adjust;
    float m_p_T;
    float m_a_T;
    float base_param_Delta;
    float P3Spline_Strength[2];
    float P3Spline_TH_MB[2];
    float P3Spline_TH[16][3];
    unsigned int P3Spline_TH_num;
    unsigned int P3Spline_TH_mode[16];
    
    
    float maxEtemp_store;
    float inputMaxEtemp_store;
    float maxE;
    float inputMaxE;
    float minE;
    float inputMinE;
    
    float maximum_maxrgb_noLine;
    float minimum_maxrgb_noLine;
    float average_maxrgb_noLine;
    float variance_maxrgb_noLine;
    
    float TML;
    float TML_linear;
    float RML;
    float RML_linear;
    
}IJKHDRVividCurve;

typedef struct IJKHDRVividRenderConfig{
    float currentHeadRoom;
    float maxHeadRoom;
    IJKMetalProcessMode processMode;
    int metadataFlag;
    int cureFlag;
    int calcCureInGPU;
    IJKMetalGPUProcessFun GPUProcessFun;
}IJKHDRVividRenderConfig;

#endif /* IJKHDRVividDataDefine_h */
