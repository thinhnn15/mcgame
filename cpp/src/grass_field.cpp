#include "grass_field.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include <vector>

using namespace godot;

namespace {

struct Pcg {
	uint64_t s;
	explicit Pcg(uint64_t seed) : s(seed * 6364136223846793005ULL + 1442695040888963407ULL) { next(); }
	uint32_t next() {
		uint64_t o = s;
		s = o * 6364136223846793005ULL + 1442695040888963407ULL;
		uint32_t x = (uint32_t)(((o >> 18u) ^ o) >> 27u);
		uint32_t r = (uint32_t)(o >> 59u);
		return (x >> r) | (x << ((32 - r) & 31));
	}
	float f() { return (next() >> 8) * (1.0f / 16777216.0f); }
	float range(float a, float b) { return a + (b - a) * f(); }
};

inline uint64_t mix64(uint64_t x) {
	x ^= x >> 30;
	x *= 0xbf58476d1ce4e5b9ULL;
	x ^= x >> 27;
	x *= 0x94d049bb133111ebULL;
	x ^= x >> 31;
	return x;
}
inline uint64_t hcell(int64_t a, int64_t b, uint64_t salt) {
	return mix64(mix64((uint64_t)a * 0x9E3779B97F4A7C15ULL + salt) ^ ((uint64_t)b * 0xC2B2AE3D27D4EB4FULL));
}
inline float uk(uint64_t h, int k) {
	return (float)(mix64(h + 0x632BE59BD9B4E019ULL * (uint64_t)(k + 1)) >> 40) * (1.0f / 16777216.0f);
}
inline float sstep(float a, float b, float x) {
	float t = Math::clamp((x - a) / (b - a), 0.0f, 1.0f);
	return t * t * (3.0f - 2.0f * t);
}
float vnoise(float x, float z, uint64_t salt) {
	float fx = Math::floor(x), fz = Math::floor(z);
	int64_t ix = (int64_t)fx, iz = (int64_t)fz;
	float ax = x - fx, az = z - fz;
	ax = ax * ax * (3.0f - 2.0f * ax);
	az = az * az * (3.0f - 2.0f * az);
	float a = uk(hcell(ix, iz, salt), 0), b = uk(hcell(ix + 1, iz, salt), 0);
	float c = uk(hcell(ix, iz + 1, salt), 0), d = uk(hcell(ix + 1, iz + 1, salt), 0);
	return Math::lerp(Math::lerp(a, b, ax), Math::lerp(c, d, ax), az);
}

enum Weed { CLOVER = 0, RAU_MA = 1, LA_RONG = 2, CO_MAY = 3, DAISY = 4, VIOLET = 5 };

int pick(float u, const float *w, const int *kinds, int count) {
	for (int i = 0; i < count; ++i) {
		if (u < w[i]) {
			return kinds[i];
		}
		u -= w[i];
	}
	return kinds[count - 1];
}
}

void GrassField::_bind_methods() {
	ClassDB::bind_static_method("GrassField",
			D_METHOD("lush_chunk", "area", "n", "half", "mats", "dens", "sdf", "heights", "no_rects", "seed", "step",
					"road_lo", "road_ramp", "noise", "colour"),
			&GrassField::lush_chunk);
	ClassDB::bind_static_method("GrassField",
			D_METHOD("weed_chunk", "area", "n", "half", "mats", "dens", "sdf", "heights", "no_rects", "no_circles",
					"skip", "seed", "road_clear"),
			&GrassField::weed_chunk);
}

PackedFloat32Array GrassField::lush_chunk(const Rect2 &area, int n, int half, const PackedByteArray &mats,
		const PackedByteArray &dens, const PackedByteArray &sdf, const PackedFloat32Array &heights,
		const Array &no_rects, int64_t seed, double step, double road_lo, double road_ramp,
		const Ref<FastNoiseLite> &noise, const Color &colour) {
	PackedFloat32Array out;
	const int64_t nn = (int64_t)n * n;
	if (n <= 1 || mats.size() < nn || dens.size() != nn || heights.size() < nn || step <= 0.0) {
		return out;
	}
	std::vector<Rect2> rects;
	for (int64_t i = 0; i < no_rects.size(); ++i) {
		Rect2 r = no_rects[i];
		if (r.intersects(area)) {
			rects.push_back(r);
		}
	}
	const uint8_t *mp = mats.ptr();
	const uint8_t *dp = dens.ptr();
	const uint8_t *sp = sdf.size() == nn ? sdf.ptr() : nullptr;
	const float *hp = heights.ptr();
	const bool has_noise = noise.is_valid();
	const float ramp = (float)Math::max(road_ramp, 0.01);
	const Vector2 centre = area.get_center();
	auto height_at = [&](float x, float z) {
		float fx = Math::clamp(x + (float)half, 0.0f, (float)n - 1.001f);
		float fz = Math::clamp(z + (float)half, 0.0f, (float)n - 1.001f);
		int ix = (int)fx, iz = (int)fz;
		float ax = fx - ix, az = fz - iz;
		const float *r0 = hp + (int64_t)iz * n + ix;
		const float *r1 = r0 + n;
		return Math::lerp(Math::lerp(r0[0], r0[1], ax), Math::lerp(r1[0], r1[1], ax), az);
	};
	Pcg rng((uint64_t)seed);
	const int steps = (int)(area.size.x / step);
	std::vector<float> buf;
	buf.reserve((size_t)steps * steps * 16 / 2);
	for (int j = 0; j < steps; ++j) {
		for (int i = 0; i < steps; ++i) {
			float x = area.position.x + (i + rng.f()) * (float)step;
			float z = area.position.y + (j + rng.f()) * (float)step;
			int gx = (int)Math::floor(x) + half;
			int gz = (int)Math::floor(z) + half;
			if (gx < 0 || gz < 0 || gx >= n || gz >= n) {
				continue;
			}
			int64_t gi = (int64_t)gz * n + gx;
			float keep_r = rng.f();
			if (mp[gi] != 0) {
				continue;
			}

			float patch = has_noise ? (float)noise->get_noise_2d(x, z) * 0.5f + 0.5f : 0.5f;
			float keep = dp[gi] / 255.0f * (0.5f + 0.5f * patch);
			if (sp) {
				float sd = sp[gi] / 255.0f * 8.0f - 2.0f;
				keep *= Math::clamp((sd - (float)road_lo) / ramp, 0.0f, 1.0f);
			}
			if (keep_r > keep) {
				continue;
			}
			bool hit = false;
			for (const Rect2 &r : rects) {
				if (r.has_point(Vector2(x, z))) {
					hit = true;
					break;
				}
			}
			if (hit) {
				continue;
			}
			float s = rng.range(0.75f, 1.3f);
			float sy = s * rng.range(0.85f, 1.25f);
			float a = rng.f() * 6.2831853f;
			float ca = Math::cos(a), sa = Math::sin(a);

			float y = height_at(x, z) - 0.02f;
			const float row[16] = {
				ca * s, 0.0f, sa * s, x - centre.x,
				0.0f, sy, 0.0f, y,
				-sa * s, 0.0f, ca * s, z - centre.y,
				colour.r, colour.g, colour.b, colour.a,
			};
			buf.insert(buf.end(), row, row + 16);
		}
	}
	out.resize((int64_t)buf.size());
	if (!buf.empty()) {
		std::copy(buf.begin(), buf.end(), out.ptrw());
	}
	return out;
}

PackedFloat32Array GrassField::weed_chunk(const Rect2 &area, int n, int half, const PackedByteArray &mats,
		const PackedByteArray &dens, const PackedByteArray &sdf, const PackedFloat32Array &heights,
		const Array &no_rects, const Array &no_circles, const Rect2 &skip, int64_t seed, double road_clear) {
	PackedFloat32Array out;
	const int64_t nn = (int64_t)n * n;
	if (n <= 4 || mats.size() < nn || dens.size() != nn || heights.size() < nn) {
		return out;
	}
	const Rect2 keep_area = area.grow(0.5f);
	const Rect2 village_area = area.grow(30.0f);
	std::vector<Rect2> rects, yards;
	for (int64_t i = 0; i < no_rects.size(); ++i) {
		Rect2 r = no_rects[i];
		if (r.intersects(village_area)) {
			yards.push_back(r);
			if (r.intersects(keep_area)) {
				rects.push_back(r);
			}
		}
	}
	std::vector<Vector3> circles;
	for (int64_t i = 0; i < no_circles.size(); ++i) {
		Vector3 c = no_circles[i];
		if (c.x + c.z > keep_area.position.x && c.x - c.z < keep_area.position.x + keep_area.size.x &&
				c.y + c.z > keep_area.position.y && c.y - c.z < keep_area.position.y + keep_area.size.y) {
			circles.push_back(c);
		}
	}
	const uint8_t *mp = mats.ptr();
	const uint8_t *dp = dens.ptr();
	const uint8_t *sp = sdf.size() == nn ? sdf.ptr() : nullptr;
	const float *hp = heights.ptr();
	const float clear = (float)road_clear;
	const Vector2 centre = area.get_center();
	const uint64_t salt = (uint64_t)seed;

	auto bilin = [&](float x, float z, auto get) {
		float fx = Math::clamp(x + (float)half, 0.0f, (float)n - 1.001f);
		float fz = Math::clamp(z + (float)half, 0.0f, (float)n - 1.001f);
		int ix = (int)fx, iz = (int)fz;
		float ax = fx - ix, az = fz - iz;
		int64_t i0 = (int64_t)iz * n + ix;
		return Math::lerp(Math::lerp(get(i0), get(i0 + 1), ax), Math::lerp(get(i0 + n), get(i0 + n + 1), ax), az);
	};
	auto height_at = [&](float x, float z) { return bilin(x, z, [&](int64_t i) { return hp[i]; }); };
	auto road_sd = [&](float x, float z) {
		return sp ? bilin(x, z, [&](int64_t i) { return (float)sp[i]; }) / 255.0f * 8.0f - 2.0f : 99.0f;
	};
	auto density = [&](float x, float z) { return bilin(x, z, [&](int64_t i) { return (float)dp[i]; }) / 255.0f; };

	auto ground_ok = [&](float x, float z) {
		int gx = (int)Math::round(x) + half, gz = (int)Math::round(z) + half;
		if (gx < 1 || gz < 1 || gx >= n - 1 || gz >= n - 1) {
			return false;
		}
		int64_t gi = (int64_t)gz * n + gx;
		if (mp[gi] != 0) {
			return false;
		}
		for (int dz = -1; dz <= 1; ++dz) {
			for (int dx = -1; dx <= 1; ++dx) {
				uint8_t m = mp[gi + (int64_t)dz * n + dx];
				if (m == 5 || m == 6) {
					return false;
				}
			}
		}
		Vector2 p(x, z);
		if (skip.has_point(p)) {
			return false;
		}
		for (const Rect2 &r : rects) {
			if (r.has_point(p)) {
				return false;
			}
		}
		for (const Vector3 &c : circles) {
			float dx = x - c.x, dz = z - c.y;
			if (dx * dx + dz * dz < c.z * c.z) {
				return false;
			}
		}
		return true;
	};

	auto bund_dist = [&](float x, float z) {
		int gx = (int)Math::round(x) + half, gz = (int)Math::round(z) + half;
		float best = 9.0f;
		for (int dz = -2; dz <= 2; ++dz) {
			for (int dx = -2; dx <= 2; ++dx) {
				int cx = gx + dx, cz = gz + dz;
				if (cx < 0 || cz < 0 || cx >= n || cz >= n) {
					continue;
				}
				uint8_t m = mp[(int64_t)cz * n + cx];
				if (m != 1 && m != 2) {
					continue;
				}
				float qx = Math::max(Math::abs(x - (float)(cx - half)) - 0.5f, 0.0f);
				float qz = Math::max(Math::abs(z - (float)(cz - half)) - 0.5f, 0.0f);
				best = Math::min(best, Math::sqrt(qx * qx + qz * qz));
			}
		}
		return best;
	};
	std::vector<float> buf;
	buf.reserve(16 * 256);
	auto emit = [&](float x, float z, int kind, float s, float sy, uint64_t h) {
		float a = uk(h, 7) * 6.2831853f;
		float ca = Math::cos(a), sa = Math::sin(a);
		float y = height_at(x, z) - 0.015f;
		const float row[16] = {
			ca * s, 0.0f, sa * s, x - centre.x,
			0.0f, sy, 0.0f, y,
			-sa * s, 0.0f, ca * s, z - centre.y,
			(float)kind, uk(h, 8), 0.0f, uk(h, 9),
		};
		buf.insert(buf.end(), row, row + 16);
	};

	struct Patch {
		float x, z, r, p1, p2;
		int kind;
	};
	const float PCELL = 11.0f;
	std::vector<Patch> patches;
	{
		const float wk[4] = { 0.32f, 0.22f, 0.26f, 0.20f };
		const int kk[4] = { CLOVER, RAU_MA, LA_RONG, CO_MAY };
		Rect2 reach = area.grow(5.5f);
		int64_t cx0 = (int64_t)Math::floor(reach.position.x / PCELL);
		int64_t cx1 = (int64_t)Math::floor((reach.position.x + reach.size.x) / PCELL);
		int64_t cz0 = (int64_t)Math::floor(reach.position.y / PCELL);
		int64_t cz1 = (int64_t)Math::floor((reach.position.y + reach.size.y) / PCELL);
		for (int64_t cz = cz0; cz <= cz1; ++cz) {
			for (int64_t cx = cx0; cx <= cx1; ++cx) {
				uint64_t h = hcell(cx, cz, salt ^ 0x5157ULL);
				if (uk(h, 0) > 0.75f) {
					continue;
				}
				Patch p;
				p.x = ((float)cx + 0.15f + 0.7f * uk(h, 1)) * PCELL;
				p.z = ((float)cz + 0.15f + 0.7f * uk(h, 2)) * PCELL;
				p.r = 1.5f + 2.5f * uk(h, 3);
				p.p1 = uk(h, 4) * 6.2831853f;
				p.p2 = uk(h, 5) * 6.2831853f;
				p.kind = pick(uk(h, 6), wk, kk, 4);
				patches.push_back(p);
			}
		}
	}

	{
		const float G = 3.0f;
		const float road_w[3] = { 0.45f, 0.30f, 0.25f };
		const int road_k[3] = { CO_MAY, LA_RONG, CLOVER };
		const float bund_w[3] = { 0.5f, 0.3f, 0.2f };
		const int bund_k[3] = { RAU_MA, CO_MAY, CLOVER };
		const int64_t ix0 = (int64_t)Math::round(area.position.x * G);
		const int64_t iz0 = (int64_t)Math::round(area.position.y * G);
		const int cnt = (int)Math::round(area.size.x * G);
		for (int j = 0; j < cnt; ++j) {
			for (int i = 0; i < cnt; ++i) {
				const int64_t ix = ix0 + i, iz = iz0 + j;
				const uint64_t h = hcell(ix, iz, salt ^ 0xC0DA1ULL);
				const float x = ((float)ix + uk(h, 0)) / G;
				const float z = ((float)iz + uk(h, 1)) / G;
				const float r = uk(h, 2);

				float m = 0.0f;
				int kind = -1;
				for (const Patch &p : patches) {
					float dx = x - p.x, dz = z - p.z;
					float d2 = dx * dx + dz * dz;
					if (d2 > p.r * p.r * 1.9f) {
						continue;
					}
					float th = Math::atan2(dz, dx);
					float reff = p.r * (1.0f + 0.2f * Math::sin(3.0f * th + p.p1) + 0.1f * Math::sin(5.0f * th + p.p2));
					float mm = 1.0f - sstep(0.5f, 1.0f, Math::sqrt(d2) / reff);
					if (mm > m) {
						m = mm;
						kind = p.kind;
					}
				}
				float keep = 0.0f, s = 1.0f;
				if (kind >= 0) {
					m *= sstep(0.25f, 0.55f, vnoise(x / 1.5f, z / 1.5f, salt ^ 0xDA54ULL)) * 0.6f + 0.4f;
					keep = 0.36f * m;
					s = 0.7f + 0.3f * m;
				} else {

					if (r > 0.26f) {
						continue;
					}
					float present = sstep(0.38f, 0.48f, vnoise(x / 6.0f, z / 6.0f, salt ^ 0xB4D1ULL));
					if (present <= 0.0f) {
						continue;
					}
					float w = 0.5f + vnoise(x / 4.0f, z / 4.0f, salt ^ 0xB4D0ULL);
					float sd = road_sd(x, z);
					float t = -1.0f;
					bool road = false;
					if (sd >= clear && sd < clear + w) {
						t = (sd - clear) / w;
						road = true;
					} else {
						float bd = bund_dist(x, z);
						if (bd >= 0.15f && bd < 0.15f + w) {
							t = (bd - 0.15f) / w;
						}
					}
					if (t < 0.0f) {
						continue;
					}
					uint64_t hb = hcell((int64_t)Math::floor(x / 6.0f), (int64_t)Math::floor(z / 6.0f), salt ^ 0xB4D2ULL);
					kind = road ? pick(uk(hb, 0), road_w, road_k, 3) : pick(uk(hb, 0), bund_w, bund_k, 3);
					keep = 0.26f * present * (1.0f - 0.5f * t * t);
					s = 0.72f + 0.28f * t;
				}
				if (r > keep) {
					continue;
				}
				if (!ground_ok(x, z)) {
					continue;
				}
				if (uk(h, 3) > sstep(0.08f, 0.4f, density(x, z))) {
					continue;
				}
				if (road_sd(x, z) < clear) {
					continue;
				}
				s *= 0.85f + 0.4f * uk(h, 4);
				emit(x, z, kind, s, s * (0.85f + 0.3f * uk(h, 5)), h);
			}
		}
	}

	{
		const float FCELL = 17.0f;
		Rect2 reach = area.grow(14.0f);
		int64_t cx0 = (int64_t)Math::floor(reach.position.x / FCELL);
		int64_t cx1 = (int64_t)Math::floor((reach.position.x + reach.size.x) / FCELL);
		int64_t cz0 = (int64_t)Math::floor(reach.position.y / FCELL);
		int64_t cz1 = (int64_t)Math::floor((reach.position.y + reach.size.y) / FCELL);
		float px[16], pz[16];
		for (int64_t cz = cz0; cz <= cz1; ++cz) {
			for (int64_t cx = cx0; cx <= cx1; ++cx) {
				uint64_t h = hcell(cx, cz, salt ^ 0xF10ULL);
				if (uk(h, 0) > 0.7f) {
					continue;
				}
				float ox = ((float)cx + 0.2f + 0.6f * uk(h, 1)) * FCELL;
				float oz = ((float)cz + 0.2f + 0.6f * uk(h, 2)) * FCELL;
				bool village = false;
				for (const Rect2 &r : yards) {
					Vector2 q(Math::clamp(ox, r.position.x, r.position.x + r.size.x),
							Math::clamp(oz, r.position.y, r.position.y + r.size.y));
					if (q.distance_squared_to(Vector2(ox, oz)) < 14.0f * 14.0f) {
						village = true;
						break;
					}
				}
				int count = village ? 2 + (int)(uk(h, 3) * 3.0f) : 5 + (int)(uk(h, 3) * 9.0f);
				int kind = uk(h, 4) < 0.55f ? DAISY : VIOLET;
				px[0] = ox;
				pz[0] = oz;
				for (int k = 1; k < count; ++k) {
					uint64_t hk = mix64(h + (uint64_t)k * 0x9E3779B97F4A7C15ULL);
					int parent = (int)(uk(hk, 0) * k);
					float a = uk(hk, 1) * 6.2831853f, d = 1.1f + 0.8f * uk(hk, 2);
					px[k] = px[parent] + Math::cos(a) * d;
					pz[k] = pz[parent] + Math::sin(a) * d;
				}
				for (int k = 0; k < count; ++k) {
					if (!area.has_point(Vector2(px[k], pz[k]))) {
						continue;
					}
					uint64_t hk = mix64(h ^ ((uint64_t)k * 0xC2B2AE3D27D4EB4FULL + 0x51ULL));
					if (!ground_ok(px[k], pz[k]) || road_sd(px[k], pz[k]) < clear + 0.3f ||
							density(px[k], pz[k]) < 0.25f) {
						continue;
					}
					float s = 0.9f + 0.25f * uk(hk, 3);
					emit(px[k], pz[k], kind, s, s * (0.9f + 0.2f * uk(hk, 4)), hk);
				}
			}
		}
	}

	out.resize((int64_t)buf.size());
	if (!buf.empty()) {
		std::copy(buf.begin(), buf.end(), out.ptrw());
	}
	return out;
}
