//
//  shader.metal
//  IJKMediaDemo
//
//  Created by hejianyuan on 2023/11/1.
//  Copyright © 2023 bilibili. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include <IJKMediaFramework/IJKHDRVividDataDefine.h>

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


float st_2084_eotf(float x){
    const float ST2084_M1 = 0.1593017578125f;
    const float ST2084_M2 = 78.84375f;
    const float ST2084_C1 = 0.8359375f;
    const float ST2084_C2 = 18.8515625f;
    const float ST2084_C3 = 18.6875f;
    float xpow = pow(x, float(1.0 / ST2084_M2));
    float num = max(xpow - ST2084_C1, 0.0);
    float den = max(ST2084_C2 - ST2084_C3 * xpow, FLT_MIN);
    return pow(num/den, 1.0 / ST2084_M1);
}


float hable(float in)
{
    float a = 0.15f, b = 0.50f, c = 0.10f, d = 0.20f, e = 0.02f, f = 0.30f;
    return (in * (in * a + b * c) + d * e) / (in * (in * a + b) + d * f) - e / f;
}


float rec_709_oetf(float x){
    const float REC709_ALPHA = 1.09929682680944f;
    const float REC709_BETA = 0.018053968510807f;
    
    x = max(x, 0.0);
    if (x < REC709_BETA )
        x = x * 4.5;
    else
        x = REC709_ALPHA * pow(x, 0.45f) - (REC709_ALPHA - 1.0);
    return x;
}



#define FFMAX(a,b) ((a) > (b) ? (a) : (b))
#define FFMAX3(a,b,c) FFMAX(FFMAX(a,b),c)



//fragment float4 fragmentShader(RasterizerData input [[ stage_in ]],
//                               texture2d <ushort> yTexture [[ texture(0) ]],
//                               texture2d <ushort> uTexture [[ texture(1) ]],
//                               texture2d <ushort> vTexture [[ texture(2) ]]) {
//    
//    uint posX = uint(input.textureCoor.x * yTexture.get_width());
//    uint posY = uint(input.textureCoor.y * yTexture.get_height());
//    
//    uint uint4_y = yTexture.read(uint2(posX, posY)).r;
//    uint uint4_u = uTexture.read(uint2(posX/2, posY/2)).r;
//    uint uint4_v = vTexture.read(uint2(posX/2, posY/2)).r;
//    
//    uint3 yuv10bit = uint3(uint4_y , uint4_u , uint4_v);
//    
//    int y = int(yuv10bit.x);
//    int u = int(yuv10bit.y);
//    int v = int(yuv10bit.z);
//    
//    
//    float3 rgb;
//    
//    // [64, 960]
//    float r = float(y - 64) * 1.164384                             - float(v - 512) * -1.67867;
//    float g = float(y - 64) * 1.164384 - float(u - 512) * 0.187326 - float(v - 512) * 0.65042;
//    float b = float(y - 64) * 1.164384 - float(u - 512) * -2.14177;
//    
//    rgb.r = r ;
//    rgb.g = g ;
//    rgb.b = b ;
//    
//    //    float ST2084_PEAK_LUMINANCE = 10000.0f;
//    //    float peak_luminance = 1000.0f;
//    //    float to_linear_scale = ST2084_PEAK_LUMINANCE / peak_luminance;
//    //
//    //       float3 fragColor = to_linear_scale * float3(st_2084_eotf(rgb.r), st_2084_eotf(rgb.g), st_2084_eotf(rgb.b));
//    //       return float4(rgb + float3(0.0), 1.f);
//    
//    rgb.r = r / 1024;
//    rgb.g = g / 1024;
//    rgb.b = b / 1024;
//    
////    return float4(rgb + float3(0.0), 1.f);
//    
//    
//    
//    
//    
//        float ST2084_PEAK_LUMINANCE = 10000.0f;
//        float peak_luminance = 1000.0f;
//        float to_linear_scale = ST2084_PEAK_LUMINANCE / peak_luminance;
//    
//        float3 fragColor = to_linear_scale * float3(st_2084_eotf(rgb.r), st_2084_eotf(rgb.g), st_2084_eotf(rgb.b));
//    
//        float sig;
//        float sig_orig;
//        sig = FFMAX(FFMAX3(fragColor.r, fragColor.g, fragColor.b), 1e-6);
//        sig_orig = sig;
//        float peak = 4; // 手机设备的最大亮度值MaxCLL / REFERENCE_WHITE(固定100);
//        sig = hable(sig) / hable(peak);
//        fragColor.r = fragColor.r * (sig / sig_orig);
//        fragColor.g = fragColor.g * (sig / sig_orig);
//        fragColor.b = fragColor.b * (sig / sig_orig);
//    
//        fragColor = float3(rec_709_oetf(fragColor.r), rec_709_oetf(fragColor.g), rec_709_oetf(fragColor.b));
//    
//    
//        return float4(fragColor*4 + float3(0.0), 1.f);
//}

/////////////////////////////////

typedef enum ProcessMode{
    Preprocess = 0,
    PostprocessHDR,
    PostprocessSDR
}ProcessMode;

#define TPA_NUM 4

float getBaseCurveParameterAdjust(thread IJKHDRVividCurve *curve){
    float TPA[TPA_NUM][2] = { { 2.5,0.99 },{ 3.5,0.879 },{ 4.5,0.777 },{ 7.5,0.54 } };

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

float clip(float val, float low, float high){
    val = max(val, low);
    val = min(val, high);
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
    float a1 = (2610.0) / (4096.0 * 4.0);
    float a2 = (2523.0 * 128.0) / 4096.0;
    float b1 = (3424.0) / 4096.0;
    float b2 = (2413.0 * 32.0) / 4096.0;
    float b3 = (2392.0 * 32.0) / 4096.0;
    value = clip(value, 0, 1.0);
    float tempValue = pow(value, a1);
    return (float)(pow(((b2 * (tempValue)+b1) / (1.0 + b3 * (tempValue))), a2));
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
    if (mode == PostprocessSDR){
        lowThreshold = 0.1;
    }else if (mode == PostprocessHDR) {
        lowThreshold = 0.3;
    }
    
    if (average_maxrgb_noLine > 0.6){
        curve->m_p = 3.5;
    } else if (average_maxrgb_noLine > lowThreshold && average_maxrgb_noLine <= 0.6) {
        if (mode == PostprocessSDR){
            curve->m_p = 6.0 + (average_maxrgb_noLine - 0.1) / (0.6 - 0.1) * (3.5 - 6.0);
        }else if (mode == PostprocessHDR){
            curve->m_p = 4.0 + (average_maxrgb_noLine - 0.3) / (0.6 - 0.3) * (3.5 - 4.0);
        }
    }
    else{
        if (mode == PostprocessSDR){
            curve->m_p = 6.0;
        } else if (mode == PostprocessHDR){
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
    
    if (mode == PostprocessSDR){
        lowThreshold = 0.67;
        highThreshold = 0.75;
    } else /*(mode == PostprocessHDR)*/ {
        lowThreshold = 0.75;
        highThreshold = 0.9;
    }
    
    if (m_inputMaxE > highThreshold){
        curve->m_p = curve->m_p + 0.6;
    } else if (m_inputMaxE > lowThreshold && m_inputMaxE <= highThreshold){
        if (mode == PostprocessSDR){
            curve->m_p = curve->m_p + 0.3 + (m_inputMaxE - 0.67) / (0.75 - 0.67) * (0.6 - 0.3);
        } else if (mode == PostprocessHDR){
            curve->m_p = curve->m_p + 0.0 + (m_inputMaxE - 0.75) / (0.9 - 0.75) * (0.6 - 0.0);
        }
    } else {
        if (mode == PostprocessSDR){
            curve->m_p = curve->m_p + 0.3;
        }
        else if (mode == PostprocessHDR){
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
        if (mode == PostprocessSDR){
            s1 = 0.9;
        } else if (mode == PostprocessHDR){
            threshold1 = 0.1;
            s1 = 0.96;
        }
    } else if (average_maxrgb > 0.3 && average_maxrgb <= 0.6) {
        if (mode == PostprocessSDR){
            s1 = 1.0 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.9 - 1.0);
        }else if (mode == PostprocessHDR){
            threshold1 = 0.25 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.1 - 0.25);
            s1 = 1.0 + (average_maxrgb - 0.3) / (0.6 - 0.3) * (0.96 - 1.0);
        }
    } else{
        if (mode == PostprocessHDR){
            threshold1 = 0.25;
        }
        s1 = 1.0;
    }
    
    if (mode == PostprocessSDR){
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
    
    if (mode == PostprocessHDR)
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
                           device IJKHDRVividCurve *curve [[ buffer(1) ]]){
    
    thread float m_maxEtemp;
    thread float m_inputMaxEtemp;
    
    //         InitParams(maxDisplay, metadata, MasterDisplayPQ, &curve, GTMcurve2);
    
    float MaxDisplay = (float)(PQinverse(metadata->_max_display_luminance / 10000.0));
    float MinDisplay = (float)(PQinverse(0.05/10000.00));
    
    genBaseCurveParameter(metadata,
                          metadata->_masterDisplay,
                          MaxDisplay,
                          MinDisplay,
                          curve,
                          &m_maxEtemp,
                          &m_inputMaxEtemp,
                          PostprocessHDR);
    
    genCubicSplineParameter(metadata,
                            m_maxEtemp,
                            m_inputMaxEtemp,
                            curve,
                            PostprocessHDR);
    
    
        //float GTMcurve2[256] = { 0 };
    
    

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
        else  if ((max > TMP->TH3_HIGH) && (TMP->high_area_flag == 0))
        {
            max1 = (3 * TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + 2 * TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->mb2_high)*(max - TMP->TH3_HIGH)
                + TMP->md2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 3) + TMP->mc2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 2) + TMP->mb2_high * pow((TMP->TH3_HIGH - TMP->TH2_HIGH), 1) + TMP->ma2_high;
        }
        else
        {
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

float saturation_modify(float Y_PQ, float MaxDisplay,  device const IJKHDRVividMetadata *metadata, device const IJKHDRVividCurve *tone_mapping_param)
{
    float smCoef = 0.0;
    if (metadata->color_saturation_mapping_flag == 0)
    {
        smCoef = 1.0;
        return smCoef;
    }
    //apply C0
    float Yin_pq = Y_PQ;
    float Yout_pq = calc_curve(Yin_pq, tone_mapping_param);
    float power_used = float(metadata->color_saturation_gain[0]) / 128.0;
    float scale = Yout_pq / Yin_pq;
    smCoef = pow(scale, power_used);
    smCoef = dClip(smCoef, 0.8, 1.0);
    float B = getB(smCoef, MaxDisplay, tone_mapping_param->inputMaxEtemp_store, metadata, tone_mapping_param);

    //apply C1
    float SATR = 0.4;
    float C1 = 0.0;
    float C2 = 1.0;

    if ((metadata->color_saturation_mapping_flag) && (metadata->color_saturation_num > 1))
    {
        C1 = float(metadata->color_saturation_gain[1] & 0xFC) / 128.0;
        C2 = float(metadata->color_saturation_gain[1] & 0x3);
        C2 = pow(2, C2);
    }
    if (C1 == 0.0)
    {
        return B;
    }
    float Sca = 1.0;
    if (Yin_pq >= tone_mapping_param->RML)
    {
        if (B >= C1 * SATR) Sca = B - C1 * SATR;
        else Sca = 0;
        smCoef = Sca;
    }
    else if (Yin_pq >= tone_mapping_param->TML)
    {
        float ratioC = (Yin_pq - tone_mapping_param->TML) / (tone_mapping_param->RML - tone_mapping_param->TML);
        ratioC = pow(ratioC, C2);
        if (B >= C1 * SATR * ratioC)    Sca = B - C1 * SATR * ratioC;
        else Sca = 0;
        smCoef = Sca;
    }
    return smCoef;
}



//fragment float4 fragmentShader(RasterizerData input [[ stage_in ]],
//                               texture2d <ushort> yTexture [[ texture(0) ]],
//                               texture2d <ushort> uTexture [[ texture(1) ]],
//                               texture2d <ushort> vTexture [[ texture(2) ]],
//                               device const IJKHDRVividMetadata *metadata [[ buffer(1) ]],
//                               device const IJKHDRVividCurve *curve [[ buffer(2) ]]) {
//    
//    uint posX = uint(input.textureCoor.x * yTexture.get_width());
//    uint posY = uint(input.textureCoor.y * yTexture.get_height());
//    
//    uint uint4_y = yTexture.read(uint2(posX, posY)).r;
//    uint uint4_u = uTexture.read(uint2(posX/2, posY/2)).r;
//    uint uint4_v = vTexture.read(uint2(posX/2, posY/2)).r;
//    
//    uint3 yuv10bit = uint3(uint4_y , uint4_u , uint4_v);
//    
//    int y = int(yuv10bit.x);
//    int u = int(yuv10bit.y);
//    int v = int(yuv10bit.z);
//    
//    float3 rgb;
//    
//    // [64, 960]
//    float r = float(y - 64) * 1.164384                             - float(v - 512) * -1.67867;
//    float g = float(y - 64) * 1.164384 - float(u - 512) * 0.187326 - float(v - 512) * 0.65042;
//    float b = float(y - 64) * 1.164384 - float(u - 512) * -2.14177;
//    
//    rgb.r = r / 1024;
//    rgb.g = g / 1024;
//    rgb.b = b / 1024;
//    
//    //compute the maximum value of the three channel
//    
//    float comp0 = rgb.r;
//    float comp1 = rgb.g;
//    float comp2 = rgb.b;
//    
//    float maxComp0 = (float)(PQinverse(comp0 / 10000));
//    float maxComp1 = (float)(PQinverse(comp1 / 10000));
//    float maxComp2 = (float)(PQinverse(comp2 / 10000));
//    
//    float max =  FFMAX3( comp0,  comp1,  comp2);
//    float maxO = max;
//    float maxC = max;
//    
//    max = FFMAX3(maxComp0, maxComp1, maxComp2);
//    float max1 = max;
//    max1 = calc_curve(max, curve);
//    
//    float lumRatio;
//    {
//        if (max > 0) {
//            lumRatio = max1 / max;
//        } else {
//            lumRatio = 1.0;
//        }
//        maxC = (float)(10000 * PQforward(max1));
//        lumRatio = maxO <= 0 ? 1 : maxC / maxO;
//
//        comp0 = (float)lumRatio * y;
//        comp1 = (float)lumRatio * u;
//        comp2 = (float)lumRatio * v;
//
//        if (max)
//        {
//            comp0 = (float)(PQinverse(comp0 / 10000));
//            comp1 = (float)(PQinverse(comp1 / 10000));
//            comp2 = (float)(PQinverse(comp2 / 10000));
//
//            float Y = 0.262700 * comp0 + 0.678000 * comp1 + 0.059300 * comp2;
//            float U = -0.1396*comp0 - 0.3604*comp1 + 0.5*comp2;
//            float V = 0.5*comp0 - 0.4598*comp1 - 0.0402*comp2;
//
//            float smCoef = saturation_modify(max, curve->maxEtemp_store, metadata, curve);
//            U = U * smCoef;
//            V = V * smCoef;
//
//            comp0 = (float)(1.0000*Y - 0.0000*U + 1.4746*V);
//            comp1 = (float)(1.0000*Y - 0.1645*U - 0.5713*V);
//            comp2 = (float)(1.0000*Y + 1.8814*U - 0.0001*V);
//
//            comp0 = clip(comp0, 0.0f, 1.0f);
//            comp1 = clip(comp1, 0.0f, 1.0f);
//            comp2 = clip(comp2, 0.0f, 1.0f);
//
//            comp0 = (float)(PQforward(comp0) * 10000);
//            comp1 = (float)(PQforward(comp1) * 10000);
//            comp2 = (float)(PQforward(comp2) * 10000);
//        }
//    }
//    
//    rgb.r = comp0;
//    rgb.g = comp1;
//    rgb.b = comp2;
//    
//    
//    return float4(rgb + float3(0.0), 1.f);
//    
//
//}

float fAbs(float x) {
    return ((x) < 0) ? -(x) : (x);
}

float fSign(float x) {
    return ((x) < 0.0) ? -1.0f : 1.0f;
}

float fRound(float x) {
    return (fSign(x) * floor((fAbs(x) + 0.5f)));
}

//ushort3 getYUVFromTexture(uint2 coor,
//                         texture2d<ushort> const yTexture,
//                         texture2d<ushort> const uTexture,
//                         texture2d<ushort> const vTexture){
//    
//    ushort3 yuv;
//    yuv.x = yTexture.read(coor).r;
//    
//    int32_t Fixed32Filter[4][4];
//    Fixed32Filter[0][0] = (int32_t)fRound(-8.0);
//    Fixed32Filter[0][1] = (int32_t)fRound(64.0);
//    Fixed32Filter[0][2] = (int32_t)fRound(216.0);
//    Fixed32Filter[0][3] = (int32_t)fRound(-16.0);
//    Fixed32Filter[1][0] = (int32_t)fRound(-16.0);
//    Fixed32Filter[1][1] = (int32_t)fRound(216.0);
//    Fixed32Filter[1][2] = (int32_t)fRound(64.0);
//    Fixed32Filter[1][3] = (int32_t)fRound(-8.0);
//    Fixed32Filter[2][0] = (int32_t)fRound(0.0);
//    Fixed32Filter[2][1] = (int32_t)fRound(256.0);
//    Fixed32Filter[3][0] = (int32_t)fRound(-10.0);
//    Fixed32Filter[3][1] = (int32_t)fRound(138.0);
//    Fixed32Filter[3][2] = (int32_t)fRound(138.0);
//    Fixed32Filter[3][3] = (int32_t)fRound(-10.0);
//    
//    
//    int scalerX = coor.x / 2;
//    int scalerY = coor.y / 2;
//    int textureWidth =  yTexture.get_width();
//    int textureHeight = yTexture.get_height();
//    
//    int32_t Fixed32Data[4] = {0};
//    {
//        int m;
//        int value = 0;
//        for (m = 0; m < 4; m++) {
//            uint uValue = uTexture.read(uint2(scalerX, scalerY)).r;
//            value += Fixed32Filter[0][m] * uValue;
//        }
//        
//        Fixed32Data[(2 * j) * ((out->pic_width[k]) / 2) + i] = (value + 0) >> 0;
//    }
//    
//    
//}





fragment float4 fragmentShader(RasterizerData input [[ stage_in ]],
                               texture2d <ushort> yTexture [[ texture(0) ]],
                               texture2d <ushort> uTexture [[ texture(1) ]],
                               texture2d <ushort> vTexture [[ texture(2) ]],
                               device const IJKHDRVividMetadata *metadata [[ buffer(0) ]],
                               device const IJKHDRVividCurve *curve [[ buffer(1) ]]) {
    
    
    uint posX = uint(input.textureCoor.x * yTexture.get_width());
    uint posY = uint(input.textureCoor.y * yTexture.get_height());

    uint uint_y = yTexture.read(uint2(posX, posY)).r;
    uint uint_u = uTexture.read(uint2(posX/2, posY/2)).r;
    uint uint_z = vTexture.read(uint2(posX/2, posY/2)).r;
    
 
    int y = static_cast<int>(uint_y);
    int u = static_cast<int>(uint_u);
    int v = static_cast<int>(uint_z);
    
    // [64, 960]
    float r = float(y - 64) * 1.164384                             - float(v - 512) * -1.67867;
    float g = float(y - 64) * 1.164384 - float(u - 512) * 0.187326 - float(v - 512) * 0.65042;
    float b = float(y - 64) * 1.164384 - float(u - 512) * -2.14177;
    
    float floatX = clip((float)r / 1024.f, 0.0, 1.0);
    float floatY = clip((float)g / 1024.f, 0.0, 1.0);
    float floatZ = clip((float)b / 1024.f, 0.0, 1.0);
    

    float ScaleFactor = 10000.0;
    floatX = ScaleFactor *PQforward(floatX);
    floatY = ScaleFactor *PQforward(floatY);
    floatZ = ScaleFactor *PQforward(floatZ);

    float comp0 = floatX;
    float comp1 = floatY;
    float comp2 = floatZ;
    
        
    float maxComp0 = (float)(PQinverse(comp0 / 10000.f));
    float maxComp1 = (float)(PQinverse(comp1 / 10000.f));
    float maxComp2 = (float)(PQinverse(comp2 / 10000.f));
    

    float max = comp0 > comp1 ? comp0 : comp1;
    max = max > comp2 ? max : comp2;
    float maxO = max;
    float maxC = max;
    max = maxComp0 > maxComp1 ? maxComp0 : maxComp1;
    max = max > maxComp2 ? max : maxComp2;
    float max1 = max;
    max1 = calc_curve(max, curve);
    float lumRatio;
    {
        if (max > 0) {
            lumRatio = max1 / max;
        } else {
            lumRatio = 1.0;
        }
        maxC = (float)(10000.f * PQforward(max1));
        lumRatio = maxO <= 0 ? 1 : maxC / maxO;

        comp0 = (float)lumRatio * comp0;
        comp1 = (float)lumRatio * comp1;
        comp2 = (float)lumRatio * comp2;

        if (max)
        {
            comp0 = (float)(PQinverse(comp0 / 10000.0));
            comp1 = (float)(PQinverse(comp1 / 10000.0));
            comp2 = (float)(PQinverse(comp2 / 10000.0));

            float Y = 0.262700 * comp0 + 0.678000 * comp1 + 0.059300 * comp2;
            float U = -0.1396*comp0 - 0.3604*comp1 + 0.5*comp2;
            float V = 0.5*comp0 - 0.4598*comp1 - 0.0402*comp2;

            float smCoef = saturation_modify(max, curve->maxEtemp_store, metadata, curve);
            U = U * smCoef;
            V = V * smCoef;

            comp0 = (float)(1.0000*Y - 0.0000*U + 1.4746*V);
            comp1 = (float)(1.0000*Y - 0.1645*U - 0.5713*V);
            comp2 = (float)(1.0000*Y + 1.8814*U - 0.0001*V);

            comp0 = clip(comp0, 0.0f, 1.0f);
            comp1 = clip(comp1, 0.0f, 1.0f);
            comp2 = clip(comp2, 0.0f, 1.0f);
    
            comp0 = (float)(PQforward(comp0) * 10000.f);
            comp1 = (float)(PQforward(comp1) * 10000.f);
            comp2 = (float)(PQforward(comp2) * 10000.f);
        }
    }
    
    ScaleFactor = 10000.0;
    comp0 = (float)PQinverse((float)comp0 / ScaleFactor);
    comp1 = (float)PQinverse((float)comp1 / ScaleFactor);
    comp2 = (float)PQinverse((float)comp2 / ScaleFactor);

    return float4(float3(comp0, comp1, comp2), 1.f);


}
