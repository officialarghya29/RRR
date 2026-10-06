class_name PopInput
extends RefCounted
## One tick of player intent for the Pop sim core (plan A2.2).
##
## Wire format is a single byte per tick, bit-packed as
## x:2 | y:2 | shift:1 | special:3 (layout mirrors SDLPoP's replay input
## record — named as behavioral reference only; see docs/ASSET_LICENSES.md).
## Bit fields: 0-1 x (signed 2-bit), 2-3 y (signed 2-bit), 4 shift,
## 5-7 special. The packing is structural, not a measured constant.

var x: int = 0      ## -1 left, 0 neutral, 1 right (2-bit signed field)
var y: int = 0      ## -1 up, 0 neutral, 1 down (2-bit signed field)
var shift: int = 0  ## 0 or 1; grab/climb modifier key
var special: int = 0 ## 3-bit extension, reserved (0 = none)


static func make(p_x: int, p_y: int = 0, p_shift: int = 0, p_special: int = 0) -> PopInput:
	var input := PopInput.new()
	input.set_axes(p_x, p_y, p_shift, p_special)
	return input


static func neutral() -> PopInput:
	return PopInput.new()


## Two's-complement 2-bit field: valid values are -2..1; we clamp to the
## meaningful subset (-1..1) so a bad caller cannot silently encode garbage.
static func _pack_signed2(v: int) -> int:
	var c: int = clampi(v, -1, 1)
	return c & 0x3


static func _unpack_signed2(bits: int) -> int:
	# 2-bit two's complement: 0->0, 1->1, 2->-2, 3->-1.
	return ((bits & 0x3) ^ 2) - 2


func set_axes(p_x: int, p_y: int = 0, p_shift: int = 0, p_special: int = 0) -> void:
	x = clampi(p_x, -1, 1)
	y = clampi(p_y, -1, 1)
	shift = clampi(p_shift, 0, 1)
	special = clampi(p_special, 0, 7)


func to_byte() -> int:
	var b: int = _pack_signed2(x)
	b |= _pack_signed2(y) << 2
	b |= (shift & 0x1) << 4
	b |= (special & 0x7) << 5
	return b


static func from_byte(b: int) -> PopInput:
	var input := PopInput.new()
	input.x = _unpack_signed2(b & 0x3)
	input.y = _unpack_signed2((b >> 2) & 0x3)
	input.shift = (b >> 4) & 0x1
	input.special = (b >> 5) & 0x7
	return input


func is_neutral() -> bool:
	return x == 0 and y == 0 and shift == 0 and special == 0
