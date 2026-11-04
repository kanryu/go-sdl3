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

type GPUShaderFormat = internal.SDL_GPUShaderFormat
type GPUPresentMode = internal.SDL_GPUPresentMode
type GPUSwapchainComposition = internal.SDL_GPUSwapchainComposition

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
