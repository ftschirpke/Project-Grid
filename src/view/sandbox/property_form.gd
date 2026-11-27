class_name PropertyForm
extends RefCounted
## Builds input fields from the exported properties of a resource, so the
## sandbox shows whatever numbers and switches a behaviour, effect or tile
## exports without knowing the type. A new exported number on a new script
## appears by itself.

const LABEL_WIDTH := 170.0


## Adds one row per exported number or switch of `res` to `parent` and
## returns how many it added. `changed` is called after every edit.
## Properties named in `skip` are left out.
static func add_fields(parent: Control, res: Resource, changed: Callable, skip: Array = []) -> int:
	var count := 0
	for property in res.get_property_list():
		if not _is_exported(property) or skip.has(property.name):
			continue
		var field := _make_field(res, property, changed)
		if field == null:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = String(property.name).capitalize()
		label.custom_minimum_size.x = LABEL_WIDTH
		row.add_child(label)
		row.add_child(field)
		parent.add_child(row)
		count += 1
	return count


## Resources held by the exported properties of `res`, directly or in arrays.
static func children(res: Resource) -> Array[Resource]:
	var out: Array[Resource] = []
	for property in res.get_property_list():
		if not _is_exported(property):
			continue
		var value: Variant = res.get(property.name)
		var candidates: Array = value if value is Array else [value]
		for candidate: Variant in candidates:
			if candidate is Resource and not candidate is Script:
				out.append(candidate)
	return out


## "ChaseBehavior" -> "Chase Behavior", from the script's class name.
static func type_title(res: Resource) -> String:
	var script := res.get_script() as Script
	var type_name := String(script.get_global_name()) if script != null else res.get_class()
	return type_name.capitalize()


static func _is_exported(property: Dictionary) -> bool:
	return property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR


static func _make_field(res: Resource, property: Dictionary, changed: Callable) -> Control:
	var prop_name: StringName = property.name
	match property.type:
		TYPE_BOOL:
			var box := CheckBox.new()
			box.button_pressed = res.get(prop_name)
			box.toggled.connect(func(on: bool) -> void:
				res.set(prop_name, on)
				changed.call())
			return box
		TYPE_INT, TYPE_FLOAT:
			if property.hint == PROPERTY_HINT_ENUM or property.hint == PROPERTY_HINT_FLAGS:
				return null
			var is_int: bool = property.type == TYPE_INT
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = 99
			spin.step = 1.0 if is_int else 0.5
			if property.hint == PROPERTY_HINT_RANGE:
				var parts: PackedStringArray = String(property.hint_string).split(",")
				if parts.size() >= 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
					spin.min_value = parts[0].to_float()
					spin.max_value = parts[1].to_float()
				if parts.size() >= 3 and parts[2].is_valid_float():
					spin.step = parts[2].to_float()
			spin.value = res.get(prop_name)
			spin.value_changed.connect(func(value: float) -> void:
				res.set(prop_name, int(value) if is_int else value)
				changed.call())
			return spin
	return null
