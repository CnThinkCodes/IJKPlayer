//
//  shader.metal
//  IJKMediaDemo
//
//  Created by hejianyuan on 2023/11/1.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_geometric>
#include <IJKMediaFramework/IJKHDRVividDataDefine.h>

using namespace metal;


#pragma mark - Struct Define

// STRUCT
typedef struct {
    vector_float4 position;
    vector_float2 textureCoordinate;
} IJKSDLMetalVertex;

typedef struct {
    float4 vertexPosition [[ position ]];
    float2 textureCoor;
} IJKMetalRasterizerData;

vertex IJKMetalRasterizerData vertexShader(uint vertexId [[ vertex_id ]],
                                           constant IJKSDLMetalVertex *vertexArray [[ buffer(0) ]]) {
    IJKMetalRasterizerData out;
    out.vertexPosition = vertexArray[vertexId].position;
    out.textureCoor = vertexArray[vertexId].textureCoordinate;
    return out;
}

#pragma mark - Common Function
#define FFMAX(a,b) ((a) > (b) ? (a) : (b))
#define FFMAX3(a,b,c) FFMAX(FFMAX(a,b),c)

float clip(float val, float low, float high){
    val = max(val, low);
    val = min(val, high);
    return val;
}

float3 clip3(float3 val, float low, float high){
    val.x =  clip(val.x, low, high);
    val.y =  clip(val.y, low, high);
    val.z =  clip(val.z, low, high);
    return val;
}

float PQforward(float value){
    float a1 = (2610.0) / (4096.0 * 4.0);
    float a2 = (2523.0 * 128.0) / 4096.0;
    float b1 = (3424.0) / 4096.0;
    float b2 = (2413.0 * 32.0) / 4096.0;
    float b3 = (2392.0 * 32.0) / 4096.0;
    value = clip(value, 0, 1.0);
    float tempValue = pow(value, (1.0 / a2));
    return (pow(max(0.0, (tempValue - b1)) / (b2 - b3 * tempValue), (1.0 / a1)));
}

float PQinverse(float value){
    float a1 = (2610.0) / (4096.0 * 4.0);  // 0.1593
    float a2 = (2523.0 * 128.0) / 4096.0; // 78.8438
    float b1 = (3424.0) / 4096.0; // 0.8359
    float b2 = (2413.0 * 32.0) / 4096.0; // 18.8516
    float b3 = (2392.0 * 32.0) / 4096.0; // 18.6875
    value = clip(value, 0, 1.0);
    float tempValue = pow(value, a1);
    return (float)(pow(((b2 * (tempValue)+b1) / (1.0 + b3 * (tempValue))), a2));
}

float fAbs(float x) {
    return ((x) < 0) ? -(x) : (x);
}

float fSign(float x) {
    return ((x) < 0.0) ? -1.0f : 1.0f;
}

float fRound(float x) {
    return (fSign(x) * floor((fAbs(x) + 0.5f)));
}

float fMin(float a, float b) {
    return ((a) < (b)) ? (a) : (b);
}

float fMax(float a, float b) {
    return ((a) > (b)) ? (a) : (b);
}

float dClip(float x, float low, float high) {
    x = fMax(x, low);
    x = fMin(x, high);
    return x;
}

#pragma mark - Color Space Trans
constant half3 kRec709Luma(.2126f,.7152f,.0722f);
constant float kLuminanceEpsilon = .001f;
float3 RinehardOperator(float3 srcColor, float luminanceScale){
    half3 halfsrcColor = half3(srcColor.r, srcColor.g, srcColor.b);
    float luminance = dot(halfsrcColor, ::kRec709Luma) + kLuminanceEpsilon;
    float targetLuminance = 1.f / (1.f + luminance);
    return srcColor * targetLuminance * luminanceScale;
}


#define TPA_NUM 4
float getBaseCurveParameterAdjust(thread IJKHDRVividCurve *curve){
    float TPA[TPA_NUM][2] = {
        {2.5, 0.99},
        {3.5, 0.879},
        {4.5, 0.777},
        {7.5, 0.54}
    };
    
    int index = 0;
    float M_a_T = TPA[0][1];
    for (int i = 0; i < TPA_NUM; i++){
        if (curve->m_p <= TPA[i][0]){
            index = i;
            break;
        }
    }
    
    if ((index == 0) && (curve->m_p < TPA[0][0])){
        M_a_T = TPA[0][1];
    } else if ((index == 0) && (curve->m_p > TPA[(TPA_NUM - 1)][0])){
        M_a_T = TPA[(TPA_NUM - 1)][1];
    } else{
        float temp1 = curve->m_p - TPA[index - 1][0];
        float temp2 = TPA[index][0] - curve->m_p;
        M_a_T = TPA[index][1] * temp1 + TPA[index - 1][1] * temp2;
        M_a_T /= (temp1 + temp2);
    }
    curve->curve_adjust = 0;
    if (curve->m_a > M_a_T){
        curve->m_a = curve->m_a_T = M_a_T;
        curve->curve_adjust = 1;
        curve->m_b = 0;
    }
    return curve->curve_adjust;
}

void AdjustVividParameter(float m_maxE, float m_inputMaxE, thread IJKHDRVividCurve* curve){
    if (curve->curve_adjust == 0) return;
    if ((curve->m_m < 2.35) || (curve->m_m > 2.45) || (curve->m_n < 0.95) || (curve->m_n > 1.05)){
        return;
    }
    
    if (m_inputMaxE < m_maxE) {
        m_inputMaxE = m_maxE;
    }
    
    float temp1 = m_maxE / m_inputMaxE;
    float max1 = (curve->m_p) * pow(m_inputMaxE, curve->m_n);
    float temp = (((curve->m_p) * (curve->K1) - (curve->K2)) * (pow(m_inputMaxE, curve->m_n)) + (curve->K3));
    if (temp) max1 /= temp;
    max1 = (curve->m_a_T) * pow(max1, curve->m_m) + (curve->m_b);
    float temp2 = max1 / m_inputMaxE;
    float WA = temp1 - temp2;
    if (WA < 0) WA = 0;
    WA /= (1 - temp2);
    
    if (curve->curve_mintiao){
        temp = (1 - (curve->DARKcurble_S1)) * WA;
        curve->DARKcurble_S1 += temp;
        
        float TH1temp = curve->TH1;
        float TH2temp = curve->TH2;
        float TH3temp = curve->TH3;
        temp = (m_inputMaxE - (curve->TH1)) * WA;
        curve->TH1 += temp;
        curve->TH2 = curve->TH1 + TH2temp - TH1temp;
        curve->TH3 = curve->TH2 + TH3temp - TH2temp;
        curve->m_b *= (1 - WA);
    }else{
        
    }
}

float genBaseCurveParameter(device IJKHDRVividMetadata* metadata,
                            float MasterDisplay,
                            float MaxDisplay,
                            float MinDisplay,
                            device IJKHDRVividCurve* curve,
                            thread float *maxE,
                            thread float *inputE,
                            int mode){
    float maximum_maxrgb_noLine = float(metadata->maximum_maxrgb) / 4095.f;
    //float minimum_maxrgb_noLine = float(metadata->minimum_maxrgb) / 4095;
    float average_maxrgb_noLine = float(metadata->average_maxrgb) / 4095.f;
    float variance_maxrgb_noLine = float(metadata->variance_maxrgb) / 4095.f;
    
    float meanVar = average_maxrgb_noLine + variance_maxrgb_noLine / 2;
    curve->m_m = 2.4;
    curve->m_n = 1.0;
    curve->m_b = 0.0;
    curve->K1 = 1.0;
    curve->K2 = 1.0;
    curve->K3 = 1.0;
    //std::cout << "10-1-1 " << std::endl;
    float lowThreshold;
    float highThreshold;
    if (mode == IJKMetalPostprocessSDR){
        lowThreshold = 0.1;
    }else if (mode == IJKMetalPostprocessHDR) {
        lowThreshold = 0.3;
    }
    
    if (average_maxrgb_noLine > 0.6){
        curve->m_p = 3.5;
    } else if (average_maxrgb_noLine > lowThreshold && average_maxrgb_noLine <= 0.6) {
        if (mode == IJKMetalPostprocessSDR){
            curve->m_p = 6.0 + (average_maxrgb_noLine - 0.1) / (0.6 - 0.1) * (3.5 - 6.0);
        }else if (mode == IJKMetalPostprocessHDR){
            curve->m_p = 4.0 + (average_maxrgb_noLine - 0.3) / (0.6 - 0.3) * (3.5 - 4.0);
        }
    }
    else{
        if (mode == IJKMetalPostprocessSDR){
            curve->m_p = 6.0;
        } else if (mode == IJKMetalPostprocessHDR){
            curve->m_p = 4.0;
        }
    }
    
    float MaxDisplaySet = MaxDisplay;
    float MinDisplaySet = MinDisplay;
    float m_maxE = MaxDisplaySet;
    float m_minE = MinDisplaySet;
    
    float m_inputMinE = 0;
    float m_inputMaxE = maximum_maxrgb_noLine;
    m_inputMaxE = 0.8 * meanVar + 0.2 * maximum_maxrgb_noLine;
    
    float ReferfenceDisplay1600 = MasterDisplay;
    
    if (m_inputMaxE > ReferfenceDisplay1600){
        m_inputMaxE = ReferfenceDisplay1600;
    }else if (m_inputMaxE < 0.5081){
        m_inputMaxE = 0.5081;
    }
    
    if (m_inputMaxE < m_maxE){
        m_inputMaxE = m_maxE;
    }
    
    if (mode == IJKMetalPostprocessSDR){
        lowThreshold = 0.67;
        highThreshold = 0.75;
    } else /*(mode == PostprocessHDR)*/ {
        lowThreshold = 0.75;
        highThreshold = 0.9;
    }
    
    if (m_inputMaxE > highThreshold){
        curve->m_p = curve->m_p + 0.6;
    } else if (m_inputMaxE > lowThreshold && m_inputMaxE <= highThreshold){
        if (mode ==     IJKMetalPostprocessSDR){
            curve->m_p = curve->m_p + 0.3 + (m_inputMaxE - 0.67) / (0.75 - 0.67) * (0.6 - 0.3);
        } else if (mode ==     IJKMetalPostprocessHDR){
            curve->m_p = curve->m_p + 0.0 + (m_inputMaxE - 0.75) / (0.9 - 0.75) * (0.6 - 0.0);
        }
    } else {
        if (mode ==     IJKMetalPostprocessSDR){
            curve->m_p = curve->m_p + 0.3;
        }
        else if (mode ==     IJKMetalPostprocessHDR){
            curve->m_p = curve->m_p + 0.0;
        }
    }
    //std::cout << "10-1-3 " << std::endl;
    float input_minE_TM = pow((curve->m_p * m_inputMinE / ((curve->m_p - 1) * m_inputMinE + 1.0)), curve->m_m);
    float input_maxE_TM = pow((curve->m_p * m_inputMaxE / ((curve->m_p - 1) * m_inputMaxE + 1.0)), curve->m_m);
    curve->m_a = (m_maxE - m_minE) / (input_maxE_TM - input_minE_TM);
    curve->m_b = MinDisplaySet;
    //std::cout << "10-1-4 " << std::endl;
    for (int i = 0; i < 2; i++){
        float targeted_system_display = float(metadata->targeted_system_display_maximum_luminance[i]) / ((1 << targeted_system_display_BIT) - 1);
        int HDRSDRTHMetedata = 2080;
        int targetedSystemDisplay = metadata->targeted_system_display_maximum_luminance[i];
        int MaxDisplayMetedata = (int)(MaxDisplay * ((1 << targeted_system_display_BIT) - 1));
        if ((metadata->Base_flag[i] == 0) || ((targetedSystemDisplay != HDRSDRTHMetedata) && (MaxDisplayMetedata == HDRSDRTHMetedata) && metadata->Base_flag[i])
            || ((targetedSystemDisplay == HDRSDRTHMetedata) && (MaxDisplayMetedata != HDRSDRTHMetedata) && metadata->Base_flag[i])){
            continue;
        }
        float targeted_system_display_linear = (float)(10000 * PQforward(targeted_system_display));
        float MaxDisplay_linear = (float)(10000 * PQforward(MaxDisplay));
        float deltai = abs(MaxDisplay_linear - targeted_system_display_linear) / 100;
        deltai = pow(deltai, 0.5);
        curve->base_param_Delta_mode = metadata->base_param_Delta_mode[i];
        
        float param_m_p = curve->m_p;
        float param_m_m = curve->m_m;
        float param_m_n = curve->m_n;
        float param_K1 = curve->K1;
        float param_K2 = curve->K2;
        float param_K3 = curve->K3;
        if (metadata->Base_flag[i]){
            curve->m_p = 10 * float((metadata->Base_param_m_p[i])) / ((1 << Base_param_m_p_BIT) - 1);
            curve->m_m = float((metadata->Base_param_m_m[i])) / (10);
            curve->m_a = float((metadata->Base_param_m_a[i])) / ((1 << Base_param_m_a_BIT) - 1);
            curve->m_b = float((metadata->Base_param_m_b[i])) / (((1 << Base_param_m_b_BIT) - 1) * 4);
            curve->m_n = float((metadata->Base_param_m_n[i])) / (10);
            curve->K1 = float((metadata->Base_param_K1[i]));
            curve->K2 = float((metadata->Base_param_K2[i]));
            curve->K3 = float((metadata->Base_param_K3[i]));
            if (metadata->Base_param_K3[i] == 2) curve->K3 = maximum_maxrgb_noLine;
        }
        if (abs(targeted_system_display_linear - MaxDisplay_linear) <= 1){
            break;
        }
        if ((metadata->base_param_Delta_mode[i] == 0) || (metadata->base_param_Delta_mode[i] == 2) || (metadata->base_param_Delta_mode[i] == 4) || (metadata->base_param_Delta_mode[i] == 6)){
            float deltaDisplay = float((metadata->base_param_Delta[i])) / ((1 << Base_param_Delta_BIT) - 1);
            deltaDisplay = (metadata->base_param_Delta_mode[i] == 2 || metadata->base_param_Delta_mode[i] == 6) ? (-deltaDisplay) : deltaDisplay;
            
            float weight = deltai * deltaDisplay;
            curve->m_p += weight;
            curve->m_p = clip(curve->m_p, 3.0, 7.5);
            curve->m_a *= (MaxDisplay - MinDisplay) / targeted_system_display;
            
            break;
        } else if (metadata->base_param_Delta_mode[i] == 1 || (metadata->base_param_Delta_mode[i] == 5)){
            float deltaDisplay = float((metadata->base_param_Delta[i])) / ((1 << Base_param_Delta_BIT) - 1);
            float weight = deltai * deltaDisplay;
            weight = weight >= 0 ? weight : -weight;
            if (weight > 1) weight = 1;
            float weightp = 1 - weight;
            curve->m_p = weightp * (curve->m_p) + weight * param_m_p;
            curve->m_m = weightp * (curve->m_m) + weight * param_m_m;
            curve->m_n = weightp * (curve->m_n) + weight * param_m_n;
            curve->K1 = weightp * (curve->K1) + weight * param_K1;
            curve->K2 = weightp * (curve->K2) + weight * param_K2;
            curve->K3 = weightp * (curve->K3) + weight * param_K3;
            
            float input_minE_TM = pow((curve->m_p * pow(m_inputMinE, curve->m_n) / ((curve->K1 * curve->m_p - curve->K2) * pow(m_inputMinE, curve->m_n) + curve->K3)), curve->m_m);
            float input_maxE_TM = pow((curve->m_p * pow(m_inputMaxE, curve->m_n) / ((curve->K1 * curve->m_p - curve->K2) * pow(m_inputMaxE, curve->m_n) + curve->K3)), curve->m_m);
            curve->m_a = (m_maxE - m_minE) / (input_maxE_TM - input_minE_TM);
            break;
        }
    }
    *maxE = m_maxE;
    *inputE = m_inputMaxE;
    
    return 1;
}


float low_area_spline(float maximum_maxrgb,
                      float average_maxrgb,
                      float tone_mapping_param_m_p,
                      float tone_mapping_param_m_m,
                      float tone_mapping_param_m_a,
                      float tone_mapping_param_m_b,
                      float tone_mapping_param_m_n,
                      float tone_mapping_param_K1,
                      float tone_mapping_param_K2,
                      float tone_mapping_param_K3,
                      float P3Spline_TH_MB,
                      float P3Spline_TH[3],
                      float P3Spline_Strength,
                      float maxDisplay,
                      thread float* md1g,
                      thread float* mc1g,
                      thread float* mb1g,
                      thread float* ma1g,
                      thread float* md2g,
                      thread float* mc2g,
                      thread float* mb2g,
                      thread float* ma2g,
                      thread float* dark,
                      thread float* DARKcurble_offset,
                      thread int* curve_mintiao,
                      thread float* m_a,
                      unsigned int base_param_Delta_mode,
                      unsigned int Base_flag,
                      int mode,
                      float m_maxE,
                      float m_inputMaxE){
    float threshold1 = 0.0;
    float threshold2 = 0.0;
    float threshold3 = 0.0;
    
    float m_ptemp = tone_mapping_param_m_p;
    float m_mtemp = tone_mapping_param_m_m;
    float m_atemp = tone_mapping_param_m_a;
    float m_btemp = tone_mapping_param_m_b;
    float m_ntemp = tone_mapping_param_m_n;
    float K1temp = tone_mapping_param_K1;
    float K2temp = tone_mapping_param_K2;
    float K3temp = tone_mapping_param_K3;
    
    float s1 = 1.0;
    if (average_maxrgb > 0.6){
        if (mode ==     IJKMetalPostprocessSDR){
            s1 = 0.9;
        } else if (mode == IJKMetalPostprocessHDR){
            threshold1 = 0.1;
            s1 = 0.96;
        }
    } else if (average_maxrgb > 0.3 && average_maxrgb <= 0.6) {
        if (mode ==     IJKMetalPostprocessSDR){
            s1 = 1.0 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.9 - 1.0);
        }else if (mode == IJKMetalPostprocessHDR){
            threshold1 = 0.25 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.1 - 0.25);
            s1 = 1.0 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.96 - 1.0);
        }
    } else{
        if (mode == IJKMetalPostprocessHDR){
            threshold1 = 0.25;
        }
        s1 = 1.0;
    }
    
    if (mode == IJKMetalPostprocessSDR){
        threshold1 = 0.0;
    }
    threshold2 = threshold1 + 0.15;
    threshold3 = threshold2 + (threshold2 - threshold1) / 2.0;
    
    thread IJKHDRVividCurve curvetemp;
    curvetemp.m_p = tone_mapping_param_m_p;
    curvetemp.m_m = tone_mapping_param_m_m;
    curvetemp.m_b = tone_mapping_param_m_b;
    curvetemp.m_a = tone_mapping_param_m_a;
    curvetemp.m_n = tone_mapping_param_m_n;
    curvetemp.K1 = tone_mapping_param_K1;
    curvetemp.K2 = tone_mapping_param_K2;
    curvetemp.K3 = tone_mapping_param_K3;
    if ((base_param_Delta_mode) < 3 && Base_flag == 1){
        getBaseCurveParameterAdjust(&curvetemp);
    }
    curvetemp.TH1 = threshold1;
    curvetemp.TH2 = threshold2;
    curvetemp.TH3 = threshold3;
    curvetemp.DARKcurble_S1 = s1;
    curvetemp.curve_mintiao = 1;
    if ((base_param_Delta_mode) < 3 && Base_flag == 1) {
        AdjustVividParameter(m_maxE, m_inputMaxE, &curvetemp);
    }
    threshold1 = curvetemp.TH1;
    s1 = curvetemp.DARKcurble_S1;
    
    threshold2 = threshold1 + 0.15;
    threshold3 = threshold2 + (threshold2 - threshold1) / 2.0;
    
    float threshold3temp = pow(threshold3, m_ntemp);
    float ValueT3 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    ValueT3 = pow(ValueT3, m_mtemp);
    ValueT3 = m_atemp * ValueT3 + m_btemp;
    
    float threshold3temp1 = pow(threshold3, (m_ntemp - 1));
    float s2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    s2 = pow(s2, m_mtemp + 1);
    s2 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold3temp1 * s2 * (1 / pow(threshold3temp * m_ptemp, 2)));
    
    float a1 = s1 * threshold1 + *DARKcurble_offset;
    float b1 = s1;
    
    float threshold2temp = pow(threshold2, m_ntemp);
    float a2 = (m_ptemp * threshold2temp / ((K1temp * m_ptemp - K2temp) * threshold2temp + K3temp));
    a2 = pow(a2, m_mtemp);
    a2 = m_atemp * a2 + m_btemp;
    
    float h1 = threshold2 - threshold1;
    float h2 = threshold3 - threshold2;
    float y1 = a2;
    
    float y2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    y2 = pow(y2, m_mtemp);
    y2 = m_atemp * y2 + m_btemp;
    
    if (mode == IJKMetalPostprocessHDR)
    {
        if (threshold3 - threshold1)
        {
            a2 = threshold2 * (y2 - a1) / (threshold3 - threshold1) + (threshold3 * a1 - y2 * threshold1) / (threshold3 - threshold1);
        }
        y1 = a2;
    }
    
    float b2 = -(3.0 * a1 * h2 * h2 + 3.0 * a2 * h1 * h1 - 3.0 * h1 * h1 * y2 - 3.0 * h2 * h2 * y1 + h1 * h1 * h2 * s2 + b1 * h1 * h2 * h2) / (2.0 * h2 * (h1 * h1 + h2 * h1));
    float c1 = (3.0 * y1 - 2.0 * b1 * h1 - 3.0 * a1 - b2 * h1) / (h1 * h1);
    float d1 = (h1 * b1 + h1 * b2 + 2 * a1 - 2.0 * y1) / (h1 * h1 * h1);
    float c2 = c1 + 3.0 * d1 * h1;
    float d2 = -(y2 - a2 - h2 * s2 + c1 * h2 * h2 + 3 * d1 * h1 * h2 * h2) / (2 * h2 * h2 * h2);
    
    P3Spline_TH[0] = threshold1;
    P3Spline_TH[1] = threshold2;
    P3Spline_TH[2] = threshold3;
    *md1g = d1, * mc1g = c1, * mb1g = b1, * ma1g = a1;
    *md2g = d2, * mc2g = c2, * mb2g = b2, * ma2g = a2;
    *dark = s1;
    
    *curve_mintiao = 1;
    return *curve_mintiao;
}


float spline_area_spec(float maximum_maxrgb,
                       float average_maxrgb,
                       float tone_mapping_param_m_p,
                       float tone_mapping_param_m_m,
                       float tone_mapping_param_m_a,
                       thread float* tone_mapping_param_m_b,
                       float tone_mapping_param_m_n,
                       float tone_mapping_param_K1,
                       float tone_mapping_param_K2,
                       float tone_mapping_param_K3,
                       float P3Spline_TH_MB,
                       float P3Spline_TH[3],
                       float P3Spline_Strength,
                       float maxDisplay,
                       thread float* md1g,
                       thread float* mc1g,
                       thread float* mb1g,
                       thread float* ma1g,
                       thread float* md2g,
                       thread float* mc2g,
                       thread float* mb2g,
                       thread float* ma2g,
                       thread float* dark,
                       thread float* DARKcurble_offset,
                       thread int* curve_mintiao,
                       unsigned int base_param_Delta_mode)

{
    float threshold1 = 0.0;
    float threshold2 = 0.0;
    float threshold3 = 0.0;
    
    float m_ptemp = tone_mapping_param_m_p;
    float m_mtemp = tone_mapping_param_m_m;
    float m_atemp = tone_mapping_param_m_a;
    float m_btemp = *tone_mapping_param_m_b;
    float m_ntemp = tone_mapping_param_m_n;
    float K1temp = tone_mapping_param_K1;
    float K2temp = tone_mapping_param_K2;
    float K3temp = tone_mapping_param_K3;
    
    float meta_str = P3Spline_Strength;
    float meta_MB = P3Spline_TH_MB;
    float s1 = meta_MB;
    
    threshold1 = P3Spline_TH[0];
    threshold2 = P3Spline_TH[1];
    threshold3 = P3Spline_TH[2];
    
    float threshold3temp = pow(threshold3, m_ntemp);
    float threshold3temp1 = pow(threshold3, (m_ntemp - 1));
    float s2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    s2 = pow(s2, m_mtemp + 1);
    s2 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold3temp1 * s2 * (1 / pow(threshold3temp * m_ptemp, 2)));
    
    float a1 = s1 * threshold1 + *DARKcurble_offset;
    float b1 = s1;
    
    float h1 = threshold2 - threshold1;
    float h2 = threshold3 - threshold2;
    
    float y2 = (m_ptemp * threshold3temp / ((K1temp * m_ptemp - K2temp) * threshold3temp + K3temp));
    y2 = pow(y2, m_mtemp);
    y2 = m_atemp * y2 + m_btemp;
    
    if (y2 > threshold3 && base_param_Delta_mode != 3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 6)
    {
        m_btemp = m_btemp - (y2 - threshold3);
        y2 = threshold3;
        *tone_mapping_param_m_b = m_btemp;
    }
    float a2 = a1 + (y2 - a1) * (threshold2 - threshold1) / (threshold3 - threshold1) + (y2 - a1) * meta_str / 2;
    if (a2 > threshold2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 6)
    {
        a2 = threshold2;
    }
    float y1 = a2;
    
    float b2 = -(3.0 * a1 * h2 * h2 + 3.0 * a2 * h1 * h1 - 3.0 * h1 * h1 * y2 - 3.0 * h2 * h2 * y1 + h1 * h1 * h2 * s2 + b1 * h1 * h2 * h2) / (2.0 * h2 * (h1 * h1 + h2 * h1));
    
    float c1 = (3.0 * y1 - 2.0 * b1 * h1 - 3.0 * a1 - b2 * h1) / (h1 * h1);
    float d1 = (h1 * b1 + h1 * b2 + 2 * a1 - 2.0 * y1) / (h1 * h1 * h1);
    float c2 = c1 + 3.0 * d1 * h1;
    float d2 = -(y2 - a2 - h2 * s2 + c1 * h2 * h2 + 3 * d1 * h1 * h2 * h2) / (2 * h2 * h2 * h2);
    
    P3Spline_TH[0] = threshold1;
    P3Spline_TH[1] = threshold2;
    P3Spline_TH[2] = threshold3;
    *md1g = d1, * mc1g = c1, * mb1g = b1, * ma1g = a1;
    *md2g = d2, * mc2g = c2, * mb2g = b2, * ma2g = a2;
    *dark = s1;
    
    *curve_mintiao = 1;
    return *curve_mintiao;
}


float spline_higharea_spec(float maximum_maxrgb,
                           float average_maxrgb,
                           float tone_mapping_param_m_p,
                           float tone_mapping_param_m_m,
                           float tone_mapping_param_m_a,
                           float tone_mapping_param_m_b,
                           float tone_mapping_param_m_n,
                           float tone_mapping_param_K1,
                           float tone_mapping_param_K2,
                           float tone_mapping_param_K3,
                           int   P3Spline_TH_Mode,
                           float P3Spline_TH_MB,
                           float P3Spline_TH[3],
                           float P3Spline_Strength,
                           float maxDisplay,
                           thread float* md1g,
                           thread float* mc1g,
                           thread float* mb1g,
                           thread float* ma1g,
                           thread float* md2g,
                           thread float* mc2g,
                           thread float* mb2g,
                           thread float* ma2g,
                           thread float* dark,
                           thread int* curve_mintiao_high_area,
                           float Referncedisplay,
                           unsigned int base_param_Delta_mode)
{
    float threshold1 = P3Spline_TH[0];
    float threshold2 = P3Spline_TH[1];
    float threshold3 = P3Spline_TH[2];
    float meta_str = P3Spline_Strength;
    
    float m_ptemp = tone_mapping_param_m_p;
    float m_mtemp = tone_mapping_param_m_m;
    float m_atemp = tone_mapping_param_m_a;
    float m_btemp = tone_mapping_param_m_b;
    float m_ntemp = tone_mapping_param_m_n;
    float K1temp = tone_mapping_param_K1;
    float K2temp = tone_mapping_param_K2;
    float K3temp = tone_mapping_param_K3;
    
    float threshold1temp = pow(threshold1, m_ntemp);
    float threshold1temp1 = pow(threshold1, m_ntemp - 1);
    float s1 = (m_ptemp * threshold1temp / ((K1temp * m_ptemp - K2temp) * threshold1temp + K3temp));
    s1 = pow(s1, m_mtemp + 1);
    s1 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold1temp1 * s1 * (1 / pow(threshold1temp * m_ptemp, 2)));
    
    float y1 = (m_ptemp * threshold1temp / ((K1temp * m_ptemp - K2temp) * threshold1temp + K3temp));
    y1 = pow(y1, m_mtemp);
    y1 = m_atemp * y1 + m_btemp;
    
    float a1 = y1;
    float b1 = s1;
    
    float y2 = maxDisplay;
    if (base_param_Delta_mode != 3) {
        y2 = maxDisplay;
    }
    if (base_param_Delta_mode == 3) {
        y2 = Referncedisplay;
    }
    
    if (P3Spline_TH_Mode == 3)
    {
        float max = pow(threshold3, m_ntemp);
        y2 = (m_ptemp * max / ((K1temp * m_ptemp - K2temp) * max + K3temp));
        y2 = pow(y2, m_mtemp);
        y2 = m_atemp * y2 + m_btemp;
    }
    
    if ((P3Spline_TH_Mode == 1 || P3Spline_TH_Mode == 2) && y2 > threshold3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 6)
    {
        threshold3 = y2;
        threshold2 = threshold1 + (threshold3 - threshold1) / 2.0;
    }
    float h1 = threshold2 - threshold1;
    float h2 = threshold3 - threshold2;
    
    float a2 = y1 + (y2 - y1) * (threshold2 - threshold1) / (threshold3 - threshold1) + (y2 - y1) * meta_str / 2;
    
    if ((P3Spline_TH_Mode == 1 || P3Spline_TH_Mode == 2) && a2 > threshold2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 2 && base_param_Delta_mode != 6) {
        a2 = threshold2;
    }
    
    float s2 = 1.0;
    if ((P3Spline_TH_Mode == 2) || (P3Spline_TH_Mode == 3))
    {
        float threshold1temp = pow(threshold3, m_ntemp);
        float threshold1temp0 = pow(threshold3, m_ntemp - 1);
        s2 = (m_ptemp * threshold1temp / ((K1temp * m_ptemp - K2temp) * threshold1temp + K3temp));
        s2 = pow(s2, m_mtemp + 1);
        s2 = (m_atemp * m_mtemp * m_ptemp * K3temp * m_ntemp * threshold1temp0 * s2 * (1 / pow(threshold1temp * m_ptemp, 2)));
        
        if (P3Spline_TH_Mode == 2)
        {
            s2 = s2 - P3Spline_TH_MB;
        }
    }
    else
    {
        float up_T = (y2 - y1) / (threshold3 - threshold2);
        float mid_T = (y2 - y1) / (threshold3 - threshold1);
        float down_T = (y2 - y1) * 0.1 / (threshold3 - threshold1);
        
        down_T = down_T < s1 ? s1 : down_T;
        up_T = up_T < s1 ? s1 : up_T;
        
        s2 = meta_str >= 0 ? (up_T * meta_str + mid_T * (1 - meta_str)) : (down_T * (-meta_str) + mid_T * (1 + meta_str));
        if (s2 > 1.0) s2 = 1.0;
    }
    
    if (threshold3 == y2 && ((P3Spline_TH_Mode == 1) || (P3Spline_TH_Mode == 2)) && base_param_Delta_mode != 2 && base_param_Delta_mode != 3 && base_param_Delta_mode != 6) {
        s2 = 1.0;
    }
    float b2 = -(3.0 * a1 * h2 * h2 + 3.0 * a2 * h1 * h1 - 3.0 * h1 * h1 * y2 - 3.0 * h2 * h2 * a2 + h1 * h1 * h2 * s2 + b1 * h1 * h2 * h2) / (2.0 * h2 * (h1 * h1 + h2 * h1));
    float c1 = (3.0 * a2 - 2.0 * b1 * h1 - 3.0 * a1 - b2 * h1) / (h1 * h1);
    float d1 = (h1 * b1 + h1 * b2 + 2 * a1 - 2.0 * a2) / (h1 * h1 * h1);
    float c2 = c1 + 3.0 * d1 * h1;
    float d2 = -(y2 - a2 - h2 * s2 + c1 * h2 * h2 + 3 * d1 * h1 * h2 * h2) / (2 * h2 * h2 * h2);
    
    P3Spline_TH[0] = threshold1;
    P3Spline_TH[1] = threshold2;
    P3Spline_TH[2] = threshold3;
    *md1g = d1, * mc1g = c1, * mb1g = b1, * ma1g = a1;
    *md2g = d2, * mc2g = c2, * mb2g = b2, * ma2g = a2;
    *curve_mintiao_high_area = 1;
    
    return *curve_mintiao_high_area;
}



void genCubicSplineParameter(device IJKHDRVividMetadata* metadata,
                             float m_maxE,
                             float m_inputMaxE,
                             device IJKHDRVividCurve* curve,
                             int mode)
{
    float MaxDisplay = m_maxE;
    float maximum_maxrgbtemp = float((metadata->maximum_maxrgb)) / 4095;
    float average_maxrgbtemp = float((metadata->average_maxrgb)) / 4095;
    
    int HDRSDRTHMetedata = 2080;
    int MaxDisplayMetedata = (int)(MaxDisplay * ((1 << targeted_system_display_BIT) - 1));
    int i3spline = -1;
    float Referncedisplay = 0.67658;
    for (int i = 0; i < 2; i++)
    {
        int targetedSystemDisplay = metadata->targeted_system_display_maximum_luminance[i];
        float target = float(metadata->targeted_system_display_maximum_luminance[i]) / ((1 << targeted_system_display_BIT) - 1);
        Referncedisplay = target;
        if (((targetedSystemDisplay == HDRSDRTHMetedata) && (MaxDisplayMetedata == HDRSDRTHMetedata) && metadata->P3Spline_flag[i])
            || ((targetedSystemDisplay != HDRSDRTHMetedata) && (MaxDisplayMetedata != HDRSDRTHMetedata) && metadata->P3Spline_flag[i]))
        {
            i3spline = i;
            break;
        }
    }
    
    int i3splinemode0 = 0;
    if (i3spline >= 0)
    {
        for (int spline_i = 0; spline_i < ((int)metadata->P3Spline_num[i3spline]); spline_i++)
        {
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 0)
            {
                i3splinemode0 = 1;
            }
        }
    }
    if (i3spline < 0 || ((i3spline >= 0) && (i3splinemode0 == 0)))
    {
        float P3Spline_TH_MB = 0;
        float P3Spline_TH[3] = { 0,0,0 };
        float P3Spline_Strength = 0;
        float m_a_T = curve->m_a;
        curve->DARKcurble_offset = 0.0;
        
        thread float md1g = curve->md1;
        thread float mc1g = curve->mc1;
        thread float mb1g = curve->mb1;
        thread float ma1g = curve->ma1;
        thread float md2g = curve->md2;
        thread float mc2g = curve->mc2;
        thread float mb2g = curve->mb2;
        thread float ma2g = curve->ma2;
        thread float dark = curve->DARKcurble_S1;
        thread float DARKcurble_offset = curve->DARKcurble_offset;
        thread int curve_mintiao = curve->curve_mintiao;
        thread float m_a = m_a_T;
        
        low_area_spline(maximum_maxrgbtemp,
                        average_maxrgbtemp,
                        curve->m_p,
                        curve->m_m,
                        curve->m_a,
                        curve->m_b,
                        curve->m_n,
                        curve->K1,
                        curve->K2,
                        curve->K3,
                        P3Spline_TH_MB,
                        P3Spline_TH,
                        P3Spline_Strength,
                        MaxDisplay,
                        //output
                        &md1g,
                        &mc1g,
                        &mb1g,
                        &ma1g,
                        &md2g,
                        &mc2g,
                        &mb2g,
                        &ma2g,
                        &dark,
                        &DARKcurble_offset,
                        &curve_mintiao,
                        &m_a,
                        metadata->base_param_Delta_mode[0],
                        metadata->Base_flag[0],
                        mode,
                        m_maxE,
                        m_inputMaxE);
        
        curve->md1 = md1g;
        curve->mc1 = mc1g;
        curve->mb1 = mb1g;
        curve->ma1 = ma1g;
        curve->md2 = md2g;
        curve->mc2 = mc2g;
        curve->mb2 = mb2g;
        curve->ma2 = ma2g;
        curve->DARKcurble_S1 = dark;
        curve->DARKcurble_offset = DARKcurble_offset;
        curve->curve_mintiao = curve_mintiao;
        
        curve->TH1 = P3Spline_TH[0];
        curve->TH2 = P3Spline_TH[1];
        curve->TH3 = P3Spline_TH[2];
    }
    
    if (i3spline >= 0){
        for (int spline_i = 0; spline_i < ((int)metadata->P3Spline_num[i3spline]); spline_i++)
        {
            float P3Spline_Strength_org = float((metadata->P3Spline_Strength[i3spline][spline_i] * 2)) / ((1 << P3Spline_Strength_BIT) - 1) - 1.0;
            int P3Spline_TH_OFFSET_code = metadata->P3Spline_TH_MB[i3spline][spline_i] & ((1 << P3Spline_TH_OFFSET_BIT) - 1);
            int P3Spline_TH_MB_code = (metadata->P3Spline_TH_MB[i3spline][spline_i] >> P3Spline_TH_OFFSET_BIT);
            float P3Spline_TH_MB = float((P3Spline_TH_MB_code * 1)) / ((1 << (P3Spline_TH_MB_BIT - P3Spline_TH_OFFSET_BIT)) - 1);
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 0) {
                curve->DARKcurble_offset = float(P3Spline_TH_OFFSET_code * 0.1) / ((1 << P3Spline_TH_OFFSET_BIT) - 1);
            }
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] != 0)
            {
                P3Spline_TH_MB = float((metadata->P3Spline_TH_MB[i3spline][spline_i] * 1.1)) / ((1 << P3Spline_TH_MB_BIT) - 1);
            }
            float TH1temp = float((metadata->P3Spline_TH[i3spline][spline_i][0])) / ((1 << P3Spline_TH1_BIT) - 1);
            float TH2temp = float((metadata->P3Spline_TH[i3spline][spline_i][1])) / (((1 << P3Spline_TH2_BIT) - 1) * 4) + TH1temp;
            float TH3temp = float((metadata->P3Spline_TH[i3spline][spline_i][2])) / (((1 << P3Spline_TH3_BIT) - 1) * 4) + TH2temp;
            float P3Spline_TH[3] = { TH1temp, TH2temp, TH3temp };
            
            if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 0)
            {
                IJKHDRVividCurve curvetemp = *curve;
                if ((metadata->base_param_Delta_mode[0]) < 3 && metadata->Base_flag[0] == 1){
                    getBaseCurveParameterAdjust(&curvetemp);
                }
                curvetemp.TH1 = P3Spline_TH[0];
                curvetemp.TH2 = P3Spline_TH[1];
                curvetemp.TH3 = P3Spline_TH[2];
                curvetemp.DARKcurble_S1 = P3Spline_TH_MB;
                curvetemp.curve_mintiao = 1;
                if ((metadata->base_param_Delta_mode[0]) < 3 && metadata->Base_flag[0] == 1)
                    
                {
                    AdjustVividParameter(m_maxE,
                                         m_inputMaxE,
                                         &curvetemp);
                }
                P3Spline_TH[0] = curvetemp.TH1;
                P3Spline_TH[1] = curvetemp.TH2;
                P3Spline_TH[2] = curvetemp.TH3;
                curve->m_b = curvetemp.m_b;
                P3Spline_TH_MB = curvetemp.DARKcurble_S1;
                
                float P3Spline_Strength = P3Spline_Strength_org;
                
                thread float tone_mapping_param_m_b = curve->m_b;
                thread float md1g = curve->md1;
                thread float mc1g = curve->mc1;
                thread float mb1g = curve->mb1;
                thread float ma1g = curve->ma1;
                thread float md2g = curve->md2;
                thread float mc2g = curve->mc2;
                thread float mb2g = curve->mb2;
                thread float ma2g = curve->ma2;
                thread float dark = curve->DARKcurble_S1;
                thread float DARKcurble_offset = curve->DARKcurble_offset;
                thread int curve_mintiao = curve->curve_mintiao;
                
                float curve_ready1 = spline_area_spec(maximum_maxrgbtemp,
                                                      average_maxrgbtemp,
                                                      curve->m_p,
                                                      curve->m_m,
                                                      curve->m_a,
                                                      &tone_mapping_param_m_b,
                                                      curve->m_n,
                                                      curve->K1,
                                                      curve->K2,
                                                      curve->K3,
                                                      P3Spline_TH_MB,
                                                      P3Spline_TH,
                                                      P3Spline_Strength,
                                                      MaxDisplay,
                                                      //output
                                                      &md1g,
                                                      &mc1g,
                                                      &mb1g,
                                                      &ma1g,
                                                      &md2g,
                                                      &mc2g,
                                                      &mb2g,
                                                      &ma2g,
                                                      &dark,
                                                      &DARKcurble_offset,
                                                      &curve_mintiao,
                                                      metadata->base_param_Delta_mode[0]);
                
                curve->md1 = md1g;
                curve->mc1 = mc1g;
                curve->mb1 = mb1g;
                curve->ma1 = ma1g;
                curve->md2 = md2g;
                curve->mc2 = mc2g;
                curve->mb2 = mb2g;
                curve->ma2 = ma2g;
                curve->DARKcurble_S1 = dark;
                curve->DARKcurble_offset = DARKcurble_offset;
                curve->curve_mintiao = curve_mintiao;
                curve->m_b = tone_mapping_param_m_b;
                
                if (curve_ready1){
                    curve->TH1 = P3Spline_TH[0];
                    curve->TH2 = P3Spline_TH[1];
                    curve->TH3 = P3Spline_TH[2];
                }
                
            }
            else if ((metadata->P3Spline_TH_mode[i3spline][spline_i] == 1) || (metadata->P3Spline_TH_mode[i3spline][spline_i] == 2) || (metadata->P3Spline_TH_mode[i3spline][spline_i] == 3))
            {
                float maxContent_in = maximum_maxrgbtemp;
                maxContent_in = m_maxE > maxContent_in ? m_maxE : maxContent_in;
                {
                    float P3Spline_Strength = P3Spline_Strength_org;
                    
                    float threshold1temp = P3Spline_TH[0];
                    float threshold2temp = P3Spline_TH[1];
                    float threshold3temp = P3Spline_TH[2];
                    
                    if (curve->curve_mintiao)
                    {
                        if (threshold3temp <= curve->TH3)
                        {
                            continue;
                        }
                        else if (threshold1temp < curve->TH3)
                        {
                            threshold1temp = curve->TH3;
                            threshold2temp = (threshold1temp + threshold3temp) / 2;
                        }
                    }
                    
                    P3Spline_TH[0] = threshold1temp;
                    P3Spline_TH[1] = threshold2temp;
                    P3Spline_TH[2] = threshold3temp;
                    curve->Light_S1 = P3Spline_TH_MB;
                    
                    
                    thread float md1g_high = curve->md1_high;
                    thread float mc1g_high = curve->mc1_high;
                    thread float mb1g_high = curve->mb1_high;
                    thread float ma1g_high = curve->ma1_high;
                    thread float md2g_high = curve->md2_high;
                    thread float mc2g_high = curve->mc2_high;
                    thread float mb2g_high = curve->mb2_high;
                    thread float ma2g_high = curve->ma2_high;
                    thread float dark = curve->DARKcurble_S1;
                    thread int curve_mintiao_high_area = curve->curve_mintiao_high_area;
                    
                    float curve_ready1 = spline_higharea_spec(maximum_maxrgbtemp,
                                                              average_maxrgbtemp,
                                                              curve->m_p,
                                                              curve->m_m,
                                                              curve->m_a,
                                                              curve->m_b,
                                                              curve->m_n,
                                                              curve->K1,
                                                              curve->K2,
                                                              curve->K3,
                                                              metadata->P3Spline_TH_mode[i3spline][spline_i],
                                                              P3Spline_TH_MB,
                                                              P3Spline_TH,
                                                              P3Spline_Strength,
                                                              MaxDisplay,
                                                              //output
                                                              &md1g_high,
                                                              &mc1g_high,
                                                              &mb1g_high,
                                                              &ma1g_high,
                                                              &md2g_high,
                                                              &mc2g_high,
                                                              &mb2g_high,
                                                              &ma2g_high,
                                                              &dark,
                                                              &curve_mintiao_high_area,
                                                              Referncedisplay,
                                                              metadata->base_param_Delta_mode[0]);
                    curve->md1_high = md1g_high;
                    curve->mc1_high = mc1g_high;
                    curve->mb1_high = mb1g_high;
                    curve->ma1_high = ma1g_high;
                    curve->md2_high = md2g_high;
                    curve->mc2_high = mc2g_high;
                    curve->mb2_high = mb2g_high;
                    curve->ma2_high = ma2g_high;
                    curve->DARKcurble_S1 = dark;
                    curve->curve_mintiao_high_area = curve_mintiao_high_area;
                    
                    
                    if (curve_ready1){
                        curve->TH1_HIGH = P3Spline_TH[0];
                        curve->TH2_HIGH = P3Spline_TH[1];
                        curve->TH3_HIGH = P3Spline_TH[2];
                        if (metadata->P3Spline_TH_mode[i3spline][spline_i] == 3){
                            curve->high_area_flag = 1;
                        }
                    }
                }
                
            }
        }
    }
    
}

kernel void initCUVAParams(device IJKHDRVividMetadata *metadata [[ buffer(0) ]],
                           device IJKHDRVividCurve *curve [[ buffer(1) ]],
                           device IJKHDRVividRenderConfig *config [[ buffer(2) ]]){
    
    thread float m_maxEtemp;
    thread float m_inputMaxEtemp;
        
    float MaxDisplay = (float)(PQinverse(metadata->_max_display_luminance / 10000.0));
    float MinDisplay = (float)(PQinverse(0.05/10000.00));
    
    if (config->processMode == IJKMetalPostprocessSDR) {
        MinDisplay = (float)(PQinverse(0.1/10000.00));
    }
    
    genBaseCurveParameter(metadata,
                          metadata->_masterDisplay,
                          MaxDisplay,
                          MinDisplay,
                          curve,
                          &m_maxEtemp,
                          &m_inputMaxEtemp,
                          config->processMode);
    
    genCubicSplineParameter(metadata,
                            m_maxEtemp,
                            m_inputMaxEtemp,
                            curve,
                            config->processMode);
        
    curve->inputMaxEtemp_store = m_inputMaxEtemp;
    curve->maxEtemp_store = m_maxEtemp;
    
    MaxDisplay = curve->maxEtemp_store;
    curve->TML = MaxDisplay;
    curve->TML_linear = (float)(10000 * PQforward(curve->TML));
    curve->RML = metadata->_masterDisplay;
    
    curve->RML_linear = (float)(10000 * PQforward(curve->RML));
    if (curve->TML_linear > curve->RML_linear) curve->RML_linear = curve->TML_linear;
    if (curve->TML > curve->RML) curve->RML = curve->TML;
}


float calc_curve(float max, device const IJKHDRVividCurve *TMP)
{
    float max1 = max;
    if (TMP->curve_mintiao&&TMP->curve_mintiao_high_area)
    {
        if (max <= TMP->TH1) {
            max1 = TMP->DARKcurble_S1 * max + TMP->DARKcurble_offset;
        }
        else if (max > TMP->TH1&&max <= TMP->TH2)
            max1 = TMP->md1 * pow((max - TMP->TH1), 3) + TMP->mc1 * pow((max - TMP->TH1), 2) + TMP->mb1 * pow((max - TMP->TH1), 1) + TMP->ma1;
        else if (max > TMP->TH2&&max <= TMP->TH3)
        {
            max1 = TMP->md2 * pow((max - TMP->TH2), 3) + TMP->mc2 * pow((max - TMP->TH2), 2) + TMP->mb2 * pow((max - TMP->TH2), 1) + TMP->ma2;
        }
        else if (max > TMP->TH1_HIGH&&max <= TMP->TH2_HIGH)
        {
            max1 = TMP->md1_high * pow((max - TMP->TH1_HIGH), 3) + TMP->mc1_high * pow((max - TMP->TH1_HIGH), 2) + TMP->mb1_high * pow((max - TMP->TH1_HIGH), 1) + TMP->ma1_high;
        }
        else if (max > TMP->TH2_HIGH&&max <= TMP->TH3_HIGH)
        {
            max1 = TMP->md2_high * pow((max - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((max - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((max - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        }
        else  if ((max > TMP->TH3_HIGH) && (TMP->high_area_flag == 0))
        {
            max1 = (3 * TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + 2 * TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->mb2_high)*(max - TMP->TH3_HIGH)
            + TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        }
        else
        {
            max = pow(max, TMP->m_n);
            max1 = (TMP->m_p * max / ((TMP->K1*TMP->m_p - TMP->K2)*max + TMP->K3));
            max1 = pow(max1, TMP->m_m);
            max1 = TMP->m_a * max1 + TMP->m_b;
        }
    }
    else if (TMP->curve_mintiao)
    {
        if (max <= TMP->TH1) {
            max1 = TMP->DARKcurble_S1 * max+TMP->DARKcurble_offset;
        }
        else if (max > TMP->TH1&&max <= TMP->TH2)
            max1 = TMP->md1 * pow((max - TMP->TH1), 3) + TMP->mc1 * pow((max - TMP->TH1), 2) + TMP->mb1 * pow((max - TMP->TH1), 1) + TMP->ma1;
        else if (max > TMP->TH2&&max <= TMP->TH3)
            max1 = TMP->md2 * pow((max - TMP->TH2), 3) + TMP->mc2 * pow((max - TMP->TH2), 2) + TMP->mb2 * pow((max - TMP->TH2), 1) + TMP->ma2;
        else
        {
            max = pow(max, TMP->m_n);
            max1 = (TMP->m_p * max / ((TMP->K1*TMP->m_p - TMP->K2)*max + TMP->K3));
            max1 = pow(max1, TMP->m_m);
            max1 = TMP->m_a * max1 + TMP->m_b;
        }
    }
    else if (TMP->curve_mintiao_high_area)
    {
        if (max > TMP->TH1_HIGH&&max <= TMP->TH2_HIGH)
            max1 = TMP->md1_high * pow((max - TMP->TH1_HIGH), 3) + TMP->mc1_high * pow((max - TMP->TH1_HIGH), 2) + TMP->mb1_high * pow((max - TMP->TH1_HIGH), 1) + TMP->ma1_high;
        else if (max > TMP->TH2_HIGH&&max <= TMP->TH3_HIGH)
            max1 = TMP->md2_high * pow((max - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((max - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((max - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        else  if ((max > TMP->TH3_HIGH) && (TMP->high_area_flag == 0)){
            max1 = (3 * TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + 2 * TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->mb2_high)*(max - TMP->TH3_HIGH)
            + TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        } else {
            max = pow(max, TMP->m_n);
            max1 = (TMP->m_p * max / ((TMP->K1 * TMP->m_p - TMP->K2) * max + TMP->K3));
            max1 = pow(max1, TMP->m_m);
            max1 = TMP->m_a * max1 + TMP->m_b;
        }
    }
    else
    {
        max = pow(max, TMP->m_n);
        max1 = (TMP->m_p * max / ((TMP->K1*TMP->m_p - TMP->K2)*max + TMP->K3));
        max1 = pow(max1, TMP->m_m);
        max1 = TMP->m_a * max1 + TMP->m_b;
    }
    return max1;
}


float getB(float smCoef, float Y_PQ, float m_inputMaxE, device const IJKHDRVividMetadata *metadata, device const IJKHDRVividCurve *tone_mapping_param){
    float Yout_pq = calc_curve(Y_PQ, tone_mapping_param);
    float power_used = float(metadata->color_saturation_gain[0]) / 128.0;
    float scale = Yout_pq / Y_PQ;
    smCoef = pow(scale, power_used);
    smCoef = clip(smCoef, 0.8, 1.0);
    return smCoef;
}


float saturation_modify(float Y_PQ, float MaxDisplay,  device const IJKHDRVividMetadata *metadata, device const IJKHDRVividCurve *tone_mapping_param){
    float smCoef = 0.0;
    if (metadata->color_saturation_mapping_flag == 0){
        smCoef = 1.0;
        return smCoef;
    }
    //apply C0
    float Yin_pq = Y_PQ;
    float Yout_pq = calc_curve(Yin_pq, tone_mapping_param);
    float power_used = float(metadata->color_saturation_gain[0]) / 128.0;
    float scale = Yout_pq / Yin_pq;
    smCoef = pow(scale, power_used);
    smCoef = clip(smCoef, 0.8, 1.0);
    float B = getB(smCoef, MaxDisplay, tone_mapping_param->inputMaxEtemp_store, metadata, tone_mapping_param);
    
    //apply C1
    float SATR = 0.4;
    float C1 = 0.0;
    float C2 = 1.0;
    
    if ((metadata->color_saturation_mapping_flag) && (metadata->color_saturation_num > 1)){
        C1 = float(metadata->color_saturation_gain[1] & 0xFC) / 128.0;
        C2 = float(metadata->color_saturation_gain[1] & 0x3);
        C2 = pow(2, C2);
    }
    if (C1 == 0.0){
        return B;
    }
    float Sca = 1.0;
    if (Yin_pq >= tone_mapping_param->RML){
        if (B >= C1 * SATR) Sca = B - C1 * SATR;
        else Sca = 0;
        smCoef = Sca;
    }
    else if (Yin_pq >= tone_mapping_param->TML){
        float ratioC = (Yin_pq - tone_mapping_param->TML) / (tone_mapping_param->RML - tone_mapping_param->TML);
        ratioC = pow(ratioC, C2);
        if (B >= C1 * SATR * ratioC)    Sca = B - C1 * SATR * ratioC;
        else Sca = 0;
        smCoef = Sca;
    }
    return smCoef;
}


float3 PQtoLinear(float3 val){
    val.r = 10000.0 * PQforward(val.r);
    val.g = 10000.0 * PQforward(val.g);
    val.b = 10000.0 * PQforward(val.b);
    return val;
}


float3 PQinverse3(float3 val){
    val.r = PQinverse(val.r / 10000.0);
    val.g = PQinverse(val.g / 10000.0);
    val.b = PQinverse(val.b / 10000.0);
    return val;
}

float max3(float3 val){
    return FFMAX3(val.r, val.g, val.b);
}

float HLGforward(float value){
    return (value <= 0.5 ? (value * value / 3.0) : (exp((value - 1.00429347) / 0.17883277) + 0.02372241));
}


float3 HLGtoLinear(float3 color, float peaklum){
    float comp00lineTemp = HLGforward(color.r);
    float comp11lineTemp = HLGforward(color.g);
    float comp22lineTemp = HLGforward(color.b);
    // BT2020
    float comp22YTemp = 0.262700 * comp00lineTemp + 0.678000 * comp11lineTemp + 0.059300 * comp22lineTemp;
    // Normally the peak luminance of HLG is 1000nits
    float gamma = 1.2 + 0.42 * log10(peaklum/1000.0);
    float comp22YTempgamma = pow(comp22YTemp, gamma);
    float comp22YTempscale = comp22YTempgamma / comp22YTemp;
    float comp00line = comp00lineTemp * comp22YTempscale * peaklum;
    float comp11line = comp11lineTemp * comp22YTempscale * peaklum;
    float comp22line = comp22lineTemp * comp22YTempscale * peaklum;
    
    color.r = comp00line;
    color.g = comp11line;
    color.b = comp22line;
    return color;
}

float GetLw(device const IJKHDRVividMetadata *metadata){
    if(metadata->system_start_code == 0x1 || metadata->system_start_code == 0x2){
        return 1000.0;
    }else if(metadata->system_start_code == 0x3 ||
             metadata->system_start_code == 0x4 ||
             metadata->system_start_code == 0x5 ||
             metadata->system_start_code == 0x6 ||
             metadata->system_start_code == 0x7){
        return (float)(2000.0*(metadata->system_start_code - 2));
    }else{
        return -1.00;
    }
}


#pragma mark - SDR

float3 BT2020toBT709(float3 color){
    float comp0 = color.r;
    float comp1 = color.g;
    float comp2 = color.b;
    
    color.r = (float)(1.6605 * comp0 - 0.5876 * comp1 -0.0728 * comp2); //see R-REP-BT2407-2017-PDF-E.pdf section 2.2 on page 4
    color.g = (float)(-0.1246 * comp0 + 1.1329 * comp1 - 0.0083 * comp2);
    color.b = (float)(-0.0182 * comp0 - 0.1006 * comp1 + 1.1187 * comp2);
    
    return color;
}

float Gammainverse(float value){
    float E;
    value = dClip(value, 0.0, 1.0);
    E = pow(value, 1.0 / 2.2);
    E = dClip(E, 0, 1.0);
    return E;
}

float GammaForward(float value){
    float E;
    value = dClip(value, 0.0, 1.0);
    E = pow(value,2.2); //see 005.1 chap 11.2,step g) gamma is 2.2
    E = dClip(E, 0, 1.0);
    return E;
}


constant float kGammaScaleFactor(100.0f);
float3 LineartoGamma(float3 color){
    color.r = (float)Gammainverse(color.r / kGammaScaleFactor);
    color.g = (float)Gammainverse(color.g / kGammaScaleFactor);
    color.b = (float)Gammainverse(color.b / kGammaScaleFactor);
    
    return color;
}


float3 GammatoLinear(float3 color){
    color.r = kGammaScaleFactor * GammaForward(color.r);
    color.g = kGammaScaleFactor * GammaForward(color.g);
    color.b = kGammaScaleFactor * GammaForward(color.b);
    return color;
}

#pragma mark - SDR HLG Static
constant float KP1(0.5247f);
constant float KP2(0.7518);
constant float maxDL(0.638285);
constant float maxSL(0.7518);
#define x0               KP1
#define x1               maxSL
#define y0               KP1
#define y1               maxDL
#define y0delta          1
#define y1delta          0
#define x1Minusx0Square  ((x1-x0)*(x1-x0))
#define x1Minusx0Spline  (x1Minusx0Square*(x1-x0))

float hmt(float x){
    float alpha0 ,alpha1,beta0,beta1;
    alpha0 =(x1 - 3*x0 + 2*x)*(x1 - x)*(x1 - x)/x1Minusx0Spline;
    alpha1 =(3*x1 - x0 - 2*x)*(x-x0)*(x-x0)/x1Minusx0Spline;
    beta0  =(x-x0)*(x-x1)*(x-x1)/x1Minusx0Square;
    beta1  =(x-x0)*(x-x0)*(x-x1)/x1Minusx0Square;
    return y0*alpha0 + y1*alpha1 + y0delta*beta0 +y1delta*beta1;
}

// equation (161) of T/UWA 005.1-2022 V1.2
float ftm(float e){
    if(e<=KP1){
        return e;
    }else if((e>KP1) && (e<KP2)){
        return hmt(e);
    }else{
        return maxDL;
    }
}

float3 HLGHDRStaticAdaptToSDR(float3 yuv){
    float RsDelta,GsDelta,BsDelta;
    float RtDelta,GtDelta,BtDelta;
    float Yt,Cbt,Crt;
    float Yd;
    float Ysf, Cbsf,Crsf;
    float Yts,Cbts,Crts;
    float Rs,Gs,Bs,Ys,Rt,Gt,Bt;
    float Ytpq,Ydpq;
    float TmGain,SmGain;
    //float Yo,Cbo,Cro;
    
    Ysf  = (float)(yuv.r -  64)/876;
    Cbsf = (float)(yuv.g - 512)/896;
    Crsf = (float)(yuv.b - 512)/896;  //T/UWA 005.1-2022 V1.2 page 41 11.2 quation (156)
    RsDelta = Ysf + 0*Cbsf +  1.4746*Crsf;
    GsDelta = Ysf - 0.1645*Cbsf - 0.5713*Crsf;
    BsDelta = Ysf + 1.8814*Cbsf + 0*Crsf;       //equation (157)
    
    RsDelta = dClip(RsDelta,0,1.0);
    GsDelta = dClip(GsDelta,0,1.0);
    BsDelta = dClip(BsDelta,0,1.0);
    
    Rs = HLGforward(RsDelta);
    Gs = HLGforward(GsDelta);
    Bs = HLGforward(BsDelta);                          //equation (14) on page 6 of T/UWA 005.1-2022 V1.2
    
    Ys = 0.2627*Rs + 0.6780*Gs + 0.0593*Bs;            //equation (158)
    Ys = dClip(Ys,0,1.0);
    Yd = 1000.0*pow(Ys,1.2);                           //equation (159)
    Ydpq  = (float)PQinverse(Yd/10000);                //equation (160)
    Ytpq  = ftm(Ydpq);                                 //equation (161)
    Yt = (float)(10000*PQforward(Ytpq));               //equation (162)
    Yt = dClip(Yt,0,350);
    
    TmGain = (Ys!=0)?(Yt/Ys):0;                       //equation (163)
    SmGain = (Ys!=0)?(pow(Yt/(1000*Ys),0.2)):0;       //equation (164)
    
    Rt = dClip((Rs*TmGain)/350,0,1.0);                //equation (165)
    Gt = dClip((Gs*TmGain)/350,0,1.0);
    Bt = dClip((Bs*TmGain)/350,0,1.0);
    RtDelta = dClip(pow(Rt,1/2.2),0,1);               //equation (166)
    GtDelta = dClip(pow(Gt,1/2.2),0,1);
    BtDelta = dClip(pow(Bt,1/2.2),0,1);
    
    Yt    =  0.2627*RtDelta + 0.6780*GtDelta + 0.0593*BtDelta;     //equation (167)
    Cbt = -0.1396*RtDelta - 0.3604*GtDelta + 0.5000*BtDelta;
    Crt =  0.5000*RtDelta - 0.4598*GtDelta - 0.0402*BtDelta;
    Yt    = dClip(Yt,0,1.0);
    Cbt = dClip(Cbt,-0.5,0.5);
    Crt = dClip(Crt,-0.5,0.5);
    
    Yts  = Yt;                                         //equation (168)
    Cbts = dClip(Cbt*SmGain,-0.5,0.5);
    Crts = dClip(Crt*SmGain,-0.5,0.5);
    
    return float3(Yts, Cbts, Crts);
}


#pragma mark - 片元着色器

//static const GLfloat g_bt2020[] = {
//    1.164384,   1.164384,   1.164384,
//    0.0,       -0.187326,   2.14177,
//    1.67867,   -0.65042,    0.0,
//};

fragment float4 fragmentShader(IJKMetalRasterizerData input [[ stage_in ]],
                               texture2d <float> yTexture [[ texture(0) ]],
                               texture2d <float> uTexture [[ texture(1) ]],
                               texture2d <float> vTexture [[ texture(2) ]],
                               device const IJKHDRVividMetadata *metadata [[ buffer(0) ]],
                               device const IJKHDRVividCurve *curve [[ buffer(1) ]],
                               device const IJKHDRVividRenderConfig *config [[ buffer(2) ]]) {
    
    
    // 获取坐标
    uint posX = uint(input.textureCoor.x * yTexture.get_width());
    uint posY = uint(input.textureCoor.y * yTexture.get_height());
    
    // 读取YUV
    float3 color;
    float3 yuv;
    if(config->pixelFormatType == IJKMetalPixelFormatTypeYUV420P10LE){
        yuv.x = static_cast<float>(yTexture.read(uint2(posX, posY)).r);
        yuv.y = static_cast<float>(uTexture.read(uint2(posX/2, posY/2)).r);
        yuv.z = static_cast<float>(vTexture.read(uint2(posX/2, posY/2)).r);
        return float4(1,0,0,1);
    }else if(config->pixelFormatType == IJKMetalPixelFormatTypeYUV444P10LE){
        yuv.x = static_cast<float>(yTexture.read(uint2(posX, posY)).r);
        yuv.y = static_cast<float>(uTexture.read(uint2(posX, posY)).r);
        yuv.z = static_cast<float>(vTexture.read(uint2(posX, posY)).r);
        return float4(1,0,0,1);
    }else if(config->pixelFormatType == IJKMetalPixelFormatTypeCVPixelBuffer){
    
        
        
        constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
        yuv.x = yTexture.sample(textureSampler, input.textureCoor).r;
        
        yuv.y = uTexture.sample(textureSampler, input.textureCoor).r;
        yuv.z = uTexture.sample(textureSampler, input.textureCoor).g;

    
        float3x3 kColorConversion601FullRangeMatrix = (matrix_float3x3){
               (float3){1.0,    1.0,    1.0},
               (float3){0.0,    -0.343, 1.765},
               (float3){1.4,    -0.711, 0.0},
        };
        
        float3 kColorConversion601FullRangeOffset = (float3){ -(16.0/255.0), -0.5, -0.5};
        
        float3 rgb = kColorConversion601FullRangeMatrix * (yuv + kColorConversion601FullRangeOffset);

        return float4(rgb,1);
    }else{
        return float4(0,0,1,1);
    }

    
    if(0){
        float weight = 1.0 / 876.0;
        float fY = clip(weight * float(yuv.x - 64), 0.0f, 1.0f);
        weight = 1.0 / 896.0;
        float fU = clip(weight * float(yuv.y - 512), -0.5f, 0.5f);
        float fV = clip(weight * float(yuv.z - 512), -0.5f, 0.5f);
        
        color.r = 1.0000 * fY - 0.0000 * fU + 1.4746 * fV;
        color.g = 1.0000 * fY - 0.1645 * fU - 0.5713 * fV;
        color.b = 1.0000 * fY + 1.8814 * fU - 0.0001 * fV;
    }else{
        // 转RGB [64, 960]
        color.r = float(yuv.x - 64) * 1.164384                                  - float(yuv.z - 512) * -1.67867;
        color.g = float(yuv.x - 64) * 1.164384 - float(yuv.y - 512) * 0.187326  - float(yuv.z - 512) * 0.65042;
        color.b = float(yuv.x - 64) * 1.164384 - float(yuv.y - 512) * -2.14177;
        color = color/1023.000;
    }
    
    
//    color = color * config->maxHeadRoom;
    
    return float4(color, 1);
    
    float3 comp;
    
    if(config->GPUProcessFun == IJKMetalGPUProcessStaticHLGHDR){
        color = GammatoLinear(color);
        comp = BT2020toBT709(color);
        comp = LineartoGamma(comp);
        return float4(comp, 1.f);
    }
        
    color = clip3(color, 0.0, 1.0);

    if(config->GPUProcessFun == IJKMetalGPUProcessPQHDR || config->GPUProcessFun == IJKMetalGPUProcessPQSDR){
        comp = PQtoLinear(color);
    }else{
        float Lw = GetLw(metadata);
        comp = HLGtoLinear(color, Lw);
    }
    
    // PROCESS
    float3 maxComp = PQinverse3(comp);
    
    float max = max3(comp);
    float maxO = max;
    float maxC = max;
    max = max3(maxComp);
    
    float max1 = max;
    max1 = calc_curve(max, curve);
    float lumRatio;
    
    if (max > 0) {
        lumRatio = max1 / max;
    } else {
        lumRatio = 1.0;
    }
    maxC = (float)(10000.f * PQforward(max1));
    lumRatio = maxO <= 0 ? 1 : maxC / maxO;
    
    comp = comp * (float)lumRatio;
    
    if (max){
        comp = PQinverse3(comp);
        
        float Y = 0.262700*comp.r + 0.678000*comp.g + 0.059300*comp.b;
        float U = -0.1396*comp.r - 0.3604*comp.g + 0.5*comp.b;
        float V = 0.5*comp.r - 0.4598*comp.g - 0.0402*comp.b;
        
        float smCoef = saturation_modify(max, curve->maxEtemp_store, metadata, curve);
        U = U * smCoef;
        V = V * smCoef;
        
        comp.r = (float)(1.0000*Y - 0.0000*U + 1.4746*V);
        comp.g = (float)(1.0000*Y - 0.1645*U - 0.5713*V);
        comp.b = (float)(1.0000*Y + 1.8814*U - 0.0001*V);
        
        comp = clip3(comp, 0.0, 1.0);
        comp = PQtoLinear(comp);
    }
    if(config->GPUProcessFun == IJKMetalGPUProcessPQHDR || config->GPUProcessFun == IJKMetalGPUProcessHLGHDR){
        comp = PQinverse3(comp);
//        float EDRHeadroom = (config->maxHeadRoom - 1.0);
//        float luminanceScale = 1.0 + EDRHeadroom;
//        comp = RinehardOperator(comp, luminanceScale);
//        comp = comp * config->maxHeadRoom;
        return float4(comp, 1.f);
    }else{
        comp = BT2020toBT709(comp);
        comp = LineartoGamma(comp);
        return float4(comp, 1.f);
    }
}
