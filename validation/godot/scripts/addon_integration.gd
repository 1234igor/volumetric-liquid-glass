extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1200.0, 800.0)
	root.add_child(host)
	var glass := VolumetricGlassLayer.new()
	host.add_child(glass)
	await process_frame

	var back_buffer := glass.get_node("BackBufferCopy") as BackBufferCopy
	var volume := glass.get_node("Volume") as ColorRect
	var canonical_shadow := glass.get_node("CanonicalShadow") as ColorRect
	var canonical_glass := glass.get_node("CanonicalGlass") as ColorRect
	var side_contents := glass.get_side_content_layer()

	_expect(volume.visible, "default volumetric pass is visible")
	_expect(not canonical_glass.visible and not canonical_shadow.visible, "canonical pass starts hidden")
	_expect(back_buffer.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT, "active material captures the framebuffer")
	_expect(not glass.is_processing(), "animation is idle by default")
	_expect(glass.mouse_filter == Control.MOUSE_FILTER_IGNORE, "input is non-blocking by default")

	glass.set_object_type(VolumetricGlassLayer.ObjectType.PANEL)
	glass.set_view_preset(VolumetricGlassLayer.ViewPreset.SIDE)
	_expect(not volume.visible, "panel side disables the ray-marched pass")
	_expect(canonical_glass.visible and canonical_shadow.visible, "panel side enables canonical glass and shadow")
	_expect(side_contents.visible, "panel side exposes its content layer")
	_expect(
		(canonical_glass.material as ShaderMaterial).shader.resource_path.ends_with("canonical_liquid_glass.gdshader"),
		"panel side uses the canonical shader"
	)

	var custom_rect := Rect2(120.0, 160.0, 520.0, 112.0)
	glass.side_glass_rect = custom_rect
	_expect(canonical_glass.position == custom_rect.position and canonical_glass.size == custom_rect.size, "side bounds are configurable")
	_expect(side_contents.position == custom_rect.position and side_contents.size == custom_rect.size, "content follows side bounds")
	glass.side_glass_rect = Rect2(120.0, 160.0, 40.0, 20.0)
	glass.side_corner_radius = 48.0
	_expect((canonical_glass.material as ShaderMaterial).get_shader_parameter("corner_radius") == 10.0, "side radius is clamped to valid geometry")
	glass.side_glass_rect = custom_rect

	glass.interaction_enabled = true
	_expect(glass.mouse_filter == Control.MOUSE_FILTER_STOP, "opt-in interaction captures input")
	glass.animation_enabled = true
	_expect(not glass.is_processing(), "canonical side does not animate an unused volume phase")

	glass.set_material_style(VolumetricGlassLayer.MaterialStyle.IDENTITY)
	_expect(back_buffer.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "Identity disables framebuffer capture")
	_expect(not volume.visible and not canonical_glass.visible and not canonical_shadow.visible, "Identity disables all optical passes")
	_expect(side_contents.visible, "Identity preserves side contents")
	_expect(not glass.is_processing(), "Identity disables processing")
	_expect(glass.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Identity cannot block application input")

	glass.set_material_style(VolumetricGlassLayer.MaterialStyle.REGULAR)
	glass.set_view_preset(VolumetricGlassLayer.ViewPreset.THREE_QUARTER)
	_expect(back_buffer.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT and volume.visible, "leaving Identity restores capture and volume rendering")
	_expect(glass.is_processing(), "enabled volume animation resumes for volumetric views")
	_expect(glass.mouse_filter == Control.MOUSE_FILTER_STOP, "opt-in interaction resumes after Identity")

	host.queue_free()
	if _failures.is_empty():
		print("ADDON INTEGRATION OK - side dispatch, Identity, capture, processing, and input")
		quit(0)
		return
	for failure in _failures:
		printerr("ADDON INTEGRATION FAIL - %s" % failure)
	quit(1)
