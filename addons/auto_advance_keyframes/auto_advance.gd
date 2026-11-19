@tool
extends EditorPlugin

var inspector: EditorInspector

func _enter_tree() -> void:
	inspector = EditorInterface.get_inspector()
	if inspector:
		if not inspector.property_keyed.is_connected(_on_property_keyed):
			inspector.property_keyed.connect(_on_property_keyed)

func _exit_tree() -> void:
	if inspector and inspector.property_keyed.is_connected(_on_property_keyed):
		inspector.property_keyed.disconnect(_on_property_keyed)

func _on_property_keyed(property: String, value: Variant, advance: bool) -> void:
	if property != "frame" and property != "frame_coords":
		return
	
	var selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	if selected_nodes.is_empty():
		return
	var target_node = selected_nodes[0]
	
	# Incrementa o frame e avanca a timeline
	_advance_node_frame.call_deferred(target_node, property)
	_advance_timeline.call_deferred(target_node)

func _advance_node_frame(node: Node, prop: String) -> void:
	if not is_instance_valid(node):
		return
		
	if prop == "frame_coords":
		var h = int(node.get("hframes"))
		var v = int(node.get("vframes"))
		var coords: Vector2i = node.get("frame_coords")
		coords.x += 1
		if coords.x >= h:
			coords.x = 0
			coords.y += 1
		if coords.x < h and coords.y < v:
			node.set("frame_coords", coords)
			node.notify_property_list_changed()
	elif prop == "frame":
		var cur = int(node.get("frame"))
		var max_f = 0
		if "hframes" in node and "vframes" in node:
			max_f = int(node.get("hframes")) * int(node.get("vframes"))
		elif "sprite_frames" in node and node.get("sprite_frames") != null:
			var sf: SpriteFrames = node.get("sprite_frames")
			var anim = node.get("animation")
			if sf.has_animation(anim):
				max_f = sf.get_frame_count(anim)
				
		if max_f <= 0 or cur + 1 < max_f:
			node.set("frame", cur + 1)
			node.notify_property_list_changed()

func _advance_timeline(node: Node) -> void:
	var anim_player: AnimationPlayer = _find_active_animation_player(node)
	if not anim_player:
		return
		
	var cur_anim_name = anim_player.current_animation
	if cur_anim_name.is_empty() or not anim_player.has_animation(cur_anim_name):
		return
		
	var anim: Animation = anim_player.get_animation(cur_anim_name)
	var step = anim.step
	if step <= 0.0:
		step = 0.1
		
	var new_time = anim_player.current_animation_position + step
	if new_time > anim.length:
		new_time = anim.length
		
	anim_player.seek(new_time, true)

func _find_active_animation_player(node: Node) -> AnimationPlayer:
	# 1. Checa irmaos do no selecionado
	if node.get_parent():
		for child in node.get_parent().get_children():
			if child is AnimationPlayer and not child.current_animation.is_empty():
				return child
				
	# 2. Checa se o proprio no tem um filho AnimationPlayer
	for child in node.get_children():
		if child is AnimationPlayer and not child.current_animation.is_empty():
			return child
			
	# 3. Busca recursiva na cena editada
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if edited_scene_root:
		return _find_player_in_tree(edited_scene_root)
		
	return null

func _find_player_in_tree(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer and not root.current_animation.is_empty():
		return root
	for child in root.get_children():
		var res = _find_player_in_tree(child)
		if res:
			return res
	return null
