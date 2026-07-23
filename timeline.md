# Project Timeline - Soccer Squad Duels!

## July 20, 2026

    *   Constructed the preliminary soccer arena map containing 8 duplicate soccer fields (`Soccer Field 1` to `Soccer Field 8`).
    *   Each field model contains `StatusAnchor` and `CountdownAnchor` parts, and `Player 1 Spot` and `Player 2 Spot` models.
    *   Anchored and transparentized all `StatusAnchor` and `CountdownAnchor` parts across all 8 fields in Edit Mode.
    *   Disabled collision (`CanCollide = false`) on all anchor parts to ensure players do not collide with invisible blocks.
    *   Ran a recursive script in the Roblox Studio editor to ensure all physical parts inside the soccer field models (including soccer balls) are anchored.
    *   Created the main server script [QueueManager.server.lua] inside `ServerScriptService` to handle core matchmaking and locking.
    *   Implemented character lock-in mechanics: locks position, sets velocity to zero, stops current walking animations, makes the character face forward, disables walkspeed/jump, and anchors the player upright.
    *   Implemented character unlock mechanics: releases anchors, restores original character movement stats, and teleports them 10 studs away from the spot to prevent immediate re-triggering.
    *   Configured camera-facing `BillboardGui` elements dynamically created on `StatusAnchor` and `CountdownAnchor` parts.
    *   Structured labels to use the **Fredoka One** font, centered alignment, and a `UIStroke` outline of `2` thickness for sharp readability.
    *   Configured the billboard sizes to be 50% larger (`UDim2.new(12, 0, 4, 0)`) to make them easily readable from a distance.
    *   Coded starting countdown sequence `3` -> `2` -> `1` -> `0` (all white text) when both spots on a field are occupied.
    *   Added checks to halt and reset countdown if a player leaves the spot mid-count.
    *   Configured `HUD` to enable on join, `ExitQueue` to enable only when locked in a spot, and `DuelGui` to enable once the countdown completes.
    *   Created `ExitQueueEvent` remote inside `ReplicatedStorage`.
    *   Programmatically wrote and injected the client-side `ExitScript` inside `StarterGui.ExitQueue.ExitFrame.ExitButton` in Roblox Studio.

## July 22, 2026

    *   Designed and built automated C# player database generator (`Generator.cs`) with Unicode diacritics stripping, name normalization, and token alias matching.
    *   Enforced 100% official licensing verification by filtering all candidate players strictly against `fut22players.csv` (Icons/Heroes) and `EAFC26-Men.csv` (Active players).
    *   Extracted and integrated official player `Nationality` attributes across all card records.
    *   Implemented realistic Pyramid Rating Distribution & 5-Rarity Hierarchy across 1,000 cards:
        *   **Legend (50 Cards):** 94–99 OVR (Top G.O.A.T.s & Icons).
        *   **Stars (150 Cards):** 88–93 OVR (Elite world-class superstars).
        *   **Gold (350 Cards):** 80–87 OVR (Top club starters).
        *   **Silver (300 Cards):** 70–79 OVR (Rotation squad players).
        *   **Bronze (150 Cards):** 65–69 OVR (Base cards & young talents).
    *   Implemented proportional face stat scaling (Pace, Shooting, Passing, Dribbling, Defending, Physical) relative to target OVR while maintaining authentic player skill profiles (e.g. keeping Messi's dribbling high and defense low).
    *   Structured player data into dual databases inside `ReplicatedStorage/Data/`:
        *   [CardDatabaseAllTime.lua] — 1,000 all-time historical and modern legends ranked exclusively by `anothertop1000.txt`.
        *   [CardDatabaseCurrent.lua] — 1,000 active modern players ranked strictly by `EAFC26-Men.csv` ratings.
        *   [CardDatabase.lua] — Central wrapper module exporting typed access to both `AllTime` and `Current` databases.
