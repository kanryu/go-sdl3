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

//go:embed shaders/triangle.vert.spv
var vertexShaderCode []byte

//go:embed shaders/triangle.frag.spv
var fragmentShaderCode []byte

func main() {
	runtime.LockOSThread()

	if !sdl.Init(sdl.InitVideo) {
		log.Fatalf("SDL_Init failed: %s", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("GoSDL3 Vulkan triangle", 800, 600, int(sdl.WindowResizable))
	if window == nil {
		log.Fatalf("SDL_CreateWindow failed: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)

	device := sdl.CreateGPUDevice(sdl.GPUShaderFormatSPIRV, false, "vulkan")
	if device == nil {
		log.Fatalf("SDL_CreateGPUDevice(vulkan) failed: %s", sdl.GetError())
	}
	defer sdl.DestroyGPUDevice(device)
	fmt.Printf("Using SDL_GPU driver: %s\n", sdl.GetGPUDeviceDriver(device))

	if !sdl.ClaimWindowForGPUDevice(device, window) {
		log.Fatalf("SDL_ClaimWindowForGPUDevice failed: %s", sdl.GetError())
	}
	defer sdl.ReleaseWindowFromGPUDevice(device, window)

	vertexEntrypoint := append([]byte("main"), 0)
	fragmentEntrypoint := append([]byte("main"), 0)
	vertexInfo := &sdl.GPUShaderCreateInfo{
		CodeSize:   uintptr(len(vertexShaderCode)),
		Code:       unsafe.Pointer(&vertexShaderCode[0]),
		Entrypoint: &vertexEntrypoint[0],
		Format:     sdl.GPUShaderFormatSPIRV,
		Stage:      sdl.GPUShaderStageVertex,
	}
	fragmentInfo := &sdl.GPUShaderCreateInfo{
		CodeSize:   uintptr(len(fragmentShaderCode)),
		Code:       unsafe.Pointer(&fragmentShaderCode[0]),
		Entrypoint: &fragmentEntrypoint[0],
		Format:     sdl.GPUShaderFormatSPIRV,
		Stage:      sdl.GPUShaderStageFragment,
	}
	vertexShader := sdl.CreateGPUShader(device, vertexInfo)
	if vertexShader == nil {
		log.Fatalf("SDL_CreateGPUShader(vertex) failed: %s", sdl.GetError())
	}
	defer sdl.ReleaseGPUShader(device, vertexShader)

	fragmentShader := sdl.CreateGPUShader(device, fragmentInfo)
	if fragmentShader == nil {
		log.Fatalf("SDL_CreateGPUShader(fragment) failed: %s", sdl.GetError())
	}
	defer sdl.ReleaseGPUShader(device, fragmentShader)

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
	if pipeline == nil {
		log.Fatalf("SDL_CreateGPUGraphicsPipeline failed: %s", sdl.GetError())
	}
	defer sdl.ReleaseGPUGraphicsPipeline(device, pipeline)

	fmt.Println("SDL_GPU Vulkan triangle sample started")
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
			time.Sleep(16 * time.Millisecond)
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
		time.Sleep(16 * time.Millisecond)
	}
}
