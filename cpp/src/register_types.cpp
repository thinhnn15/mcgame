#include "register_types.h"

#include "apiary.h"
#include "moto_ride.h"
#include "pave_grid.h"
#include "farm_soil.h"
#include "duck_flock.h"
#include "farm_critters.h"
#include "chain_sway.h"
#include "decor_grid.h"
#include "fish_school.h"
#include "grade.h"
#include "grass_field.h"
#include "hair_physics.h"
#include "home_work.h"
#include "mc_common.h"
#include "photo_print.h"
#include "recolor.h"
#include "room_shell.h"
#include "room_surfaces.h"
#include "pattern_shop.h"
#include "fruit_trees.h"
#include "cooking.h"
#include "farm_splat.h"
#include "farm_height.h"
#include "tea_rows.h"
#include "buffalo.h"
#include "pen_rules.h"
#include "pen_work.h"
#include "save_slots.h"
#include "stock.h"
#include "progress.h"
#include "skirt_follow.h"
#include "terrain_mesher.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_mcgame_core(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(HairPhysics);
	GDREGISTER_CLASS(ChainSway);
	GDREGISTER_CLASS(SkirtFollow);
	GDREGISTER_CLASS(FishSchool);
	GDREGISTER_CLASS(TerrainMesher);
	GDREGISTER_CLASS(Progress);
	Progress::init();
	GDREGISTER_CLASS(Grade);
	GDREGISTER_CLASS(GrassField);
	GDREGISTER_CLASS(DecorGrid);
	GDREGISTER_CLASS(PhotoPrint);
	GDREGISTER_CLASS(Recolor);
	GDREGISTER_CLASS(RoomShell);
	GDREGISTER_CLASS(RoomSurfaces);
	GDREGISTER_CLASS(PatternShop);
	GDREGISTER_CLASS(PenRules);
	GDREGISTER_CLASS(PenWork);
	GDREGISTER_CLASS(FruitTrees);
	GDREGISTER_CLASS(Cooking);
	GDREGISTER_CLASS(FarmSplat);
	GDREGISTER_CLASS(FarmHeight);
	GDREGISTER_CLASS(TeaRows);
	GDREGISTER_CLASS(Buffalo);
	GDREGISTER_CLASS(Stock);
	GDREGISTER_CLASS(HomeWork);
	GDREGISTER_CLASS(Apiary);
	GDREGISTER_CLASS(MotoRide);
	GDREGISTER_CLASS(PaveGrid);
	GDREGISTER_CLASS(FarmSoil);
	GDREGISTER_CLASS(DuckFlock);
	GDREGISTER_CLASS(FarmCritters);
	GDREGISTER_CLASS(SaveSlots);
	Grade::init();
}

void uninitialize_mcgame_core(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	Grade::finish();
	Progress::finish();
	PenRules::finish();
	PenWork::finish();
	mc::Scripts::release();
}

extern "C" {
GDExtensionBool GDE_EXPORT mcgame_core_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_mcgame_core);
	init_obj.register_terminator(uninitialize_mcgame_core);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
