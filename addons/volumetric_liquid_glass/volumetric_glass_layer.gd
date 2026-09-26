class_name VolumetricGlassLayer
extends Control

enum ObjectType { PANEL, ORB, TORUS, CLUSTER }
enum MaterialStyle { REGULAR, CLEAR, REGULAR_TINTED, CLEAR_TINTED, IDENTITY }
enum ViewPreset { SIDE, THREE_QUARTER, GRAZING, TOP }

const DEFAULT_SIDE_RECT := Rect2(380.0, 602.0, 440.0, 96.0)
const SIDE_SHADOW_TOP_LEFT := Vector2(54.0, 54.0)
const SIDE_SHADOW_BOTTOM_RIGHT := Vector2(54.0, 30.0)

@export var object_type := ObjectType.ORB:
	set(value):
		object_type = value
		_apply_camera_preset()
		_apply_material()
@export var material_style := MaterialStyle.CLEAR:
	set(value):
		material_style = value
		_apply_material()
@export var view_preset := ViewPreset.THREE_QUARTER:
	set(value):
		view_preset = value
		_apply_camera_preset()
		_apply_material()
@export_range(0.0, 1.0, 0.01) var warmth := 0.75:
	set(value):
		warmth = value
		_apply_material()
@export var side_glass_rect := DEFAULT_SIDE_RECT:
	set(value):
		side_glass_rect = value
		_apply_side_geometry()
@export_range(0.0, 48.0, 0.5) var side_corner_radius := 34.0:
	set(value):
		side_corner_radius = value
		_apply_side_geometry()
@export_range(0.0, 1.0, 0.01) var side_shadow_opacity := 0.22:
	set(value):
		side_shadow_opacity = value
		_apply_side_geometry()
@export var animation_enabled := false:
	set(value):
		animation_enabled = value
		_update_processing()
@export var interaction_enabled := false:
	set(value):
		interaction_enabled = value
		if not interaction_enabled:
			_dragging = false
		_update_input_mode()

var _back_buffer: BackBufferCopy
var _volume: ColorRect
var _canonical_shadow: ColorRect
var _canonical_glass: ColorRect
var _side_contents: Control
var _yaw := 0.65
var _pitch := -0.18
var _distance := 5.1
var _phase := 0.0
var _dragging := false
var _interaction_energy := 0.0


func _ready() -> void:
	_sync_viewport_size()
	get_viewport().size_changed.connect(_sync_viewport_size)
	_build_layers()
	resized.connect(_on_resized)
	gui_input.connect(_on_gui_input)
	_apply_camera_preset()
	_apply_material()


func _sync_viewport_size() -> void:
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		position = Vector2.ZERO
		size = get_viewport_rect().size
	_on_resized()


func _on_resized() -> void:
	_apply_side_geometry()
	_apply_material()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 0.55, TAU)
	if is_instance_valid(_volume):
		(_volume.material as ShaderMaterial).set_shader_parameter("phase", _phase)


func set_object_type(value: ObjectType) -> void:
	object_type = value


func set_material_style(value: MaterialStyle) -> void:
	material_style = value


func set_view_preset(value: ViewPreset) -> void:
	view_preset = value


func set_interaction_energy(value: float) -> void:
	_interaction_energy = clampf(value, 0.0, 1.0)
	_apply_material()


func get_side_content_layer() -> Control:
	return _side_contents


func _build_layers() -> void:
	_back_buffer = BackBufferCopy.new()
	_back_buffer.name = "BackBufferCopy"
	_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_back_buffer)

	_volume = ColorRect.new()
	_volume.name = "Volume"
	_volume.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_volume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var volume_material := ShaderMaterial.new()
	volume_material.shader = load("res://addons/volumetric_liquid_glass/volumetric_liquid_glass.gdshader")
	_volume.material = volume_material
	add_child(_volume)

	_canonical_shadow = ColorRect.new()
	_canonical_shadow.name = "CanonicalShadow"
	_canonical_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = load("res://addons/volumetric_liquid_glass/glass_shadow.gdshader")
	_canonical_shadow.material = shadow_material
	add_child(_canonical_shadow)

	_canonical_glass = ColorRect.new()
	_canonical_glass.name = "CanonicalGlass"
	_canonical_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canonical_material := ShaderMaterial.new()
	canonical_material.shader = load("res://addons/volumetric_liquid_glass/canonical_liquid_glass.gdshader")
	_canonical_glass.material = canonical_material
	add_child(_canonical_glass)

	_side_contents = Control.new()
	_side_contents.name = "SideContents"
	_side_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_side_contents)
	_apply_side_geometry()


func _canonical_side() -> bool:
	return object_type == ObjectType.PANEL and view_preset == ViewPreset.SIDE


func _apply_camera_preset() -> void:
	match view_preset:
		ViewPreset.SIDE:
			_yaw = 0.0
			_pitch = 0.0
		ViewPreset.GRAZING:
			_yaw = 1.13
			_pitch = 0.10
		ViewPreset.TOP:
			_yaw = 0.42
			_pitch = 0.78
		_:
			_yaw = 0.65
			_pitch = -0.18
	match object_type:
		ObjectType.PANEL:
			_distance = 6.5
		ObjectType.ORB:
			_distance = 5.1
		ObjectType.TORUS:
			_distance = 5.2
		_:
			_distance = 5.7


func _apply_material() -> void:
	if not is_instance_valid(_volume) or size.x <= 0.0 or size.y <= 0.0:
		_update_processing()
		_update_input_mode()
		return
	var clear := material_style == MaterialStyle.CLEAR or material_style == MaterialStyle.CLEAR_TINTED
	var tinted := material_style == MaterialStyle.REGULAR_TINTED or material_style == MaterialStyle.CLEAR_TINTED
	var identity := material_style == MaterialStyle.IDENTITY
	var canonical := _canonical_side()

	_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED if identity else BackBufferCopy.COPY_MODE_VIEWPORT
	_volume.visible = not identity and not canonical
	_canonical_shadow.visible = not identity and canonical
	_canonical_glass.visible = not identity and canonical
	_side_contents.visible = canonical

	var volume_material := _volume.material as ShaderMaterial
	volume_material.set_shader_parameter("object_type", object_type)
	volume_material.set_shader_parameter("is_clear", 1.0 if clear else 0.0)
	volume_material.set_shader_parameter("is_tinted", 1.0 if tinted else 0.0)
	volume_material.set_shader_parameter("warmth", 0.0 if clear else warmth)
	volume_material.set_shader_parameter("interaction_energy", _interaction_energy)
	volume_material.set_shader_parameter("screen_pixel_size", Vector2.ONE / size)
	volume_material.set_shader_parameter("viewport_size", size)
	volume_material.set_shader_parameter("camera_yaw", _yaw)
	volume_material.set_shader_parameter("camera_pitch", _pitch)
	volume_material.set_shader_parameter("camera_distance", _distance)
	volume_material.set_shader_parameter("phase", _phase)

	var canonical_material := _canonical_glass.material as ShaderMaterial
	canonical_material.set_shader_parameter("screen_pixel_size", Vector2.ONE / size)
	canonical_material.set_shader_parameter("render_scale", get_window().content_scale_factor)
	canonical_material.set_shader_parameter("is_clear", 1.0 if clear else 0.0)
	canonical_material.set_shader_parameter("is_tinted", 1.0 if tinted else 0.0)
	canonical_material.set_shader_parameter("is_identity", 0.0)
	canonical_material.set_shader_parameter("warmth", 0.0 if clear else warmth)
	canonical_material.set_shader_parameter("interaction_energy", _interaction_energy)

	_apply_side_geometry()
	_update_processing()
	_update_input_mode()


func _apply_side_geometry() -> void:
	if not is_instance_valid(_canonical_glass):
		return
	_canonical_glass.position = side_glass_rect.position
	_canonical_glass.size = side_glass_rect.size
	_side_contents.position = side_glass_rect.position
	_side_contents.size = side_glass_rect.size

	_canonical_shadow.position = side_glass_rect.position - SIDE_SHADOW_TOP_LEFT
	_canonical_shadow.size = side_glass_rect.size + SIDE_SHADOW_TOP_LEFT + SIDE_SHADOW_BOTTOM_RIGHT
	var effective_radius := clampf(side_corner_radius, 0.0, minf(side_glass_rect.size.x, side_glass_rect.size.y) * 0.5)
	var canonical_material := _canonical_glass.material as ShaderMaterial
	canonical_material.set_shader_parameter("size_points", side_glass_rect.size)
	canonical_material.set_shader_parameter("corner_radius", effective_radius)
	var shadow_material := _canonical_shadow.material as ShaderMaterial
	shadow_material.set_shader_parameter("bounds_points", _canonical_shadow.size)
	shadow_material.set_shader_parameter("glass_origin", SIDE_SHADOW_TOP_LEFT)
	shadow_material.set_shader_parameter("glass_size", side_glass_rect.size)
	shadow_material.set_shader_parameter("corner_radius", effective_radius)
	shadow_material.set_shader_parameter("opacity", side_shadow_opacity)


func _update_processing() -> void:
	set_process(animation_enabled and material_style != MaterialStyle.IDENTITY and not _canonical_side())


func _update_input_mode() -> void:
	var accepts_input := interaction_enabled and material_style != MaterialStyle.IDENTITY
	mouse_filter = Control.MOUSE_FILTER_STOP if accepts_input else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_MOVE if accepts_input else Control.CURSOR_ARROW


func _on_gui_input(event: InputEvent) -> void:
	if not interaction_enabled or material_style == MaterialStyle.IDENTITY:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			set_interaction_energy(1.0 if _dragging else 0.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - 0.25, 2.8)
			_apply_material()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + 0.25, 8.0)
			_apply_material()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch - event.relative.y * 0.006, -1.18, 1.18)
		_apply_material()
