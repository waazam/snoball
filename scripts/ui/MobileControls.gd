extends CanvasLayer
## Shows/hides and enables/disables the on-screen touch controls. Desktop
## (PC) players keep plain keyboard + mouse and never see this HUD; it only
## appears on Android/iOS (or any other touch-primary device), and keyboard
## input keeps working there too if a keyboard happens to be attached.
##
## Kept deliberately minimal, like a standard third-person shooter mobile
## layout: a left-side movement joystick, a drag-to-look right side
## (handled directly by Player.gd, no on-screen widget needed for it), and
## a single jump button. Throwing is automatic (see Player.gd's auto-throw
## timer) and weapon switching/dash/pause aren't offered on touch, so
## there's nothing else to show.

@onready var joystick: Control = $Joystick
@onready var move_label: Label = $MoveLabel
@onready var jump_button: Control = $JumpButton

func _is_mobile_platform() -> bool:
	# Explicit Android/iOS web-export feature tags first; touchscreen
	# presence as a fallback so any other touch-primary device still works.
	if OS.has_feature("web_android") or OS.has_feature("android"):
		return true
	if OS.has_feature("web_ios") or OS.has_feature("ios"):
		return true
	return DisplayServer.is_touchscreen_available()

func _ready() -> void:
	var is_touch: bool = _is_mobile_platform()
	visible = is_touch
	if not is_touch:
		return
	Game.state_changed.connect(_on_state_changed)
	_on_state_changed(Game.state)

func _on_state_changed(state: int) -> void:
	var playing: bool = state == Game.State.PLAYING
	joystick.set_active(playing)
	jump_button.set_active(playing)
