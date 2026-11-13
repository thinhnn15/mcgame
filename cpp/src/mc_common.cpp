#include "mc_common.h"

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/texture2d.hpp>

#include <vector>

namespace mc {
Ref<Script> Scripts::wind;
Ref<Script> Scripts::clock;
Ref<Script> Scripts::story;
Ref<Script> Scripts::fish_table;
Ref<Script> Scripts::swim_fx;
Ref<Script> Scripts::hero;
}

namespace mc {
namespace {

std::vector<uint8_t> noise_a;
int noise_w = 0, noise_h = 0;
bool noise_tried = false;

void load_noise() {
	noise_tried = true;
	Ref<Texture2D> tex = ResourceLoader::get_singleton()->load("res://props/farm/ground/noise.png");
	if (tex.is_null()) {
		return;
	}
	Ref<Image> img = tex->get_image();
	if (img.is_null()) {
		return;
	}
	if (img->is_compressed()) {
		img->decompress();
	}
	img->convert(Image::FORMAT_RGBA8);
	noise_w = img->get_width();
	noise_h = img->get_height();
	PackedByteArray data = img->get_data();
	noise_a.resize((size_t)noise_w * noise_h);
	const uint8_t *src = data.ptr();
	for (size_t i = 0; i < noise_a.size(); ++i) {
		noise_a[i] = src[i * 4 + 3];
	}
}
}

float Wind::gust_at(const Vector3 &at) {
	if (!noise_tried) {
		load_noise();
	}
	if (noise_a.empty()) {
		return 0.5f;
	}
	const float dx = 0.94f, dz = 0.33f;
	const float inv = 1.0f / Math::sqrt(dx * dx + dz * dz);

	double t = Math::fmod(Time::get_singleton()->get_ticks_msec() / 1000.0, 3600.0);
	float u = (float)((at.x - dx * inv * t * 2.4) / 24.0);
	float v = (float)((at.z - dz * inv * t * 2.4) / 24.0);
	float px = wrapf(u * noise_w - 0.5f, 0.0f, (float)noise_w);
	float py = wrapf(v * noise_h - 0.5f, 0.0f, (float)noise_h);
	int x0 = (int)px % noise_w, y0 = (int)py % noise_h;
	int x1 = (x0 + 1) % noise_w, y1 = (y0 + 1) % noise_h;
	float fx = px - Math::floor(px), fy = py - Math::floor(py);
	auto a = [](int x, int y) { return noise_a[(size_t)y * noise_w + x] / 255.0f; };
	float n = Math::lerp(Math::lerp(a(x0, y0), a(x1, y0), fx), Math::lerp(a(x0, y1), a(x1, y1), fx), fy);
	float k = clampf((n - 0.35f) / 0.45f, 0.0f, 1.0f);
	return k * k * (3.0f - 2.0f * k);
}
}
