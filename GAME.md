# GAME.md: Melt the World's Biggest Ice Block

## Pitch
Players melt an enormous ice block with increasingly powerful heaters. Inside the ice are frozen treasures that you can only reach as the ice melts. Each finished block is followed by a bigger, colder one.

## Core loop
1. Stand next to the ice. Your equipped heater automatically heats the nearest **exposed** cubes in range (server tick 0.25 s).
2. Melted cubes pay coins (`coinPerCube × layer`), so deeper layers pay more.
3. Some inner cubes have **frozen treasures** visible inside them (fish, coin chest, mammoth tusk, caveman), which pay big bonuses.
4. Spend coins on the **Heating Power** upgrade (+15% heat per level) or the next heater.
5. Reach the centre: everyone in the server gets the block reward, and the next block spawns.

## Progression
| Heater | Price | Heat/s | Range | Cubes at once |
|---|---|---|---|---|
| Pocket Heater | 0 | 4 | 8 | 1 |
| Hair Dryer | 60 | 10 | 10 | 2 |
| Space Heater | 350 | 28 | 12 | 3 |
| Blowtorch | 1.8K | 80 | 14 | 4 |
| Industrial Furnace (industrial) | 9K | 240 | 18 | 6 |
| Plasma Cannon (industrial) | 50K | 800 | 24 | 9 |
| Miniature Sun (industrial) | 300K | 3000 | 32 | 14 |

Heaters unlock in order. Blocks: Freezer Cube (5³) → Glacier Chunk (7³) → Permafrost Slab (9³) → Polar Monolith (11³) → **World's Biggest Ice Block (13³)**. Cube HP = `baseHp × coldness^(layer-1)`, so the inner layers are much colder.

## Code map (Rojo, `default.project.json`)
- `src/shared/Config.luau`: all balance data (heaters, blocks, treasures, upgrade costs).
- `src/server/Main.server.luau`: arena build (stud style), ice block, heat loop, shop validation, DataStore save.
- `src/client/HUD.client.luau`: progress bar, coins, heater shop, popups, heater glow.
- `web/index.html`: browser prototype of the loop using the same numbers, served for the Alloy preview.

## Remotes (`ReplicatedStorage.Remotes`)
| Name | Direction | Payload |
|---|---|---|
| Buy | C→S | `("power")` or `("heater", id)` |
| Equip | C→S | `(id)` |
| State | S→C | `{coins, owned, equipped, power, melted}` |
| Block | S→All | `{index, name, remaining, total, count}` |
| Popup | S→C | `(text, Color3)` |

## Rules followed (see `docs/skills/`)
- The server is the authority. Currency math is done only on the server, and remotes are type-checked and rate-limited (0.2 s).
- DataStore calls are wrapped in `pcall`. Saves happen on leave, on `BindToClose`, and every 60 s.
- Arena uses stud style (`studify.md`): Plastic + MaterialVariants, with a SurfaceType fallback. Ice cubes use `Ice` material as the intentional exception.
- Client connections are disconnected when the character is removed.

## Trailer beats (for `roblox-trailer.md`)
Spawn → pocket heater barely dents the ice → buy hair dryer → treasure popup → industrial furnace roars → progress bar to 100% → centre reached → giant 13³ block spawns.
