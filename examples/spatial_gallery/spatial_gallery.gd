extends Node2D

const OBJECT_NAMES := ["Panel", "Orb", "Torus", "Cluster"]
const MATERIAL_NAMES := ["Regular", "Clear", "Regular Tint", "Clear Tint", "Identity"]

var _glass: VolumetricGlassLayer
var _object_label: Label
var _material_button: Button
var _playback_button: Button
var _material_index := 1
var _shot_path := ""


func _ready() -> void:
	var requested_object := VolumetricGlassLayer.ObjectType.ORB
	var requested_material := VolumetricGlassLayer.MaterialStyle.CLEAR
	var requested_view := VolumetricGlassLayer.ViewPreset.THREE_QUARTER
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot_path = argument.trim_prefix("--shot=")
		elif argument.begins_with("--object="):
			requested_object = _object_from_name(argument.trim_prefix("--object="))
		elif argument.begins_with("--material="):
			requested_material = _material_from_name(argument.trim_prefix("--material="))
		elif argument.begins_with("--view="):
			requested_view = _view_from_name(argument.trim_prefix("--view="))
	get_window().title = "Spatial Gallery"
	_glass = VolumetricGlassLayer.new()
	add_child(_glass)
	_glass.set_object_type(requested_object)
	_glass.set_material_style(requested_material)
	_glass.set_view_preset(requested_view)
	_glass.animation_enabled = true
	_glass.interaction_enabled = true
	_material_index = requested_material
	_build_side_contents()
	_build_header()
	_build_object_bar()
	if not _shot_path.is_empty():
		_capture_after_frames.call_deferred()


func _object_from_name(value: String) -> int:
	match value.to_lower():
		"panel": return VolumetricGlassLayer.ObjectType.PANEL
		"torus": return VolumetricGlassLayer.ObjectType.TORUS
		"cluster": return VolumetricGlassLayer.ObjectType.CLUSTER
		_: return VolumetricGlassLayer.ObjectType.ORB


func _material_from_name(value: String) -> int:
	match value.to_lower():
		"regular": return VolumetricGlassLayer.MaterialStyle.REGULAR
		"regular-tinted": return VolumetricGlassLayer.MaterialStyle.REGULAR_TINTED
		"clear-tinted": return VolumetricGlassLayer.MaterialStyle.CLEAR_TINTED
		"identity": return VolumetricGlassLayer.MaterialStyle.IDENTITY
		_: return VolumetricGlassLayer.MaterialStyle.CLEAR


func _view_from_name(value: String) -> int:
	match value.to_lower():
		"side": return VolumetricGlassLayer.ViewPreset.SIDE
		"grazing": return VolumetricGlassLayer.ViewPreset.GRAZING
		"top": return VolumetricGlassLayer.ViewPreset.TOP
		_: return VolumetricGlassLayer.ViewPreset.THREE_QUARTER


func _build_header() -> void:
	var header := MarginContainer.new()
	header.position = Vector2(44.0, 34.0)
	header.size = Vector2(1112.0, 72.0)
	header.add_theme_constant_override("margin_left", 18)
	header.add_theme_constant_override("margin_right", 18)
	var row := HBoxContainer.new()
	header.add_child(row)
	var title := _label("Spatial Gallery", 22, Color.WHITE)
	row.add_child(title)
	row.add_child(_spacer())
	_object_label = _label(OBJECT_NAMES[_glass.object_type], 15, Color(1.0, 1.0, 1.0, 0.72))
	row.add_child(_object_label)
	_material_button = Button.new()
	_material_button.text = MATERIAL_NAMES[_material_index]
	_material_button.flat = true
	_material_button.add_theme_font_size_override("font_size", 15)
	_material_button.add_theme_color_override("font_color", Color.WHITE)
	_material_button.pressed.connect(_cycle_material)
	row.add_child(_material_button)
	add_child(header)


func _build_side_contents() -> void:
	var contents := _glass.get_side_content_layer()
	_playback_button = Button.new()
	_playback_button.text = "Pause"
	_playback_button.position = Vector2(16.0, 20.0)
	_playback_button.size = Vector2(64.0, 56.0)
	_playback_button.flat = true
	_playback_button.add_theme_font_size_override("font_size", 14)
	_playback_button.add_theme_color_override("font_color", Color.WHITE)
	_playback_button.pressed.connect(_toggle_playback)
	contents.add_child(_playback_button)

	var title := _label("Glass Horizon", 18, Color.WHITE)
	title.position = Vector2(92.0, 19.0)
	contents.add_child(title)
	var subtitle := _label("Harbour Sessions", 14, Color(1.0, 1.0, 1.0, 0.72))
	subtitle.position = Vector2(92.0, 49.0)
	contents.add_child(subtitle)
	var duration := _label("3:42", 14, Color(1.0, 1.0, 1.0, 0.88))
	duration.position = Vector2(388.0, 35.0)
	contents.add_child(duration)


func _toggle_playback() -> void:
	_playback_button.text = "Play" if _playback_button.text == "Pause" else "Pause"


func _build_object_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(410.0, 716.0)
	bar.size = Vector2(380.0, 54.0)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	for index in OBJECT_NAMES.size():
		var button := Button.new()
		button.text = OBJECT_NAMES[index]
		button.flat = true
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.pressed.connect(_select_object.bind(index))
		bar.add_child(button)
	add_child(bar)


func _select_object(index: int) -> void:
	_glass.set_object_type(index)
	_object_label.text = OBJECT_NAMES[index]


func _cycle_material() -> void:
	_material_index = (_material_index + 1) % MATERIAL_NAMES.size()
	_glass.set_material_style(_material_index)
	_material_button.text = MATERIAL_NAMES[_material_index]


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _capture_after_frames() -> void:
	for _frame in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_shot_path)
	if error != OK:
		printerr("VOLUMETRIC APP FAIL - capture error %d" % error)
		get_tree().quit(1)
		return
	print("VOLUMETRIC APP OK size=%dx%d shot=%s" % [image.get_width(), image.get_height(), _shot_path])
	get_tree().quit(0)
