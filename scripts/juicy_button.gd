extends Button


const UI_HOVER_SOUND = preload("res://audio/ui_hover.wav")


@export var m := 0.2
@export var k := 50.0
@export var damping := 0.9


var hover_t := 0.0
var pressed_t := 0.0
var v := 0.0


func _on_mouse_entered() -> void:
	$SfxPlayer.stream = UI_HOVER_SOUND
	$SfxPlayer.play()
	

func _process(delta: float) -> void:
	var target := 1.0
	if button_pressed:
		target = 1.2
	elif is_hovered():
		target = 1.1
	var x = target - offset_transform_scale.x
	var f = k * x
	var a = f / m
	v *= pow(damping, delta * 60.0)
	v += a * delta
	offset_transform_scale.x += v * delta
	offset_transform_scale.y += v * delta
