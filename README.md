<p align="center">
  <img src="docs/screenshots/banner.jpg" width="100%" alt="Về Nhà: Coming Home">
</p>

<p align="center">
  <img alt="Godot 4" src="https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white">
  <img alt="C++17" src="https://img.shields.io/badge/C%2B%2B-17-00599C?logo=cplusplus&logoColor=white">
  <img alt="Shaders" src="https://img.shields.io/badge/shaders-65-8a5cf5">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Windows%20%7C%20iOS-6aa84f">
</p>

<p align="center"><i>
Sungha comes home to a little village tucked between limestone mountains.<br>
Ride the old Vespa past the rice fields, wander the lotus ponds, fix up the family house<br>
and share the village with up to three friends online.
</i></p>

<p align="center"><img src="docs/screenshots/s01_vespa.jpg" width="100%" alt="Riding the Vespa through the fields"></p>
<p align="center"><i>Riding the old Vespa through the fields</i></p>

<p align="center"><img src="docs/screenshots/s02_pier.jpg" width="100%" alt="Pier"></p>
<p align="center"><i>Out on the pier, facing the mountains</i></p>

<p align="center"><img src="docs/screenshots/s03_fields_dusk.jpg" width="100%" alt="Fields at dusk"></p>
<p align="center"><i>The fields at dusk</i></p>

<p align="center"><img src="docs/screenshots/s04_banyan.jpg" width="100%" alt="Banyan"></p>
<p align="center"><i>Under the old banyan at the village gate</i></p>

<p align="center"><img src="docs/screenshots/s05_home.jpg" width="100%" alt="Home"></p>
<p align="center"><i>Home, on a fresh morning</i></p>

<p align="center"><img src="docs/screenshots/s06_lotus_walk.jpg" width="100%" alt="Lotus walk"></p>
<p align="center"><i>The lotus pond boardwalk</i></p>

<p align="center"><img src="docs/screenshots/s07_rice_gold.jpg" width="100%" alt="Golden rice"></p>
<p align="center"><i>Harvest-gold rice</i></p>

<p align="center"><img src="docs/screenshots/s08_lake.jpg" width="100%" alt="Lake"></p>
<p align="center"><i>Reeds by the duck pond</i></p>

<p align="center"><img src="docs/screenshots/s09_village_gate.jpg" width="100%" alt="Village gate"></p>
<p align="center"><i>Làng Yên Khê</i></p>

<p align="center"><img src="docs/screenshots/s10_morning.jpg" width="100%" alt="Morning over the fields"></p>
<p align="center"><i>Morning over the fields</i></p>

### Dress up, meet the animals, join the festivals

<p align="center"><img src="docs/screenshots/x1_outfits.jpg" width="100%" alt="Sungha's outfits"></p>
<p align="center"><i>Sungha's outfits</i></p>

<p align="center"><img src="docs/screenshots/x3_lion_dance.jpg" width="100%" alt="Lion dance festival"></p>
<p align="center"><i>The lion dance festival</i></p>

<p align="center"><img src="docs/screenshots/x2_cats.jpg" width="100%" alt="Village cats"></p>
<p align="center"><i>The village cats</i></p>

---

## Under the hood

| | |
|---|---|
| **Engine** | Godot 4.7, customised build |
| **Native code** | C++17 GDExtension, 31 classes: hair and cloth physics, fish schooling and flocking, terrain meshing, chunked grass, time-of-day colour grading, saves and gameplay rules |
| **Rendering** | 65 hand-written shaders: toon lighting, water, rain, wind, sky and screen effects |
| **World** | A 2 × 2 km valley streamed by area, with a day–night cycle and seasons |
| **Online play** | Up to 4 players over UDP (ENet); single-player runs through the same code path |
| **Platforms** | Windows, iOS |

*Every screenshot above is an in-game capture, rendered by the game itself.*

## About this repository

This is a **source-code showcase**: C++ (`cpp/`), GDScript (`scripts/`) and shaders (`shaders/`).
Art, models, animations, audio, game data, tools and the engine build are **not included**, so the project does not run from this repository.

## License

© 2026 Nguyen Ngoc Thinh. All rights reserved.
The code and images are published for viewing only; no permission is granted to copy, modify or redistribute them.
