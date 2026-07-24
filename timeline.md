# Project Timeline - Soccer Squad Duels!

## July 20, 2026

    *   Constructed the preliminary soccer arena map containing 8 duplicate soccer fields (`Soccer Field 1` to `Soccer Field 8`)[cite: 6].
    *   Each field model contains `StatusAnchor` and `CountdownAnchor` parts, and `Player 1 Spot` and `Player 2 Spot` models[cite: 6].
    *   Anchored and transparentized all `StatusAnchor` and `CountdownAnchor` parts across all 8 fields in Edit Mode[cite: 6].
    *   Disabled collision (`CanCollide = false`) on all anchor parts to ensure players do not collide with invisible blocks[cite: 6].
    *   Ran a recursive script in the Roblox Studio editor to ensure all physical parts inside the soccer field models (including soccer balls) are anchored[cite: 6].
    *   Created the main server script [QueueManager.server.lua] inside `ServerScriptService` to handle core matchmaking and locking[cite: 6].
    *   Implemented character lock-in mechanics: locks position, sets velocity to zero, stops current walking animations, makes the character face forward, disables walkspeed/jump, and anchors the player upright[cite: 6].
    *   Implemented character unlock mechanics: releases anchors, restores original character movement stats, and teleports them 10 studs away from the spot to prevent immediate re-triggering[cite: 6].
    *   Configured camera-facing `BillboardGui` elements dynamically created on `StatusAnchor` and `CountdownAnchor` parts[cite: 6].
    *   Structured labels to use the **Fredoka One** font, centered alignment, and a `UIStroke` outline of `2` thickness for sharp readability[cite: 6].
    *   Configured the billboard sizes to be 50% larger (`UDim2.new(12, 0, 4, 0)`) to make them easily readable from a distance[cite: 6].
    *   Coded starting countdown sequence `3` -> `2` -> `1` -> `0` (all white text) when both spots on a field are occupied[cite: 6].
    *   Added checks to halt and reset countdown if a player leaves the spot mid-count[cite: 6].
    *   Configured `HUD` to enable on join, `ExitQueue` to enable only when locked in a spot, and `DuelGui` to enable once the countdown completes[cite: 6].
    *   Created `ExitQueueEvent` remote inside `ReplicatedStorage`[cite: 6].
    *   Programmatically wrote and injected the client-side `ExitScript` inside `StarterGui.ExitQueue.ExitFrame.ExitButton` in Roblox Studio[cite: 6].

## July 22, 2026

    *   Designed and built automated C# player database generator (`Generator.cs`) with Unicode diacritics stripping, name normalization, and token alias matching[cite: 6].
    *   Enforced 100% official licensing verification by filtering all candidate players strictly against `fut22players.csv` (Icons/Heroes) and `EAFC26-Men.csv` (Active players)[cite: 6].
    *   Extracted and integrated official player `Nationality` attributes across all card records[cite: 6].
    *   Aggregated and assigned `AlternativePositions` across all 107,450 historical and modern player records from `EAFC26-Men.csv`, `ea-fc25-men.csv`, `fifa-15-to-fc24-men-players.csv`, and `fut22players.csv` (e.g. Messi: Primary `RW`, Alternative: `{"CAM", "RM", "ST"}`; Mbappé: Primary `ST`, Alternative: `{"LM", "LW"}`)[cite: 6].
    *   Implemented realistic Pyramid Rating Distribution & 5-Rarity Hierarchy across 1,000 cards[cite: 6]:
        *   **Legend (50 Cards):** 94–99 OVR (Top G.O.A.T.s & Icons)[cite: 6].
        *   **Stars (150 Cards):** 88–93 OVR (Elite world-class superstars)[cite: 6].
        *   **Gold (350 Cards):** 80–87 OVR (Top club starters)[cite: 6].
        *   **Silver (300 Cards):** 70–79 OVR (Rotation squad players)[cite: 6].
        *   **Bronze (150 Cards):** 65–69 OVR (Base cards & young talents)[cite: 6].
    *   Implemented proportional face stat scaling (Pace, Shooting, Passing, Dribbling, Defending, Physical) relative to target OVR while maintaining authentic player skill profiles[cite: 6].
    *   Structured player data into dual databases inside `ReplicatedStorage/Data/`[cite: 6]:
        *   [CardDatabaseAllTime.lua] — 1,000 all-time historical and modern legends[cite: 6].
        *   [CardDatabaseCurrent.lua] — 1,000 active modern players[cite: 6].
        *   [CardDatabase.lua] — Central wrapper module exporting typed access to both databases[cite: 6].

## July 23, 2026

    *   **Guaranteed DuelGui Screen Display:**
        *   Configured server-side direct GUI enablement (`pGui.DuelGui.Enabled = true`) and dual client initialization listeners (`StartDuelEvent` + `GetPropertyChangedSignal("Enabled")`)[cite: 6].
        *   Pre-populated all 11 formation slots across `YourTeamView` and `OpponentTeamView` with `EmptySlotView` frames and `?` OVR default text[cite: 6].
    *   **11 Unique Formation Slot Key Mapping (`CB1` vs `CB2` Key Collision Fix):**
        *   Resolved the server-side dictionary key overwriting bug by generating unique slot keys (`CB1`, `CB2`) on client initialization and sending unique keys via `RollCardsEvent` and `CardSelectedEvent`[cite: 6].
        *   Ensured server tracks 11 distinct slot draft picks per player before resolving match completion[cite: 6].
        *   Locked squad formation position labels (`RW`, `ST`, `LW`, etc.) on `SelectedSlotView` when player cards are picked, overriding natural database positions (e.g. keeping `RW` indicator even if a natural `RM` like Bowen is placed there)[cite: 6].
    *   **Optimized Two-Phase Kinematic Reel Spinning & Zero-Flicker Cutoff:**
        *   Engineered instant multi-reel spin initialization eliminating static initial pauses or visible card stats[cite: 6].
        *   Implemented Phase 1 linear high-speed roll during stagger delays (`0.5s`, `1.0s`), transitioning smoothly into Phase 2 3.0-second `OutCubic` deceleration curve[cite: 6].
        *   Calculated target positions using exact C++ engine pixel bounds (`winnerYOffset = winnerCardFrame.AbsolutePosition.Y - reelStrip.AbsolutePosition.Y`), achieving 100% resolution independence[cite: 6].
        *   Eliminated card "flashing/morphing" on stop: reveals stats first while resting, destroys `UIListLayout`, purges all 39 dummy sibling cards instantly, and centers the winner card without reparenting[cite: 6].
        *   Implemented $O(1)$ DOM element caching (`cacheCardElements`), reducing recursive tree lookups by over 90%[cite: 6].
        *   Added a multi-voice cloned sound pool to prevent audio tick clipping[cite: 6].
    *   **Opponent Draft Mirroring & Solid Rarity Colors:**
        *   Updated `OpponentSlotUpdatedEvent` to set `BackgroundTransparency = 0` with solid rarity background colors, replacing the `SelectPlayerButton` `+` text with `"SELECTED"` in Fredoka One font while preserving position indicators[cite: 6].
        *   Blanked initial opponent button text (`""`), keeping empty slots clean prior to selection[cite: 6].
    *   **Complete Match Resolution & Dual Result Display System:**
        *   Reveals opponent final team OVR on `MatchCompletedEvent`[cite: 6].
        *   Displays a high-visibility 2D screen banner (`MatchResultBanner`) with outcome (`VICTORY!`, `DEFEAT!`, `MATCH DRAW!`) and score summary[cite: 6].
        *   Auto-closes `DuelGui` after 4 seconds to transition players back to physical field view[cite: 6].
        *   Server updates 3D `StatusAnchor` `BillboardGui` with winner text (`Player 1 won!`), releases player controls, teleports characters 10 studs back, and resets field status text to default after a 5-second window[cite: 6].
        * Removed fallback to table in card selected event in QueueManager to ensure exploiters can't inject card selections and MUST use the server-determined cards via candidate index [cite: 6].