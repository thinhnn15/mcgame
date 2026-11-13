class_name TexCache
extends RefCounted

const DIR := "res://characters/_vram/"

static func enabled() -> bool:
	return OS.get_environment("MC_TEXC") != "0" and RenderingServer.has_os_feature("bptc")

static func shipped() -> bool:
	return not OS.has_feature("editor")

static func exists(path: String) -> bool:
	return ResourceLoader.exists(path) if shipped() else FileAccess.file_exists(path)

static func read(path: String) -> Image:
	if not shipped():
		return Image.load_from_file(ProjectSettings.globalize_path(path))
	var t := load(path) as Texture2D if ResourceLoader.exists(path) else null
	return t.get_image() if t else null

static var _prebuilt := {}

static func compressed(path: String) -> Image:
	if not enabled():
		return null
	if shipped():
		if _prebuilt.is_empty():
			for f in DirAccess.get_files_at(DIR):
				if f.ends_with(".res"):
					_prebuilt[f.get_slice(".", 0)] = DIR + f
		var key := path.trim_prefix("res://characters/").get_basename().replace("/", "__")
		return ResourceLoader.load(_prebuilt[key], "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image \
				if _prebuilt.has(key) else null
	var src := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(src):
		return null
	var stem := path.trim_prefix("res://characters/").get_basename().replace("/", "__")
	var cache := DIR + "%s.%d.res" % [stem, FileAccess.get_modified_time(src)]
	if FileAccess.file_exists(ProjectSettings.globalize_path(cache)):
		var c := ResourceLoader.load(cache, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
		if c != null:
			return c
	var img := Image.load_from_file(src)
	if img == null:
		return null
	img.generate_mipmaps()
	if path.ends_with("_nrm.png"):
		img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_NORMAL)
	else:
		img.compress(Image.COMPRESS_BPTC)
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for old in DirAccess.get_files_at(dir):
		if old.begins_with(stem + ".") and old.ends_with(".res"):
			DirAccess.remove_absolute(dir.path_join(old))
	ResourceSaver.save(img, cache, ResourceSaver.FLAG_COMPRESS)
	return img
