class_name ContentLoader
extends RefCounted


## Loads every resource file in a folder, sorted by file name.
static func load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var names: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		# Exported builds list resources as "name.tres.remap".
		var file_name := file.trim_suffix(".remap")
		if (file_name.ends_with(".tres") or file_name.ends_with(".res")) and not names.has(file_name):
			names.append(file_name)
	names.sort()
	for file_name in names:
		var res: Resource = load(dir_path.path_join(file_name))
		if res != null:
			out.append(res)
	return out
