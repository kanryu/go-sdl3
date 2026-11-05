//go:build linux && amd64

package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"runtime"
	"unsafe"

	"bnema.dev/purego-vulkan/vulkan"
)

type renderer struct {
	sdl    *sdlAPI
	window uintptr

	instance       vulkan.Instance
	instanceAPI    *vulkan.InstanceDispatch
	surface        vulkan.SurfaceKHR
	physicalDevice vulkan.PhysicalDevice
	device         vulkan.Device
	deviceAPI      *vulkan.DeviceDispatch
	queue          vulkan.Queue
	queueFamily    uint32

	swapchain vulkan.SwapchainKHR
	extent    vulkan.Extent2D
	format    vulkan.Format
	views     []vulkan.ImageView

	pipelineLayout vulkan.PipelineLayout
	pipeline       vulkan.Pipeline
	commandPool    vulkan.CommandPool
	commandBuffer  vulkan.CommandBuffer
	imageAvailable vulkan.Semaphore
	renderFinished vulkan.Semaphore
}

func newRenderer(sdl *sdlAPI, window uintptr, extensions []*byte, vertexCode, fragmentCode []byte) (_ *renderer, retErr error) {
	r := &renderer{sdl: sdl, window: window}
	defer func() {
		if retErr != nil {
			retErr = errors.Join(retErr, r.close())
		}
	}()

	if err := vulkan.Init(); err != nil {
		return nil, fmt.Errorf("initialize Vulkan loader: %w", err)
	}

	appName := []byte("go-sdl3 pure Go Vulkan triangle\x00")
	engineName := []byte("go-sdl3\x00")
	application := vulkan.ApplicationInfo{
		SType:              vulkan.StructureTypeApplicationInfo,
		ApplicationName:    &appName[0],
		ApplicationVersion: vulkan.MakeVersion(1, 0, 0),
		EngineName:         &engineName[0],
		EngineVersion:      vulkan.MakeVersion(1, 0, 0),
		ApiVersion:         vulkan.MakeVersion(1, 3, 0),
	}
	instanceInfo := vulkan.InstanceCreateInfo{
		SType:                   vulkan.StructureTypeInstanceCreateInfo,
		ApplicationInfo:         &application,
		EnabledExtensionCount:   uint32(len(extensions)),
		PpEnabledExtensionNames: &extensions[0],
	}
	if err := vulkan.Check(vulkan.Global().CreateInstance(&instanceInfo, nil, &r.instance)); err != nil {
		return nil, fmt.Errorf("vkCreateInstance: %w", err)
	}
	runtime.KeepAlive(appName)
	runtime.KeepAlive(engineName)
	runtime.KeepAlive(extensions)

	r.instanceAPI, retErr = vulkan.LoadInstanceDispatch(r.instance)
	if retErr != nil {
		return nil, fmt.Errorf("load Vulkan instance functions: %w", retErr)
	}
	var surface uint64
	if !sdl.vulkanCreateSurface(window, uintptr(r.instance), 0, &surface) {
		return nil, fmt.Errorf("SDL_Vulkan_CreateSurface failed: %s", sdl.errorString())
	}
	r.surface = vulkan.SurfaceKHR(surface)

	if err := r.selectPhysicalDevice(); err != nil {
		return nil, err
	}
	if err := r.createLogicalDevice(); err != nil {
		return nil, err
	}
	if err := r.createSwapchain(); err != nil {
		return nil, err
	}
	if err := r.createImageViews(); err != nil {
		return nil, err
	}
	if err := r.createGraphicsPipeline(vertexCode, fragmentCode); err != nil {
		return nil, err
	}
	if err := r.createCommandsAndSync(); err != nil {
		return nil, err
	}
	return r, nil
}

func (r *renderer) selectPhysicalDevice() error {
	var count uint32
	if err := vulkan.Check(r.instanceAPI.EnumeratePhysicalDevices(r.instance, &count, nil)); err != nil {
		return fmt.Errorf("vkEnumeratePhysicalDevices(count): %w", err)
	}
	if count == 0 {
		return errors.New("Vulkan reports no physical devices")
	}
	devices := make([]vulkan.PhysicalDevice, count)
	if err := vulkan.Check(r.instanceAPI.EnumeratePhysicalDevices(r.instance, &count, &devices[0])); err != nil {
		return fmt.Errorf("vkEnumeratePhysicalDevices: %w", err)
	}

	for _, device := range devices {
		queueFamily, ok, err := r.findGraphicsPresentQueue(device)
		if err != nil {
			return err
		}
		if !ok {
			continue
		}

		dynamicRendering := vulkan.PhysicalDeviceDynamicRenderingFeatures{
			SType: vulkan.StructureTypePhysicalDeviceDynamicRenderingFeatures,
		}
		features := vulkan.PhysicalDeviceFeatures2{
			SType: vulkan.StructureTypePhysicalDeviceFeatures2,
			Next:  unsafe.Pointer(&dynamicRendering),
		}
		r.instanceAPI.GetPhysicalDeviceFeatures2(device, &features)
		if dynamicRendering.DynamicRendering == 0 {
			continue
		}
		r.physicalDevice = device
		r.queueFamily = queueFamily
		return nil
	}
	return errors.New("no Vulkan device supports both presentation and dynamic rendering")
}

func (r *renderer) findGraphicsPresentQueue(device vulkan.PhysicalDevice) (uint32, bool, error) {
	var count uint32
	r.instanceAPI.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)
	if count == 0 {
		return 0, false, nil
	}
	properties := make([]vulkan.QueueFamilyProperties, count)
	r.instanceAPI.GetPhysicalDeviceQueueFamilyProperties(device, &count, &properties[0])

	for index, property := range properties {
		if property.QueueCount == 0 || property.QueueFlags&vulkan.QueueGraphicsBit == 0 {
			continue
		}
		var supported vulkan.Bool32
		if err := vulkan.Check(r.instanceAPI.GetPhysicalDeviceSurfaceSupportKHR(device, uint32(index), r.surface, &supported)); err != nil {
			return 0, false, fmt.Errorf("vkGetPhysicalDeviceSurfaceSupportKHR: %w", err)
		}
		if supported != 0 {
			return uint32(index), true, nil
		}
	}
	return 0, false, nil
}

func (r *renderer) createLogicalDevice() error {
	priority := float32(1)
	queueInfo := vulkan.DeviceQueueCreateInfo{
		SType:            vulkan.StructureTypeDeviceQueueCreateInfo,
		QueueFamilyIndex: r.queueFamily,
		QueueCount:       1,
		QueuePriorities:  &priority,
	}
	dynamicRendering := vulkan.PhysicalDeviceDynamicRenderingFeatures{
		SType:            vulkan.StructureTypePhysicalDeviceDynamicRenderingFeatures,
		DynamicRendering: 1,
	}
	swapchainExtension := []byte("VK_KHR_swapchain\x00")
	swapchainExtensionPtr := &swapchainExtension[0]
	deviceInfo := vulkan.DeviceCreateInfo{
		SType:                   vulkan.StructureTypeDeviceCreateInfo,
		Next:                    unsafe.Pointer(&dynamicRendering),
		QueueCreateInfoCount:    1,
		QueueCreateInfos:        &queueInfo,
		EnabledExtensionCount:   1,
		PpEnabledExtensionNames: &swapchainExtensionPtr,
	}
	if err := vulkan.Check(r.instanceAPI.CreateDevice(r.physicalDevice, &deviceInfo, nil, &r.device)); err != nil {
		return fmt.Errorf("vkCreateDevice: %w", err)
	}
	runtime.KeepAlive(swapchainExtension)

	deviceAPI, err := vulkan.LoadDeviceDispatch(r.instanceAPI, r.device)
	if err != nil {
		return fmt.Errorf("load Vulkan device functions: %w", err)
	}
	r.deviceAPI = deviceAPI
	if !r.deviceAPI.HasCmdBeginRendering() || !r.deviceAPI.HasCmdEndRendering() {
		return errors.New("Vulkan device does not expose core dynamic-rendering commands")
	}
	r.deviceAPI.GetDeviceQueue(r.device, r.queueFamily, 0, &r.queue)
	return nil
}

func (r *renderer) createSwapchain() error {
	var capabilities vulkan.SurfaceCapabilitiesKHR
	if err := vulkan.Check(r.instanceAPI.GetPhysicalDeviceSurfaceCapabilitiesKHR(r.physicalDevice, r.surface, &capabilities)); err != nil {
		return fmt.Errorf("vkGetPhysicalDeviceSurfaceCapabilitiesKHR: %w", err)
	}
	if capabilities.SupportedUsageFlags&vulkan.ImageUsageColorAttachmentBit == 0 {
		return errors.New("Vulkan surface does not support color-attachment swapchain images")
	}

	var formatCount uint32
	if err := vulkan.Check(r.instanceAPI.GetPhysicalDeviceSurfaceFormatsKHR(r.physicalDevice, r.surface, &formatCount, nil)); err != nil {
		return fmt.Errorf("vkGetPhysicalDeviceSurfaceFormatsKHR(count): %w", err)
	}
	if formatCount == 0 {
		return errors.New("Vulkan surface reports no swapchain formats")
	}
	formats := make([]vulkan.SurfaceFormatKHR, formatCount)
	if err := vulkan.Check(r.instanceAPI.GetPhysicalDeviceSurfaceFormatsKHR(r.physicalDevice, r.surface, &formatCount, &formats[0])); err != nil {
		return fmt.Errorf("vkGetPhysicalDeviceSurfaceFormatsKHR: %w", err)
	}
	surfaceFormat := chooseSurfaceFormat(formats)
	r.format = surfaceFormat.Format

	r.extent = capabilities.CurrentExtent
	if r.extent.Width == ^uint32(0) {
		var width, height int32
		if !r.sdl.getWindowSizeInPixels(r.window, &width, &height) || width <= 0 || height <= 0 {
			return fmt.Errorf("SDL_GetWindowSizeInPixels failed: %s", r.sdl.errorString())
		}
		r.extent.Width = clamp(uint32(width), capabilities.MinImageExtent.Width, capabilities.MaxImageExtent.Width)
		r.extent.Height = clamp(uint32(height), capabilities.MinImageExtent.Height, capabilities.MaxImageExtent.Height)
	}

	imageCount := capabilities.MinImageCount + 1
	if capabilities.MaxImageCount != 0 && imageCount > capabilities.MaxImageCount {
		imageCount = capabilities.MaxImageCount
	}
	compositeAlpha, ok := chooseCompositeAlpha(capabilities.SupportedCompositeAlpha)
	if !ok {
		return errors.New("Vulkan surface reports no supported composite-alpha mode")
	}
	swapchainInfo := vulkan.SwapchainCreateInfoKHR{
		SType:            vulkan.StructureTypeSwapchainCreateInfoKHR,
		Surface:          r.surface,
		MinImageCount:    imageCount,
		ImageFormat:      surfaceFormat.Format,
		ImageColorSpace:  surfaceFormat.ColorSpace,
		ImageExtent:      r.extent,
		ImageArrayLayers: 1,
		ImageUsage:       vulkan.ImageUsageColorAttachmentBit,
		ImageSharingMode: vulkan.SharingModeExclusive,
		PreTransform:     capabilities.CurrentTransform,
		CompositeAlpha:   compositeAlpha,
		PresentMode:      vulkan.PresentModeFifoKHR,
		Clipped:          1,
	}
	if err := vulkan.Check(r.deviceAPI.CreateSwapchainKHR(r.device, &swapchainInfo, nil, &r.swapchain)); err != nil {
		return fmt.Errorf("vkCreateSwapchainKHR: %w", err)
	}
	return nil
}

func chooseSurfaceFormat(formats []vulkan.SurfaceFormatKHR) vulkan.SurfaceFormatKHR {
	for _, format := range formats {
		if format.Format == vulkan.FormatB8g8r8a8Unorm {
			return format
		}
	}
	for _, format := range formats {
		if format.Format == vulkan.FormatR8g8b8a8Unorm {
			return format
		}
	}
	chosen := formats[0]
	if chosen.Format == vulkan.FormatUndefined {
		chosen.Format = vulkan.FormatB8g8r8a8Unorm
	}
	return chosen
}

func chooseCompositeAlpha(supported vulkan.CompositeAlphaFlagsKHR) (vulkan.CompositeAlphaFlagBitsKHR, bool) {
	for _, mode := range []vulkan.CompositeAlphaFlagBitsKHR{
		vulkan.CompositeAlphaOpaqueBitKHR,
		vulkan.CompositeAlphaPreMultipliedBitKHR,
		vulkan.CompositeAlphaPostMultipliedBitKHR,
		vulkan.CompositeAlphaInheritBitKHR,
	} {
		if supported&vulkan.CompositeAlphaFlagsKHR(mode) != 0 {
			return mode, true
		}
	}
	return 0, false
}

func clamp(value, minimum, maximum uint32) uint32 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

func (r *renderer) createImageViews() error {
	var count uint32
	if err := vulkan.Check(r.deviceAPI.GetSwapchainImagesKHR(r.device, r.swapchain, &count, nil)); err != nil {
		return fmt.Errorf("vkGetSwapchainImagesKHR(count): %w", err)
	}
	if count == 0 {
		return errors.New("Vulkan swapchain has no images")
	}
	images := make([]vulkan.Image, count)
	if err := vulkan.Check(r.deviceAPI.GetSwapchainImagesKHR(r.device, r.swapchain, &count, &images[0])); err != nil {
		return fmt.Errorf("vkGetSwapchainImagesKHR: %w", err)
	}
	r.views = make([]vulkan.ImageView, 0, len(images))
	for _, image := range images {
		viewInfo := vulkan.ImageViewCreateInfo{
			SType:    vulkan.StructureTypeImageViewCreateInfo,
			Image:    image,
			ViewType: vulkan.ImageViewType2d,
			Format:   r.format,
			SubresourceRange: vulkan.ImageSubresourceRange{
				AspectMask: vulkan.ImageAspectColorBit,
				LevelCount: 1,
				LayerCount: 1,
			},
		}
		var view vulkan.ImageView
		if err := vulkan.Check(r.deviceAPI.CreateImageView(r.device, &viewInfo, nil, &view)); err != nil {
			return fmt.Errorf("vkCreateImageView: %w", err)
		}
		r.views = append(r.views, view)
	}
	return nil
}

func (r *renderer) createGraphicsPipeline(vertexCode, fragmentCode []byte) error {
	vertexModule, err := r.createShaderModule(vertexCode)
	if err != nil {
		return fmt.Errorf("create vertex shader module: %w", err)
	}
	defer r.deviceAPI.DestroyShaderModule(r.device, vertexModule, nil)
	fragmentModule, err := r.createShaderModule(fragmentCode)
	if err != nil {
		return fmt.Errorf("create fragment shader module: %w", err)
	}
	defer r.deviceAPI.DestroyShaderModule(r.device, fragmentModule, nil)

	var entrypoint = []byte("main\x00")
	stages := [2]vulkan.PipelineShaderStageCreateInfo{
		{
			SType:  vulkan.StructureTypePipelineShaderStageCreateInfo,
			Stage:  vulkan.ShaderStageVertexBit,
			Module: vertexModule,
			Name:   &entrypoint[0],
		},
		{
			SType:  vulkan.StructureTypePipelineShaderStageCreateInfo,
			Stage:  vulkan.ShaderStageFragmentBit,
			Module: fragmentModule,
			Name:   &entrypoint[0],
		},
	}
	vertexInput := vulkan.PipelineVertexInputStateCreateInfo{
		SType: vulkan.StructureTypePipelineVertexInputStateCreateInfo,
	}
	inputAssembly := vulkan.PipelineInputAssemblyStateCreateInfo{
		SType:    vulkan.StructureTypePipelineInputAssemblyStateCreateInfo,
		Topology: vulkan.PrimitiveTopologyTriangleList,
	}
	viewport := vulkan.Viewport{
		Width:    float32(r.extent.Width),
		Height:   float32(r.extent.Height),
		MaxDepth: 1,
	}
	scissor := vulkan.Rect2D{Extent: r.extent}
	viewportState := vulkan.PipelineViewportStateCreateInfo{
		SType:         vulkan.StructureTypePipelineViewportStateCreateInfo,
		ViewportCount: 1,
		Viewports:     &viewport,
		ScissorCount:  1,
		Scissors:      &scissor,
	}
	rasterizer := vulkan.PipelineRasterizationStateCreateInfo{
		SType:       vulkan.StructureTypePipelineRasterizationStateCreateInfo,
		PolygonMode: vulkan.PolygonModeFill,
		CullMode:    vulkan.CullModeNone,
		FrontFace:   vulkan.FrontFaceCounterClockwise,
		LineWidth:   1,
	}
	multisampling := vulkan.PipelineMultisampleStateCreateInfo{
		SType:                vulkan.StructureTypePipelineMultisampleStateCreateInfo,
		RasterizationSamples: vulkan.SampleCount1Bit,
	}
	colorBlendAttachment := vulkan.PipelineColorBlendAttachmentState{
		ColorWriteMask: vulkan.ColorComponentRBit |
			vulkan.ColorComponentGBit |
			vulkan.ColorComponentBBit |
			vulkan.ColorComponentABit,
	}
	colorBlending := vulkan.PipelineColorBlendStateCreateInfo{
		SType:           vulkan.StructureTypePipelineColorBlendStateCreateInfo,
		AttachmentCount: 1,
		Attachments:     &colorBlendAttachment,
	}
	renderingInfo := vulkan.PipelineRenderingCreateInfo{
		SType:                  vulkan.StructureTypePipelineRenderingCreateInfo,
		ColorAttachmentCount:   1,
		ColorAttachmentFormats: &r.format,
	}
	layoutInfo := vulkan.PipelineLayoutCreateInfo{
		SType: vulkan.StructureTypePipelineLayoutCreateInfo,
	}
	if err := vulkan.Check(r.deviceAPI.CreatePipelineLayout(r.device, &layoutInfo, nil, &r.pipelineLayout)); err != nil {
		return fmt.Errorf("vkCreatePipelineLayout: %w", err)
	}
	pipelineInfo := vulkan.GraphicsPipelineCreateInfo{
		SType:              vulkan.StructureTypeGraphicsPipelineCreateInfo,
		Next:               unsafe.Pointer(&renderingInfo),
		StageCount:         uint32(len(stages)),
		Stages:             &stages[0],
		VertexInputState:   &vertexInput,
		InputAssemblyState: &inputAssembly,
		ViewportState:      &viewportState,
		RasterizationState: &rasterizer,
		MultisampleState:   &multisampling,
		ColorBlendState:    &colorBlending,
		Layout:             r.pipelineLayout,
	}
	if err := vulkan.Check(r.deviceAPI.CreateGraphicsPipelines(r.device, 0, 1, &pipelineInfo, nil, &r.pipeline)); err != nil {
		return fmt.Errorf("vkCreateGraphicsPipelines: %w", err)
	}
	runtime.KeepAlive(entrypoint)
	return nil
}

func (r *renderer) createShaderModule(code []byte) (vulkan.ShaderModule, error) {
	if len(code) == 0 || len(code)%4 != 0 {
		return 0, errors.New("SPIR-V shader data must have a non-empty, 4-byte-aligned size")
	}
	words := make([]uint32, len(code)/4)
	for i := range words {
		words[i] = binary.LittleEndian.Uint32(code[i*4:])
	}
	info := vulkan.ShaderModuleCreateInfo{
		SType:    vulkan.StructureTypeShaderModuleCreateInfo,
		CodeSize: uintptr(len(code)),
		Code:     &words[0],
	}
	var module vulkan.ShaderModule
	if err := vulkan.Check(r.deviceAPI.CreateShaderModule(r.device, &info, nil, &module)); err != nil {
		return 0, err
	}
	runtime.KeepAlive(words)
	return module, nil
}

func (r *renderer) createCommandsAndSync() error {
	poolInfo := vulkan.CommandPoolCreateInfo{
		SType:            vulkan.StructureTypeCommandPoolCreateInfo,
		QueueFamilyIndex: r.queueFamily,
	}
	if err := vulkan.Check(r.deviceAPI.CreateCommandPool(r.device, &poolInfo, nil, &r.commandPool)); err != nil {
		return fmt.Errorf("vkCreateCommandPool: %w", err)
	}
	allocateInfo := vulkan.CommandBufferAllocateInfo{
		SType:              vulkan.StructureTypeCommandBufferAllocateInfo,
		CommandPool:        r.commandPool,
		Level:              vulkan.CommandBufferLevelPrimary,
		CommandBufferCount: 1,
	}
	if err := vulkan.Check(r.deviceAPI.AllocateCommandBuffers(r.device, &allocateInfo, &r.commandBuffer)); err != nil {
		return fmt.Errorf("vkAllocateCommandBuffers: %w", err)
	}
	semaphoreInfo := vulkan.SemaphoreCreateInfo{SType: vulkan.StructureTypeSemaphoreCreateInfo}
	if err := vulkan.Check(r.deviceAPI.CreateSemaphore(r.device, &semaphoreInfo, nil, &r.imageAvailable)); err != nil {
		return fmt.Errorf("vkCreateSemaphore(image available): %w", err)
	}
	if err := vulkan.Check(r.deviceAPI.CreateSemaphore(r.device, &semaphoreInfo, nil, &r.renderFinished)); err != nil {
		return fmt.Errorf("vkCreateSemaphore(render finished): %w", err)
	}
	return nil
}

func (r *renderer) drawFrame() error {
	var imageIndex uint32
	acquireResult := r.deviceAPI.AcquireNextImageKHR(
		r.device, r.swapchain, ^uint64(0), r.imageAvailable, 0, &imageIndex,
	)
	if acquireResult != vulkan.Success && acquireResult != vulkan.SuboptimalKHR {
		return fmt.Errorf("vkAcquireNextImageKHR: %s", vulkan.ResultString(acquireResult))
	}
	if imageIndex >= uint32(len(r.views)) {
		return fmt.Errorf("vkAcquireNextImageKHR returned out-of-range image index %d", imageIndex)
	}

	beginInfo := vulkan.CommandBufferBeginInfo{
		SType: vulkan.StructureTypeCommandBufferBeginInfo,
	}
	if err := vulkan.Check(r.deviceAPI.BeginCommandBuffer(r.commandBuffer, &beginInfo)); err != nil {
		return fmt.Errorf("vkBeginCommandBuffer: %w", err)
	}
	clear := vulkan.ClearValue{
		math.Float32bits(0.05),
		math.Float32bits(0.07),
		math.Float32bits(0.12),
		math.Float32bits(1),
	}
	attachment := vulkan.RenderingAttachmentInfo{
		SType:       vulkan.StructureTypeRenderingAttachmentInfo,
		ImageView:   r.views[imageIndex],
		ImageLayout: vulkan.ImageLayoutColorAttachmentOptimal,
		LoadOp:      vulkan.AttachmentLoadOpClear,
		StoreOp:     vulkan.AttachmentStoreOpStore,
		ClearValue:  clear,
	}
	rendering := vulkan.RenderingInfo{
		SType:                vulkan.StructureTypeRenderingInfo,
		RenderArea:           vulkan.Rect2D{Extent: r.extent},
		LayerCount:           1,
		ColorAttachmentCount: 1,
		ColorAttachments:     &attachment,
	}
	r.deviceAPI.CmdBeginRendering(r.commandBuffer, &rendering)
	r.deviceAPI.CmdBindPipeline(r.commandBuffer, vulkan.PipelineBindPointGraphics, r.pipeline)
	r.deviceAPI.CmdDraw(r.commandBuffer, 3, 1, 0, 0)
	r.deviceAPI.CmdEndRendering(r.commandBuffer)
	if err := vulkan.Check(r.deviceAPI.EndCommandBuffer(r.commandBuffer)); err != nil {
		return fmt.Errorf("vkEndCommandBuffer: %w", err)
	}

	waitStage := vulkan.PipelineStageFlags(vulkan.PipelineStageColorAttachmentOutputBit)
	submit := vulkan.SubmitInfo{
		SType:                vulkan.StructureTypeSubmitInfo,
		WaitSemaphoreCount:   1,
		WaitSemaphores:       &r.imageAvailable,
		WaitDstStageMask:     &waitStage,
		CommandBufferCount:   1,
		CommandBuffers:       &r.commandBuffer,
		SignalSemaphoreCount: 1,
		SignalSemaphores:     &r.renderFinished,
	}
	if err := vulkan.Check(r.deviceAPI.QueueSubmit(r.queue, 1, &submit, 0)); err != nil {
		return fmt.Errorf("vkQueueSubmit: %w", err)
	}
	present := vulkan.PresentInfoKHR{
		SType:              vulkan.StructureTypePresentInfoKHR,
		WaitSemaphoreCount: 1,
		WaitSemaphores:     &r.renderFinished,
		SwapchainCount:     1,
		Swapchains:         &r.swapchain,
		ImageIndices:       &imageIndex,
	}
	presentResult := r.deviceAPI.QueuePresentKHR(r.queue, &present)
	if presentResult != vulkan.Success && presentResult != vulkan.SuboptimalKHR {
		return fmt.Errorf("vkQueuePresentKHR: %s", vulkan.ResultString(presentResult))
	}
	if err := vulkan.Check(r.deviceAPI.QueueWaitIdle(r.queue)); err != nil {
		return fmt.Errorf("vkQueueWaitIdle: %w", err)
	}
	return nil
}

func (r *renderer) close() error {
	var cleanupErr error
	if r.device != 0 {
		if r.deviceAPI != nil {
			if err := vulkan.Check(r.deviceAPI.DeviceWaitIdle(r.device)); err != nil {
				cleanupErr = fmt.Errorf("vkDeviceWaitIdle during cleanup: %w", err)
			}
			if r.imageAvailable != 0 {
				r.deviceAPI.DestroySemaphore(r.device, r.imageAvailable, nil)
			}
			if r.renderFinished != 0 {
				r.deviceAPI.DestroySemaphore(r.device, r.renderFinished, nil)
			}
			if r.commandPool != 0 {
				r.deviceAPI.DestroyCommandPool(r.device, r.commandPool, nil)
			}
			if r.pipeline != 0 {
				r.deviceAPI.DestroyPipeline(r.device, r.pipeline, nil)
			}
			if r.pipelineLayout != 0 {
				r.deviceAPI.DestroyPipelineLayout(r.device, r.pipelineLayout, nil)
			}
			for _, view := range r.views {
				r.deviceAPI.DestroyImageView(r.device, view, nil)
			}
			if r.swapchain != 0 {
				r.deviceAPI.DestroySwapchainKHR(r.device, r.swapchain, nil)
			}
			r.deviceAPI.DestroyDevice(r.device, nil)
		} else if vulkan.VkDestroyDevice != nil {
			vulkan.VkDestroyDevice(r.device, nil)
		}
	}
	if r.surface != 0 && r.instanceAPI != nil {
		r.instanceAPI.DestroySurfaceKHR(r.instance, r.surface, nil)
	}
	if r.instance != 0 && r.instanceAPI != nil {
		r.instanceAPI.DestroyInstance(r.instance, nil)
	} else if r.instance != 0 && vulkan.VkDestroyInstance != nil {
		vulkan.VkDestroyInstance(r.instance, nil)
	}
	return cleanupErr
}
