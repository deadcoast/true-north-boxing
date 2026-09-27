#!/usr/bin/env python3
"""build_hissatsu_library.py - generates data/hissatsu_library.v2.json (87 moves)\nv2 = v1 (80) + 7 worlds desperations per NP_04B (PAC-047 amendment, additive only).
against the NP_11 s9 Hissatsu schema. Regenerable: content edits happen HERE,
the JSON is build output. Run from repo root. Audit with tools/hissatsu_audit.py.
"""
import json, os

# tier -> (tension_cost, cinematic_ms bounds) per NP_05 s3/s5
TIER = {"T0": (10, (800, 1200)), "T1": (35, (1200, 1800)),
        "T2": (25, (1000, 1500)), "T3": (50, (1800, 2500))}

def mv(name, tier, family, element, house, source, cine, effects, cp, notes="", **kw):
    e = {"id": "HIS-" + format(mv.n, "03d"), "name": name, "tier": tier, "family": family,
         "element": element, "house_id": house, "style_req": kw.get("style_req"),
         "tension_cost": kw.get("cost", TIER[tier][0]), "private_meter_cost": kw.get("pmc"),
         "startup_cinematic_ms": cine, "effect": effects, "counter_profile": cp,
         "duo_variant": kw.get("duo"), "hybrid_parents": kw.get("hyb"),
         "camera_script_id": "cam_" + family.lower() + "_" + tier.lower(),
         "vfx_set": "vfx_" + (element.lower() if element else "neutral"),
         "source": source, "secret": kw.get("secret", False), "notes": notes}
    mv.n += 1
    return e
mv.n = 1

def dmg(x, byp=0): return {"type": "DMG", "params": {"mult": x, "composure_bypass_pct": byp}}
def shred(x):      return {"type": "SHRED", "params": {"guard": x}}
def burn(x):       return {"type": "BURN", "params": {"stamina": x}}
def disp(z, m=1.0):return {"type": "DISPLACE", "params": {"toward": z, "meters": m}}
def state(n, s):   return {"type": "STATE", "params": {"name": n, "seconds": s}}
def buff(n, s):    return {"type": "BUFF", "params": {"name": n, "seconds": s}}
def wall(pts, s):  return {"type": "WALL", "params": {"points": pts, "seconds": s}}

CP_STD  = {"interruptible": True,  "window_ms": 700, "negation": "perfect WALL negates; perfect slip 40% chip; block 60% + heavy shred"}
CP_FAST = {"interruptible": True,  "window_ms": 500, "negation": "perfect slip full evade; block 70%"}
CP_ARM  = {"interruptible": False, "window_ms": 0,   "negation": "dodge-only; perfect-defense weathering applies"}
CP_WALL = {"interruptible": False, "window_ms": 0,   "negation": "wait out, or any T1+ breaks at cost parity"}
CP_RELAY= {"interruptible": True,  "window_ms": 700, "negation": "interruptible only during afterimage windup (Loud)"}

L = []
A = L.append

# ================= EXISTING CANON (NP_05 s10 + NP_04A) - retained, no removals =================
A(mv("Aurora Borealis Breaker","T1","HAYMAKER","FROST",None,"protagonist_line",1800,
     [dmg(2.5), disp("ROPES",1.0), state("arena_freeze_vfx",3)], CP_STD, "Rory's line signature; Ep1 flashback shows the 1976 original"))
A(mv("First Snap","T0","PISTON","FROST",None,"generic",900,[dmg(1.3), state("foot_freeze_slow",1.5)], CP_FAST))
A(mv("Chinook Rush","T1","ARC","GALE",None,"generic",1400,[dmg(1.8), buff("forward_glide",2)], CP_STD))
A(mv("Grain Elevator","T1","RISE","GRANITE","kowalchuk","native",1500,[dmg(2.0), shred(40)], CP_STD, "Yuri's desperation"))
A(mv("Premiere Neige","T2","WALL","FROST","tremblay","native",1200,[wall(0,5), state("auto_slip",5)], CP_WALL, "Marta's desperation"))
A(mv("Sorry Eh","T1","ARC","FROST","tagaq","personal:sam",1300,[state("counter_stance",2.5), dmg(2.0)], CP_STD, "Sam's apologized counter"))
A(mv("Net-Hauler's Yank","T1","HAYMAKER","TIMBER","macisaac","native",1600,[dmg(1.9), disp("ROPES",1.0)], CP_STD))
A(mv("Liver Line","T1","ARC","GRANITE","reyes","native",1400,[dmg(1.6), burn(25)], CP_STD, "Body finisher; LT-flagged"))
A(mv("Pressure Cooker","T0","PISTON","GALE","okafor","native",1000,[dmg(1.4), {"type":"BUFF","params":{"name":"bonus_tension_on_counter","value":2}}], CP_FAST))
A(mv("Long Winter","T2","WALL","FROST","whitecloud","native",1300,[wall(0,4), buff("stamina_regen_x2",4)], CP_WALL))
A(mv("Timberfall","T1","RISE","TIMBER",None,"taught:coach_questline",1500,[dmg(2.1), state("beats_duck_reads",0)], CP_STD, "Delayed-timing uppercut"))
A(mv("Black Ice","T0","PISTON","FROST",None,"taught",900,[dmg(1.1), state("tell_jam_audio",3)], CP_FAST, "Rare by design; tell-jam is vicious"))
A(mv("Thunder Bay","T1","HAYMAKER","GALE",None,"shop:hbp_t3",1700,[dmg(2.2), buff("range_plus",0)], CP_STD))
A(mv("Shield Wall","T2","WALL","GRANITE",None,"board:anchor",1200,[wall(20,0)], CP_WALL, "20-pt mini Wall Gauge, one reform"))
A(mv("Two Rivers","T3","ARC","DUAL",None,"hybrid:forge",2200,[dmg(2.4), state("afterimage_partner",3)], CP_RELAY,
     "Hybrid exemplar", hyb=["nguyen-roy","delacroix-cardinal"]))
A(mv("Relay: North Star","T3","RISE","ANY",None,"full_relay_exclusive",2400,
     [{"type":"DMG","params":{"mult_per_chain_link":0.8,"base":1.6}}], CP_RELAY, "FULL RELAY only; dmg scales with chain"))
# NP_04A desperations not already above
A(mv("Undertow","T1","HAYMAKER","TIMBER","macisaac","native",1600,[dmg(2.0), disp("ROPES",1.5)], CP_STD, "Moira's pull-counter desperation"))
A(mv("Pont Couvert","T1","ARC","GALE","nguyen-roy","native",1400,[dmg(1.8), state("angle_exit",1)], CP_STD, "Tam's desperation"))
A(mv("Empty Net","T1","PISTON","GALE",None,"personal:carter",1300,[dmg(1.7), burn(15)], CP_FAST, "Carter's third-period rush"))
A(mv("Fevrier","T1","HAYMAKER","FROST","moreau","native",1700,[dmg(2.3), state("arena_frost_creep",3)], CP_STD, "Jean-Guy's desperation"))
A(mv("Deep Roots","T1","ARC","TIMBER","osei","native",1500,[dmg(2.2), shred(30), state("counter_stance",2)], CP_STD,
     "Osei SECRET; shares the house trait's name deliberately. Efua casts it UNSANCTIONED at 70% with a stumble", secret=True))
A(mv("Thesis Defense","T2","WALL","FROST",None,"personal:anders",1400,[wall(0,5), state("counter_state",5)], CP_WALL, "Anders' desperation; breakable per NP_05 s9"))

# ================= HOUSE NATIVES - completing every house's 2-4 (one SECRET each) =================
# Tremblay (has Premiere Neige)
A(mv("Miroir d'Hiver","T1","ARC","FROST","tremblay","native",1400,[state("mirror_counter",2), dmg(2.0)], CP_STD, "The doctrine's teaching counter"))
A(mv("Verglas","T1","PISTON","FROST","tremblay","native",1600,[dmg(1.8), state("foot_freeze_slow",2.5), state("tell_jam_visual",2)], CP_STD,
     "SECRET: the 1998 dual's unanswered question, taught only past the feud quest", secret=True))
# Kowalchuk (has Grain Elevator)
A(mv("Full Load","T1","HAYMAKER","GRANITE","kowalchuk","native",1700,[dmg(2.4), shred(25)], CP_STD))
A(mv("Harvest Moon","T1","RISE","GRANITE","kowalchuk","native",1800,[dmg(2.6), shred(50), disp("CORNER",0.5)], CP_ARM,
     "SECRET: armored rising finisher; the patriarch's barn-lesson scene", secret=True))
# Okafor (has Pressure Cooker)
A(mv("Heat Advisory","T1","ARC","GALE","okafor","native",1400,[dmg(1.7), burn(20)], CP_STD, "Pressure line body flurry"))
A(mv("Eye of the Storm","T2","WALL","GALE","okafor","native",1300,[wall(0,4), buff("counter_window_plus_100ms",4)], CP_WALL,
     "SECRET: stillness inside the swarm", secret=True))
# Reyes (has Liver Line)
A(mv("Body Bank","T0","PISTON","GRANITE","reyes","native",1000,[dmg(1.2), burn(8)], CP_FAST, "Deposits now, withdrawals later"))
A(mv("La Campana","T1","ARC","GRANITE","reyes","native",1600,[dmg(2.0), burn(35), state("wobble_on_gassed_target",0)], CP_STD,
     "SECRET: the bell only rings for a drained body - lethal vs <40 stamina", secret=True))
# MacIsaac (has Yank + Undertow)
A(mv("Rogue Wave","T1","HAYMAKER","TIMBER","macisaac","native",1800,[dmg(2.5), disp("CORNER",1.0)], CP_ARM,
     "SECRET: the wave nobody reads twice; armored", secret=True))
# Whitecloud (has Long Winter)
A(mv("First Light","T0","PISTON","FROST","whitecloud","native",1000,[dmg(1.3), buff("stamina_regen_x1_5",3)], CP_FAST))
A(mv("Polaris","T2","WALL","FROST","whitecloud","native",1500,[wall(15,0), buff("all_stats_r4r5_plus5",0)], CP_WALL,
     "SECRET: seven generations of holding the north; strongest in late slots", secret=True))
# Tagaq
A(mv("Still Water","T1","ARC","FROST","tagaq","native",1300,[state("counter_stance",3), dmg(1.8)], CP_STD, "The patience line's foundation"))
A(mv("Northern Silence","T2","WALL","FROST","tagaq","native",1500,[wall(0,6), state("enemy_tension_earn_minus25pct",6)], CP_WALL,
     "SECRET: the quiet that starves a crowd", secret=True))
# Nguyen-Roy (has Pont Couvert)
A(mv("Deux Ponts","T0","PISTON","GALE","nguyen-roy","native",1000,[dmg(1.2), state("angle_exit",0.8)], CP_FAST))
A(mv("Third Bridge","T1","ARC","GALE","nguyen-roy","native",1600,[dmg(2.1), state("afterimage_self",2)], CP_STD,
     "SECRET: the bridge that isn't on any map; dual-house footwork fused", secret=True))
# Petrov - the teaching house; natives flagged giftable-first
A(mv("System Jab","T0","PISTON","GRANITE","petrov","native",900,[dmg(1.3), shred(10)], CP_FAST, "The amateur system's first page; Petrov gifts it freely"))
A(mv("Amateur Classic","T1","ARC","GRANITE","petrov","native",1300,[dmg(1.8), buff("ep_plus_on_clean",3)], CP_STD))
A(mv("Perfect Score","T1","RISE","GRANITE","petrov","native",1700,[dmg(2.2), {"type":"BUFF","params":{"name":"tension_plus_on_hit","value":5}}], CP_STD,
     "SECRET: the 10-9 round distilled; Anders never learned it - Vey took him first", secret=True))
# Osei (has Deep Roots SECRET)
A(mv("Shell Game","T1","ARC","TIMBER","osei","native",1300,[state("shell_counter",2.5), dmg(1.7)], CP_STD))
A(mv("Through the Window","T1","PISTON","TIMBER","osei","native",1400,[dmg(1.9), disp("ROPES",0.5)], CP_STD, "The surge Efua built her theft on"))
# Delacroix-Cardinal
A(mv("River Read","T1","ARC","GALE","delacroix-cardinal","native",1400,[state("counter_stance",2), dmg(1.9)], CP_STD))
A(mv("Red River Turn","T0","PISTON","GALE","delacroix-cardinal","native",1000,[dmg(1.3), state("angle_exit",0.8)], CP_FAST))
A(mv("The Forks","T1","RISE","GALE","delacroix-cardinal","native",1700,[dmg(2.3), state("two_hit_echo",2)], CP_STD,
     "SECRET: where two currents meet, written with the house's consultants per NP_07 s9", secret=True))
# Iron - dead lineage: SECRET only, archive-findable
A(mv("Iron Doctrine","T1","HAYMAKER","GRANITE","iron","native:archive_find",1800,[dmg(2.6), shred(60)], CP_ARM,
     "SECRET and sole survivor of the lineage; findable only through Scout Book archaeology (NP_07 s5)", secret=True))
# Moreau (has Fevrier)
A(mv("Tempered Edge","T1","ARC","FROST","moreau","native",1400,[dmg(2.0), shred(30)], CP_STD))
A(mv("Le Gel Noir","T1","HAYMAKER","FROST","moreau","native",1800,[dmg(2.4), state("tell_jam_audio",2), burn(20)], CP_ARM,
     "SECRET: black frost; the technique the Commissioner comes to Quebec for", secret=True))
# [SEALED] - protagonist's house: reserved rows, payload redacted until Arc 2
A(mv("[SEALED-NATIVE-1]","T1","RISE","FROST","sealed","native:arc2_unseal",1500,[{"type":"REDACTED","params":{}}], CP_STD,
     "Reserved id; unsealing ADDs per NP_07 s7 no-invalidation rule"))
A(mv("[SEALED-NATIVE-2]","T1","ARC","FROST","sealed","native:arc2_unseal",1500,[{"type":"REDACTED","params":{}}], CP_STD, "Reserved id"))
A(mv("[SEALED-SECRET]","T2","WALL","FROST","sealed","native:arc3",1500,[{"type":"REDACTED","params":{}}], CP_WALL,
     "Reserved id; the Awakening gate (NP_09 s6)", secret=True))

# ================= PERSONAL SIGNATURES (named cast T0s and specials) =================
A(mv("Marginalia","T0","PISTON","GALE",None,"personal:priya",900,[dmg(1.2), {"type":"BUFF","params":{"name":"scout_book_note_on_hit","value":1}}], CP_FAST,
     "Priya's counter-jab; landing it annotates the opponent's Scout Book page - tactician-in-ring made mechanical"))
A(mv("Prodigal","T1","HAYMAKER","TIMBER",None,"personal:dex",1600,[dmg(2.2), disp("ROPES",0.8)], CP_STD,
     "Dex's refusal of the Net-Hauler line, which is itself a pull-counter - the house style leaking through denial"))
A(mv("Freelance","T1","ARC","GALE",None,"personal:vane_arc3",1400,[dmg(1.9), state("counter_stance",1.5)], CP_STD,
     "Cassidy's first move issued by nobody; Arc 3 remix content"))

# ================= TAUGHT / SHOP / BOARD GENERICS (build economy breadth) =================
A(mv("Cornerstone","T0","PISTON","GRANITE",None,"shop:hbp_t1",900,[dmg(1.3), shred(12)], CP_FAST))
A(mv("Gust Step","T0","PISTON","GALE",None,"shop:hbp_t1",900,[dmg(1.2), state("angle_exit",0.6)], CP_FAST))
A(mv("Sapling","T0","PISTON","TIMBER",None,"shop:hbp_t1",900,[dmg(1.2), buff("guard_regen_plus",2)], CP_FAST))
A(mv("Snowblind","T1","PISTON","FROST",None,"shop:hbp_t2",1300,[dmg(1.6), state("tell_jam_visual",1.5)], CP_FAST))
A(mv("Landslide","T1","HAYMAKER","GRANITE",None,"shop:hbp_t2",1700,[dmg(2.3), disp("ROPES",0.7)], CP_STD))
A(mv("Root Bind","T1","ARC","TIMBER",None,"shop:hbp_t2",1400,[dmg(1.7), state("foot_slow",2), burn(10)], CP_STD, "LT body hook line"))
A(mv("White Squall","T1","ARC","FROST",None,"shop:hbp_t3",1500,[dmg(1.9), {"type":"DMG","params":{"mult":0.5,"hits":2}}], CP_STD, "Three-hit flurry"))
A(mv("Updraft","T1","RISE","GALE",None,"shop:hbp_t2",1500,[dmg(2.0), state("beats_duck_reads",0)], CP_STD))
A(mv("Palisade","T2","WALL","TIMBER",None,"board:anchor",1200,[wall(0,4), buff("guard_regen_x2",4)], CP_WALL))
A(mv("Windbreak","T2","WALL","GALE",None,"board:anchor",1200,[wall(0,3), buff("move_speed_plus15",3)], CP_WALL))
A(mv("Eight Count Answer","T1","RISE","GRANITE",None,"taught:whitlock",1600,[dmg(2.2), {"type":"BUFF","params":{"name":"tension_plus_if_post_count","value":8}}], CP_STD,
     "Whitlock teaches it only after your first survived standing-eight; the legacy Inheritance thread starts here"))
A(mv("Roadwork","T0","PISTON","TIMBER",None,"taught:conditioning_staff",900,[dmg(1.1), buff("stamina_regen_x1_5",2)], CP_FAST))
A(mv("Overtime","T1","HAYMAKER","GRANITE",None,"shop:hbp_t3",1700,[dmg(2.0), {"type":"DMG","params":{"mult_bonus_final_30s":0.5}}], CP_STD, "Clock-scaled power"))
A(mv("Portage","T1","ARC","TIMBER",None,"quest:harbour",1400,[dmg(1.8), disp("CENTER",1.0)], CP_STD, "Carries the fight back to open water - anti-corner tool"))
A(mv("Breakup","T1","RISE","FROST",None,"quest:rink_district",1500,[dmg(2.1), shred(35)], CP_STD, "Spring ice gives way; the bridge-the-town quest reward"))

# ================= T3 RELAY / DUO / HYBRID EXEMPLARS =================
# PAC-080: the relay T3s carry their Duo variant (NP_08 s5.2 Lv4 "named duo T3 unlocked (afterimage variant)"; NP_05 s7 "bonded pairs get
# named duo variants with unique VFX"): a Duo pair's named T3 is its base under the pair's name, VFX and camera, the partner's afterimage
# joining it, hitting as the base. A pair takes the base that names it; else the relay T3 of the element both partners carry; else the
# ANY-element one. North Star stays the chain's move (FULL RELAY), no pair's. The named pairs are placeholders for the content lane.
def duo(vfx, cam, add, pairs):
    return {"afterimage": "partner", "name_rule": "{base} - {a} & {b}", "vfx_set": vfx, "camera_script_id": cam,
            "effect_add": add, "pairs": pairs, "source": "NP_08 s5.2 Lv4; NP_05 s7",
            "notes": "hits as its base; the pair's name, VFX, camera and the partner's afterimage are the variant (placeholder names)"}
A(mv("Relay: Coast to Coast","T3","HAYMAKER","ANY",None,"relay:charged",2200,[dmg(2.6), disp("ROPES",1.2)], CP_RELAY, "CHARGED-state relay finisher",
     duo=duo("vfx_duo_any", "cam_haymaker_t3_duo", [state("afterimage_partner",3)],
             {"PRIYA|RORY": "Whiteout", "MARCUS|PRIYA": "Chinook Arch", "MARCUS|RORY": "Permafrost", "JUNE|MARCUS": "Frost Heave", "JUNE|PRIYA": "Snow Squall"})))
A(mv("Relay: Aurora Chain","T3","ARC","FROST",None,"relay:charged",2300,[dmg(2.2), state("arena_freeze_vfx",2), state("afterimage_partner",3)], CP_RELAY,
     duo=duo("vfx_duo_frost", "cam_arc_t3_duo", [], {"JUNE|RORY": "Freeze-Up"})))
A(mv("Double Overtime","T3","RISE","ANY",None,"duo:2v2_festival",2400,[dmg(2.8)], CP_RELAY,
     "True simultaneous duo (both inputs within 500ms); festival exclusive", duo="sync_500ms"))
A(mv("Two-Hand Winter","T3","WALL","FROST",None,"duo:2v2_festival",2000,[wall(30,0)], CP_WALL, "Duo wall; the only shared gauge in the game", duo="sync_500ms"))
A(mv("Grain & Snow","T3","HAYMAKER","DUAL",None,"hybrid:forge",2300,[dmg(2.5), shred(40), state("auto_slip",2)], CP_RELAY,
     "Hybrid exemplar: Kowalchuk load inside Tremblay counter-timing", hyb=["kowalchuk","tremblay"]))

# ================= ARC 2 SYNDICATE SET (Hollow Circuit extracted techniques) =================
A(mv("Hollow Echo","T1","ARC","FROST",None,"syndicate:extracted",1400,[dmg(1.9), state("copies_last_player_hissatsu_vfx",0)], CP_STD,
     "Extracted technique; casts with a hollow audio signature - the love is missing and the mix says so"))
A(mv("Extracted: Elevator","T1","RISE","GRANITE",None,"syndicate:extracted",1500,[dmg(1.8), shred(36)], CP_STD,
     "Grain Elevator at 90% and cost +5, permanently ineligible for home bonus - counterfeit lineage priced in the math"))
A(mv("Migrant Wall","T2","WALL","GRANITE",None,"syndicate:boss",1500,[wall(60,0), state("gauge_migrates_to_teammate_on_break",0)], CP_WALL,
     "The Arc 2 anchor mechanic as a technique; boss-only"))
A(mv("Erased Name","T1","PISTON","FROST",None,"syndicate:extracted",1300,[dmg(1.7), state("suppress_commentary_ids",4)], CP_FAST,
     "Commentary loses the caster's name for 4s; the erasure thesis, audible"))
A(mv("Borrowed Blood","T3","ARC","DUAL",None,"syndicate:boss",2200,[dmg(2.3), state("steals_charged_state",0)], CP_RELAY,
     "Steals the player's CHARGED relay on hit; boss-only, the relay economy inverted"))
A(mv("The Commissioner's Due","T2","WALL","FROST",None,"syndicate:finale",1500,[wall(45,0), state("enemy_hissatsu_cost_plus10",5)], CP_WALL,
     "Arc 2 finale boss-only; taxes the elevated arts themselves"))

# ================= LIBRARY v2 AMENDMENT (PAC-047): worlds desperations from NP_04B =================
A(mv("Rush Hour","T1","PISTON","GALE",None,"worlds:boss_vaughn",1400,
     [{"type":"DMG","params":{"mult":0.5,"hits":5}}, state("guard_regen_minus1",3)], CP_FAST,
     "Vaughn's 5-hit volume string; each hit slows guard recovery"))
A(mv("La Catedral","T1","ARC","GRANITE",None,"worlds:boss_itzel",1600,
     [{"type":"DMG","params":{"mult":0.7,"hits":3,"target":"body"}}, burn(24)], CP_STD,
     "Three-station body series; the gassed-curve fight"))
A(mv("Fudoshin","T2","WALL","FROST",None,"worlds:boss_kannagi",1400,
     [wall(0,4), state("counter_on_break_attempt",4)], CP_WALL,
     "Immovable-mind wall; punishes the impatient break"))
A(mv("Last Orders","T1","HAYMAKER","TIMBER",None,"worlds:boss_crane",1800,
     [{"type":"DMG","params":{"mult":2.6,"zone_req":"ROPES"}}], CP_STD,
     "Rope-zone only; whiffs harmlessly in open ring - zone denial IS the counter"))
A(mv("Graduacion","T1","RISE","GALE",None,"worlds:boss_baro",1700,
     [dmg(2.4), shred(30)], CP_STD,
     "Castable only after his Examen lands - the player controls whether this move exists"))
A(mv("Harmattan","T1","ARC","GALE",None,"worlds:boss_chiamaka",1500,
     [{"type":"DMG","params":{"mult":0.6,"hits":4}}, state("tell_jam_visual",2)], CP_STD,
     "Dust-wind flurry; visual tell-jam"))
A(mv("The Mean","T2","WALL","ANY",None,"worlds:boss_vasile",1500,
     [wall(0,5), state("averages_incoming_damage_over_duration",5)], CP_WALL,
     "Element-null; burst play feeds it, steady play starves it"))

assert len(L) == 87, f"library holds {len(L)}, v2 law says 87 (80 + PAC-047 amendment)"
os.makedirs("data", exist_ok=True)
with open("data/hissatsu_library.v2.json", "w") as f:
    json.dump({"schema": "Hissatsu/NP_11-s9/v1.0", "library": "v2", "count": len(L), "moves": L}, f, indent=1)
print(f"data/hissatsu_library.v2.json written :: {len(L)} moves")
