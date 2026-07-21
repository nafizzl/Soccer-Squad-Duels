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
