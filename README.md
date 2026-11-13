# Về Nhà — *Coming Home*

**A cozy 3D life-sim set in the countryside of northern Vietnam.**
Ride a Vespa down the village road, grow a garden, raise ducks and buffalo, fix up the family house and share the village with up to three friends online.

![Riding home](docs/screenshots/01_vespa_home.jpg)

| | |
|:---:|:---:|
| ![Village road](docs/screenshots/02_village_road.jpg) | ![Rooftops](docs/screenshots/03_rooftops.jpg) |
| *The village road* | *Riding under the tiled roofs* |
| ![Family](docs/screenshots/04_family.jpg) | ![Pond](docs/screenshots/05_pond.jpg) |
| *Back home with the family* | *Fishing by the duck pond* |
| ![Farm](docs/screenshots/06_farm.jpg) | ![Garden](docs/screenshots/07_garden.jpg) |
| *Working the vegetable plots* | *Fruit trees and crops* |

<p align="center">
  <img src="docs/screenshots/09_outfits.jpg" width="49%" alt="Outfits and hair">
  <img src="docs/screenshots/11_lion_dance.jpg" width="49%" alt="Lion dance festival">
</p>

![Cats](docs/screenshots/10_cats.jpg)

<details>
<summary><b>Upgrading the family house, level by level</b></summary>

<p align="center"><img src="docs/screenshots/08_house_levels.jpg" width="70%" alt="House upgrade levels"></p>
</details>

---

## Under the hood

| | |
|---|---|
| **Engine** | Godot 4.7, customised build |
| **Native code** | C++17 GDExtension, 31 classes: hair and cloth physics, fish schooling and flocking, terrain meshing, chunked grass, time-of-day colour grading, saves and gameplay rules |
| **Rendering** | 65 hand-written shaders: toon lighting, water, rain, wind, sky and screen effects |
| **Online play** | Up to 4 players over UDP (ENet); single-player runs through the same code path |
| **Platforms** | Windows, iOS |

## About this repository

This is a **source-code showcase**: C++ (`cpp/`), GDScript (`scripts/`) and shaders (`shaders/`).
Art, models, audio, game data, tools and the engine build are **not included**, so the project does not run from this repository.

## License

© 2026 Nguyen Ngoc Thinh. All rights reserved.
The code is published for viewing only; no permission is granted to copy, modify or redistribute it.
