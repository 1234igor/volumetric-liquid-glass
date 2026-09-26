extends Node2D

const VARIANTS := ["regular", "clear", "regular-tinted", "clear-tinted", "identity"]
const BACKGROUNDS := ["harbour", "city-night", "prism", "facade"]
const STATES := ["rest", "hover", "pressed"]
const OBJECTS := ["panel", "orb", "torus", "cluster"]
const VIEWS := ["side", "three-quarter", "grazing", "top"]
const DEFAULT_CAPTURE_FRAMES := 12
const CAPTURE_WARMUP_FRAMES := 4
const MAX_CAPTURE_FRAMES := 600
const GLASS_SOURCE_RECT := Rect2i(760, 1204, 880, 192)

@onready var backdrop: TextureRect = $Backdrop
@onready var volume: ColorRect = $Volume
@onready var canonical_shadow: ColorRect = $CanonicalShadow
@onready var canonical_glass: ColorRect = $CanonicalGlass
@onready var playback_contents: Control = $PlaybackContents

var _variant := "regular"
var _background := "harbour"
var _state := "rest"
var _object := "cluster"
var _view := "three-quarter"
var _shot_path := ""
var _capture_frames := DEFAULT_CAPTURE_FRAMES
var _parse_error := ""
var _capture_scale := 1.0
var _yaw := 0.65
var _pitch := -0.18
var _distance := 5.4
var _phase := 0.0
var _dragging := false


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	if not _parse_error.is_empty():
		printerr("VOLUMETRIC GLASS FAIL - %s" % _parse_error)
		get_tree().quit(2)
		return

	_capture_scale = 2.0 if not _shot_path.is_empty() else 1.0
	if _capture_scale > 1.0:
		get_window().size = Vector2i(2400, 1600)
		scale = Vector2(_capture_scale, _capture_scale)
	get_window().title = "Volumetric Liquid Glass - %s - %s" % [_title(_object), _title(_view)]
	backdrop.texture = load("res://assets/backgrounds/%s.png" % _background)
	_apply_view_preset()
	_configure_scene()
	volume.gui_input.connect(_on_volume_input)

	if not _shot_path.is_empty():
		_capture_after_frames.call_deferred()


func _process(delta: float) -> void:
	if _shot_path.is_empty() and not _canonical_side():
		_phase += delta * 0.55
		(volume.material as ShaderMaterial).set_shader_parameter("phase", _phase)


func _parse_args(args: PackedStringArray) -> void:
	for raw_argument in args:
		var argument := raw_argument
		var value := ""
		var equals := argument.find("=")
		if equals >= 0:
			value = argument.substr(equals + 1)
			argument = argument.substr(0, equals)
		match argument:
			"--variant":
				_variant = _validated(value, VARIANTS, "variant")
			"--background":
				_background = _validated(value, BACKGROUNDS, "background")
			"--state":
				_state = _validated(value, STATES, "state")
			"--object":
				_object = _validated(value, OBJECTS, "object")
			"--view":
				_view = _validated(value, VIEWS, "view")
			"--shot":
				if value.is_empty() or not value.is_absolute_path() or value.get_extension().to_lower() != "png":
					_fail("--shot needs an absolute .png path")
				else:
					_shot_path = value
			"--frames":
				if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > MAX_CAPTURE_FRAMES:
					_fail("--frames must be 1..%d" % MAX_CAPTURE_FRAMES)
				else:
					_capture_frames = value.to_int()
			_:
				_fail("unknown argument %s" % raw_argument)


func _validated(value: String, allowed: Array, label: String) -> String:
	if value in allowed:
		return value
	_fail("--%s must be one of %s, got %s" % [label, ", ".join(allowed), value])
	return allowed[0]


func _fail(message: String) -> void:
	if _parse_error.is_empty():
		_parse_error = message


func _canonical_side() -> bool:
	return _object == "panel" and _view == "side"


func _configure_scene() -> void:
	var identity := _variant == "identity"
	var canonical := _canonical_side()
	volume.visible = not canonical and not identity
	canonical_glass.visible = canonical and not identity
	canonical_shadow.visible = canonical and not identity
	playback_contents.visible = canonical
	if canonical:
		_configure_canonical_material()
	else:
		_configure_volume_material()


func _configure_canonical_material() -> void:
	var material := canonical_glass.material as ShaderMaterial
	var clear := _variant == "clear" or _variant == "clear-tinted"
	var tinted := _variant == "regular-tinted" or _variant == "clear-tinted"
	material.set_shader_parameter("is_clear", 1.0 if clear else 0.0)
	material.set_shader_parameter("is_tinted", 1.0 if tinted else 0.0)
	material.set_shader_parameter("is_identity", 0.0)
	material.set_shader_parameter("warmth", 0.0 if clear else _background_warmth())
	material.set_shader_parameter("interaction_energy", _state_energy())
	material.set_shader_parameter("render_scale", _capture_scale)
	material.set_shader_parameter(
		"screen_pixel_size",
		Vector2(1.0 / (1200.0 * _capture_scale), 1.0 / (800.0 * _capture_scale))
	)


func _configure_volume_material() -> void:
	var material := volume.material as ShaderMaterial
	var clear := _variant == "clear" or _variant == "clear-tinted"
	var tinted := _variant == "regular-tinted" or _variant == "clear-tinted"
	material.set_shader_parameter("object_type", OBJECTS.find(_object))
	material.set_shader_parameter("is_clear", 1.0 if clear else 0.0)
	material.set_shader_parameter("is_tinted", 1.0 if tinted else 0.0)
	material.set_shader_parameter("warmth", 0.0 if clear else _background_warmth())
	material.set_shader_parameter("interaction_energy", _state_energy())
	material.set_shader_parameter("screen_pixel_size", Vector2(1.0 / (1200.0 * _capture_scale), 1.0 / (800.0 * _capture_scale)))
	material.set_shader_parameter("camera_yaw", _yaw)
	material.set_shader_parameter("camera_pitch", _pitch)
	material.set_shader_parameter("camera_distance", _distance)
	material.set_shader_parameter("phase", _phase)


func _apply_view_preset() -> void:
	match _view:
		"side":
			_yaw = 0.0
			_pitch = 0.0
		"grazing":
			_yaw = 1.13
			_pitch = 0.10
		"top":
			_yaw = 0.42
			_pitch = 0.78
		_:
			_yaw = 0.65
			_pitch = -0.18
	match _object:
		"panel":
			_distance = 6.5
		"orb":
			_distance = 5.1
		"torus":
			_distance = 5.2
		_:
			_distance = 5.7


func _background_warmth() -> float:
	var image := (backdrop.texture as Texture2D).get_image()
	var total := 0.0
	var count := 0
	for y in range(GLASS_SOURCE_RECT.position.y, GLASS_SOURCE_RECT.end.y, 4):
		for x in range(GLASS_SOURCE_RECT.position.x, GLASS_SOURCE_RECT.end.x, 4):
			var color := image.get_pixel(x, y)
			var high: float = maxf(color.r, maxf(color.g, color.b))
			var low: float = minf(color.r, minf(color.g, color.b))
			total += (high - low) * 255.0
			count += 1
	var average_chroma: float = total / float(maxi(count, 1))
	return 0.55 + 0.45 * clampf((average_chroma - 10.0) / 46.0, 0.0, 1.0)


func _state_energy() -> float:
	match _state:
		"hover":
			return 0.48
		"pressed":
			return 1.0
		_:
			return 0.0


func _on_volume_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - 0.25, 2.8)
			_configure_volume_material()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + 0.25, 8.0)
			_configure_volume_material()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch - event.relative.y * 0.006, -1.18, 1.18)
		_configure_volume_material()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		_object = OBJECTS[key.keycode - KEY_1]
		_apply_view_preset()
	elif key.keycode == KEY_V:
		_view = VIEWS[(VIEWS.find(_view) + 1) % VIEWS.size()]
		_apply_view_preset()
	elif key.keycode == KEY_M:
		_variant = VARIANTS[(VARIANTS.find(_variant) + 1) % (VARIANTS.size() - 1)]
	elif key.keycode == KEY_B:
		_background = BACKGROUNDS[(BACKGROUNDS.find(_background) + 1) % BACKGROUNDS.size()]
		backdrop.texture = load("res://assets/backgrounds/%s.png" % _background)
	else:
		return
	get_window().title = "Volumetric Liquid Glass - %s - %s" % [_title(_object), _title(_view)]
	_configure_scene()


func _capture_after_frames() -> void:
	for _frame in CAPTURE_WARMUP_FRAMES:
		await get_tree().process_frame
	var capture_started := Time.get_ticks_usec()
	for _frame in _capture_frames:
		await get_tree().process_frame
	var average_frame_ms := (Time.get_ticks_usec() - capture_started) / (1000.0 * _capture_frames)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_shot_path)
	if error != OK:
		printerr("VOLUMETRIC GLASS FAIL - could not save %s (error %d)" % [_shot_path, error])
		get_tree().quit(1)
		return
	print(
		"VOLUMETRIC GLASS OK object=%s view=%s variant=%s background=%s state=%s size=%dx%d avg_frame_ms=%.3f shot=%s"
		% [_object, _view, _variant, _background, _state, image.get_width(), image.get_height(), average_frame_ms, _shot_path]
	)
	get_tree().quit(0)


func _title(value: String) -> String:
	return value.replace("-", " ").capitalize()
