extends RefCounted

static var _of := {}
static var _made := {}

static func with_define(original: Shader, define: String) -> Shader:
	var key := "%d|%s" % [original.get_instance_id(), define]
	if _made.has(key):
		return _made[key]
	var code := original.code
	var at := code.find("shader_type spatial;")
	if at < 0:
		return original
	at += "shader_type spatial;".length()
	var c := Shader.new()
	c.code = code.substr(0, at) + "\n#define " + define + code.substr(at)
	c.resource_name = "%s+%s" % [original.resource_path.get_file(), define]
	_of[c] = original
	_made[key] = c
	return c

static func family(originals: Array) -> Array:
	var out := originals.duplicate()
	for c: Shader in _of:
		if _of[c] in originals:
			out.append(c)
	return out
