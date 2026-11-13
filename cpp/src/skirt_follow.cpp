#include "skirt_follow.h"
#include "mc_common.h"

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

static const char *DIRS[] = { "LF", "LC", "LB", "RF", "RC", "RB" };
static const float MARGIN = 0.3f;
static const float MAX_OUT = 0.97f;
static const float HEM_OUT = 0.55f;
static const float STIFF = 90.0f;
static const float DAMP = 13.0f;
static const float SWAY = 0.012f;
static const float DROOP = 0.7f;
static const float LIFT = 0.8f;
static const float HEM = 0.2f;
static const float FLOOR_GAP = -0.06f;

static const int RING[] = { 0, 1, 2, 5, 4, 3 };
static const float HEM_STIFF = 55.0f;
static const float HEM_DAMP = 7.0f;
static const float HEM_ACC = 0.05f;
static const float HEM_SWING = 0.3f;
static const float HEM_WIND = 0.08f;
static const float HEM_TURN = 0.16f;
static const float HEM_BOB = 0.02f;
static const float HEM_MAX = 0.6f;
static const float HEM_IN = 0.12f;
static const float HEM_NEIGHBOUR = 0.15f;
static const float HEM_B2 = 0.4f;

static float SEAT_TOP = 0.072f;
static float SEAT_KNEE = 0.074f;

static float SEAT_DRAPE = 0.55f;

static float SEAT_SIDE = 0.080f;
static float SEAT_SIDE_UP = 0.85f;

static float SEAT_SIDE_DRAPE = 0.7f;

void SkirtFollow::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_lap", "lap"), &SkirtFollow::set_lap);
	ClassDB::bind_method(D_METHOD("get_lap"), &SkirtFollow::get_lap);
	ClassDB::bind_method(D_METHOD("set_long_hem", "long_hem"), &SkirtFollow::set_long_hem);
	ClassDB::bind_method(D_METHOD("get_long_hem"), &SkirtFollow::get_long_hem);
	ClassDB::bind_method(D_METHOD("get_seated"), &SkirtFollow::get_seated);
	ClassDB::bind_method(D_METHOD("set_seat_lift", "lift"), &SkirtFollow::set_seat_lift);
	ClassDB::bind_method(D_METHOD("get_seat_lift"), &SkirtFollow::get_seat_lift);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "seat_lift"), "set_seat_lift", "get_seat_lift");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "lap"), "set_lap", "get_lap");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "long_hem"), "set_long_hem", "get_long_hem");
}

void SkirtFollow::setup(Skeleton3D *sk) {
	set_up = true;
	chains.clear();
	hem_wave = !OS::get_singleton()->get_cmdline_user_args().has("--no-hem-wave");
	if (OS::get_singleton()->has_environment("MC_SKIRT_SEAT")) {
		String e = OS::get_singleton()->get_environment("MC_SKIRT_SEAT");
		seat_on = e != "off";
		PackedFloat32Array v = e.split_floats(",");
		if (v.size() == 6) {
			SEAT_TOP = v[0];
			SEAT_KNEE = v[1];
			SEAT_DRAPE = v[2];
			SEAT_SIDE = v[3];
			SEAT_SIDE_UP = v[4];
			SEAT_SIDE_DRAPE = v[5];
		}
	}
	waist = sk->find_bone("Waist");
	Basis w_rest = sk->get_bone_global_rest(waist).basis.orthonormalized();
	Vector3 down_w = (w_rest.inverse().xform(Vector3(0, -1, 0))).normalized();
	for (int di = 0; di < 6; di++) {
		String ds = DIRS[di];
		String side = ds.left(1);
		int b1 = sk->find_bone("Skirt_1_" + ds);
		int b2 = sk->find_bone("Skirt_2_" + ds);
		int leg = sk->find_bone("Leg_1_" + side);
		int knee = sk->find_bone("Leg_2_" + side);
		int ankle = sk->find_bone("Ankle_" + side);
		if (b1 < 0 || b2 < 0 || leg < 0 || knee < 0) {
			continue;
		}
		Vector3 d0 = sk->get_bone_global_rest(b2).origin - sk->get_bone_global_rest(b1).origin;
		Vector3 d0_w = (w_rest.inverse().xform(d0)).normalized();
		Vector3 out_w = d0_w - down_w * d0_w.dot(down_w);
		Vector3 l0 = sk->get_bone_global_rest(knee).origin - sk->get_bone_global_rest(leg).origin;
		Basis leg_rest = sk->get_bone_global_rest(leg).basis.orthonormalized();
		int b3 = sk->find_bone("Skirt_3_" + ds);
		if (b3 < 0) {
			continue;
		}

		Vector3 d3 = (sk->get_bone_global_rest(b3).basis.orthonormalized().xform(Vector3(0, 1, 0))).normalized();
		Chain c;
		c.bone = b1;
		c.leg = leg;
		c.knee = knee;
		c.b2 = b2;
		c.b3 = b3;
		c.ring = RING[di];
		c.rest_local = sk->get_bone_rest(b1).basis.orthonormalized();
		c.r1 = w_rest.inverse() * sk->get_bone_global_rest(b1).basis.orthonormalized();
		c.d3 = w_rest.inverse().xform(d3);
		c.r2 = w_rest.inverse() * sk->get_bone_global_rest(b2).basis.orthonormalized();
		c.r3 = w_rest.inverse() * sk->get_bone_global_rest(b3).basis.orthonormalized();
		c.d0 = d0_w;
		c.out = out_w.normalized();
		c.down = down_w;
		c.leg_axis = leg_rest.inverse().xform(l0.normalized());
		c.front = ds.ends_with("F");
		c.at_side = ds.ends_with("C");
		c.d2 = w_rest.inverse().xform(sk->get_bone_global_rest(b2).basis.orthonormalized().xform(Vector3(0, 1, 0))).normalized();
		c.rest_pos = sk->get_bone_rest(b1).origin;
		c.parent = sk->get_bone_parent(b1);
		c.shin_axis = ankle >= 0 ? sk->get_bone_global_rest(knee).basis.orthonormalized().inverse().xform((sk->get_bone_global_rest(ankle).origin - sk->get_bone_global_rest(knee).origin).normalized()) : Vector3();
		c.cur = d0_w;
		c.vel = Vector3();
		c.prev_cur = d0_w;
		c.hem = Vector3();
		c.hem_v = Vector3();
		chains.push_back(c);
	}
}

void SkirtFollow::_process_modification_with_delta(double p_delta) {
	Skeleton3D *sk = get_skeleton();
	if (sk == nullptr) {
		return;
	}
	if (!set_up) {
		setup(sk);
	}
	if (waist < 0) {
		return;
	}
	float dt = (float)p_delta;
	if (dt <= 0.0f) {
		dt = 1.0f / 60.0f;
	}
	Transform3D w = sk->get_global_transform();
	Transform3D w_pose = sk->get_bone_global_pose(waist);
	Vector3 hp = (w * w_pose).origin;

	Camera3D *cam = sk->get_viewport() ? sk->get_viewport()->get_camera_3d() : nullptr;
	if (cam && !cam->is_position_in_frustum(hp) && cam->get_global_position().distance_to(hp) > 1.5f) {
		started = false;
		have_prev_basis = false;
		return;
	}
	Basis w_inv = w_pose.basis.orthonormalized().inverse();
	Basis sk_inv = w.basis.orthonormalized().inverse();

	if (!started) {
		prev_pos = hp;
		started = true;
	}
	Vector3 vel = (hp - prev_pos) / dt;
	Vector3 acc = (vel - prev_vel) / dt;
	prev_pos = hp;
	prev_vel = vel;
	Vector3 acc_w = w_inv.xform(sk_inv.xform(acc));
	Vector3 down_now = (w_inv.xform(sk_inv.xform(Vector3(0, -1, 0)))).normalized();
	Vector3 wind_w = hem_wave ? w_inv.xform(sk_inv.xform(mc::Wind::force(hp, mc::Wind::strength()))) : Vector3();

	Basis wb = (w.basis * w_pose.basis).orthonormalized();
	Vector3 omega_w;
	if (have_prev_basis) {
		Quaternion dq = (wb * prev_basis.inverse()).get_rotation_quaternion();
		float ang = dq.get_angle();
		if (ang > 1e-5f && ang < 1.0f) {
			omega_w = w_inv.xform(sk_inv.xform(dq.get_axis() * (ang / dt)));
		}
	}
	prev_basis = wb;
	have_prev_basis = true;
	Quaternion qs[6];
	float bends[6] = { 0, 0, 0, 0, 0, 0 };
	Vector3 seat2[6];
	float seat2_k[6] = { 0, 0, 0, 0, 0, 0 };
	Basis w_b = w_inv.transposed();
	seated = 0.0f;
	for (size_t i = 0; i < chains.size(); i++) {
		Chain &c = chains[i];
		Basis leg_b = sk->get_bone_global_pose(c.leg).basis.orthonormalized();
		Vector3 thigh_w = w_inv.xform(leg_b.xform(c.leg_axis));
		const Vector3 &o = c.out;
		const Vector3 &dn = c.down;
		const Vector3 &d0 = c.d0;
		float margin = (long_hem && c.front) ? 0.45f : MARGIN;
		float s = MAX(d0.dot(o), thigh_w.dot(o) + margin);
		Vector3 shin_w;
		if (long_hem && c.shin_axis != Vector3()) {
			shin_w = w_inv.xform(sk->get_bone_global_pose(c.knee).basis.orthonormalized().xform(c.shin_axis));
			s = MAX(s, shin_w.dot(o) + margin);
		}

		s = MIN(s, lap ? MAX_OUT : HEM_OUT);
		if (long_hem) {
			s = MIN(s, 0.8f);
		}
		Vector3 target = (o * s + dn * Math::sqrt(1.0f - s * s)).normalized();

		float raised = lap ? Math::smoothstep(0.6f, 0.15f, thigh_w.dot(dn)) : 0.0f;
		Vector3 shift;
		if (raised > 0.0f && !long_hem && seat_on) {
			if (c.front || c.at_side) {
				Vector3 hip = sk->get_bone_global_pose(c.leg).origin;
				Vector3 knee = sk->get_bone_global_pose(c.knee).origin;
				Vector3 ax = knee - hip;
				float len = ax.length();
				if (len > 1e-4f) {
					ax /= len;
					Vector3 up_s = sk_inv.xform(Vector3(0, 1, 0)).normalized();
					Vector3 u = up_s - ax * ax.dot(up_s);
					u = u.length() > 1e-4f ? u.normalized() : up_s;
					Transform3D pg = c.parent >= 0 ? sk->get_bone_global_pose(c.parent) : Transform3D();
					Vector3 root0 = pg.xform(c.rest_pos);
					Vector3 r = root0 - hip;
					float t = r.dot(ax);
					Vector3 perp = r - ax * t;
					Vector3 side = perp - u * perp.dot(u);
					Vector3 root1, aim;
					if (c.front) {
						float top = SEAT_TOP + seat_lift, kr = SEAT_KNEE + seat_lift;
						float sl = MIN(side.length(), top * 0.95f);
						Vector3 sd = side.length() > 1e-5f ? side.normalized() : Vector3();
						root1 = hip + ax * t + sd * sl + u * MAX(Math::sqrt(top * top - sl * sl), perp.dot(u));
						float kl = MIN(sl, kr * 0.95f);
						aim = knee + sd * kl + u * Math::sqrt(kr * kr - kl * kl);
						seat2[i] = w_inv.xform(ax * Math::cos(SEAT_DRAPE) - u * Math::sin(SEAT_DRAPE)).normalized();
					} else {
						Vector3 outw = side.length() > 1e-4f ? side.normalized() : w_b.xform(o);
						float sr = SEAT_SIDE + seat_lift;
						Vector3 np = outw * (sr * Math::cos(SEAT_SIDE_UP)) + u * (sr * Math::sin(SEAT_SIDE_UP));
						root1 = hip + ax * t + np;
						aim = knee + np;

						Vector3 fall = (outw * 0.55f - u).normalized();
						seat2[i] = w_inv.xform(ax * Math::cos(SEAT_SIDE_DRAPE) + fall * Math::sin(SEAT_SIDE_DRAPE)).normalized();
					}
					shift = root1 - root0;
					seat2_k[i] = raised;
					Vector3 d1 = aim - root1;
					if (d1.length() > 1e-4f) {
						target = target.slerp(w_inv.xform(d1.normalized()).normalized(), raised);
					}
				}
				if (c.front) {
					seated = MAX(seated, raised);
				}
			}
		} else if (raised > 0.0f && thigh_w.dot(o) > 0.3f) {
			Vector3 over = (thigh_w - dn * (long_hem ? 1.0f : LIFT)).normalized();
			target = target.slerp(over, raised * Math::smoothstep(0.3f, 0.7f, thigh_w.dot(o)));
		}
		Vector3 lag = -(acc_w - dn * acc_w.dot(dn)) * (long_hem ? 0.006f : SWAY);
		float lag_max = long_hem ? 0.15f : 0.35f;
		if (lag.length() > lag_max) {
			lag = lag.normalized() * lag_max;
		}
		target = (target + lag).normalized();

		float root_y = w.xform(sk->get_bone_global_pose(c.bone).origin + shift * raised).y;
		float room = (root_y - w.origin.y - FLOOR_GAP) / HEM;
		if (room < 1.0f) {
			float kd = mc::clampf(room, -0.2f, 1.0f);
			if (target.dot(down_now) > kd) {
				Vector3 flat = target - down_now * target.dot(down_now);
				if (flat.length() < 1e-3f) {
					flat = o - down_now * o.dot(down_now);
				}
				target = (flat.normalized() * Math::sqrt(1.0f - kd * kd) + down_now * kd).normalized();
			}
		}
		Vector3 cur = c.cur;
		Vector3 v = c.vel;
		v += ((target - cur) * STIFF - v * (long_hem ? 19.0f : DAMP)) * dt;
		cur = (cur + v * dt).normalized();
		if (long_hem && raised < 0.5f) {
			float need = MIN(MAX(thigh_w.dot(o), shin_w.dot(o)) + margin, MAX_OUT);
			float co = cur.dot(o);
			if (co < need) {
				Vector3 tg = cur - o * co;
				tg = tg.length() > 1e-4f ? tg.normalized() : dn;
				cur = (o * need + tg * Math::sqrt(1.0f - need * need)).normalized();
				float vo = v.dot(o);
				if (vo < 0.0f) {
					v -= o * vo;
				}
			}
		}
		c.cur = cur;
		c.vel = v;
		Quaternion q = mc::turn(d0, cur);
		sk->set_bone_pose_rotation(c.bone, (Basis(q) * c.rest_local).get_rotation_quaternion());
		if (shift != Vector3() && c.parent >= 0) {
			sk->set_bone_pose_position(c.bone, c.rest_pos + sk->get_bone_global_pose(c.parent).basis.inverse().xform(shift * raised));
			c.shifted = true;
		} else if (c.shifted) {
			sk->set_bone_pose_position(c.bone, c.rest_pos);
			c.shifted = false;
		}
		qs[i] = q;

		bends[i] = raised * (long_hem ? 0.35f : DROOP);
		if (hem_wave) {

			Vector3 swing = (cur - c.prev_cur) / dt;
			Vector3 tgt = -(acc_w - dn * acc_w.dot(dn)) * HEM_ACC - swing * HEM_SWING + wind_w * HEM_WIND
					- omega_w.cross(o) * HEM_TURN + o * omega_w.length() * HEM_TURN * 0.5f
					+ o * acc_w.dot(dn) * HEM_BOB;
			tgt -= cur * tgt.dot(cur);
			tgt *= (lap ? (long_hem ? 0.7f : 1.0f) : 0.5f) * (1.0f - raised) * mc::clampf(room, 0.0f, 1.0f);
			if (tgt.length() > HEM_MAX) {
				tgt = tgt.normalized() * HEM_MAX;
			}
			c.hem_v += ((tgt - c.hem) * HEM_STIFF - c.hem_v * HEM_DAMP) * dt;
			c.hem += c.hem_v * dt;
		}
		c.prev_cur = cur;
	}

	Vector3 by_ring[6];
	bool has[6] = { false, false, false, false, false, false };
	for (const Chain &c : chains) {
		by_ring[c.ring] = c.hem;
		has[c.ring] = true;
	}
	for (size_t i = 0; i < chains.size(); i++) {
		Chain &c = chains[i];
		Vector3 h;
		if (hem_wave) {
			const Vector3 &a = has[(c.ring + 5) % 6] ? by_ring[(c.ring + 5) % 6] : c.hem;
			const Vector3 &b = has[(c.ring + 1) % 6] ? by_ring[(c.ring + 1) % 6] : c.hem;
			h = c.hem * (1.0f - 2.0f * HEM_NEIGHBOUR) + (a + b) * HEM_NEIGHBOUR;
			c.hem = h;
			float in = h.dot(c.out);
			if (in < -HEM_IN) {
				h -= c.out * (in + HEM_IN);
			}
			if (h.length() > HEM_MAX) {
				h = h.normalized() * HEM_MAX;
			}
		}

		Basis q(qs[i]);
		Basis rb2, rb3;
		float ang = h.length();
		Vector3 dir = c.cur;
		if (ang > 1e-4f) {
			Vector3 axis = dir.cross(h / ang);
			if (axis.length() > 1e-4f) {
				axis.normalize();
				rb2 = Basis(axis, ang * HEM_B2);
				rb3 = Basis(axis, ang * (1.0f - HEM_B2));
			}
		}
		Basis g1 = q * c.r1;
		Basis fall2;
		if (seat2_k[i] > 0.0f) {
			Vector3 d2_now = q.xform(c.d2);
			fall2 = Basis(mc::turn(d2_now, d2_now.slerp(seat2[i], seat2_k[i]).normalized()));
		}
		Basis g2 = rb2 * fall2 * q * c.r2;
		sk->set_bone_pose_rotation(c.b2, (g1.inverse() * g2).get_rotation_quaternion());
		Basis g3 = rb2 * fall2 * q * c.r3;
		if (bends[i] > 0.0f) {
			Vector3 d3_now = (rb2 * fall2 * q).xform(c.d3);
			Quaternion r = mc::turn(d3_now, d3_now.slerp(c.down, bends[i]).normalized());
			g3 = Basis(r) * g3;
		}
		g3 = rb3 * g3;
		sk->set_bone_pose_rotation(c.b3, (g2.inverse() * g3).get_rotation_quaternion());
	}
}
