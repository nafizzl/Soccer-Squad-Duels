# Project Context & File Structure

This document provides a complete map of the codebase, detailing what is stored in the local file directory and how it correlates to the Roblox Studio Explorer tree (including runtime/client UI templates, frames, and services)[cite: 5].

---

## 1. Local Directory Structure

The local workspace directory contains files synced to Roblox Studio[cite: 5]:

*   📁 **StarterPlayer/**[cite: 5]
    *   📁 **StarterPlayerScripts/**[cite: 5]
        *   📁 **Controllers/**[cite: 5]
            *   📄 [DuelGuiController.client.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/StarterPlayer/StarterPlayerScripts/Controllers/DuelGuiController.client.lua) — Central client UI controller handling 11-man formation drafting, $O(1)$ DOM element caching, unique slot key generation (`CB1` vs `CB2`), two-phase kinematic vertical reel spinning (linear fast-spin to 3.0s `OutCubic` deceleration), pixel-exact C++ layout targeting, zero-flicker dummy card cutoff, multi-voice tick audio, formation position locking, 2D `MatchResultBanner` presentation, auto-closing draft GUI, and forfeit/cleanup state management[cite: 5].
*   📁 **ServerScriptService/**[cite: 5]
    *   📄 [QueueManager.server.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ServerScriptService/QueueManager.server.lua) — Central server script controlling 8-field matchmaking, player movement lock/unlock mechanics, server-authoritative 1/N card rolling, candidate index validation across 11 unique formation slots (`CB1`, `CB2`), 3D `StatusAnchor` billboard winner & forfeit announcements with auto-clearing timers, disconnect handling, and match completion resolution[cite: 5].
*   📁 **ReplicatedStorage/**[cite: 5]
    *   📁 **Data/**[cite: 5]
        *   📄 [CardDatabase.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/CardDatabase.lua) — Unified wrapper module exporting typed access to both `AllTime` and `Current` card databases[cite: 5].
        *   📄 [CardDatabaseAllTime.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/CardDatabaseAllTime.lua) — Master database of 1,000 all-time historical icons and modern legends[cite: 5].
        *   📄 [CardDatabaseCurrent.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/CardDatabaseCurrent.lua) — Master database of 1,000 active modern EA FC 26 players[cite: 5].
        *   📄 [RarityColors.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/RarityColors.lua) — Exported `Color3` background color mappings for Bronze, Silver, Gold, Stars, and Legend rarity tiers[cite: 5].
    *   📄 [DuelEvents.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/DuelEvents.lua) — RemoteEvent infrastructure module for client-server duel communication[cite: 5].
*   📁 **ServerStorage/**[cite: 5]
    *   *(Reserved for server-only assets & models)*[cite: 5]
*   📁 **ReplicatedFirst/**[cite: 5]
    *   *(Reserved for client loading & pre-rendering scripts)*[cite: 5]
*   📄 [FC_Table_Duels_PRD-1.md](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/FC_Table_Duels_PRD-1.md) — Product Requirements Document[cite: 5].
*   📄 [timeline.md](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/timeline.md) — Chronological progress log[cite: 5].
*   📄 [context.md](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/context.md) — Codebase context map (this file)[cite: 5].

---

## 2. Roblox Studio Explorer Tree

Assets and UI frames managed directly in Roblox Studio[cite: 5]:

### 📁 Workspace[cite: 5]
*   📁 **Soccer Field 1** through **Soccer Field 8** (Models)[cite: 5]
    *   📁 **Player 1 Spot** (Model) — Boundary box for Player 1 queue lock-in[cite: 5].
    *   📁 **Player 2 Spot** (Model) — Boundary box for Player 2 queue lock-in (facing 180° opposite)[cite: 5].
    *   ⬜ **StatusAnchor** (Part) — Anchored part used as `Adornee` for match status, winner announcements (`Player 1 won!`), and 3-second forfeit `BillboardGui` messages[cite: 5].
    *   ⬜ **CountdownAnchor** (Part) — Anchored part used as `Adornee` for the match start countdown `BillboardGui`[cite: 5].

### 📁 ReplicatedStorage[cite: 5]
*   📁 **Templates** (Folder — Reusable UI Templates)[cite: 5]
    *   📁 **TeamViewSlot** (Folder)[cite: 5]
        *   🖼️ **EmptySlotView** (Frame) — Template containing `SelectPlayerButton` (`+` button or `"SELECTED"` text), `SlotPosition`, `UIStroke`, `UICorner`, and `UIAspectRatioConstraint`[cite: 5].
        *   🖼️ **SelectedSlotView** (Frame) — Template containing `CardImage`, `CardName` (ShortName), `SlotPosition`, `OVRValue`, `UIStroke`, `UICorner`, and `UIAspectRatioConstraint`[cite: 5].
    *   📁 **CardRolledSlot** (Folder)[cite: 5]
        *   🖼️ **CardRolledSlot** (Frame) — Template containing `CardImage`, `CardName` (ShortName), `SlotPosition`, `OVRValue`, 6 substats (`PAC`, `SHO`, `PAS`, `DRI`, `DEF`, `PHY`), `UIStroke`, `UICorner`, and `UIAspectRatioConstraint`[cite: 5].
*   📡 **ExitQueueEvent** (RemoteEvent) — Server-created remote event for queue exit requests[cite: 5].

### 📁 StarterGui[cite: 5]
*   🖥️ **HUD** (ScreenGui) — Player HUD (`Enabled = true` by default)[cite: 5].
*   🖥️ **ExitQueue** (ScreenGui) — Displayed when locked in queue (`Enabled = false` by default)[cite: 5].
    *   📁 **ExitFrame** (Frame) $\rightarrow$ 🔘 **ExitButton** (TextButton) $\rightarrow$ 📜 **ExitScript** (LocalScript)[cite: 5].
*   🖥️ **DuelGui** (ScreenGui) — Main squad drafting and duel interface (`Enabled = false` by default)[cite: 5].
    *   🖼️ **DuelMenu** (Frame)[cite: 5]
        *   📁 **YourTeamFrame** (Frame)[cite: 5]
            *   🖼️ **YourTeamView** (Frame) — Holds the 11 formation position slots (`LW`, `ST`, `RW`, `LM`, `CM`, `RM`, `LB`, `CB1`, `CB2`, `RB`, `GK`)[cite: 5].
            *   🔤 **YourTeamLabel** (TextLabel) & **YourOVRValue** (TextLabel) — Dynamic team average OVR[cite: 5].
        *   📁 **OpponentTeamFrame** (Frame)[cite: 5]
            *   🖼️ **OpponentTeamView** (Frame) — Holds opponent's 11 formation slots (updates background transparency to 0 with solid Rarity colors and replaces `SelectPlayerButton` `+` text with `"SELECTED"` while preserving formation position labels)[cite: 5].
            *   🔤 **OpponentTeamLabel** (TextLabel) & **OpponentOVRValue** (TextLabel) — Opponent final team OVR reveal[cite: 5].
        *   📁 **CardSelectionFrame** (Frame — Slime-RNG Roll View)[cite: 5]
            *   🖼️ **CardSlot1**, **CardSlot2**, **CardSlot3** (Frames — Reel viewports with `ClipsDescendants = true`)[cite: 5].
            *   🎨 **SketchActiveGradient** (UIGradient — `#181818` bottom fade overlay)[cite: 5].
        *   🏷️ **MatchResultBanner** (TextLabel — Runtime-generated 2D match result banner displaying `VICTORY!`, `DEFEAT!`, or `MATCH DRAW!` alongside score breakdown)[cite: 5].
        *   🔘 **ExitButtonFrame** (Frame) $\rightarrow$ **ExitButton** (TextButton — Forfeit button)[cite: 5].
        *   ⬛ **BackgroundDim** (Frame — Dark background dimming)[cite: 5].