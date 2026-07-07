class_name FlashComponent
extends Node
## White hit-flash on an AnimatedSprite2D via a tiny mix-to-white shader.

const FLASH_SHADER := "
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}"

@export var target: CanvasItem
@export var duration := 0.1

var _material: ShaderMaterial


func _ready() -> void:
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	if target != null:
		target.material = _material


func flash() -> void:
	_material.set_shader_parameter(&"flash", 1.0)
	var tween := create_tween()
	tween.tween_property(_material, "shader_parameter/flash", 0.0, duration)
