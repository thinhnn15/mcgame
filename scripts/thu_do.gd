extends Node3D

const BASE := {"hair": "short", "hair_color": "#4a3328", "skin": "#ffd6c4",
	"top": {"shape": "tee", "color": "#f4f2ec", "color_b": "#ffffff", "pattern": "plain", "trim": "#f4f2ec"},
	"bottom": {"shape": "pants", "color": "#3d4450", "color_b": "#ffffff", "pattern": "plain", "trim": "#3d4450"},
	"shoes": {"shape": "sneakers", "color": "#ffffff", "color_b": "#ffffff", "pattern": "plain", "trim": "#ff8fa8"}}
const HAT := {"shape": "nonla", "color": "#e2cf98", "color_b": "#e2cf98", "trim": "#e2cf98"}
const DAD := {"hair": "sidepart", "hat": {"shape": "nonla_noquai", "color": "#e2cf98", "color_b": "#e2cf98", "trim": "#e2cf98"},
	"top": {"shape": "shirt", "design": "soc", "color": "#f4f2ec", "color_b": "#7a8a9c", "trim": "#f4f2ec"},
	"bottom": {"shape": "pants", "color": "#6b5a48", "trim": "#6b5a48"},
	"shoes": {"shape": "slides", "design": "to_ong", "color": "#3f7fd0", "color_b": "#3f7fd0", "trim": "#3f7fd0"}}

const LANH := {"shape": "wide", "design": "lanh", "color": "#16171c", "color_b": "#4a4e5a", "color_c": "#ffffff", "trim": "#16171c", "pattern": "plain"}
const GRANNY := {"hair": "lowbun", "hair_color": "#d6d8de", "eye_style": "elder", "age": 1, "blush": 0.2, "bottom": LANH,
	"shoes": {"shape": "slides", "color": "#7a5a44", "color_b": "#7a5a44", "trim": "#7a5a44", "design": ""}}

const GRANDPA := {"hair": "bald", "hair_color": "#d6d8de", "eye_style": "elder", "age": 1, "blush": 0.15, "skin": "#f0c4a4",
	"bottom": {"shape": "shorts", "color": "#4a5568", "trim": "#4a5568", "design": ""},
	"shoes": {"shape": "slides", "design": "to_ong", "color": "#3f7fd0", "color_b": "#3f7fd0", "trim": "#3f7fd0", "pattern": "plain"}}

const KID_TI := {"body": "kid", "hair": "messy", "hair_color": "#2e2320", "eye_style": "round", "skin": "#f2c29a",
	"top": {"shape": "tee", "design": "", "color": "#7fb4ff", "color_b": "#ffffff", "pattern": "stripes", "trim": "#7fb4ff"},
	"bottom": {"shape": "shorts", "color": "#e06464", "trim": "#e06464", "design": ""},
	"shoes": {"shape": "slides", "design": "", "color": "#ffd23f", "color_b": "#ffd23f", "trim": "#ffd23f", "pattern": "plain"}}
const KID_BONG := {"body": "kid", "hair": "pigtails", "hair_color": "#2e2320", "eye_style": "sparkle",
	"top": {"shape": "dress", "design": "", "color": "#ffd6e2", "color_b": "#ffffff", "pattern": "flowers", "trim": "#ff8fb0"},
	"bottom": {"shape": "none"},
	"shoes": {"shape": "slides", "design": "", "color": "#ff9fb8", "color_b": "#ff9fb8", "trim": "#ff9fb8", "pattern": "plain"}}

const SUMMER := {"hair": "bob", "hair_color": "#3a2a22",
	"top": {"shape": "tee", "design": "", "color": "#f4f2ec", "color_b": "#ffffff", "pattern": "plain", "trim": "#f4f2ec"},
	"bottom": {"shape": "shorts", "design": "", "color": "#5a6b80", "color_b": "#ffffff", "pattern": "plain", "trim": "#5a6b80"},
	"shoes": {"shape": "slides", "design": "", "color": "#e8dcc4", "color_b": "#e8dcc4", "trim": "#e8dcc4", "pattern": "plain"}}

const HAI := {"hair": "messy", "hair_color": "#2e2320", "skin": "#e8b48e",
	"top": {"shape": "tee", "design": "", "color": "#7fd3e6", "color_b": "#ffffff", "pattern": "plain", "trim": "#7fd3e6"},
	"bottom": {"shape": "shorts", "design": "", "color": "#5a6b80", "trim": "#5a6b80"},
	"shoes": {"shape": "boots", "design": "", "color": "#3a3a3a", "color_b": "#3a3a3a", "trim": "#3a3a3a", "pattern": "plain"}}

const TU := {"hair": "sidepart", "hair_color": "#2e2320", "skin": "#d9a074",
	"top": {"shape": "balo", "design": "", "color": "#5a6b5a", "color_b": "#5a6b5a", "pattern": "plain", "trim": "#5a6b5a"},
	"bottom": {"shape": "shorts", "design": "", "color": "#3d4450", "trim": "#3d4450"},
	"shoes": {"shape": "slides", "design": "", "color": "#2b2b30", "color_b": "#2b2b30", "trim": "#2b2b30", "pattern": "plain"}}

const CONDUCTOR_SHIRT := {"shape": "shirt", "design": "conductor", "color": "#2b3f6b", "color_b": "#11151f", "color_c": "#f0c95a",
	"trim": "#2b3f6b", "pattern": "plain"}
const ESPORTS_TOP := {"shape": "tee", "design": "esports", "color": "#d4202e", "color_b": "#16171c", "color_c": "#d9b45a", "trim": "#16171c", "pattern": "plain"}
const FOOTBALL_KIT := {"top": {"shape": "tee", "design": "football", "color": "#d32a1f", "color_b": "#f7f6f2", "color_c": "#1a1a1e", "trim": "#f7f6f2", "pattern": "plain"},
	"bottom": {"shape": "shorts", "design": "track", "color": "#f7f6f2", "color_b": "#1a1a1e", "color_c": "#ffffff", "trim": "#f7f6f2", "pattern": "plain"},
	"socks": {"shape": "knee", "color": "#1a1a1e", "trim": "#d32a1f"},
	"shoes": {"shape": "sneakers", "design": "", "color": "#1a1a1e", "color_b": "#1a1a1e", "trim": "#d32a1f", "pattern": "plain"}}
const CONDUCTOR_CAP := {"shape": "conductor_cap", "color": "#24304f", "color_b": "#1a1d26", "trim": "#1a1d26"}

const SON := {"hair": "buzz", "hair_color": "#8a8a90", "eye_style": "elder", "age": 1, "blush": 0.15, "skin": "#c48a62", "face": "square",
	"top": {"shape": "shirt", "design": "", "color": "#9aa38a", "color_b": "#ffffff", "trim": "#9aa38a", "pattern": "plain"},
	"bottom": {"shape": "wide", "design": "", "color": "#4a4038", "trim": "#4a4038", "pattern": "plain"},
	"shoes": {"shape": "strapsandal", "design": "", "color": "#7a5a44", "color_b": "#7a5a44", "trim": "#e8dcc4", "pattern": "plain"}}

var ITEMS := [
	["Món 1 · Dép lê / tổ ong", "feet", [
		["Tổ ong xanh", {"bottom": {"shape": "shorts", "color": "#5a6b80"}, "shoes": _shoe("#3f7fd0", "to_ong")}],
		["Tổ ong trắng", {"bottom": {"shape": "shorts", "color": "#5a6b80"}, "shoes": _shoe("#f2f0ea", "to_ong")}],
		["Dép lê đen", {"shoes": _shoe("#2b2b30", "")}],
		["Dép lê hồng", {"bottom": {"shape": "shorts", "color": "#7fb4ff"}, "shoes": _shoe("#ff9fb8", "")}]]],
	["Món 2 · Nón lá", "head", [
		["Có quai · tóc ngắn", {"hat": HAT}],
		["Có quai · tóc búi", {"hat": HAT, "hair": "buns"}],
		["Có quai · tóc dài", {"hat": HAT, "hair": "tripo_long"}],
		["Có quai · đuôi ngựa", {"hat": HAT, "hair": "ponytail"}],
		["Không quai · tóc ngắn", {"hat": _hat("nonla_noquai")}],
		["Không quai · hai bím", {"hat": _hat("nonla_noquai"), "hair": "pigtails"}]]],
	["Món 3 · Áo sơ mi ngắn tay", "full", [
		["Trắng", {"top": _shirt("", "#f7f7f4", "#f7f7f4")}],
		["Xanh", {"top": _shirt("", "#9cc4e8", "#2f4f8a")}],
		["Sọc", {"top": _shirt("soc", "", "")}],
		["Kẻ ô", {"top": _shirt("gingham", "", "")}],
		["Hoa", {"top": _shirt("floral", "", "")}],
		["Công sở", {"top": _shirt("office", "", "")}]]],
	["Món 4 · Áo bà ba", "full", [
		["Tím", _merged(GRANNY, {"top": _baba("#5a3f6b", "#efe6d6", "")})],
		["Nâu", _merged(GRANNY, {"top": _baba("#7a5236", "#f0e4cc", "")})],
		["Đen", _merged(GRANNY, {"top": _baba("#2e2a2c", "#e8dfcf", "")})],
		["Trắng ngà", _merged(GRANNY, {"top": _baba("#efe4cc", "#a8875e", "")})],
		["Hoa nhí", _merged(GRANNY, {"top": _baba("#3d4e7a", "#e8d9b5", "floral")})]]],
	["Món 5 · Quần ống rộng", "full", [
		["Lãnh đen (satin)", _merged(GRANNY, {"top": _baba("#5a3f6b", "#efe6d6", "")})],
		["Vải đen", _merged(GRANNY, {"top": _baba("#efe4cc", "#a8875e", ""), "bottom": _wide("#2b2a2e")})],
		["Vải nâu", _merged(GRANNY, {"top": _baba("#efe4cc", "#a8875e", ""), "bottom": _wide("#5b4a3c")})],
		["Lãnh + áo hoa nhí", _merged(GRANNY, {"top": _baba("#3d4e7a", "#e8d9b5", "floral")})]]],
	["Món 6 · Tóc búi thấp", "head", [
		["Bạc", _merged(GRANNY, {"top": _baba("#5a3f6b", "#efe6d6", "")})],
		["Muối tiêu", _merged(GRANNY, {"hair_color": "#8a8a90", "top": _baba("#7a5236", "#f0e4cc", "")})],
		["Đen nâu (cô, dì)", _merged(GRANNY, {"hair_color": "#3a2a22", "top": _baba("#efe4cc", "#a8875e", "")})],
		["Đội nón lá", _merged(GRANNY, {"hat": HAT, "top": _baba("#3d4e7a", "#e8d9b5", "floral")})],
		["Đeo kính lão", _merged(GRANNY, {"glasses": "#8a6e52", "glasses_shape": "round", "top": _baba("#5a3f6b", "#efe6d6", "")})],
		["Mặt trẻ (so sánh)", _merged(GRANNY, {"eye_style": "classic", "age": 0, "blush": 0.35, "top": _baba("#5a3f6b", "#efe6d6", "")})]]],
	["Món 7 · Áo ba lỗ", "full", [
		["Trắng", _merged(GRANDPA, {"top": _balo("#f4f2ec")})],
		["Ngà cũ", _merged(GRANDPA, {"top": _balo("#e9dcc0")})],
		["Xanh bộ đội", _merged(GRANDPA, {"top": _balo("#5a6b5a")})],
		["Trắng, quần dài nâu", _merged(GRANDPA, {"top": _balo("#f4f2ec"), "bottom": _wide("#5b4a3c")})]]],
	["Món 8 · Tóc ông (hói, ngắn thưa)", "head", [
		["Hói · bạc", _merged(GRANDPA, {"top": _balo("#f4f2ec")})],
		["Hói · muối tiêu (chú)", _merged(GRANDPA, {"hair_color": "#5a5a60", "top": _balo("#f4f2ec")})],
		["Ngắn thưa · bạc", _merged(GRANDPA, {"hair": "thin", "top": _balo("#f4f2ec")})],
		["Ngắn thưa · muối tiêu (chú)", _merged(GRANDPA, {"hair": "thin", "hair_color": "#5a5a60", "top": _balo("#f4f2ec")})]]],
	["Cả bộ · Ông ở quê", "full", [
		["Ba lỗ, quần đùi, dép tổ ong", _merged(GRANDPA, {"top": _balo("#f4f2ec")})],
		["Ba lỗ, quần dài nâu, nón lá", _merged(GRANDPA, {"hat": _hat("nonla_noquai"), "top": _balo("#f4f2ec"), "bottom": _wide("#5b4a3c")})],
		["Ba lỗ bộ đội, kính lão", _merged(GRANDPA, {"hair": "thin", "glasses": "#8a6e52", "glasses_shape": "round", "top": _balo("#5a6b5a")})],
		["Sơ mi sọc, tóc thưa", _merged(GRANDPA, {"hair": "thin", "top": _shirt("soc", "", ""), "bottom": _wide("#5b4a3c")})]]],
	["Cả bộ · Bà ở quê", "full", [
		["Áo tím, quần lãnh", _merged(GRANNY, {"top": _baba("#5a3f6b", "#efe6d6", "")})],
		["Áo hoa nhí, nón lá", _merged(GRANNY, {"hat": HAT, "top": _baba("#3d4e7a", "#e8d9b5", "floral")})],
		["Áo trắng ngà, quần nâu", _merged(GRANNY, {"top": _baba("#efe4cc", "#a8875e", ""), "bottom": _wide("#5b4a3c")})],
		["Áo tím, kính lão", _merged(GRANNY, {"glasses": "#8a6e52", "glasses_shape": "round", "top": _baba("#5a3f6b", "#efe6d6", "")})]]],
	["Đợt 2 · Mũ bảo hiểm", "head", [
		["Đỏ · Bố", _merged(DAD, {"hair": "thin", "hair_color": "#5a5a60", "hat": _helmet("#d8343c")})],
		["Xanh · tóc đuôi ngựa", {"hair": "ponytail", "hair_color": "#3a2a22", "hat": _helmet("#2f6fd0")}],
		["Trắng · tóc dài", {"hair": "tripo_long", "hair_color": "#3a2a22", "hat": _helmet("#f2f2ee")}],
		["Hồng · tóc búi", {"hair": "buns", "hair_color": "#3a2a22", "hat": _helmet("#f08aa6")}]]],
	["Đợt 2 · Gậy chống (ông)", "full", [
		["Ông chống gậy (bấm Đi để xem bước)", _merged(GRANDPA, {"tool": "cane", "top": _balo("#f4f2ec"), "bottom": _wide("#5b4a3c")})],
		["Sơ mi sọc, nón lá, gậy", _merged(GRANDPA, {"tool": "cane", "hat": _hat("nonla_noquai"), "top": _shirt("soc", "", ""), "bottom": _wide("#5b4a3c")})]]],
	["Đợt 2 · Trẻ con (Tí, Bống)", "full", [
		["Tí: áo sọc, quần đùi", KID_TI],
		["Bống: tóc hai bím, váy hoa", KID_BONG],
		["Tí đội nón lá", _merged(KID_TI, {"hat": HAT})],
		["Bống đội mũ bảo hiểm", _merged(KID_BONG, {"hat": _helmet("#f08aa6")})],
		["So với người lớn: Bố", _merged(DAD, {"hair": "thin", "hair_color": "#5a5a60"})]]],
	["Đợt 2 · Khẩu trang", "head", [
		["Xanh nhạt, viền trắng", _merged(GRANNY, {"hair_color": "#3a2a22", "eye_style": "classic", "age": 0, "blush": 0.35, "mask": "#7fa8d8", "mask_trim": "#ffffff", "top": _baba("#3d4e7a", "#e8d9b5", "floral")})],
		["Hồng + nón lá (mẹ đi chợ)", _merged(GRANNY, {"hair_color": "#3a2a22", "eye_style": "classic", "age": 0, "blush": 0.35, "mask": "#e88aa6", "mask_trim": "#ffffff", "hat": HAT, "top": _baba("#3d4e7a", "#e8d9b5", "floral")})],
		["Đen + mũ bảo hiểm (bố đi xe)", _merged(DAD, {"hair": "thin", "hair_color": "#5a5a60", "mask": "#2b2b30", "mask_trim": "#2b2b30", "hat": _helmet("#d8343c")})],
		["Trắng + kính lão (ông)", _merged(GRANDPA, {"mask": "#f2f2ee", "mask_trim": "#d8d8d8", "glasses": "#8a6e52", "glasses_shape": "round", "top": _balo("#f4f2ec")})],
		["Vàng · Bống", _merged(KID_BONG, {"mask": "#ffd23f", "mask_trim": "#ffffff"})]]],
	["Đợt 2 · Mũ cối", "head", [
		["Bác trưởng thôn (xanh)", _merged(GRANDPA, {"hair": "thin", "hair_color": "#8a8a90", "hat": _moicoi("#6b7f4e", "#4f5f38"), "top": _shirt("", "#f7f7f4", "#f7f7f4"), "bottom": _wide("#3d4450")})],
		["Màu kaki", _merged(GRANDPA, {"hat": _moicoi("#b5a77a", "#8a7d55"), "top": _balo("#f4f2ec")})],
		["Tóc dài", {"hair": "tripo_long", "hair_color": "#3a2a22", "hat": _moicoi("#6b7f4e", "#4f5f38")}],
		["Tí đội mũ cối", _merged(KID_TI, {"hat": _moicoi("#6b7f4e", "#4f5f38")})]]],
	["Đợt 2 · Mũ lưỡi trai", "head", [
		["Đỏ · Hải", _merged(HAI, {"hat": _cap("#e05050", "#be4444")})],
		["Trắng lưỡi xanh", _merged(HAI, {"hat": _cap("#f4f2ec", "#2f4f8a")})],
		["Vàng · tóc búi", {"hair": "buns", "hair_color": "#3a2a22", "hat": _cap("#f2c23a", "#cfa22a")}],
		["Tí đội mũ lưỡi trai (lưỡi ngắn)", _merged(KID_TI, {"hat": _cap("#e05050", "#be4444")})],
		["Tóc đuôi ngựa + mũ (đuôi thò ra sau)", {"hair": "ponytail", "hair_color": "#3a2a22", "hat": _cap("#f4f2ec", "#2f4f8a")}],
		["Tóc hai bím + mũ hồng", {"hair": "pigtails", "hair_color": "#3a2a22", "hat": _cap("#f08aa6", "#c86a86")}],
		["Bống: hai bím + mũ", _merged(KID_BONG, {"hat": _cap("#ffd23f", "#d8a82a")})],
		["Đuôi ngựa + mũ bảo hiểm", {"hair": "ponytail", "hair_color": "#3a2a22", "hat": _helmet("#2f6fd0")}],
		["Đuôi ngựa + nón lá", {"hair": "ponytail", "hair_color": "#3a2a22", "hat": HAT}]]],
	["Đợt 2 · Khăn rằn", "full", [
		["Trắng đen · chú Tư", _merged(TU, {"scarf": "#f4f2ec", "scarf_b": "#2b2b30"})],
		["Chú Tư + nón lá", _merged(TU, {"scarf": "#f4f2ec", "scarf_b": "#2b2b30", "hat": _hat("nonla_noquai")})],
		["Nâu kem + sơ mi trắng", _merged(TU, {"scarf": "#f4ead2", "scarf_b": "#7a4a2a", "top": _shirt("", "#f7f7f4", "#f7f7f4")})],
		["Xanh trắng + ba lỗ trắng", _merged(TU, {"scarf": "#f4f2ec", "scarf_b": "#2f4f8a", "top": _balo("#f4f2ec")})],
		["Ông + khăn rằn", _merged(GRANDPA, {"scarf": "#f4f2ec", "scarf_b": "#2b2b30", "top": _balo("#f4f2ec")})],
		["Tí quàng khăn", _merged(KID_TI, {"scarf": "#f4f2ec", "scarf_b": "#2b2b30"})]]],
	["Món mới · Quần áo hè (phiên khác làm)", "full", [
		["Dép tông xanh", _merged(SUMMER, {"shoes": {"shape": "flipflop", "design": "", "color": "#3f7fd0", "color_b": "#3f7fd0", "trim": "#f4f1ea", "pattern": "plain"}})],
		["Dép tông đỏ đen", _merged(SUMMER, {"shoes": {"shape": "flipflop", "design": "", "color": "#e04848", "color_b": "#e04848", "trim": "#2b2b30", "pattern": "plain"}})],
		["Dép quai hậu", _merged(SUMMER, {"bottom": {"shape": "rolled", "design": "", "color": "#3d3d45", "color_b": "#3d3d45", "trim": "#6a6a74", "pattern": "plain"}, "shoes": {"shape": "strapsandal", "design": "", "color": "#3a4a6a", "color_b": "#3a4a6a", "trim": "#2b2b30", "pattern": "plain"}})],
		["Dép quai hậu nâu kem", _merged(SUMMER, {"shoes": {"shape": "strapsandal", "design": "", "color": "#7a5a44", "color_b": "#7a5a44", "trim": "#e8dcc4", "pattern": "plain"}})],
		["Áo chống nắng hồng", _merged(SUMMER, {"top": {"shape": "sunjacket", "design": "", "color": "#f6c1d2", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "mask": "#f6c1d2", "mask_trim": "#ffffff", "hat": HAT})],
		["Áo chống nắng xanh", _merged(SUMMER, {"top": {"shape": "sunjacket", "design": "", "color": "#9fd0e8", "color_b": "#ffffff", "trim": "#2f3a63", "pattern": "plain"}})],
		["Quần yếm", _merged(SUMMER, {"top": {"shape": "overalls", "design": "", "color": "#5b7fb3", "color_b": "#5b7fb3", "trim": "#f7e7a8", "pattern": "plain"}})],
		["Quần yếm kaki", _merged(SUMMER, {"top": {"shape": "overalls", "design": "", "color": "#b39a6a", "color_b": "#b39a6a", "trim": "#ffffff", "pattern": "plain"}})],
		["Áo dài đỏ", _merged(SUMMER, {"hair": "tripo_long", "top": {"shape": "aodai", "design": "", "color": "#c8323c", "color_b": "#ffffff", "trim": "#f4f1ea", "pattern": "plain"}})],
		["Áo dài trắng", _merged(SUMMER, {"hair": "tripo_long", "top": {"shape": "aodai", "design": "", "color": "#f4f6fa", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}})],
		["Áo dài hoa xanh", _merged(SUMMER, {"hair": "tripo_long", "top": {"shape": "aodai", "design": "", "color": "#2f4f8a", "color_b": "#9fc7e8", "trim": "#1e1e22", "pattern": "flowers"}})],
		["Váy hai dây", _merged(SUMMER, {"top": {"shape": "sundress", "design": "", "color": "#f7d9a8", "color_b": "#ffffff", "trim": "#f7d9a8", "pattern": "plain"}})],
		["Váy hai dây, dây đỏ", _merged(SUMMER, {"top": {"shape": "sundress", "design": "", "color": "#f4ead2", "color_b": "#ffffff", "trim": "#d0503c", "pattern": "plain"}})],
		["Váy hai dây hoa", _merged(SUMMER, {"top": {"shape": "sundress", "design": "", "color": "#9fc7e8", "color_b": "#ffffff", "trim": "#9fc7e8", "pattern": "flowers"}})],
		["Áo polo", _merged(SUMMER, {"hair": "sidepart", "top": {"shape": "polo", "design": "", "color": "#2f5d8a", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}})],
		["Áo mưa cánh dơi xanh", _merged(SUMMER, {"top": {"shape": "poncho", "design": "", "color": "#3f9fd8", "color_b": "#ffffff", "trim": "#1f5f8a", "pattern": "plain"}})],
		["Áo mưa cánh dơi vàng", _merged(SUMMER, {"top": {"shape": "poncho", "design": "", "color": "#f2c23a", "color_b": "#ffffff", "trim": "#2f3a63", "pattern": "plain"}})],
		["Quần xắn gấu", _merged(SUMMER, {"bottom": {"shape": "rolled", "design": "", "color": "#3d3d45", "color_b": "#3d3d45", "trim": "#6a6a74", "pattern": "plain"}})],
		["Quần xắn gấu bò", _merged(SUMMER, {"bottom": {"shape": "rolled", "design": "denim", "color": "#3f6699", "color_b": "#ffffff", "color_c": "#ffffff", "trim": "#e0a050", "pattern": "plain"}})],
		["Quần lụa", _merged(SUMMER, {"bottom": {"shape": "silk", "design": "", "color": "#2b2a2e", "color_b": "#2b2a2e", "trim": "#2b2a2e", "pattern": "plain"}})]]],
	["Cả bộ · Bố ở quê", "full", [
		["Sơ mi sọc, mũ bảo hiểm (đi xe Dream)", _merged(DAD, {"hair": "thin", "hair_color": "#5a5a60", "hat": _helmet("#d8343c")})],
		["Sơ mi sọc + nón lá + tổ ong", DAD],
		["Như trên, nón có quai", _merged(DAD, {"hat": HAT})]]],

	["Giày dép mới (04/11)", "feet", [
		["Giày vải bata xanh", _merged(SUMMER, {"shoes": {"shape": "bata", "design": "", "color": "#2f3a6b", "color_b": "#2f3a6b", "trim": "#f7f5ef", "pattern": "plain"}})],
		["Giày vải bata đỏ", _merged(SUMMER, {"shoes": {"shape": "bata", "design": "", "color": "#c8383e", "color_b": "#c8383e", "trim": "#f7f5ef", "pattern": "plain"}})],
		["Giày lười nâu", _merged(SUMMER, {"bottom": {"shape": "pants", "design": "", "color": "#3b4256", "color_b": "#3b4256", "trim": "#3b4256", "pattern": "plain"}, "shoes": {"shape": "loafer", "design": "", "color": "#7a4630", "color_b": "#7a4630", "trim": "#4a2a1c", "pattern": "plain"}})],
		["Giày búp bê hồng", _merged(SUMMER, {"bottom": {"shape": "skirt", "design": "", "color": "#f6b6c8", "color_b": "#f6b6c8", "trim": "#ffffff", "pattern": "plain"}, "shoes": {"shape": "ballet", "design": "", "color": "#f0b0b8", "color_b": "#f0b0b8", "trim": "#d0506a", "pattern": "plain"}})],
		["Sandal đế xuồng", _merged(SUMMER, {"shoes": {"shape": "wedge", "design": "", "color": "#f4ead8", "color_b": "#f4ead8", "trim": "#c9a46a", "pattern": "plain"}})],
		["Guốc mộc quai đen", _merged(SUMMER, {"bottom": {"shape": "wide", "design": "lanh", "color": "#16171c", "color_b": "#4a4e5a", "trim": "#ffffff", "pattern": "plain"}, "shoes": {"shape": "guoc", "design": "", "color": "#3a2a24", "color_b": "#3a2a24", "trim": "#b5683e", "pattern": "plain"}})],
		["Guốc mộc quai đỏ", _merged(SUMMER, {"shoes": {"shape": "guoc", "design": "", "color": "#c8383e", "color_b": "#c8383e", "trim": "#d9b07a", "pattern": "plain"}})],
		["Ủng lội ruộng đen", _merged(SUMMER, {"bottom": {"shape": "rolled", "design": "", "color": "#3d3d45", "color_b": "#3d3d45", "trim": "#6a6a74", "pattern": "plain"}, "shoes": {"shape": "farmboots", "design": "", "color": "#2b2d2a", "color_b": "#2b2d2a", "trim": "#c9c2b0", "pattern": "plain"}})],
		["Ủng lội ruộng xanh lính", _merged(SUMMER, {"shoes": {"shape": "farmboots", "design": "", "color": "#4f5f38", "color_b": "#4f5f38", "trim": "#2b2d2a", "pattern": "plain"}})]]],
	["Tất (04/11)", "feet", [
		["Tất cổ lửng trắng sọc đỏ + giày thể thao", _merged(SUMMER, {"shoes": {"shape": "sneakers", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#ff8fa8", "pattern": "plain"}, "socks": {"shape": "crew", "color": "#ffffff", "trim": "#e06464"}})],
		["Tất cao gối xanh than + giày lười", _merged(SUMMER, {"bottom": {"shape": "skirt", "design": "tartan", "color": "#5a5f7a", "color_b": "#283c6a", "color_c": "#f2d04a", "trim": "#ffffff", "pattern": "plain"}, "shoes": {"shape": "loafer", "design": "", "color": "#7a4630", "color_b": "#7a4630", "trim": "#4a2a1c", "pattern": "plain"}, "socks": {"shape": "knee", "color": "#2f3a56", "trim": "#2f3a56"}})],
		["Tất cổ ngắn vàng + dép lê", _merged(SUMMER, {"shoes": {"shape": "slides", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#7fb4ff", "pattern": "plain"}, "socks": {"shape": "ankle", "color": "#f6d06a", "trim": "#ffffff"}})],
		["Tất kẻ sọc + giày bata", _merged(SUMMER, {"shoes": {"shape": "bata", "design": "", "color": "#2f3a6b", "color_b": "#2f3a6b", "trim": "#f7f5ef", "pattern": "plain"}, "socks": {"shape": "crew", "color": "#ff9fb8", "color_b": "#ffffff", "pattern": "stripes", "trim": "#ff9fb8"}})]]],
	["Quần áo mới (04/11)", "full", [
		["Áo phông oversize xanh lá", _merged(SUMMER, {"top": {"shape": "oversize", "design": "", "color": "#a8e6a1", "color_b": "#ffffff", "trim": "#a8e6a1", "pattern": "plain"}})],
		["Croptop trắng + quần jogger", _merged(SUMMER, {"top": {"shape": "croptop", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "bottom": {"shape": "jogger", "design": "", "color": "#9aa0ac", "color_b": "#ffffff", "trim": "#6a707c", "pattern": "plain"}, "shoes": {"shape": "sneakers", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#e06464", "pattern": "plain"}})],
		["Quần lửng bò", _merged(SUMMER, {"bottom": {"shape": "capri", "design": "denim", "color": "#3f6699", "color_b": "#ffffff", "trim": "#e0a050", "pattern": "plain", "color_c": "#ffffff"}})],
		["Quần jogger thể thao", _merged(SUMMER, {"bottom": {"shape": "jogger", "design": "track", "color": "#2f3a56", "color_b": "#e8e8ee", "trim": "#2f3a56", "pattern": "plain"}, "shoes": {"shape": "sneakers", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#2f3a56", "pattern": "plain"}})],
		["Chân váy dài hoa tím", _merged(SUMMER, {"top": {"shape": "shirt", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "bottom": {"shape": "skirt_midi", "design": "", "color": "#c4a3ff", "color_b": "#ffffff", "trim": "#c4a3ff", "pattern": "flowers"}, "shoes": {"shape": "ballet", "design": "", "color": "#f0b0b8", "color_b": "#ffffff", "trim": "#d0506a", "pattern": "plain"}})],
		["Chân váy xếp ly kẻ", _merged(SUMMER, {"top": {"shape": "shirt", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "bottom": {"shape": "skirt_pleat", "design": "tartan", "color": "#c23a3a", "color_b": "#283c6a", "trim": "#ffffff", "pattern": "plain", "color_c": "#f2d04a"}, "shoes": {"shape": "loafer", "design": "", "color": "#7a4630", "color_b": "#ffffff", "trim": "#4a2a1c", "pattern": "plain"}, "socks": {"shape": "knee", "color": "#2f3a56", "trim": "#2f3a56"}})],
		["Váy maxi hoa", _merged(SUMMER, {"top": {"shape": "dress_maxi", "design": "", "color": "#f4ead2", "color_b": "#ffffff", "trim": "#f7d9a8", "pattern": "flowers"}, "bottom": {"shape": "none"}, "shoes": {"shape": "wedge", "design": "", "color": "#f4ead8", "color_b": "#ffffff", "trim": "#c9a46a", "pattern": "plain"}})],
		["Đầm công sở xanh than", _merged(SUMMER, {"top": {"shape": "dress_office", "design": "", "color": "#2f3a63", "color_b": "#ffffff", "trim": "#1a1d26", "pattern": "plain"}, "bottom": {"shape": "none"}, "shoes": {"shape": "ballet", "design": "", "color": "#2b2b30", "color_b": "#ffffff", "trim": "#2b2b30", "pattern": "plain"}})],
		["Váy xòe tầng chấm bi", _merged(SUMMER, {"top": {"shape": "dress_tier", "design": "", "color": "#ffb27a", "color_b": "#ffffff", "trim": "#ffb27a", "pattern": "dots"}, "bottom": {"shape": "none"}, "shoes": {"shape": "strapsandal", "design": "", "color": "#7a5a44", "color_b": "#ffffff", "trim": "#e8dcc4", "pattern": "plain"}})],
		["Váy yếm bò", _merged(SUMMER, {"top": {"shape": "pinafore", "design": "", "color": "#3f6699", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "bottom": {"shape": "none"}, "shoes": {"shape": "bata", "design": "", "color": "#c8383e", "color_b": "#ffffff", "trim": "#f7f5ef", "pattern": "plain"}, "socks": {"shape": "crew", "color": "#ffffff", "trim": "#ffffff"}})],
		["Áo khoác bò", _merged(SUMMER, {"top": {"shape": "jacket", "design": "", "color": "#4f78ad", "color_b": "#ffffff", "trim": "#f4f2ec", "pattern": "plain", "stitch": "#e0a050"}, "bottom": {"shape": "pants", "design": "", "color": "#3b4256", "color_b": "#ffffff", "trim": "#3b4256", "pattern": "plain"}})],
		["Áo khoác gió xanh rêu", _merged(SUMMER, {"top": {"shape": "bomber", "design": "", "color": "#3f5a3a", "color_b": "#ffffff", "trim": "#2a2d2a", "pattern": "plain"}, "bottom": {"shape": "pants", "design": "", "color": "#3b4256", "color_b": "#ffffff", "trim": "#3b4256", "pattern": "plain"}})],
		["Cardigan vàng mở", _merged(SUMMER, {"top": {"shape": "cardigan_open", "design": "", "color": "#e8c27a", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "bottom": {"shape": "pants", "design": "", "color": "#3b4256", "color_b": "#ffffff", "trim": "#3b4256", "pattern": "plain"}})],
		["Blazer xanh than + quần âu", _merged(SUMMER, {"top": {"shape": "blazer", "design": "", "color": "#2f3a56", "color_b": "#ffffff", "trim": "#f7f8fb", "pattern": "plain"}, "bottom": {"shape": "pants", "design": "", "color": "#2f3a56", "color_b": "#ffffff", "trim": "#2f3a56", "pattern": "plain"}, "shoes": {"shape": "loafer", "design": "", "color": "#3a2418", "color_b": "#ffffff", "trim": "#2a1a10", "pattern": "plain"}})],
		["Blazer be + chân váy xếp ly", _merged(SUMMER, {"top": {"shape": "blazer", "design": "", "color": "#b89a6a", "color_b": "#ffffff", "trim": "#2f3a56", "pattern": "plain"}, "bottom": {"shape": "skirt_pleat", "design": "", "color": "#5a4a30", "color_b": "#ffffff", "trim": "#5a4a30", "pattern": "plain"}})],
		["Đồng phục học sinh (khăn quàng đỏ)", _merged(SUMMER, {"top": {"shape": "shirt", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "bottom": {"shape": "pants", "design": "", "color": "#2f3a63", "color_b": "#ffffff", "trim": "#2f3a63", "pattern": "plain"}, "shoes": {"shape": "bata", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#f7f5ef", "pattern": "plain"}, "scarf": "#d8343c", "scarf_b": "#d8343c"})],
		["Áo bà ba nâu", _merged(SUMMER, {"top": {"shape": "baba", "design": "", "color": "#6b4a36", "color_b": "#ffffff", "trim": "#6b4a36", "pattern": "plain"}, "bottom": {"shape": "wide", "design": "", "color": "#2b2a2e", "color_b": "#2b2a2e", "trim": "#2b2a2e", "pattern": "plain"}})]]],

	["Loftia (04/11)", "feet", [
		["Giày Mary-Jane đỏ + tất viền ren", _merged(SUMMER, {"bottom": {"shape": "skirt", "design": "", "color": "#a9c9dc", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"}, "shoes": {"shape": "maryjane", "design": "", "color": "#c8463c", "color_b": "#c8463c", "trim": "#f3ece0", "pattern": "plain"}, "socks": {"shape": "frill", "color": "#a9d3e0", "trim": "#f2d24a"}})],
		["Giày Mary-Jane đen + tất ren trắng", _merged(SUMMER, {"shoes": {"shape": "maryjane", "design": "", "color": "#2b2b30", "color_b": "#2b2b30", "trim": "#2b2b30", "pattern": "plain"}, "socks": {"shape": "frill", "color": "#ffffff", "trim": "#ff9fb8"}})]]],

	["Tóc mới · Bob (Thợ Tóc)", "head", [
		["Bob cũ (để so)", _merged(SUMMER, {"hair": "bob"})],
		["Bob mới", _merged(SUMMER, {"hair": "bob2"})],
		["Bob mới · tóc đen", _merged(SUMMER, {"hair": "bob2", "hair_color": "#1f1a1c"})],
		["Bob mới · nâu sáng", _merged(SUMMER, {"hair": "bob2", "hair_color": "#9a6a44"})],
		["Bob mới · Bống", _merged(KID_BONG, {"hair": "bob2"})],
		["Bob mới + nón lá", _merged(SUMMER, {"hair": "bob2", "hat": HAT})]]],

	["Tóc mới · Lọn rời (Thợ Tóc)", "head", [
		["Tóc ngắn (short)", _merged(SUMMER, {"hair": "short"})],
		["Tóc rối (messy)", _merged(SUMMER, {"hair": "messy"})],
		["Rẽ ngôi (sidepart)", _merged(SUMMER, {"hair": "sidepart"})],
		["Tóc dựng (spiky)", _merged(SUMMER, {"hair": "spiky"})],
		["Tóc thưa (ông)", _merged(SUMMER, {"hair": "thin"})],
		["Búi cao (topbun)", _merged(SUMMER, {"hair": "topbun"})],
		["Đuôi ngựa (ponytail)", _merged(SUMMER, {"hair": "ponytail"})],
		["Hai bím (pigtails)", _merged(SUMMER, {"hair": "pigtails"})],
		["Búi thấp (bà)", _merged(SUMMER, {"hair": "lowbun"})]]],

	["Tóc Tripo · kín gáy", "head", [
		["Tripo kín gáy", _merged(SUMMER, {"hair": "tripo_full"})],
		["Tripo kín gáy · tóc đen", _merged(SUMMER, {"hair": "tripo_full", "hair_color": "#1f1a1c"})],
		["Tripo kín gáy · nâu sáng", _merged(SUMMER, {"hair": "tripo_full", "hair_color": "#9a6a44"})],
		["Tripo ngang vai uốn sóng", _merged(SUMMER, {"hair": "tripo_wavy"})],
		["Tripo uốn sóng · tóc đen", _merged(SUMMER, {"hair": "tripo_wavy", "hair_color": "#1f1a1c"})],
		["Tripo uốn sóng · nâu sáng", _merged(SUMMER, {"hair": "tripo_wavy", "hair_color": "#9a6a44"})],
		["Tripo uốn sóng + nón lá", _merged(SUMMER, {"hair": "tripo_wavy", "hat": HAT})],
		["Tripo tóc tém", _merged(SUMMER, {"hair": "tripo_pixie"})],
		["Tripo tóc tém · tóc đen", _merged(SUMMER, {"hair": "tripo_pixie", "hair_color": "#1f1a1c"})],
		["Tripo tóc tém · nâu sáng", _merged(SUMMER, {"hair": "tripo_pixie", "hair_color": "#9a6a44"})],
		["Tripo buộc lệch vai", _merged(SUMMER, {"hair": "tripo_sidetail"})],
		["Tripo buộc lệch · tóc đen", _merged(SUMMER, {"hair": "tripo_sidetail", "hair_color": "#1f1a1c"})],
		["Tripo buộc lệch · nâu sáng", _merged(SUMMER, {"hair": "tripo_sidetail", "hair_color": "#9a6a44"})],
		["Tripo dài thẳng", _merged(SUMMER, {"hair": "tripo_long"})],
		["Tripo dài thẳng · tóc đen", _merged(SUMMER, {"hair": "tripo_long", "hair_color": "#1f1a1c"})],
		["Tripo dài thẳng · nâu sáng", _merged(SUMMER, {"hair": "tripo_long", "hair_color": "#9a6a44"})],
		["Tripo hai búi", _merged(SUMMER, {"hair": "tripo_buns"})],
		["Tripo hai búi · tóc đen", _merged(SUMMER, {"hair": "tripo_buns", "hair_color": "#1f1a1c"})],
		["Tripo hai búi · nâu sáng", _merged(SUMMER, {"hair": "tripo_buns", "hair_color": "#9a6a44"})],
		["Tóc ngắn của mình (để so)", _merged(SUMMER, {"hair": "short"})]]],

	["Trưởng tàu (04/11)", "full", [
		["Trưởng tàu: mũ, cầu vai, còi", _merged(GRANDPA, {"hair": "short", "hair_color": "#5a5a60", "eye_style": "classic", "age": 0,
			"top": CONDUCTOR_SHIRT, "bottom": {"shape": "pants", "design": "", "color": "#23262e", "color_b": "#23262e", "trim": "#23262e", "pattern": "plain"},
			"shoes": {"shape": "loafer", "design": "", "color": "#24252a", "color_b": "#24252a", "trim": "#24252a", "pattern": "plain"},
			"hat": CONDUCTOR_CAP, "neck": "coi", "neck_cord": "#c8383e"})],
		["Cạnh bác bảo vệ (mũ khác nhau)", _merged(GRANDPA, {"hair": "thin", "top": {"shape": "shirt", "design": "", "color": "#bcd3ea", "color_b": "#ffffff", "trim": "#bcd3ea", "pattern": "plain"},
			"bottom": {"shape": "pants", "design": "", "color": "#2b2d36", "color_b": "#2b2d36", "trim": "#2b2d36", "pattern": "plain"}, "hat": _hat_c("guard_cap", "#3b4a6b", "#2a3550")})],
		["Trưởng tàu trẻ, còi dây xanh", _merged(SUMMER, {"hair": "sidepart", "hair_color": "#2e2320",
			"top": CONDUCTOR_SHIRT, "bottom": {"shape": "pants", "design": "", "color": "#23262e", "color_b": "#23262e", "trim": "#23262e", "pattern": "plain"},
			"shoes": {"shape": "loafer", "design": "", "color": "#24252a", "color_b": "#24252a", "trim": "#24252a", "pattern": "plain"},
			"hat": CONDUCTOR_CAP, "neck": "coi", "neck_cord": "#2f4f8a"})],
		["Thẻ nhân viên mc_studio (dây hồng)", _merged(SUMMER, {"hair": "sidepart", "top": {"shape": "shirt", "design": "", "color": "#f7f7f4", "color_b": "#ffffff", "trim": "#f7f7f4", "pattern": "plain"},
			"bottom": {"shape": "pants", "design": "", "color": "#2f3a56", "color_b": "#2f3a56", "trim": "#2f3a56", "pattern": "plain"}, "neck": "the_nv"})],
		["Thẻ nhân viên trên blazer", _merged(SUMMER, {"hair": "bob2", "top": {"shape": "blazer", "design": "", "color": "#2f3a56", "color_b": "#ffffff", "trim": "#f7f8fb", "pattern": "plain"},
			"bottom": {"shape": "pants", "design": "", "color": "#2f3a56", "color_b": "#2f3a56", "trim": "#2f3a56", "pattern": "plain"}, "neck": "the_nv"})],
		["Thẻ nhân viên trên áo phông", _merged(SUMMER, {"neck": "the_nv"})]]],

	["Bác Sơn thợ rèn (04/11)", "full", [
		["Tạp dề da, khăn vắt cổ", _merged(SON, {"apron": "#6b4a32", "apron_b": "#2e2219", "apron_c": "#c9a77a", "apron_style": "ren", "neck": "khan_mat"})],
		["Tạp dề vải bạt", _merged(SON, {"apron": "#8a8068", "apron_b": "#3d3a32", "apron_c": "#d8cfb4", "apron_style": "ren", "apron_fabric": "bat", "neck": "khan_mat"})],
		["Áo xanh bạc, khăn sọc đỏ", _merged(SON, {"top": {"shape": "shirt", "design": "", "color": "#8fa3b8", "color_b": "#ffffff", "trim": "#8fa3b8", "pattern": "plain"},
			"apron": "#6b4a32", "apron_b": "#2e2219", "apron_c": "#c9a77a", "apron_style": "ren", "neck": "khan_mat", "neck_item": "#c8483e"})],
		["Không tạp dề (ra chợ)", _merged(SON, {"neck": "khan_mat"})],
		["Để so: tạp dề của bà", _merged(GRANNY, {"apron": "#b0574a", "apron_b": "#8e3f36", "top": _baba("#5a3f6b", "#efe6d6", "")})]]],

	["Ô đổi màu (04/11)", "full", [
		["Ô cũ (hồng kem, không ghi màu)", _merged(SUMMER, {"tool": "umbrella"})],
		["Ô vàng (hero ở sân ga)", _merged(SUMMER, {"tool": "umbrella", "umbrella": "#ffd23f"})],
		["Ô xanh trắng", _merged(SUMMER, {"tool": "umbrella", "umbrella": ["#5a8fd0", "#f4f2ec"]})],
		["Ô đen · Bố", _merged(DAD, {"tool": "umbrella", "umbrella": "#2f3036"})],
		["Ô kẻ đỏ kem · bà", _merged(GRANNY, {"tool": "umbrella", "umbrella": ["#d0503c", "#f4ead2"], "top": _baba("#5a3f6b", "#efe6d6", "")})]]],

	["Chất vải (06/11)", "full", [
		["Áo dài lụa đỏ", _merged(SUMMER, {"hair": "tripo_long", "top": {"shape": "aodai", "design": "", "color": "#c8323c", "color_b": "#ffffff", "trim": "#c8323c", "pattern": "plain"},
			"shoes": {"shape": "guoc", "design": "", "color": "#c9a46a", "color_b": "#ffffff", "trim": "#7a4630", "pattern": "plain"}})],
		["Cardigan len + mũ len", _merged(SUMMER, {"top": {"shape": "cardigan_open", "design": "", "color": "#e8c27a", "color_b": "#ffffff", "trim": "#ffffff", "pattern": "plain"},
			"bottom": {"shape": "pants", "design": "", "color": "#3b4256", "color_b": "#ffffff", "trim": "#3b4256", "pattern": "plain"}, "hat": _hat_c("beanie_cat", "#c8b6e2", "#ffffff")})],
		["Áo khoác bò + quần bò", _merged(SUMMER, {"top": {"shape": "jacket", "design": "", "color": "#4f78ad", "color_b": "#ffffff", "trim": "#f4f2ec", "pattern": "plain", "stitch": "#e0a050"},
			"bottom": {"shape": "pants", "design": "denim", "color": "#3f6699", "color_b": "#ffffff", "color_c": "#ffffff", "trim": "#e0a050", "pattern": "plain", "weave": "jean"},
			"shoes": {"shape": "bata", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#f7f5ef", "pattern": "plain"}})],
		["Blazer, cúc và giày da", _merged(SUMMER, {"hair": "bob2", "top": {"shape": "blazer", "design": "", "color": "#2f3a56", "color_b": "#ffffff", "trim": "#f7f8fb", "pattern": "plain"},
			"bottom": {"shape": "pants", "design": "", "color": "#2f3a56", "color_b": "#ffffff", "trim": "#2f3a56", "pattern": "plain"},
			"shoes": {"shape": "loafer", "design": "", "color": "#6a3a24", "color_b": "#ffffff", "trim": "#2a1a10", "pattern": "plain"}})],
		["Bác Sơn · tạp dề da", _merged(SON, {"apron": "#6b4a32", "apron_b": "#2e2219", "apron_c": "#c9a77a", "apron_style": "ren", "neck": "khan_mat"})],
		["Trưởng tàu · phù hiệu", _merged(GRANDPA, {"hair": "short", "hair_color": "#5a5a60", "eye_style": "classic", "age": 0,
			"top": CONDUCTOR_SHIRT, "bottom": {"shape": "pants", "design": "", "color": "#23262e", "color_b": "#23262e", "trim": "#23262e", "pattern": "plain"},
			"shoes": {"shape": "loafer", "design": "", "color": "#24252a", "color_b": "#24252a", "trim": "#24252a", "pattern": "plain"},
			"hat": CONDUCTOR_CAP, "neck": "coi", "neck_cord": "#c8383e"})],
		["Áo bà ba + quần lãnh", _merged(GRANNY, {"top": _baba("#5a3f6b", "#efe6d6", ""),
			"bottom": {"shape": "wide", "design": "lanh", "color": "#16171c", "color_b": "#4a4e5a", "color_c": "#ffffff", "trim": "#16171c", "pattern": "plain", "fabric": "lua", "weave": ""}})]]],

	["Đồ đỏ thể thao (07/11)", "full", [
		["Áo esports đỏ + jogger", _merged(SUMMER, {"top": ESPORTS_TOP, "bottom": {"shape": "jogger", "design": "", "color": "#1d1e24", "color_b": "#1d1e24", "trim": "#1d1e24", "pattern": "plain"},
			"shoes": {"shape": "sneakers", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#16171c", "pattern": "plain"}})],
		["Áo esports đỏ dài tay", _merged(SUMMER, {"top": _merged(ESPORTS_TOP, {"shape": "longsleeve"}), "bottom": {"shape": "jogger", "design": "", "color": "#1d1e24", "color_b": "#1d1e24", "trim": "#1d1e24", "pattern": "plain"},
			"shoes": {"shape": "sneakers", "design": "", "color": "#ffffff", "color_b": "#ffffff", "trim": "#16171c", "pattern": "plain"}})],
		["Áo bóng đá đỏ số 7", _merged(SUMMER, FOOTBALL_KIT)],
		["Áo bóng đá đỏ cổ polo", _merged(SUMMER, _merged(FOOTBALL_KIT, {"top": _merged(FOOTBALL_KIT["top"], {"shape": "polo"})}))]]],
]

const ACTIONS := [["Đứng", "Base_Wait"], ["Đi", "Move_Walk"], ["Chạy", "Move_Run"], ["Ngồi ghế", "Act_SitChair_Idle"],
	["Ngồi đất", "Act_SitFloor"], ["Vẫy tay", "emote:wave"], ["Vui", "emote:happy"]]

const CAMS := {"full": [Vector3(0, 1.1, 4.2), Vector3(0, 0.78, 0), 32.0], "head": [Vector3(0, 1.5, 3.0), Vector3(0, 1.1, 0), 32.0],
	"feet": [Vector3(0, 0.55, 1.9), Vector3(0, 0.12, 0), 32.0], "game": [Vector3(0, 0.7 + 4.65, 6.0), Vector3(0, 0.7, 0), 40.0],
	"crowd": [Vector3(0, 1.7, 13.0), Vector3(0, 0.7, 0), 32.0]}
const CAM_NAMES := [["Toàn thân", "full"], ["Cận đầu", "head"], ["Cận chân", "feet"], ["Camera game", "game"]]
const SEAT_SCALE := 1.28
const OUT := "res://review/"

var chibi: Chibi
var stool: Node3D
var cam: Camera3D
var item := 0
var variant := 0
var action := 0
var cam_key := "full"
var zoom := 1.0
var yaw := deg_to_rad(-20.0)
var shown_yaw := yaw
var auto_spin := false
var spin_rate := 0.6
var _glide := false
var _glide_t := 0.0
var dragging := false
var ui: Control
var variant_box: VBoxContainer
var item_label: Label
var note: TextEdit
var status: Label
var _cam_btns := {}
var _item_btns := []
var _action_btns := []
var _glasses: Node3D
var _scarf: Node3D
var _mask: Node3D

var _neck: Node3D
var _job := ""
var _seed := 1
var _recolor := {}
var _colour_slot := "top"
var _crowd_on := false
var _crowd: Array = []
var _job_opt: OptionButton
var _seed_label: Label
var _name_edit: LineEdit
const CROWD := 8
const CROWD_GAP := 1.05
const CROWD_SHIFT := 0.9
const SAVED := "res://data/wardrobe/saved_people.json"
const COLOUR_SLOTS := [["Áo", "top"], ["Quần", "bottom"], ["Giày", "shoes"], ["Mũ", "hat"], ["Tất", "socks"]]

static func _shoe(col: String, design: String) -> Dictionary:
	return {"shape": "slides", "color": col, "color_b": col, "trim": col, "pattern": "plain", "design": design}

static func _hat(shape: String) -> Dictionary:
	var h := HAT.duplicate()
	h["shape"] = shape
	return h

static func _hat_c(shape: String, col: String, trim: String) -> Dictionary:
	return {"shape": shape, "color": col, "color_b": trim, "trim": trim}

static func _shirt(design: String, col: String, trim: String) -> Dictionary:
	if design != "":
		var c: Array = Looks.DESIGNS[design][1]
		return {"shape": "shirt", "design": design, "color": c[0], "color_b": c[1], "trim": c[2], "pattern": "plain"}
	return {"shape": "shirt", "design": "", "color": col, "color_b": "#ffffff", "trim": trim, "pattern": "plain"}

static func _baba(col: String, buttons: String, design: String) -> Dictionary:
	"""Plain: the buttons take the trim colour (cream on dark cloth). Hoa nhí: the print's own colours."""
	if design != "":
		return {"shape": "baba", "design": design, "color": col, "color_b": buttons, "color_c": "#8fa88c", "trim": col, "pattern": "plain"}
	return {"shape": "baba", "design": "", "color": col, "color_b": buttons, "trim": buttons, "pattern": "plain"}

static func _balo(col: String) -> Dictionary:
	return {"shape": "balo", "design": "", "color": col, "color_b": "#ffffff", "trim": col, "pattern": "plain"}

static func _helmet(col: String) -> Dictionary:
	return {"shape": "helmet", "color": col, "color_b": "#2a2a2e", "trim": "#2a2a2e"}

static func _moicoi(col: String, trim: String) -> Dictionary:
	return {"shape": "moicoi", "color": col, "color_b": trim, "trim": trim}

static func _cap(col: String, bill: String) -> Dictionary:
	return {"shape": "cap", "color": col, "color_b": bill, "trim": bill}

static func _wide(col: String) -> Dictionary:
	return {"shape": "wide", "design": "", "color": col, "trim": col, "pattern": "plain"}

static func _merged(a: Dictionary, b: Dictionary) -> Dictionary:
	var l := a.duplicate(true)
	l.merge(b, true)
	return l

func _ready() -> void:
	Stage.setup(self)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/toon.gdshader")
	gm.set_shader_parameter("base_color", Color("cdeeb4"))
	gm.set_shader_parameter("rim", 0.0)
	ground.material_override = gm
	add_child(ground)
	stool = Furniture.place(self, "plastic_stool_blue", Vector3(0, 0, 0.0), 0.0, false)
	stool.visible = false
	stool.scale.y = SEAT_SCALE
	chibi = Chibi.new()
	add_child(chibi)
	chibi.build(_look())
	cam = Camera3D.new()
	add_child(cam)
	_build_ui()
	_pick_item(0)
	var a := Stage.arg("--item")
	if a != "":
		_pick_item(int(a))
		_pick_variant(int(Stage.arg("--variant", "0")))
		_pick_action(int(Stage.arg("--action", "0")))
		_glide = OS.get_cmdline_user_args().has("--glide")
		if Stage.arg("--spin") != "":
			auto_spin = true
			spin_rate = float(Stage.arg("--spin"))
		yaw = deg_to_rad(float(Stage.arg("--yaw", "-20")))
		shown_yaw = yaw
		if Stage.arg("--cam") != "":
			_pick_cam(Stage.arg("--cam"))
		zoom = float(Stage.arg("--zoom", "1"))
	var job := Stage.arg("--job")
	if job != "":
		_seed = int(Stage.arg("--seed", "1"))
		_colour_slot = Stage.arg("--slot", "top")
		_job_opt.select(Wardrobe.job_ids().find(job) + 1)
		_job = "" if job == "none" else job
		_crowd_on = OS.get_cmdline_user_args().has("--crowd")
		_pick_cam("crowd" if _crowd_on else "full")
		_show()
	ui.visible = not OS.get_cmdline_user_args().has("--no-ui")
	var still := Stage.arg("--still")
	if still != "":
		await get_tree().create_timer(float(Stage.arg("--at", "1.0"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still)
		get_tree().quit()

func _look() -> Dictionary:
	var l: Dictionary = _item_look() if _job == "" else Wardrobe.dress(_job, _seed)
	for slot in _recolor:
		if l.get(slot) is Dictionary and str(l[slot].get("shape", "none")) != "none":
			l[slot] = Wardrobe.garment(slot, str(l[slot]["shape"]), _recolor[slot])
	return l

func _item_look() -> Dictionary:
	var l: Dictionary = BASE.duplicate(true)
	if not ITEMS.is_empty():
		var v: Dictionary = ITEMS[item][2][variant][1]
		for k in v:
			if v[k] is Dictionary and l.get(k) is Dictionary:
				var d: Dictionary = l[k].duplicate(true)
				if k == "top" or k == "shoes":
					d.erase("design")
				d.merge(v[k], true)
				l[k] = d
			else:
				l[k] = v[k]
	return l

func _pick_item(i: int) -> void:
	item = clampi(i, 0, ITEMS.size() - 1)
	item_label.text = ITEMS[item][0]
	_press(_item_btns, item)
	for c in variant_box.get_children():
		c.queue_free()
	var g := ButtonGroup.new()
	for j in ITEMS[item][2].size():
		var b := _button(ITEMS[item][2][j][0], g)
		b.pressed.connect(_pick_variant.bind(j))
		variant_box.add_child(b)
	_pick_cam(ITEMS[item][1])
	_pick_variant(0)

func _pick_variant(j: int) -> void:
	variant = clampi(j, 0, ITEMS[item][2].size() - 1)
	var bs := variant_box.get_children().filter(func(n): return not n.is_queued_for_deletion())
	if variant < bs.size():
		(bs[variant] as Button).button_pressed = true
	_recolor.clear()
	if _job != "":
		_job = ""
		if _job_opt:
			_job_opt.select(0)
	_show()

func _show() -> void:
	var look := _look()
	chibi.apply_look(look)
	if is_instance_valid(_glasses):
		_glasses.queue_free()
	_glasses = Glasses.add(chibi, look)
	if is_instance_valid(_mask):
		_mask.queue_free()
	_mask = FaceMask.add(chibi, look)
	if is_instance_valid(_scarf):
		_scarf.queue_free()
	_scarf = Scarf.add(chibi, look)
	if is_instance_valid(_neck):
		_neck.queue_free()
	_neck = NeckWear.add(chibi, look)
	chibi.hold(str(look.get("tool", "")))
	_build_crowd()
	_pick_action(action)
	status.text = ""
	if _seed_label:
		_seed_label.text = "%s · số %d" % [Wardrobe.job_name(_job), _seed] if _job != "" else "(đồ của món đang chọn)"

func _pick_job(i: int) -> void:
	_job = "" if i == 0 else Wardrobe.job_ids()[i - 1]
	_recolor.clear()
	_show()

func _reroll() -> void:
	if _job == "":
		return
	_seed += CROWD if _crowd_on else 1
	_recolor.clear()
	_show()

func _cycle_colour(step: int) -> void:
	var g = _look().get(_colour_slot)
	if not g is Dictionary or str(g.get("shape", "none")) == "none":
		status.text = "Người này không có %s" % _colour_slot
		return
	var ps := Wardrobe.presets(_colour_slot, str(g["shape"]))
	if ps.is_empty():
		status.text = "%s chưa có bộ màu" % g["shape"]
		return
	var i: int = posmod(int(_recolor.get(_colour_slot, -1)) + step, ps.size())
	_recolor[_colour_slot] = i
	_show()
	status.text = "%s · %s (%d/%d)" % [g["shape"], ps[i].get("name", ""), i + 1, ps.size()]

func _toggle_crowd(on: bool) -> void:
	_crowd_on = on
	_pick_cam("crowd" if on else "full")
	_show()

func _build_crowd() -> void:
	"""8 people side by side: the job's next draws, or (no job) every colourway of the picked slot's garment."""
	for e in _crowd:
		for n in e[1]:
			n.queue_free()
		e[0].queue_free()
	_crowd.clear()
	chibi.visible = not _crowd_on
	if not _crowd_on:
		return
	var looks := []
	if _job != "":
		for k in CROWD:
			looks.append(Wardrobe.dress(_job, _seed + k))
	else:
		var base := _look()
		var g = base.get(_colour_slot)
		if g is Dictionary and str(g.get("shape", "none")) != "none":
			for k in mini(CROWD, Wardrobe.presets(_colour_slot, str(g["shape"])).size()):
				var l := base.duplicate(true)
				l[_colour_slot] = Wardrobe.garment(_colour_slot, str(g["shape"]), k)
				looks.append(l)
	for k in looks.size():
		var c := Chibi.new()
		add_child(c)
		c.build(looks[k])
		c.position.x = (k - (looks.size() - 1) * 0.5) * CROWD_GAP + CROWD_SHIFT
		_crowd.append([c, Wardrobe.add_wear(c, looks[k])])

func _save_person() -> void:
	"""The look on show, kept in data/wardrobe/saved_people.json under a name; a villager wears it with
	"look": {"saved": "<name>"} in data/village_life.json (or the draw itself: {"job": ..., "seed": ...})."""
	var who := _name_edit.text.strip_edges().to_lower().replace(" ", "_")
	if who == "":
		status.text = "Gõ tên trước đã (ví dụ ba_tu_ban_rau)"
		return
	var all := {}
	if FileAccess.file_exists(SAVED):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVED))
		if d is Dictionary:
			all = d
	var look := _look()
	all[who] = {"job": _job, "seed": _seed, "look": look} if _job != "" else {"look": look}
	var f := FileAccess.open(SAVED, FileAccess.WRITE)
	f.store_string(JSON.stringify(all, "\t"))
	f.close()
	status.text = "Đã lưu \"%s\". Trong village_life.json: \"look\": {\"saved\": \"%s\"}" % [who, who]

func _pick_action(k: int) -> void:
	action = k
	var clip: String = ACTIONS[k][1]
	var seated := clip == "Act_SitChair_Idle"
	stool.visible = seated
	chibi.position.y = chibi.seat_lift() if seated else 0.0
	_press(_action_btns, k)
	if clip.begins_with("emote:"):
		chibi.play("Base_Wait", 0.15)
		chibi.emote(clip.substr(6))
	else:
		chibi.play(clip, 0.15)
	for e in _crowd:
		e[0].play("Base_Wait" if clip.begins_with("emote:") or seated else clip, 0.15)

func _pick_cam(k: String) -> void:
	cam_key = k
	zoom = 1.0
	if _cam_btns.has(k):
		(_cam_btns[k] as Button).button_pressed = true

func _press(btns: Array, i: int) -> void:
	if i < btns.size():
		(btns[i] as Button).button_pressed = true

func _button(text: String, group: ButtonGroup = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if group:
		b.toggle_mode = true
		b.button_group = group
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.make()
	layer.add_child(ui)

	var left := PanelContainer.new()
	left.position = Vector2(20, 20)
	left.custom_minimum_size = Vector2(360, 0)
	ui.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	var t := Label.new()
	t.text = "Phòng thử đồ"
	t.add_theme_font_size_override("font_size", 32)
	lv.add_child(t)
	var gi := ButtonGroup.new()
	for i in ITEMS.size():
		var b := _button(ITEMS[i][0], gi)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_pressed = i == 0
		b.pressed.connect(_pick_item.bind(i))
		_item_btns.append(b)
		lv.add_child(b)
	lv.add_child(HSeparator.new())
	item_label = Label.new()
	item_label.add_theme_font_size_override("font_size", 20)
	lv.add_child(item_label)
	variant_box = VBoxContainer.new()
	variant_box.add_theme_constant_override("separation", 6)
	lv.add_child(variant_box)

	var bottom := PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 20
	bottom.offset_top = -20
	bottom.offset_bottom = -20
	ui.add_child(bottom)
	var bv := VBoxContainer.new()
	bottom.add_child(bv)
	var ar := HBoxContainer.new()
	bv.add_child(ar)
	var ga := ButtonGroup.new()
	for k in ACTIONS.size():
		var b := _button(ACTIONS[k][0], ga)
		b.button_pressed = k == 0
		b.pressed.connect(_pick_action.bind(k))
		_action_btns.append(b)
		ar.add_child(b)
	var cr := HBoxContainer.new()
	bv.add_child(cr)
	var gc := ButtonGroup.new()
	for c in CAM_NAMES:
		var b := _button(c[0], gc)
		b.pressed.connect(_pick_cam.bind(c[1]))
		_cam_btns[c[1]] = b
		cr.add_child(b)
	var spin := _button("Tự xoay")
	spin.toggle_mode = true
	spin.toggled.connect(func(on): auto_spin = on)
	cr.add_child(spin)
	var hint := Label.new()
	hint.text = "  kéo chuột: xoay · lăn chuột: phóng to"
	hint.add_theme_font_size_override("font_size", 18)
	cr.add_child(hint)

	var right := PanelContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -440
	right.offset_right = -20
	right.offset_top = -300
	right.offset_bottom = -20
	ui.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	var nl := Label.new()
	nl.text = "Nhận xét (kèm ảnh màn hình)"
	nl.add_theme_font_size_override("font_size", 20)
	rv.add_child(nl)
	note = TextEdit.new()
	note.placeholder_text = "Ví dụ: quai nón dày quá, dép hơi to..."
	note.custom_minimum_size = Vector2(0, 120)
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 12, Color("f3d9d0"), 2))
	note.add_theme_stylebox_override("focus", UiTheme.box(Color.WHITE, 12, UiTheme.PINK, 3))
	note.add_theme_color_override("font_color", UiTheme.INK)
	note.add_theme_color_override("font_placeholder_color", Color(UiTheme.INK, 0.45))
	note.add_theme_color_override("caret_color", UiTheme.INK)
	rv.add_child(note)
	var nr := HBoxContainer.new()
	rv.add_child(nr)
	for v in [["Duyệt ✓", "DUYỆT"], ["Chưa ổn ✗", "CHƯA ỔN"], ["Chỉ ghi chú", "GHI CHÚ"]]:
		var b := _button(v[0])
		b.pressed.connect(_save_note.bind(v[1]))
		nr.add_child(b)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	rv.add_child(status)

	var jobs := PanelContainer.new()
	jobs.anchor_left = 1.0
	jobs.anchor_right = 1.0
	jobs.offset_left = -560
	jobs.offset_right = -20
	jobs.offset_top = 20
	ui.add_child(jobs)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 6)
	jobs.add_child(jv)
	var jl := Label.new()
	jl.text = "Người làng theo nghề"
	jl.add_theme_font_size_override("font_size", 20)
	jv.add_child(jl)
	_job_opt = OptionButton.new()
	_job_opt.focus_mode = Control.FOCUS_NONE
	_job_opt.add_item("(tắt: đồ của món đang chọn)")
	for j in Wardrobe.job_ids():
		_job_opt.add_item(Wardrobe.job_name(j))
	_job_opt.item_selected.connect(_pick_job)
	jv.add_child(_job_opt)
	var jr := HBoxContainer.new()
	jv.add_child(jr)
	var again := _button("Bốc người khác")
	again.pressed.connect(_reroll)
	jr.add_child(again)
	var crowd := _button("Xem cả nhóm (8)")
	crowd.toggle_mode = true
	crowd.toggled.connect(_toggle_crowd)
	jr.add_child(crowd)
	_seed_label = Label.new()
	_seed_label.add_theme_font_size_override("font_size", 16)
	jv.add_child(_seed_label)
	var cr2 := HBoxContainer.new()
	jv.add_child(cr2)
	var gs := ButtonGroup.new()
	for s in COLOUR_SLOTS:
		var b := _button(s[0], gs)
		b.button_pressed = s[1] == _colour_slot
		b.pressed.connect(func():
			_colour_slot = s[1]
			if _crowd_on and _job == "":
				_show())
		cr2.add_child(b)
	var cr3 := HBoxContainer.new()
	jv.add_child(cr3)
	var prev := _button("‹ Bộ màu trước")
	prev.pressed.connect(_cycle_colour.bind(-1))
	cr3.add_child(prev)
	var next := _button("Bộ màu sau ›")
	next.pressed.connect(_cycle_colour.bind(1))
	cr3.add_child(next)
	var sr := HBoxContainer.new()
	jv.add_child(sr)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "tên, ví dụ ba_tu_ban_rau"
	_name_edit.custom_minimum_size = Vector2(230, 0)
	_name_edit.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 12, Color("f3d9d0"), 2))
	_name_edit.add_theme_stylebox_override("focus", UiTheme.box(Color.WHITE, 12, UiTheme.PINK, 3))
	_name_edit.add_theme_color_override("font_color", UiTheme.INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(UiTheme.INK, 0.45))
	_name_edit.add_theme_color_override("caret_color", UiTheme.INK)
	sr.add_child(_name_edit)
	var save := _button("Lưu thành người làng")
	save.pressed.connect(_save_person)
	sr.add_child(save)

func _save_note(verdict: String) -> void:
	"""Append the verdict, what was shown and a screenshot (without the panels) to review/nhan_xet.md."""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "anh"))
	if not FileAccess.file_exists(OUT + ".gdignore"):
		FileAccess.open(OUT + ".gdignore", FileAccess.WRITE).store_string("")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	ui.visible = false
	await RenderingServer.frame_post_draw
	var shot := "anh/%s.png" % stamp
	get_viewport().get_texture().get_image().save_png(OUT + shot)
	ui.visible = true
	var path := OUT + "nhan_xet.md"
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	f.seek_end()
	f.store_string("## %s · %s\n- %s · %s · %s · %s\n- ảnh: %s\n%s\n\n" % [stamp, verdict, ITEMS[item][0], ITEMS[item][2][variant][0],
		ACTIONS[action][0], cam_key, shot, note.text.strip_edges()])
	f.close()
	note.text = ""
	status.text = "Đã lưu: %s · %s" % [verdict, ITEMS[item][2][variant][0]]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom = maxf(0.35, zoom * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom = minf(2.5, zoom / 0.9)
	elif e is InputEventMouseMotion and dragging:
		yaw += e.relative.x * 0.012
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_LEFT:
			yaw -= PI / 4.0
		elif e.physical_keycode == KEY_RIGHT:
			yaw += PI / 4.0

func _process(delta: float) -> void:
	if auto_spin and not dragging:
		yaw += delta * spin_rate
	shown_yaw = lerp_angle(shown_yaw, yaw, 1.0 - exp(-delta * 10.0))
	chibi.rotation.y = shown_yaw
	stool.rotation.y = shown_yaw
	if _glide:
		_glide_t += delta
		chibi.position.x = sin(_glide_t * 2.0) * 0.6
	for e in _crowd:
		e[0].rotation.y = shown_yaw
	var c: Array = CAMS[cam_key]
	var target: Vector3 = c[1]
	var eye: Vector3 = target + (c[0] - target) * zoom
	var k := 1.0 - exp(-delta * 8.0)
	cam.position = cam.position.lerp(eye, k) if cam.position != Vector3.ZERO else eye
	cam.fov = c[2]
	cam.look_at(target, Vector3.UP)
	cam.h_offset = -0.12 * (eye - target).length() * tan(deg_to_rad(c[2]) * 0.5) * 2.0
