#include "fish_school.h"
#include "mc_common.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/geometry_instance3d.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/packed_scene.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>

using namespace godot;

static const char *DIR = "res://props/farm/animals/";
static const char *SHADER = "res://shaders/fish.gdshader";

struct RowDef {
	const char *name;
	float cruise, dart, turn;
	bool schools;
	float deep, peck;
	float s0, s1;
};
static const RowDef KIND_TABLE[] = {
	{ "ca_chep", 0.16f, 0.95f, 1.4f, false, 0.85f, 26.0f, 0.55f, 1.0f },
	{ "ca_tram", 0.18f, 1.05f, 1.3f, false, 0.6f, 22.0f, 0.5f, 0.9f },
	{ "ca_me", 0.15f, 0.95f, 1.5f, true, 0.3f, 14.0f, 0.55f, 0.85f },
	{ "ca_diec", 0.11f, 0.70f, 2.6f, true, 0.55f, 12.0f, 0.7f, 1.0f },
	{ "ca_ro", 0.09f, 0.60f, 3.0f, false, 0.7f, 18.0f, 0.75f, 1.0f },

	{ "ca_ro_phi", 0.10f, 0.75f, 2.4f, true, 0.45f, 16.0f, 0.5f, 1.0f },
	{ "ca_qua", 0.06f, 1.60f, 1.8f, false, 0.2f, 40.0f, 0.5f, 1.0f },
	{ "ca_tre", 0.08f, 0.90f, 2.0f, false, 1.0f, 60.0f, 0.55f, 1.0f },
	{ "chach", 0.05f, 0.50f, 3.0f, false, 1.0f, 50.0f, 0.6f, 1.0f },
	{ "luon", 0.07f, 0.60f, 2.2f, false, 1.0f, 60.0f, 0.55f, 1.0f },
	{ "ca_co", 0.07f, 0.50f, 3.4f, false, 0.0f, 8.0f, 0.6f, 1.0f },
	{ "ca_bong", 0.03f, 0.60f, 2.5f, false, 1.0f, 999.0f, 0.5f, 1.0f },
	{ "ca_muong", 0.20f, 1.00f, 2.8f, true, 0.1f, 9.0f, 0.6f, 1.0f },
	{ "ca_nganh", 0.14f, 1.00f, 1.8f, false, 0.95f, 40.0f, 0.5f, 1.0f },
	{ "ca_that_lat", 0.08f, 0.80f, 1.6f, false, 0.5f, 30.0f, 0.5f, 1.0f },
	{ "ca_chep:do", 0.12f, 0.80f, 1.2f, false, 0.5f, 20.0f, 0.65f, 1.1f },
	{ "ca_tram:den", 0.12f, 0.90f, 0.9f, false, 1.0f, 60.0f, 1.8f, 2.2f },
};

struct SwimDef {
	const char *name;
	float wave_n, eel, beat;
};
static const SwimDef SWIM_TABLE[] = {
	{ "chach", 7.0f, 1.0f, 1.3f }, { "luon", 6.0f, 1.0f, 1.4f }, { "ca_tre", 4.5f, 0.4f, 1.1f }, { "ca_qua", 4.0f, 0.25f, 1.0f },
	{ "ca_that_lat", 3.2f, 0.0f, 0.45f }
};

static float rnd() { return (float)UtilityFunctions::randf(); }
static float rnd_range(float a, float b) { return (float)UtilityFunctions::randf_range(a, b); }

void FishSchool::_bind_methods() {
	ClassDB::bind_static_method("FishSchool", D_METHOD("make", "parent", "centre", "radii", "water", "floor_fn", "kinds"), &FishSchool::make);
	ClassDB::bind_method(D_METHOD("set_centre", "v"), &FishSchool::set_centre);
	ClassDB::bind_method(D_METHOD("get_centre"), &FishSchool::get_centre);
	ClassDB::bind_method(D_METHOD("set_radii", "v"), &FishSchool::set_radii);
	ClassDB::bind_method(D_METHOD("get_radii"), &FishSchool::get_radii);
	ClassDB::bind_method(D_METHOD("set_water_y", "v"), &FishSchool::set_water_y);
	ClassDB::bind_method(D_METHOD("get_water_y"), &FishSchool::get_water_y);
	ClassDB::bind_method(D_METHOD("set_floor_at", "fn"), &FishSchool::set_floor_at);
	ClassDB::bind_method(D_METHOD("get_floor_at"), &FishSchool::get_floor_at);
	ClassDB::bind_method(D_METHOD("set_scarer", "node"), &FishSchool::set_scarer);
	ClassDB::bind_method(D_METHOD("get_scarer"), &FishSchool::get_scarer);
	ClassDB::bind_method(D_METHOD("set_scare_r", "v"), &FishSchool::set_scare_r);
	ClassDB::bind_method(D_METHOD("get_scare_r"), &FishSchool::get_scare_r);
	ClassDB::bind_method(D_METHOD("set_shallow", "v"), &FishSchool::set_shallow);
	ClassDB::bind_method(D_METHOD("get_shallow"), &FishSchool::get_shallow);
	ClassDB::bind_method(D_METHOD("get_fish"), &FishSchool::get_fish);
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "centre"), "set_centre", "get_centre");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "radii"), "set_radii", "get_radii");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "water_y"), "set_water_y", "get_water_y");
	ADD_PROPERTY(PropertyInfo(Variant::CALLABLE, "floor_at"), "set_floor_at", "get_floor_at");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "scarer", PROPERTY_HINT_NODE_TYPE, "Node3D"), "set_scarer", "get_scarer");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "scare_r"), "set_scare_r", "get_scare_r");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shallow"), "set_shallow", "get_shallow");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "fish"), "", "get_fish");

	ClassDB::bind_method(D_METHOD("add_kind", "kind", "n"), &FishSchool::add_kind);
	ClassDB::bind_method(D_METHOD("scare", "at", "r"), &FishSchool::scare, DEFVAL(1.5f));
	ClassDB::bind_method(D_METHOD("cm_of", "f"), &FishSchool::cm_of);
	ClassDB::bind_method(D_METHOD("near", "at", "r"), &FishSchool::near);
	ClassDB::bind_method(D_METHOD("lure", "f", "at"), &FishSchool::lure);
	ClassDB::bind_method(D_METHOD("let_go", "f"), &FishSchool::let_go);
	ClassDB::bind_method(D_METHOD("take", "f"), &FishSchool::take);
	ClassDB::bind_method(D_METHOD("reset", "kinds"), &FishSchool::reset);
}

Object *FishSchool::make(Node *parent, const Vector2 &centre_, const Vector2 &radii_, float water, const Callable &floor_fn, const Array &kinds_) {
	FishSchool *s = memnew(FishSchool);
	s->set_name("Fish");
	s->centre = centre_;
	s->radii = radii_;
	s->water_y = water;
	s->floor_at = floor_fn;
	parent->add_child(s);
	for (int i = 0; i < kinds_.size(); i++) {
		Array k = kinds_[i];
		s->add_kind(k[0], (int)k[1]);
	}
	return s;
}

void FishSchool::set_scarer(Object *o) {
	scarer_id = o ? o->get_instance_id() : 0;
}

Object *FishSchool::get_scarer() const {
	return scarer_id ? ObjectDB::get_instance(scarer_id) : nullptr;
}

void FishSchool::_ready() {
	set_as_top_level(true);
	set_process(true);
	Node3D *dot = memnew(Node3D);
	dot->set_name("Rings");
	add_child(dot);
	dot->set_global_position(Vector3(centre.x, water_y, centre.y));
	Ref<Script> sfx = mc::Scripts::swim_fx_gd();
	if (sfx.is_valid()) {
		Object *fx = sfx->call("attach", dot, 0.3f, water_y);
		if (fx) {
			fx_id = fx->get_instance_id();
			Dictionary consts = sfx->get_script_constant_map();
			fx->set("mode", consts.get("OFF", 0));
		}
	}
}

FishSchool::KindRow FishSchool::kind_row(const String &kind) {

	const RowDef *found = nullptr;
	String base = kind.get_slice(":", 0);
	for (const RowDef &r : KIND_TABLE) {
		if (kind == r.name) {
			found = &r;
			break;
		}
		if (found == nullptr && base == r.name) {
			found = &r;
		}
	}
	if (found == nullptr) {
		found = &KIND_TABLE[3];
	}
	return KindRow{ found->cruise, found->dart, found->turn, found->schools, found->deep, found->peck, Vector2(found->s0, found->s1) };
}

int FishSchool::kind_index(const String &kind) {
	for (size_t i = 0; i < kinds.size(); i++) {
		if (kinds[i].name == kind) {
			return (int)i;
		}
	}
	return -1;
}

int FishSchool::make_kind(const String &kind) {
	String base = kind.get_slice(":", 0);
	String coat = kind.contains(":") ? kind.get_slice(":", 1) : String();
	Ref<PackedScene> ps = ResourceLoader::get_singleton()->load(String(DIR) + base + ".glb");
	ERR_FAIL_COND_V_MSG(ps.is_null(), -1, "FishSchool: no model for " + kind);
	Node3D *scene = Object::cast_to<Node3D>(ps->instantiate());
	TypedArray<Node> mis = scene->find_children("*", "MeshInstance3D", true, false);
	ERR_FAIL_COND_V_MSG(mis.is_empty(), -1, "FishSchool: no mesh in " + kind);
	MeshInstance3D *mi = Object::cast_to<MeshInstance3D>(mis[0]);
	Ref<Mesh> mesh = mi->get_mesh();
	KindDraw kd;
	kd.name = kind;
	kd.row = kind_row(kind);

	Transform3D t;
	for (Node3D *n = mi; n != nullptr && n != scene; n = Object::cast_to<Node3D>(n->get_parent())) {
		t = n->get_transform() * t;
	}
	kd.xf = t;
	AABB box = mesh->get_aabb();
	kd.len = box.size.z * kd.xf.basis.get_scale().z;
	Ref<ShaderMaterial> m;
	m.instantiate();
	m->set_shader(ResourceLoader::get_singleton()->load(SHADER));
	m->set_shader_parameter("albedo_tex", ResourceLoader::get_singleton()->load(String(DIR) + base + "_alb" + (coat.is_empty() ? String() : "_" + coat) + ".png"));
	float wave_n = 3.2f, eel = 0.0f, beat = 1.0f;
	for (const SwimDef &sd : SWIM_TABLE) {
		if (base == sd.name) {
			wave_n = sd.wave_n;
			eel = sd.eel;
			beat = sd.beat;
		}
	}
	m->set_shader_parameter("wave_n", wave_n);
	m->set_shader_parameter("eel", eel);
	m->set_shader_parameter("beat", beat);
	m->set_shader_parameter("head_z", box.get_end().z);
	m->set_shader_parameter("body_len", box.size.z);
	memdelete(scene);
	Ref<MultiMesh> mm;
	mm.instantiate();
	mm->set_transform_format(MultiMesh::TRANSFORM_3D);
	mm->set_use_custom_data(true);
	mm->set_mesh(mesh);
	MultiMeshInstance3D *mmi = memnew(MultiMeshInstance3D);
	mmi->set_name(kind.replace(":", "_"));
	mmi->set_multimesh(mm);
	mmi->set_material_override(m);
	mmi->set_cast_shadows_setting(GeometryInstance3D::SHADOW_CASTING_SETTING_OFF);
	mmi->set_visibility_range_end(FAR + 4.0f);
	add_child(mmi);

	mmi->set_custom_aabb(AABB(Vector3(centre.x - radii.x, water_y - 1.0f, centre.y - radii.y), Vector3(radii.x * 2.0f, 1.1f, radii.y * 2.0f)));
	kd.mm = mm;
	kinds.push_back(kd);
	return (int)kinds.size() - 1;
}

int FishSchool::count(int kind) const {
	int c = 0;
	for (const Fish &f : fish) {
		c += f.kind == kind ? 1 : 0;
	}
	return c;
}

int FishSchool::index_of(const Dictionary &f) const {
	int id = (int)f.get("id", -1);
	for (size_t i = 0; i < fish.size(); i++) {
		if (fish[i].id == id) {
			return (int)i;
		}
	}
	return -1;
}

const char *FishSchool::state_name(State s) {
	switch (s) {
		case CRUISE:
			return "cruise";
		case HANG:
			return "hang";
		case RISE:
			return "rise";
		case FLEE:
			return "flee";
		default:
			return "bait";
	}
}

void FishSchool::set_state(Fish &f, State s) {
	if (f.state != s) {
		f.state = s;
		f.d["state"] = state_name(s);
	}
}

float FishSchool::floor_y(float x, float z) {
	return floor_at.is_valid() ? (float)(double)floor_at.call(x, z) : water_y - 1.0f;
}

Vector3 FishSchool::spot(float deep) {

	float a = rnd() * (float)Math::TAU;
	float r = Math::sqrt(rnd()) * 0.78f;
	float x = centre.x + Math::cos(a) * r * radii.x;
	float z = centre.y + Math::sin(a) * r * radii.y;
	float lo = floor_y(x, z) + 0.06f;
	float hi = water_y - 0.07f;
	float y = hi > lo ? Math::lerp(hi, lo, mc::clampf(deep - shallow + rnd_range(-0.25f, 0.25f), 0.0f, 1.0f)) : hi;
	return Vector3(x, y, z);
}

float FishSchool::e(const Vector3 &p) const {
	Vector2 q = (Vector2(p.x, p.z) - centre) / radii;
	return q.dot(q);
}

void FishSchool::bolt(Fish &f, const Vector3 &from) {
	Vector3 away(f.pos.x - from.x, 0, f.pos.z - from.z);
	if (away.length() < 0.01f) {
		away = Vector3(rnd() - 0.5f, 0, rnd() - 0.5f);
	}
	Vector3 g = f.pos + away.normalized() * rnd_range(1.0f, 1.8f);

	Vector2 q = (Vector2(g.x, g.z) - centre) / radii;
	if (q.length() > 0.75f) {
		q = q.normalized() * 0.75f;
	}
	g = Vector3(centre.x + q.x * radii.x, 0, centre.y + q.y * radii.y);
	g.y = floor_y(g.x, g.z) + 0.06f;
	f.goal = Vector3(g.x, MIN(g.y, water_y - 0.07f), g.z);
	set_state(f, FLEE);
	f.there = false;
	f.d["there"] = false;
	f.t = rnd_range(1.2f, 2.0f);
}

void FishSchool::add_kind(const String &kind, int n) {

	int ki = kind_index(kind);
	if (ki < 0) {
		ki = make_kind(kind);
		if (ki < 0) {
			return;
		}
	}
	const KindRow &k = kinds[ki].row;
	Vector2 cm;
	Ref<Script> ft = mc::Scripts::fish_table_gd();
	if (ft.is_valid()) {
		cm = ft->call("cm", kind);
	}
	int lead = -1;
	for (int i = 0; i < n; i++) {
		Fish f;
		f.id = next_id++;
		f.kind = ki;
		f.pos = spot(k.deep);
		f.yaw = rnd() * (float)Math::TAU;
		f.goal = spot(k.deep);
		f.state = CRUISE;
		f.t = rnd_range(0.0f, 3.0f);
		f.ph = rnd() * (float)Math::TAU;
		f.amp = 0.6f;
		f.size = cm != Vector2() ? rnd_range(cm.x, cm.y) / 100.0f / kinds[ki].len : rnd_range(k.size.x, k.size.y);
		f.peck = rnd_range(3.0f, k.peck);
		f.lead = lead;
		f.slot = i;
		f.offset = Vector3(rnd_range(-0.25f, 0.25f), rnd_range(-0.05f, 0.05f), rnd_range(-0.35f, -0.15f));
		f.d["id"] = f.id;
		f.d["kind"] = kind;
		f.d["size"] = f.size;
		f.d["state"] = "cruise";
		f.d["pos"] = f.pos;
		f.d["gap"] = 0.0f;
		f.d["there"] = false;
		if (k.schools && lead < 0) {
			lead = (int)fish.size();
		}
		fish_arr.push_back(f.d);
		fish.push_back(f);
	}
	kinds[ki].mm->set_instance_count(count(ki));
	draw_all();
}

void FishSchool::scare(const Vector3 &at, float r) {

	for (Fish &f : fish) {
		if (Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < r) {
			bolt(f, Vector3(at.x, f.pos.y, at.z));
		}
	}
}

float FishSchool::cm_of(const Dictionary &f) const {

	int i = index_of(f);
	if (i < 0) {
		return 0.0f;
	}
	return fish[i].size * kinds[fish[i].kind].len * 100.0f;
}

Array FishSchool::near(const Vector3 &at, float r) const {

	std::vector<std::pair<float, int>> out;
	for (size_t i = 0; i < fish.size(); i++) {
		const Fish &f = fish[i];
		float d = Vector2(f.pos.x - at.x, f.pos.z - at.z).length();
		if (f.state != FLEE && d < r) {
			out.push_back({ d, (int)i });
		}
	}
	std::sort(out.begin(), out.end(), [](const std::pair<float, int> &a, const std::pair<float, int> &b) { return a.first < b.first; });
	Array res;
	for (const auto &o : out) {
		res.push_back(fish[o.second].d);
	}
	return res;
}

void FishSchool::lure(const Dictionary &fd, const Vector3 &at) {

	int i = index_of(fd);
	if (i < 0) {
		return;
	}
	Fish &f = fish[i];
	set_state(f, BAIT);
	f.bait = Vector3(at.x, MAX(water_y - 0.06f - 0.05f * f.size, floor_y(at.x, at.z) + 0.06f), at.z);
	f.d["bait"] = f.bait;
	f.gap = 0.14f;
	f.d["gap"] = f.gap;
	f.there = false;
	f.d["there"] = false;
	f.lead = -1;
}

void FishSchool::let_go(const Dictionary &fd) {

	int i = index_of(fd);
	if (i < 0) {
		return;
	}
	Fish &f = fish[i];
	bolt(f, f.state == BAIT || f.d.has("bait") ? f.bait : f.pos);
}

Dictionary FishSchool::take(const Dictionary &fd) {

	int i = index_of(fd);
	if (i < 0) {
		return Dictionary();
	}
	Dictionary d = fish[i].d;
	int ki = fish[i].kind;
	fish.erase(fish.begin() + i);
	fish_arr.remove_at(i);
	for (Fish &g : fish) {
		if (g.lead == i) {
			g.lead = -1;
		} else if (g.lead > i) {
			g.lead -= 1;
		}
	}
	kinds[ki].mm->set_instance_count(count(ki));
	draw_all();
	return d;
}

void FishSchool::reset(const Array &kinds_) {

	fish.clear();
	fish_arr.clear();
	for (KindDraw &kd : kinds) {
		kd.mm->set_instance_count(0);
	}
	for (int i = 0; i < kinds_.size(); i++) {
		Array k = kinds_[i];
		add_kind(k[0], (int)k[1]);
	}
}

void FishSchool::_process(double delta_d) {
	Camera3D *cam = get_viewport() ? get_viewport()->get_camera_3d() : nullptr;
	if (cam != nullptr) {
		bool far = cam->get_global_position().distance_to(Vector3(centre.x, water_y, centre.y)) > FAR + MAX(radii.x, radii.y);
		if (far) {
			return;
		}
	}
	float delta = MIN((float)delta_d, 1.0f / 20.0f);

	Vector3 s;
	const Vector3 *sp = nullptr;
	bool s_moving = false;
	Node3D *scarer = Object::cast_to<Node3D>(get_scarer());
	if (scarer != nullptr) {
		s = scarer->get_global_position();
		sp = &s;
		s_moving = has_last_scarer && Vector2(s.x - last_scarer.x, s.z - last_scarer.z).length() > delta * 0.4f;
		last_scarer = s;
		has_last_scarer = true;
	}
	for (Fish &f : fish) {
		steer(f, delta, sp, s_moving);
	}
	draw_all();
}

void FishSchool::steer(Fish &f, float delta, const Vector3 *s, bool s_moving) {
	const KindRow &k = kinds[f.kind].row;
	f.t -= delta;
	if (s != nullptr && f.state != FLEE) {
		float d = Vector2(f.pos.x - s->x, f.pos.z - s->z).length();
		if (d < scare_r && (s_moving || d < scare_r * 0.5f)) {
			bolt(f, *s);
		}
	}
	Vector3 goal = f.goal;
	float cruise = k.cruise * f.size;
	float want = cruise;
	float beat = 1.0f;
	float hz = 1.6f;
	switch (f.state) {
		case CRUISE: {
			if (f.lead >= 0 && fish[f.lead].state == FLEE) {
				const Fish &l = fish[f.lead];
				set_state(f, FLEE);
				f.goal = l.goal + Basis(Vector3(0, 1, 0), l.yaw).xform(f.offset);
				f.t = l.t;
			} else if (f.lead >= 0) {
				const Fish &l = fish[f.lead];
				goal = l.pos + Basis(Vector3(0, 1, 0), l.yaw).xform(f.offset);
				want = cruise * mc::clampf(Vector2(goal.x - f.pos.x, goal.z - f.pos.z).length() / 0.3f, 0.0f, 1.6f);
			} else if (Vector2(goal.x - f.pos.x, goal.z - f.pos.z).length() < 0.25f) {
				set_state(f, HANG);
				f.t = rnd_range(1.5f, 5.0f);
			}
			f.peck -= delta;
			if (f.peck <= 0.0f && f.lead < 0) {
				set_state(f, RISE);
				f.peck = rnd_range(k.peck * 0.6f, k.peck * 1.4f);
			}
		} break;
		case HANG: {
			want = 0.0f;
			beat = 0.3f;
			hz = 0.9f;
			if (f.t <= 0.0f) {
				set_state(f, CRUISE);
				f.goal = spot(k.deep);
			}
		} break;
		case RISE: {
			want = cruise * 0.8f;
			goal = Vector3(f.pos.x + Math::sin(f.yaw) * 0.3f, water_y - 0.035f, f.pos.z + Math::cos(f.yaw) * 0.3f);
			if (Math::abs(f.pos.y - goal.y) < 0.02f) {
				Object *fx = fx_id ? ObjectDB::get_instance(fx_id) : nullptr;
				if (fx) {
					fx->call("ring", f.pos, 0.02f * f.size, 0.25f * f.size, 1.4f, 0.6f);
				}
				set_state(f, CRUISE);
				f.goal = spot(k.deep);
			}
		} break;
		case FLEE: {
			want = k.dart * f.size;
			beat = 1.6f;
			hz = 5.0f;
			if (f.t <= 0.0f) {
				set_state(f, HANG);
				f.t = rnd_range(2.0f, 4.0f);
			}
		} break;
		case BAIT: {
			f.gap = (float)(double)f.d.get("gap", f.gap);
			Vector3 d(f.bait.x - f.pos.x, 0, f.bait.z - f.pos.z);
			goal = f.bait - (d.length() > 0.001f ? d.normalized() : Vector3(0, 0, -1)) * (kinds[f.kind].len * f.size * 0.5f + f.gap);
			goal.y = f.bait.y;
			float off = Vector2(goal.x - f.pos.x, goal.z - f.pos.z).length();
			want = cruise * mc::clampf(off / 0.25f, 0.35f, 1.3f);
			if (off < 0.1f || f.there) {
				if (!f.there) {
					f.there = true;
					f.d["there"] = true;
				}
				f.yaw = Math::lerp_angle(f.yaw, Math::atan2(d.x, d.z), mc::clampf(delta * 5.0f, 0.0f, 1.0f));
				Vector3 was = f.pos;
				f.pos = f.pos.lerp(goal, mc::clampf(delta * 9.0f, 0.0f, 1.0f));
				f.speed = (f.pos - was).length() / MAX(delta, 0.001f);
				float lunge = mc::clampf(f.speed / 0.4f, 0.0f, 1.0f);
				f.amp = Math::lerp(f.amp, 0.35f + 1.2f * lunge, mc::clampf(delta * 6.0f, 0.0f, 1.0f));
				f.ph = mc::wrapf(f.ph + delta * (float)Math::TAU * Math::lerp(1.0f, 4.0f, lunge), 0.0f, (float)Math::TAU);
				f.pitch = Math::lerp(f.pitch, 0.0f, mc::clampf(delta * 3.0f, 0.0f, 1.0f));
				f.bow = Math::lerp(f.bow, 0.0f, mc::clampf(delta * 3.0f, 0.0f, 1.0f));
				f.d["pos"] = f.pos;
				return;
			}
		} break;
	}

	Vector3 to = goal - f.pos;
	Vector2 flat(to.x, to.z);
	float turn = 0.0f;
	if (flat.length() > 0.02f && want > 0.0f) {
		float aim = Math::atan2(to.x, to.z);
		float dy = mc::wrapf(aim - f.yaw, -(float)Math::PI, (float)Math::PI);
		float rate = k.turn * (f.state == FLEE ? 2.2f : 1.0f);
		turn = mc::clampf(dy, -rate * delta, rate * delta);
		f.yaw = mc::wrapf(f.yaw + turn, -(float)Math::PI, (float)Math::PI);
		want *= mc::clampf(1.0f - Math::abs(dy) / (float)Math::PI, 0.25f, 1.0f);
	}
	f.speed = Math::lerp(f.speed, want, mc::clampf(delta * (f.state == FLEE ? 6.0f : 1.6f), 0.0f, 1.0f));
	Vector3 fwd(Math::sin(f.yaw), 0, Math::cos(f.yaw));
	Vector3 p = f.pos + fwd * f.speed * delta;
	p.y = mc::move_toward(p.y, goal.y, MAX(f.speed, 0.06f) * (f.state == RISE ? 1.2f : 0.5f) * delta);

	if (e(p) > 0.85f) {
		Vector2 q = (Vector2(p.x, p.z) - centre) / radii;
		q = q.normalized() * Math::sqrt(0.85f);
		p = Vector3(centre.x + q.x * radii.x, p.y, centre.y + q.y * radii.y);
		if (f.state != RISE) {
			f.goal = spot(k.deep);
		}
	}
	float lo = floor_y(p.x, p.z) + 0.05f * f.size;
	p.y = mc::clampf(p.y, MIN(lo, water_y - 0.035f), water_y - 0.035f);
	f.pitch = Math::lerp(f.pitch, mc::clampf((p.y - f.pos.y) / MAX(f.speed * delta, 0.001f), -0.5f, 0.5f), mc::clampf(delta * 3.0f, 0.0f, 1.0f));
	f.pos = p;
	f.d["pos"] = p;

	float sp = f.speed / MAX(cruise, 0.01f);
	f.amp = Math::lerp(f.amp, beat * mc::clampf(0.35f + 0.65f * sp, 0.3f, 1.6f), mc::clampf(delta * 4.0f, 0.0f, 1.0f));
	f.ph = mc::wrapf(f.ph + delta * (float)Math::TAU * hz * Math::lerp(0.6f, 1.0f, mc::clampf(sp, 0.0f, 1.0f)), 0.0f, (float)Math::TAU);
	f.bow = Math::lerp(f.bow, mc::clampf(turn / MAX(delta, 0.001f) / 2.5f, -1.0f, 1.0f), mc::clampf(delta * 5.0f, 0.0f, 1.0f));
}

void FishSchool::draw_all() {
	std::vector<int> idx(kinds.size(), 0);
	for (const Fish &f : fish) {
		int i = idx[f.kind]++;
		Basis b = Basis(Vector3(0, 1, 0), f.yaw) * Basis(Vector3(1, 0, 0), -f.pitch);
		kinds[f.kind].mm->set_instance_transform(i, Transform3D(b.scaled(Vector3(f.size, f.size, f.size)), f.pos) * kinds[f.kind].xf);
		kinds[f.kind].mm->set_instance_custom_data(i, Color(f.ph, f.amp, f.bow, 0.0f));
	}
}
