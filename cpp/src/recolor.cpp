#include "recolor.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {

inline float smooth(float e0, float e1, float x) {
	float t = std::clamp((x - e0) / (e1 - e0), 0.0f, 1.0f);
	return t * t * (3.0f - 2.0f * t);
}

inline void to_hsv(float r, float g, float b, float &h, float &s, float &v) {
	float mx = std::max(r, std::max(g, b)), mn = std::min(r, std::min(g, b));
	float d = mx - mn;
	v = mx;
	s = mx > 0.0f ? d / mx : 0.0f;
	if (d <= 1e-6f) {
		h = 0.0f;
		return;
	}
	if (mx == r)
		h = 60.0f * std::fmod((g - b) / d, 6.0f);
	else if (mx == g)
		h = 60.0f * ((b - r) / d + 2.0f);
	else
		h = 60.0f * ((r - g) / d + 4.0f);
	if (h < 0.0f)
		h += 360.0f;
}

inline void to_rgb(float h, float s, float v, float &r, float &g, float &b) {
	h = std::fmod(h, 360.0f);
	if (h < 0.0f)
		h += 360.0f;
	float c = v * s, x = c * (1.0f - std::fabs(std::fmod(h / 60.0f, 2.0f) - 1.0f)), m = v - c;
	float rr = 0, gg = 0, bb = 0;
	int k = int(h / 60.0f) % 6;
	switch (k) {
		case 0: rr = c, gg = x; break;
		case 1: rr = x, gg = c; break;
		case 2: gg = c, bb = x; break;
		case 3: gg = x, bb = c; break;
		case 4: rr = x, bb = c; break;
		default: rr = c, bb = x; break;
	}
	r = rr + m, g = gg + m, b = bb + m;
}

inline float hue_gap(float a, float b) {
	float d = std::fmod(a - b + 540.0f, 360.0f) - 180.0f;
	return d;
}

Ref<Image> plain_copy(const Ref<Image> &image) {
	Ref<Image> im = image->duplicate();
	if (im->is_compressed())
		im->decompress();
	if (im->has_mipmaps())
		im->clear_mipmaps();
	im->convert(Image::FORMAT_RGBA8);
	return im;
}

}

Ref<Image> Recolor::apply(const Ref<Image> &image, const Dictionary &look) {
	ERR_FAIL_COND_V(image.is_null() || image->is_empty(), Ref<Image>());
	Ref<Image> im = plain_copy(image);
	PackedByteArray px = im->get_data();
	uint8_t *p = px.ptrw();
	const int64_t n = px.size() / 4;
	const String mode = look.get("mode", "hue");
	const float sat_mul = float(look.get("sat", 1.0)), val_mul = float(look.get("val", 1.0));
	if (mode == "paint") {
		Color c = look.get("color", Color(1, 1, 1));
		const float max_sat = float(look.get("max_sat", 0.18)), min_val = float(look.get("min_val", 0.55));
		const float ref = float(look.get("ref", 0.92));
		for (int64_t i = 0; i < n; i++) {
			float r = p[i * 4] / 255.0f, g = p[i * 4 + 1] / 255.0f, b = p[i * 4 + 2] / 255.0f, h, s, v;
			to_hsv(r, g, b, h, s, v);
			float w = smooth(max_sat, max_sat * 0.45f, s) * smooth(min_val - 0.12f, min_val, v);
			if (w <= 0.0f)
				continue;
			float k = std::min(v / ref, 1.15f);
			float nr = std::min(c.r * k, 1.0f), ng = std::min(c.g * k, 1.0f), nb = std::min(c.b * k, 1.0f);
			p[i * 4] = uint8_t(std::lround((r + (nr - r) * w) * 255.0f));
			p[i * 4 + 1] = uint8_t(std::lround((g + (ng - g) * w) * 255.0f));
			p[i * 4 + 2] = uint8_t(std::lround((b + (nb - b) * w) * 255.0f));
		}
	} else {
		const float from = float(look.get("from", 0.0)), tol = float(look.get("tol", 30.0)), to = float(look.get("to", 0.0));
		const float min_sat = float(look.get("min_sat", 0.18));
		for (int64_t i = 0; i < n; i++) {
			float r = p[i * 4] / 255.0f, g = p[i * 4 + 1] / 255.0f, b = p[i * 4 + 2] / 255.0f, h, s, v;
			to_hsv(r, g, b, h, s, v);
			float d = hue_gap(h, from);
			float w = smooth(tol, tol * 0.6f, std::fabs(d)) * smooth(min_sat * 0.5f, min_sat, s);
			if (w <= 0.0f)
				continue;
			float nr, ng, nb;
			to_rgb(to + d, std::clamp(s * sat_mul, 0.0f, 1.0f), std::clamp(v * val_mul, 0.0f, 1.0f), nr, ng, nb);
			p[i * 4] = uint8_t(std::lround((r + (nr - r) * w) * 255.0f));
			p[i * 4 + 1] = uint8_t(std::lround((g + (ng - g) * w) * 255.0f));
			p[i * 4 + 2] = uint8_t(std::lround((b + (nb - b) * w) * 255.0f));
		}
	}
	im->set_data(im->get_width(), im->get_height(), false, Image::FORMAT_RGBA8, px);
	im->generate_mipmaps();
	return im;
}

Dictionary Recolor::main_hue(const Ref<Image> &image) {
	Dictionary out;
	ERR_FAIL_COND_V(image.is_null() || image->is_empty(), out);
	Ref<Image> im = plain_copy(image);
	PackedByteArray px = im->get_data();
	const uint8_t *p = px.ptr();
	const int64_t n = px.size() / 4;
	float bins[36] = {};
	float total = 0.0f;
	int64_t coloured = 0, seen = 0;
	for (int64_t i = 0; i < n; i++) {
		if (p[i * 4 + 3] < 128)
			continue;
		seen++;
		float h, s, v;
		to_hsv(p[i * 4] / 255.0f, p[i * 4 + 1] / 255.0f, p[i * 4 + 2] / 255.0f, h, s, v);
		if (s < 0.25f || v < 0.2f)
			continue;
		coloured++;
		float w = s * v;
		bins[int(h / 10.0f) % 36] += w;
		total += w;
	}
	int best = 0;
	float best_w = -1.0f;
	for (int k = 0; k < 36; k++) {
		float w = bins[(k + 35) % 36] + bins[k] + bins[(k + 1) % 36];
		if (w > best_w)
			best_w = w, best = k;
	}

	const float centre = best * 10.0f + 5.0f;
	double ss = 0.0, vv = 0.0;
	int64_t nb = 0;
	for (int64_t i = 0; i < n; i++) {
		if (p[i * 4 + 3] < 128)
			continue;
		float h, sa, va;
		to_hsv(p[i * 4] / 255.0f, p[i * 4 + 1] / 255.0f, p[i * 4 + 2] / 255.0f, h, sa, va);
		if (sa < 0.25f || va < 0.2f || std::fabs(hue_gap(h, centre)) > 15.0f)
			continue;
		ss += sa, vv += va, nb++;
	}
	out["sat"] = nb > 0 ? float(ss / nb) : 0.0f;
	out["val"] = nb > 0 ? float(vv / nb) : 0.0f;
	out["hue"] = best * 10 + 5;
	out["share"] = total > 0.0f ? best_w / total : 0.0f;
	out["colourful"] = seen > 0 ? float(coloured) / float(seen) : 0.0f;
	return out;
}

void Recolor::_bind_methods() {
	ClassDB::bind_static_method("Recolor", D_METHOD("apply", "image", "look"), &Recolor::apply);
	ClassDB::bind_static_method("Recolor", D_METHOD("main_hue", "image"), &Recolor::main_hue);
}
