package sdl

import (
	"runtime"
	"unsafe"

	internal "github.com/kanryu/go-sdl3/internal/sdl"
)

// Opaque handles exposed by SDL_GPU.
type GPUDevice = internal.SDL_GPUDevice
type GPUCommandBuffer = internal.SDL_GPUCommandBuffer
type GPUTexture = internal.SDL_GPUTexture
type GPUShader = internal.SDL_GPUShader
type GPUGraphicsPipeline = internal.SDL_GPUGraphicsPipeline
type GPURenderPass = internal.SDL_GPURenderPass

type GPUShaderFormat = internal.SDL_GPUShaderFormat
type GPUPresentMode = internal.SDL_GPUPresentMode
type GPUSwapchainComposition = internal.SDL_GPUSwapchainComposition

type GPUShaderStage int32
type GPUPrimitiveType int32
type GPULoadOp int32
type GPUStoreOp int32
type GPUVertexInputRate int32
type GPUVertexElementFormat int32
type GPUFillMode int32
type GPUCullMode int32
type GPUFrontFace int32
type GPUTextureFormat int32

type GPUShaderCreateInfo struct {
	CodeSize           uintptr
	Code               unsafe.Pointer
	Entrypoint         *byte
	Format             GPUShaderFormat
	Stage              GPUShaderStage
	NumSamplers        uint32
	NumStorageTextures uint32
	NumStorageBuffers  uint32
	NumUniformBuffers  uint32
	Props              uint64
}

type GPUVertexBufferDescription struct {
	Slot             uint32
	Pitch            uint32
	InputRate        GPUVertexInputRate
	InstanceStepRate uint32
}

type GPUVertexAttribute struct {
	Location   uint32
	BufferSlot uint32
	Format     GPUVertexElementFormat
	Offset     uint32
}

type GPUVertexInputState struct {
	VertexBufferDescriptions *GPUVertexBufferDescription
	NumVertexBuffers         uint32
	VertexAttributes         *GPUVertexAttribute
	NumVertexAttributes      uint32
}

type GPURasterizerState struct {
	FillMode                GPUFillMode
	CullMode                GPUCullMode
	FrontFace               GPUFrontFace
	DepthBiasConstantFactor float32
	DepthBiasClamp          float32
	DepthBiasSlopeFactor    float32
	EnableDepthBias         bool
	EnableDepthClip         bool
	Padding1                byte
	Padding2                byte
}

type GPUMultisampleState struct {
	SampleCount           int32
	SampleMask            uint32
	EnableMask            bool
	EnableAlphaToCoverage bool
	Padding2              byte
	Padding3              byte
}

type GPUStencilOpState struct {
	FailOp      int32
	PassOp      int32
	DepthFailOp int32
	CompareOp   int32
}

type GPUDepthStencilState struct {
	CompareOp         int32
	BackStencilState  GPUStencilOpState
	FrontStencilState GPUStencilOpState
	CompareMask       byte
	WriteMask         byte
	EnableDepthTest   bool
	EnableDepthWrite  bool
	EnableStencilTest bool
	Padding1          byte
	Padding2          byte
	Padding3          byte
}

type GPUColorTargetBlendState struct {
	SrcColorBlendFactor  int32
	DstColorBlendFactor  int32
	ColorBlendOp         int32
	SrcAlphaBlendFactor  int32
	DstAlphaBlendFactor  int32
	AlphaBlendOp         int32
	ColorWriteMask       byte
	EnableBlend          bool
	EnableColorWriteMask bool
	Padding1             byte
	Padding2             byte
}

type GPUColorTargetDescription struct {
	Format     GPUTextureFormat
	BlendState GPUColorTargetBlendState
}

type GPUGraphicsPipelineTargetInfo struct {
	ColorTargetDescriptions *GPUColorTargetDescription
	NumColorTargets         uint32
	DepthStencilFormat      GPUTextureFormat
	HasDepthStencilTarget   bool
	Padding1                byte
	Padding2                byte
	Padding3                byte
}

type GPUGraphicsPipelineCreateInfo struct {
	VertexShader      GPUShader
	FragmentShader    GPUShader
	VertexInputState  GPUVertexInputState
	PrimitiveType     GPUPrimitiveType
	RasterizerState   GPURasterizerState
	MultisampleState  GPUMultisampleState
	DepthStencilState GPUDepthStencilState
	TargetInfo        GPUGraphicsPipelineTargetInfo
	Props             uint64
}

type FColor struct{ R, G, B, A float32 }

type GPUColorTargetInfo struct {
	Texture             GPUTexture
	MipLevel            uint32
	LayerOrDepthPlane   uint32
	ClearColor          FColor
	LoadOp              GPULoadOp
	StoreOp             GPUStoreOp
	ResolveTexture      GPUTexture
	ResolveMipLevel     uint32
	ResolveLayer        uint32
	Cycle               bool
	CycleResolveTexture bool
	Padding1            byte
	Padding2            byte
}

const (
	GPUShaderStageVertex         GPUShaderStage         = 0
	GPUShaderStageFragment       GPUShaderStage         = 1
	GPUPrimitiveTypeTriangleList GPUPrimitiveType       = 0
	GPULoadOpLoad                GPULoadOp              = 0
	GPULoadOpClear               GPULoadOp              = 1
	GPUStoreOpStore              GPUStoreOp             = 0
	GPUVertexInputRateVertex     GPUVertexInputRate     = 0
	GPUVertexElementFormatFloat2 GPUVertexElementFormat = 10
	GPUVertexElementFormatFloat4 GPUVertexElementFormat = 12
	GPUFillModeFill              GPUFillMode            = 0
	GPUCullModeNone              GPUCullMode            = 0
	GPUFrontFaceCounterClockwise GPUFrontFace           = 0
)

const (
	GPUShaderFormatInvalid  GPUShaderFormat = 0
	GPUShaderFormatPrivate  GPUShaderFormat = 1 << 0
	GPUShaderFormatSPIRV    GPUShaderFormat = 1 << 1
	GPUShaderFormatDXBC     GPUShaderFormat = 1 << 2
	GPUShaderFormatDXIL     GPUShaderFormat = 1 << 3
	GPUShaderFormatMSL      GPUShaderFormat = 1 << 4
	GPUShaderFormatMetalLib GPUShaderFormat = 1 << 5
)

const (
	GPUPresentModeVSync     GPUPresentMode = 0
	GPUPresentModeImmediate GPUPresentMode = 1
	GPUPresentModeMailbox   GPUPresentMode = 2
)

const (
	GPUSwapchainCompositionSDR               GPUSwapchainComposition = 0
	GPUSwapchainCompositionSDRLinear         GPUSwapchainComposition = 1
	GPUSwapchainCompositionHDRExtendedLinear GPUSwapchainComposition = 2
	GPUSwapchainCompositionHDR10ST2084       GPUSwapchainComposition = 3
)

// CreateGPUDevice creates an SDL GPU device. The name can be "vulkan",
// "direct3d12", "metal", or empty to let SDL choose the backend.
func CreateGPUDevice(format GPUShaderFormat, debug bool, name string) GPUDevice {
	nameBytes := append([]byte(name), 0)
	device := internal.CreateGPUDevice(int(format), debug, &nameBytes[0])
	runtime.KeepAlive(nameBytes)
	return device
}

func DestroyGPUDevice(device GPUDevice) {
	if device != nil {
		internal.DestroyGPUDevice(device)
	}
}

func ClaimWindowForGPUDevice(device GPUDevice, window *Window) bool {
	return device != nil && window != nil && window.ptr != nil && internal.ClaimWindowForGPUDevice(device, window.ptr)
}

func ReleaseWindowFromGPUDevice(device GPUDevice, window *Window) {
	if device != nil && window != nil && window.ptr != nil {
		internal.ReleaseWindowFromGPUDevice(device, window.ptr)
	}
}

func AcquireGPUCommandBuffer(device GPUDevice) GPUCommandBuffer {
	if device == nil {
		return nil
	}
	return internal.AcquireGPUCommandBuffer(device)
}

// AcquireGPUSwapchainTexture acquires the current swapchain texture and its size.
func AcquireGPUSwapchainTexture(commandBuffer GPUCommandBuffer, window *Window) (GPUTexture, uint32, uint32, bool) {
	if commandBuffer == nil || window == nil || window.ptr == nil {
		return nil, 0, 0, false
	}
	var texture GPUTexture
	var width, height uint32
	ok := internal.AcquireGPUSwapchainTexture(
		commandBuffer,
		window.ptr,
		(*byte)(unsafe.Pointer(&texture)),
		(*byte)(unsafe.Pointer(&width)),
		(*byte)(unsafe.Pointer(&height)),
	)
	runtime.KeepAlive(window)
	return texture, width, height, ok
}

func SubmitGPUCommandBuffer(commandBuffer GPUCommandBuffer) bool {
	return commandBuffer != nil && internal.SubmitGPUCommandBuffer(commandBuffer)
}

func CancelGPUCommandBuffer(commandBuffer GPUCommandBuffer) bool {
	return commandBuffer != nil && internal.CancelGPUCommandBuffer(commandBuffer)
}

func SetGPUSwapchainParameters(device GPUDevice, window *Window, composition GPUSwapchainComposition, presentMode GPUPresentMode) bool {
	return device != nil && window != nil && window.ptr != nil && internal.SetGPUSwapchainParameters(device, window.ptr, int(composition), int(presentMode))
}

func GetGPUDeviceDriver(device GPUDevice) string {
	if device == nil {
		return ""
	}
	return internal.GetGPUDeviceDriver(device)
}

func GetGPUShaderFormats(device GPUDevice) GPUShaderFormat {
	if device == nil {
		return GPUShaderFormatInvalid
	}
	return GPUShaderFormat(internal.GetGPUShaderFormats(device))
}

func GetGPUSwapchainTextureFormat(device GPUDevice, window *Window) int {
	if device == nil || window == nil || window.ptr == nil {
		return 0
	}
	return internal.GetGPUSwapchainTextureFormat(device, window.ptr)
}

func WaitForGPUSwapchain(device GPUDevice, window *Window) bool {
	return device != nil && window != nil && window.ptr != nil && internal.WaitForGPUSwapchain(device, window.ptr)
}

func WaitForGPUIdle(device GPUDevice) bool {
	return device != nil && internal.WaitForGPUIdle(device)
}

func CreateGPUShader(device GPUDevice, info *GPUShaderCreateInfo) GPUShader {
	if device == nil || info == nil {
		return nil
	}
	return internal.CreateGPUShader(device, (*byte)(unsafe.Pointer(info)))
}

func ReleaseGPUShader(device GPUDevice, shader GPUShader) {
	if device != nil && shader != nil {
		internal.ReleaseGPUShader(device, shader)
	}
}

func CreateGPUGraphicsPipeline(device GPUDevice, info *GPUGraphicsPipelineCreateInfo) GPUGraphicsPipeline {
	if device == nil || info == nil {
		return nil
	}
	return internal.CreateGPUGraphicsPipeline(device, (*byte)(unsafe.Pointer(info)))
}

func ReleaseGPUGraphicsPipeline(device GPUDevice, pipeline GPUGraphicsPipeline) {
	if device != nil && pipeline != nil {
		internal.ReleaseGPUGraphicsPipeline(device, pipeline)
	}
}

func BeginGPURenderPass(commandBuffer GPUCommandBuffer, colors []GPUColorTargetInfo) GPURenderPass {
	if commandBuffer == nil || len(colors) == 0 {
		return nil
	}
	return internal.BeginGPURenderPass(commandBuffer, (*byte)(unsafe.Pointer(&colors[0])), uint32(len(colors)), nil)
}

func BindGPUGraphicsPipeline(renderPass GPURenderPass, pipeline GPUGraphicsPipeline) {
	if renderPass != nil && pipeline != nil {
		internal.BindGPUGraphicsPipeline(renderPass, pipeline)
	}
}

func DrawGPUPrimitives(renderPass GPURenderPass, vertexCount, instanceCount, firstVertex, firstInstance uint32) {
	if renderPass != nil {
		internal.DrawGPUPrimitives(renderPass, vertexCount, instanceCount, firstVertex, firstInstance)
	}
}

func EndGPURenderPass(renderPass GPURenderPass) {
	if renderPass != nil {
		internal.EndGPURenderPass(renderPass)
	}
}
