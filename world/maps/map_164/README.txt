Map: vuotai/thien_tam_thap_tang_1

1. Copy this whole folder into your Godot 4 project, e.g. res://maps/map_d5e5a9be/
2. Quick test scene:  MapDemo (Node2D, script MapDemo.gd)
                        |- Map    (Node2D, script VltkMap.gd)  -> Map Dir = this folder, Focus = Player
                        |- Player (Node2D, script Player.gd)
   Run it and left-click to walk. (VltkMap.gd declares class_name VltkMap: keep ONE copy in the project.)
3. Your own game: add characters as children of Map.objects_root so houses and trees sort around them.
   NPCs stand still, monsters patrol (role/wander/respawn are in map.json); Map.kill_npc(node) removes a monster until it respawns; demo: right-click.
   Monsters in code: get_tree().get_nodes_in_group("monster"), Map.get_monsters(), Map.nearest_monster(pos, radius), Map.monsters_near(pos, r),
   Map.npc_data(node) (template, level, series, respawn...), Map.all_spawns("monster") (whole map), signals npc_spawned / monster_killed / monster_respawned.
   Ground: map.json "ground_mode" = "tiles" (baked tiles/X_Y.webp) or "atlas" (atlas/atlas_N.png + per-region cell lists, much smaller).
   Online: upload this whole folder to any web server / CDN, set Map.base_url to its address (e.g. https://cdn.example.com/maps/map_d5e5a9be/).
   Files are downloaded when first needed, stored in user://vltk_cache (kept after the game is closed) and re-downloaded only when manifest.json changes.
   Quick local test: run  python -m http.server 8000  in the parent folder and use http://127.0.0.1:8000/map_d5e5a9be/
4. minimap.jpg = the whole map (64 px per region); minimap_npc.jpg = the same with a yellow dot on every NPC.
   Map.get_minimap_texture() loads it, Map.world_to_minimap(pos) gives the pixel of a world point, Map.minimap_npcs() lists the NPCs on it.
Obstacle cells are 32x16 px in absolute map pixels. value = (type<<4)|kind, type 0 = free.
