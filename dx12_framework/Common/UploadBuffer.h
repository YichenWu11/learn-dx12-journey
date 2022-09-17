#pragma once

#include "d3dUtil.h"

template<typename T>
class UploadBuffer
{
public:
    // �����ڸ������͵��ϴ�������
    UploadBuffer(ID3D12Device* device, UINT elementCount, bool isConstantBuffer) : 
        mIsConstantBuffer(isConstantBuffer)
    {
        mElementByteSize = sizeof(T);

        // Constant buffer elements need to be multiples of 256 bytes.
        // This is because the hardware can only view constant data 
        // at m*256 byte offsets and of n*256 byte lengths. 
        // typedef struct D3D12_CONSTANT_BUFFER_VIEW_DESC {
        // UINT64 OffsetInBytes; // multiple of 256
        // UINT   SizeInBytes;   // multiple of 256
        // } D3D12_CONSTANT_BUFFER_VIEW_DESC;
        if(isConstantBuffer)
            mElementByteSize = d3dUtil::CalcConstantBufferByteSize(sizeof(T));

        // ����һ����Դ��һ���ѣ�������Դ�ύ������
        ThrowIfFailed(device->CreateCommittedResource(
            get_rvalue_ptr(CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_UPLOAD)), // �ϴ���
            D3D12_HEAP_FLAG_NONE,
            get_rvalue_ptr(CD3DX12_RESOURCE_DESC::Buffer(mElementByteSize*elementCount)), // elementCount��
			D3D12_RESOURCE_STATE_GENERIC_READ,
            nullptr,
            IID_PPV_ARGS(&mUploadBuffer)));

        // ͨ�� CPU��mMappedData��Ϊ������������Դ��������
        ThrowIfFailed(mUploadBuffer->Map(0, nullptr, reinterpret_cast<void**>(&mMappedData)));

        // ֻҪ�����޸ĵ�ǰ����Դ�����Ǿ�����ȡ��ӳ��
        // ���ǣ�����Դ��GPUʹ���ڼ䣬����ǧ�򲻿������Դ����д���������Ա��������ͬ��������
    }

    UploadBuffer(const UploadBuffer& rhs) = delete;
    UploadBuffer& operator=(const UploadBuffer& rhs) = delete;
    ~UploadBuffer()
    {
        if(mUploadBuffer != nullptr)
            // ���ͷ�ӳ���ڴ�֮ǰ�������ȡ��ӳ�����
            mUploadBuffer->Unmap(0, nullptr);

        mMappedData = nullptr;
    }

    ID3D12Resource* Resource()const
    {
        return mUploadBuffer.Get();  // ��ȡ�ϴ���������Դ
    }

    // ����Դ��CPU���Ƶ�Data��
    void CopyData(int elementIndex, const T& data)
    {
        memcpy(&mMappedData[elementIndex*mElementByteSize], &data, sizeof(T));
    }

private:
    Microsoft::WRL::ComPtr<ID3D12Resource> mUploadBuffer; // �ϴ�������
    BYTE* mMappedData = nullptr;  // map media

    UINT mElementByteSize = 0;
    bool mIsConstantBuffer = false;
};