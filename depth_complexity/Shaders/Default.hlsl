//***************************************************************************************
// Default.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Default shader, currently supports lighting.
//***************************************************************************************

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

Texture2D    gDiffuseMap : register(t0);

SamplerState gsamPointWrap        : register(s0);
SamplerState gsamPointClamp       : register(s1);
SamplerState gsamLinearWrap       : register(s2);
SamplerState gsamLinearClamp      : register(s3);
SamplerState gsamAnisotropicWrap  : register(s4);
SamplerState gsamAnisotropicClamp : register(s5);

// Constant data that varies per frame.
cbuffer cbPerObject : register(b0)
{
    float4x4 gWorld;
	float4x4 gTexTransform;
};

// Constant data that varies per pass.
cbuffer cbPass : register(b1)
{
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;

	// Allow application to change fog parameters once per frame.
	// For example, we may only use fog for certain times of day.
	float4 gFogColor;
	float gFogStart;
	float gFogRange;
	float2 cbPerObjectPad2;

    // Indices [0, NUM_DIR_LIGHTS) are directional lights;
    // indices [NUM_DIR_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHTS) are point lights;
    // indices [NUM_DIR_LIGHTS+NUM_POINT_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHT+NUM_SPOT_LIGHTS)
    // are spot lights for a maximum of MaxLights per object.
    Light gLights[MaxLights];
};

cbuffer cbMaterial : register(b2)
{
	float4   gDiffuseAlbedo;
    float3   gFresnelR0;
    float    gRoughness;
	float4x4 gMatTransform;
};

struct VertexIn
{
	float3 PosL : POSITION;
	float3 NormalL : NORMAL;
	float2 TexC : TEXCOORD;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
    float3 PosW    : POSITION;
    float3 NormalW : NORMAL;
	float2 TexC    : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout = (VertexOut) 0.0f;
	
    // Transform to world space.
	float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
	vout.PosW = posW.xyz;

    // Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
	vout.NormalW = mul(vin.NormalL, (float3x3) gWorld);

    // Transform to homogeneous clip space.
	vout.PosH = mul(posW, gViewProj);
	
	// Output vertex attributes for interpolation across triangle.
	float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gTexTransform);
	vout.TexC = mul(texC, gMatTransform).xy;

	return vout;
}

//VertexIn VS(VertexIn vin)
//{
//	return vin;
//}

//[maxvertexcount(6)]
//void GS(point VertexIn gin[3],
//        uint primID : SV_PrimitiveID,
//        inout TriangleStream<GeoOut> triStream)
//{
//    // �����е�
//	VertexIn m[3];
//	VertexIn outVerts[6];
//	m[0].PosL = 0.5f * (gin[0].PosL + gin[1].PosL);
//	m[1].PosL = 0.5f * (gin[1].PosL + gin[2].PosL);
//	m[2].PosL = 0.5f * (gin[2].PosL + gin[0].PosL);
    
//	m[0].PosL = normalize(m[0].PosL);
//	m[1].PosL = normalize(m[1].PosL);
//	m[2].PosL = normalize(m[2].PosL);
	
//	m[0].NormalL = m[0].PosL;
//	m[1].NormalL = m[1].PosL;
//	m[2].NormalL = m[2].PosL;
	
//	m[0].TexC = 0.5f * (gin[0].TexC + gin[1].TexC);
//	m[1].TexC = 0.5f * (gin[1].TexC + gin[2].TexC);
//	m[2].TexC = 0.5f * (gin[2].TexC + gin[0].TexC);
	
//	outVerts[0] = gin[0];
//	outVerts[1] = m[0];
//	outVerts[2] = m[2];
//	outVerts[3] = m[1];
//	outVerts[4] = gin[2];
//	outVerts[5] = gin[1];
	
//	GeoOut gout[6];
	
//	[unroll]
//	for (int i = 0; i < 6; ++i)
//	{
//		gout[i].PosW = mul(float4(outVerts[i].PosL, 1.0f), gWorld).xyz;
//		gout[i].NormalW = mul(outVerts[i].NormalL, (float3x3) gWorld);
//		gout[i].PosH = mul(float4(outVerts[i].PosL, 1.0f), gViewProj);
//		gout[i].TexC = outVerts[i].TexC;
//	}
	
//	[unroll]
//	for (int j = 0; j < 5; ++j)
//	{
//		triStream.Append(gout[j]);
//	}
//	triStream.RestartStrip();
//	triStream.Append(gout[1]);
//	triStream.Append(gout[5]);
//	triStream.Append(gout[3]);
//}

//float4 PS(GeoOut pin) : SV_Target
//{
//	float4 diffuseAlbedo = gDiffuseMap.Sample(gsamAnisotropicWrap, pin.TexC) * gDiffuseAlbedo;
	
//#ifdef ALPHA_TEST
//	// Discard pixel if texture alpha < 0.1.  We do this test as soon 
//	// as possible in the shader so that we can potentially exit the
//	// shader early, thereby skipping the rest of the shader code.
//	clip(diffuseAlbedo.a - 0.1f);
//#endif

//    // Interpolating normal can unnormalize it, so renormalize it.
//		pin.NormalW = normalize(pin.NormalW);

//    // Vector from point being lit to eye. 
//		float3 toEyeW = gEyePosW - pin.PosW;
//		float distToEye = length(toEyeW);
//		toEyeW /= distToEye; // normalize

//    // Light terms.
//		float4 ambient = gAmbientLight * diffuseAlbedo;

//		const float shininess = 1.0f - gRoughness;
//		Material mat = { diffuseAlbedo, gFresnelR0, shininess };
//		float3 shadowFactor = 1.0f;
//		float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
//        pin.NormalW, toEyeW, shadowFactor);

//		float4 litColor = ambient + directLight;

//#ifdef FOG
//	float fogAmount = saturate((distToEye - gFogStart) / gFogRange);
//	litColor = lerp(litColor, gFogColor, fogAmount);
//#endif

//    // Common convention to take alpha from diffuse albedo.
//		litColor.a = diffuseAlbedo.a;

//		return litColor;
//    //float4 col = { 1, 1, 1, 1 };
//    //return col;
//}


float4 PS(VertexOut pin) : SV_Target
{
	float4 diffuseAlbedo = gDiffuseMap.Sample(gsamAnisotropicWrap, pin.TexC) * gDiffuseAlbedo;
	
#ifdef ALPHA_TEST
	// Discard pixel if texture alpha < 0.1.  We do this test as soon 
	// as possible in the shader so that we can potentially exit the
	// shader early, thereby skipping the rest of the shader code.
	clip(diffuseAlbedo.a - 0.1f);
#endif

    // Interpolating normal can unnormalize it, so renormalize it.
	pin.NormalW = normalize(pin.NormalW);

    // Vector from point being lit to eye. 
	float3 toEyeW = gEyePosW - pin.PosW;
	float distToEye = length(toEyeW);
	toEyeW /= distToEye; // normalize

    // Light terms.
	float4 ambient = gAmbientLight * diffuseAlbedo;

	const float shininess = 1.0f - gRoughness;
	Material mat = { diffuseAlbedo, gFresnelR0, shininess };
	float3 shadowFactor = 1.0f;
	float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

	float4 litColor = ambient + directLight;

#ifdef FOG
	float fogAmount = saturate((distToEye - gFogStart) / gFogRange);
	litColor = lerp(litColor, gFogColor, fogAmount);
#endif

    // Common convention to take alpha from diffuse albedo.
	litColor.a = diffuseAlbedo.a;

	return litColor;
    //float4 col = { 1, 1, 1, 1 };
    //return col;
}


