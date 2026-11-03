package sdl

import (
	"encoding/binary"
	"unsafe"
)

const eventSize = 128

const (
	EventQuit              uint32 = 0x0100
	EventWindowShown       uint32 = 0x0202
	EventWindowHidden      uint32 = 0x0203
	EventWindowExposed     uint32 = 0x0204
	EventWindowMoved       uint32 = 0x0205
	EventWindowResized     uint32 = 0x0206
	EventWindowPixelSize   uint32 = 0x0207
	EventWindowMetalResize uint32 = 0x0208
	EventWindowMinimized   uint32 = 0x0209
	EventWindowMaximized   uint32 = 0x020A
	EventWindowRestored    uint32 = 0x020B
	EventWindowMouseEnter  uint32 = 0x020C
	EventWindowMouseLeave  uint32 = 0x020D
	EventWindowFocusGained uint32 = 0x020E
	EventWindowFocusLost   uint32 = 0x020F
	EventWindowClose       uint32 = 0x0210
	EventKeyDown           uint32 = 0x0300
	EventKeyUp             uint32 = 0x0301
	EventTextEditing       uint32 = 0x0302
	EventTextInput         uint32 = 0x0303
	EventMouseMotion       uint32 = 0x0400
	EventMouseButtonDown   uint32 = 0x0401
	EventMouseButtonUp     uint32 = 0x0402
	EventMouseWheel        uint32 = 0x0403
)

// EventValue is the typed representation of an SDL event.
type EventValue interface{ eventValue() }

type QuitEvent struct {
	Type      uint32
	Timestamp uint64
}

func (QuitEvent) eventValue() {}

type WindowEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Data1     int32
	Data2     int32
}

func (WindowEvent) eventValue() {}

type KeyboardEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Which     uint32
	Scancode  int32
	Keycode   int32
	KeyName   string
	Mod       uint16
	Raw       uint16
	Down      bool
	Repeat    bool
}

func (KeyboardEvent) eventValue() {}

type TextEditingEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Text      string
	Start     int32
	Length    int32
}

func (TextEditingEvent) eventValue() {}

type TextInputEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Text      string
}

func (TextInputEvent) eventValue() {}

type MouseMotionEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Which     uint32
	State     uint32
	X         float32
	Y         float32
	XRel      float32
	YRel      float32
}

func (MouseMotionEvent) eventValue() {}

type MouseButtonEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Which     uint32
	Button    uint8
	Down      bool
	Clicks    uint8
	X         float32
	Y         float32
}

func (MouseButtonEvent) eventValue() {}

type MouseWheelEvent struct {
	Type      uint32
	Timestamp uint64
	WindowID  uint32
	Which     uint32
	X         float32
	Y         float32
	Direction uint32
	MouseX    float32
	MouseY    float32
}

func (MouseWheelEvent) eventValue() {}

// UnknownEvent preserves the raw bytes for SDL events not yet decoded here.
type UnknownEvent struct {
	Type uint32
	Data [eventSize]byte
}

func (UnknownEvent) eventValue() {}

// PollEventTyped returns the next SDL event as a Go value.
// PollEvent remains available for callers that need the original raw event ID
// and buffer-based API.
func PollEventTyped() (EventValue, bool) {
	var raw [eventSize]byte
	if !PollEvent(&raw[0]) {
		return nil, false
	}
	return decodeEvent(raw[:]), true
}

// KeyName returns an ASCII name for an SDL keycode, including control keys.
func KeyName(keycode int32) string {
	switch keycode {
	case 8:
		return "Backspace"
	case 9:
		return "Tab"
	case 13:
		return "Enter"
	case 27:
		return "Escape"
	case 32:
		return "Space"
	case 127:
		return "Delete"
	default:
		if name := GetKeyName(int(keycode)); name != "" {
			return name
		}
		return "Keycode(" + itoa(int(keycode)) + ")"
	}
}

func itoa(value int) string {
	if value == 0 {
		return "0"
	}
	negative := value < 0
	if negative {
		value = -value
	}
	var digits [20]byte
	i := len(digits)
	for value > 0 {
		i--
		digits[i] = byte('0' + value%10)
		value /= 10
	}
	if negative {
		i--
		digits[i] = '-'
	}
	return string(digits[i:])
}

func decodeEvent(raw []byte) EventValue {
	typ := u32(raw, 0)
	timestamp := u64(raw, 8)
	switch typ {
	case EventQuit:
		return QuitEvent{Type: typ, Timestamp: timestamp}
	case EventWindowShown, EventWindowHidden, EventWindowExposed,
		EventWindowMoved, EventWindowResized, EventWindowPixelSize,
		EventWindowMetalResize, EventWindowMinimized, EventWindowMaximized,
		EventWindowRestored, EventWindowMouseEnter, EventWindowMouseLeave,
		EventWindowFocusGained, EventWindowFocusLost, EventWindowClose:
		return WindowEvent{Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Data1: i32(raw, 24), Data2: i32(raw, 28)}
	case EventKeyDown, EventKeyUp:
		return KeyboardEvent{
			Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Which: u32(raw, 20),
			Scancode: i32(raw, 24), Keycode: i32(raw, 28), KeyName: KeyName(i32(raw, 28)), Mod: u16(raw, 32), Raw: u16(raw, 34),
			Down: raw[36] != 0, Repeat: raw[37] != 0,
		}
	case EventTextEditing:
		return TextEditingEvent{Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Text: eventString(raw, 24), Start: i32(raw, 32), Length: i32(raw, 36)}
	case EventTextInput:
		return TextInputEvent{Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Text: eventString(raw, 24)}
	case EventMouseMotion:
		return MouseMotionEvent{Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Which: u32(raw, 20), State: u32(raw, 24), X: f32(raw, 28), Y: f32(raw, 32), XRel: f32(raw, 36), YRel: f32(raw, 40)}
	case EventMouseButtonDown, EventMouseButtonUp:
		return MouseButtonEvent{Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Which: u32(raw, 20), Button: raw[24], Down: typ == EventMouseButtonDown, Clicks: raw[26], X: f32(raw, 28), Y: f32(raw, 32)}
	case EventMouseWheel:
		return MouseWheelEvent{Type: typ, Timestamp: timestamp, WindowID: u32(raw, 16), Which: u32(raw, 20), X: f32(raw, 24), Y: f32(raw, 28), Direction: u32(raw, 32), MouseX: f32(raw, 36), MouseY: f32(raw, 40)}
	default:
		var data [eventSize]byte
		copy(data[:], raw)
		return UnknownEvent{Type: typ, Data: data}
	}
}

func u16(raw []byte, offset int) uint16 { return binary.LittleEndian.Uint16(raw[offset : offset+2]) }
func u32(raw []byte, offset int) uint32 { return binary.LittleEndian.Uint32(raw[offset : offset+4]) }
func i32(raw []byte, offset int) int32  { return int32(u32(raw, offset)) }
func u64(raw []byte, offset int) uint64 { return binary.LittleEndian.Uint64(raw[offset : offset+8]) }
func f32(raw []byte, offset int) float32 {
	return *(*float32)(unsafe.Pointer(&raw[offset]))
}

func eventString(raw []byte, offset int) string {
	ptr := *(*uintptr)(unsafe.Pointer(&raw[offset]))
	if ptr == 0 {
		return ""
	}
	data := unsafe.Slice((*byte)(unsafe.Pointer(ptr)), 1<<20)
	for i, b := range data {
		if b == 0 {
			return string(data[:i])
		}
	}
	return ""
}
