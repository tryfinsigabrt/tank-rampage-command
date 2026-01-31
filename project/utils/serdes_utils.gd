class_name SerdesUtils

static func create_save_file_path(filename: String) -> String:
	print_debug("create_save_file_path: %s/%s" % [OS.get_user_data_dir(), filename])
	return "user://%s" % filename

static func does_file_exist(filename: String) -> bool:
	var file_path:String = create_save_file_path(filename)
	return FileAccess.file_exists(file_path)
	
static func read_file_as_string(file_path:String) -> String:
	if not FileAccess.file_exists(file_path):
		print_debug("read_file_as_string: %s does not exist" % file_path)
		return ""

	var file = FileAccess.open(file_path, FileAccess.READ)
	var contents:String = ""
	if file:
		contents = file.get_as_text()
		file.close()
	else:
		push_error("read_file_as_string: Failed to open file %s for reading" % file_path)
	return contents

static func write_file_as_string(file_path:String, contents: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(contents)
		file.flush()
		file.close()
	else:
		push_error("write_fle_as_string: Failed to open file %s for writing" % file_path)


static func serialize_as_json_string(data: Variant) -> String:
	return JSON.stringify(JSON.from_native(data, false))

static func deserialize_from_json_string(contents: String) -> Variant:
	var raw_json:Variant = JSON.parse_string(contents)
	if not raw_json:
		return null

	return JSON.to_native(raw_json, false)

static func write_file_as_properties(file_path:String, contents: Dictionary[String,String]) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		for key in contents:
			var value:String = contents[key]
			file.store_string(key)
			file.store_string("=")
			file.store_line(value)
		file.flush()
		file.close()
	else:
		push_error("write_file_as_properties: Failed to open file %s for writing" % file_path)

static func read_file_as_properties(file_path:String) -> Dictionary[String,String]:
	var properties:Dictionary[String,String] = {}
	
	if not FileAccess.file_exists(file_path):
		print_debug("read_file_as_properties: %s does not exist" % file_path)
		return properties

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line:String = file.get_line()
			if line:
				# Assuming keys do not have "=" delimiters in them
				var delimiter_index:int = line.find("=")
				if delimiter_index > 0:
					var key:String = line.substr(0, delimiter_index)
					# Returns empty string if delimiter_index + 1 is past the end of the string
					var value:String = line.substr(delimiter_index + 1)
					properties[key] = value
		file.close()
	else:
		push_error("read_file_as_string: Failed to open file %s for reading" % file_path)
	return properties
