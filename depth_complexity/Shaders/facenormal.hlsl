#include "LightingUtil.hlsl"

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
	float4 gDiffuseAlbedo;
	float3 gFresnelR0;
	float gRoughness;
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
	float3 PosL : POSITION;
	float3 NormalL : NORMAL;
	float2 TexC : TEXCOORD;
};

struct GeoOut
{
	float4 PosH : SV_POSITION;
	float3 PosW : POSITION;
	float3 NormalW : NORMAL;
	float2 TexC : TEXCOORD;
	uint PrimID : SV_PrimitiveID;
};

VertexOut VS(VertexIn vin)
{
	VertexOut output;
	
	output.PosL    = vin.PosL;
	output.NormalL = vin.NormalL;
	output.TexC    = vin.TexC;
	
	return output;
}

[maxvertexcount(2)]
void GS(point VertexOut gin[1],
		uint prim_ID : SV_PrimitiveID,
		inout LineStream<GeoOut> lineOutStream)
{
	float len = 2.0f; // 绘制的法线的长度
	
	GeoOut gout[2];


	gout[0].NormalW = mul(gin[0].NormalL, (float3x3) gWorld);
	gout[1].NormalW = mul(gin[0].NormalL, (float3x3) gWorld);
	gout[0].PosW = float4(gin[0].PosL, 1.0f);
	gout[1].PosW = gout[0].PosH + float4(len * gin[0].NormalL, 0.0f);

	[unroll]
	for (int i = 0; i < 2; ++i)
	{
		float4 PosW = mul(float4(gout[i].PosW,1.0f), gWorld);
		gout[i].PosH = mul(PosW, gViewProj);
		if (i == 1) {
			float3 tmp = 2 * gout[0].PosH.xyz - gout[1].PosH.xyz;
			gout[1].PosH.xyz = tmp;
		}

		lineOutStream.Append(gout[i]);
	}
}

float4 PS(GeoOut pin) : SV_Target
{
	return float4(0, 0, 1, 1);
}
