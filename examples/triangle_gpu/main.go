package main

import (
	_ "embed"
	"fmt"
	"log"
	"runtime"
	"time"
	"unsafe"

	"github.com/kanryu/go-sdl3/sdl"
)

//go:embed shaders/triangle.vert.dxil
var vertexShaderCode []byte

//go:embed shaders/triangle.frag.dxil
var fragmentShaderCode []byte

func main() {
	runtime.LockOSThread()

	if !sdl.Init(sdl.InitVideo) {
		log.Fatalf("SDL_Init failed: %s", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("GoSDL3 SDL_GPU triangle", 800, 600, int(sdl.WindowResizable))
	if window == nil {
		log.Fatalf("SDL_CreateWindow failed: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)

	device := sdl.CreateGPUDevice(sdl.GPUShaderFormatDXIL, false, "direct3d12")
	if device == nil {
		log.Fatalf("SDL_CreateGPUDevice failed: %s", sdl.GetError())
	}
	defer sdl.DestroyGPUDevice(device)

	if !sdl.ClaimWindowForGPUDevice(device, window) {
		log.Fatalf("SDL_ClaimWindowForGPUDevice failed: %s", sdl.GetError())
	}
	defer sdl.ReleaseWindowFromGPUDevice(device, window)

	vertexEntrypoint := append([]byte("vertex_main"), 0)
	fragmentEntrypoint := append([]byte("fragment_main"), 0)
	vertexInfo := &sdl.GPUShaderCreateInfo{
		CodeSize:   uintptr(len(vertexShaderCode)),
		Code:       unsafePointer(vertexShaderCode),
		Entrypoint: &vertexEntrypoint[0],
		Format:     sdl.GPUShaderFormatDXIL,
		Stage:      sdl.GPUShaderStageVertex,
	}
	fragmentInfo := &sdl.GPUShaderCreateInfo{
		CodeSize:   uintptr(len(fragmentShaderCode)),
		Code:       unsafePointer(fragmentShaderCode),
		Entrypoint: &fragmentEntrypoint[0],
		Format:     sdl.GPUShaderFormatDXIL,
		Stage:      sdl.GPUShaderStageFragment,
	}
	vertexShader := sdl.CreateGPUShader(device, vertexInfo)
	fragmentShader := sdl.CreateGPUShader(device, fragmentInfo)
	if vertexShader == nil || fragmentShader == nil {
		log.Fatalf("SDL_CreateGPUShader failed: %s", sdl.GetError())
	}

	format := sdl.GPUTextureFormat(sdl.GetGPUSwapchainTextureFormat(device, window))
	pipelineInfo := &sdl.GPUGraphicsPipelineCreateInfo{
		VertexShader:   vertexShader,
		FragmentShader: fragmentShader,
		PrimitiveType:  sdl.GPUPrimitiveTypeTriangleList,
		RasterizerState: sdl.GPURasterizerState{
			FillMode:  sdl.GPUFillModeFill,
			CullMode:  sdl.GPUCullModeNone,
			FrontFace: sdl.GPUFrontFaceCounterClockwise,
		},
		TargetInfo: sdl.GPUGraphicsPipelineTargetInfo{
			ColorTargetDescriptions: &sdl.GPUColorTargetDescription{Format: format},
			NumColorTargets:         1,
		},
	}
	pipeline := sdl.CreateGPUGraphicsPipeline(device, pipelineInfo)
	sdl.ReleaseGPUShader(device, vertexShader)
	sdl.ReleaseGPUShader(device, fragmentShader)
	if pipeline == nil {
		log.Fatalf("SDL_CreateGPUGraphicsPipeline failed: %s", sdl.GetError())
	}
	defer sdl.ReleaseGPUGraphicsPipeline(device, pipeline)

	fmt.Printf("SDL_GPU triangle sample started (%s)\n", sdl.GetGPUDeviceDriver(device))
	for {
		for {
			event, ok := sdl.PollEventTyped()
			if !ok {
				break
			}
			if windowEvent, ok := event.(sdl.WindowEvent); ok && windowEvent.Type == sdl.EventWindowClose {
				return
			}
			if _, ok := event.(sdl.QuitEvent); ok {
				return
			}
		}

		commandBuffer := sdl.AcquireGPUCommandBuffer(device)
		if commandBuffer == nil {
			log.Fatalf("SDL_AcquireGPUCommandBuffer failed: %s", sdl.GetError())
		}
		texture, _, _, ok := sdl.AcquireGPUSwapchainTexture(commandBuffer, window)
		if !ok {
			sdl.CancelGPUCommandBuffer(commandBuffer)
			time.Sleep(time.Millisecond * 16)
			continue
		}

		colors := []sdl.GPUColorTargetInfo{{
			Texture:    texture,
			ClearColor: sdl.FColor{R: 0.05, G: 0.07, B: 0.12, A: 1},
			LoadOp:     sdl.GPULoadOpClear,
			StoreOp:    sdl.GPUStoreOpStore,
		}}
		pass := sdl.BeginGPURenderPass(commandBuffer, colors)
		if pass == nil {
			sdl.CancelGPUCommandBuffer(commandBuffer)
			log.Fatalf("SDL_BeginGPURenderPass failed: %s", sdl.GetError())
		}
		sdl.BindGPUGraphicsPipeline(pass, pipeline)
		sdl.DrawGPUPrimitives(pass, 3, 1, 0, 0)
		sdl.EndGPURenderPass(pass)
		if !sdl.SubmitGPUCommandBuffer(commandBuffer) {
			log.Fatalf("SDL_SubmitGPUCommandBuffer failed: %s", sdl.GetError())
		}
		time.Sleep(time.Millisecond * 16)
	}
}

func unsafePointer(data []byte) unsafe.Pointer {
	if len(data) == 0 {
		return nil
	}
	return unsafe.Pointer(&data[0])
}
