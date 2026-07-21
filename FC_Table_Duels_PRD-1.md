# Soccer Squad Duels! — Product Requirements Document (MVP)
**Version:** 1.0 (Working Title)
**Target Build Time:** 60–120 hours (solo Luau developer)
**Platform:** Roblox (PC / Mobile / Console via ScreenGui + GamepadService)

> **Naming note:** "FC Table Duels" is close enough to EA Sports FC that it should be treated as a placeholder. All cards/players in this design are fictional — recommend finalizing a distinct name before any marketing push or store listing.

---

## 1. Executive Summary & Core Game Loop

### 1.1 Vision
FC Table Duels turns passive card-pack RNG into a face-to-face, real-time social duel. Two players sit at a physical 3D table, speed-draft an 11-man squad from independently-rolled card pools, secretly arrange their formation, and then watch a cinematic, sector-by-sector reveal decide the match. The core tension isn't "who has better luck" in isolation — it's "who drafted better *against this specific opponent, with imperfect information about what they got.*"

### 1.2 Core Game Loop

```
[LOBBY]
   │  Player queues for a table (Matchmaking or Friend Invite)
   ▼
[SIT AT TABLE]
   │  Both players seated → Seat.Occupied fires → camera locks to table view
   │  Countdown (3s) → Draft begins
   ▼
[11-MAN SPEED DRAFT]
   │  Sequential position order: GK → CB → CB → LB → RB → CM → CM → CAM → RW → LW → ST
   │  Each position: 3-card randomized choice, 3s timer, auto-pick if timer expires
   │  Opponent's picks shown ONLY as rarity-tier borders (see Section 4.2) — not name/OVR
   ▼
[POSITIONAL PLACEMENT / CONFIRM]
   │  Brief (5–8s) formation confirm screen — swap card among same-position duplicates if any
   ▼
[CINEMATIC MATCH REVEAL]
   │  Phase A: Card flip + sector reveal (Midfield → Defense/Attack → Striker/GK)
   │  Phase B: Suspense build (drumroll, camera push-ins)
   │  Phase C: Score resolution, confetti/victory VFX, emote trigger
   ▼
[PAYOUT & META-PROGRESSION]
   │  Coins awarded (win > draw > loss), Win/Loss stat updated, cards return to collection
   │  Return to Lobby
```

**Target full-match duration: ~2–3 minutes** (draft ~35–45s, placement ~8s, reveal ~60–90s, payout ~10s). This is short enough to sustain queue velocity but long enough for the reveal to feel earned — pacing targets in Section 4 are built around this window.

---

## 2. Technical Architecture & Roblox Engine Specs

### 2.1 Client-Server Responsibility Map

| Responsibility | Location | Notes |
|---|---|---|
| Seat detection / camera lock | `StarterPlayerScripts` (LocalScript) | Listens to `Seat.Occupied:GetPropertyChangedSignal()`; purely cosmetic/input, no authority |
| Draft card display & selection UI | `StarterPlayerScripts` | Renders 3-card choice via SurfaceGui/ScreenGui; sends selection to server, never resolves outcome locally |
| Card inspector / hover-zoom | `StarterPlayerScripts` | Local-only camera tricks, no gameplay state |
| Reveal cinematic playback | `StarterPlayerScripts` | Plays deterministic sequence driven by server-authoritative result payload |
| **Draft pool generation** | `ServerScriptService` | Authoritative RNG, seeded per-match; removes drafted cards from both pools |
| **Duplicate-across-match prevention** | `ServerScriptService` | Maintains a per-match "reserved card" set (see 3.1.1) |
| **Pick validation & timers** | `ServerScriptService` | Server owns the 3s timer; enforces auto-pick on timeout |
| **Match Resolution Engine** | `ServerScriptService` | All 3-zone math (Section 3.2) — client never calculates outcomes |
| **DataStore read/write** | `ServerScriptService` (ProfileService) | Coins, W/L, cosmetics — never trust client-submitted values |
| **Payout distribution** | `ServerScriptService` | Triggered only after server-side match resolution completes |

**Golden rule:** the client never determines a match outcome or generates the "true" draft pool — it only requests actions and renders whatever the server tells it happened. This closes the most obvious exploit surface (client-side RNG spoofing) with almost no extra dev cost if built this way from day one.

### 2.2 Required RemoteEvents / RemoteFunctions

| Name | Type | Direction | Payload | Purpose |
|---|---|---|---|---|
| `RequestJoinTable` | RemoteFunction | C→S | `tableId` (optional) | Matchmake or join specific table; returns success/fail |
| `TableStateChanged` | RemoteEvent | S→C | `{tableId, state, players}` | Broadcasts lobby→draft→reveal→payout transitions |
| `DraftOptionsPresented` | RemoteEvent | S→C | `{position, cardOptions[3], timeRemaining}` | Server pushes the 3-card choice for current position |
| `SubmitDraftPick` | RemoteFunction | C→S | `{cardId}` | Player's selection; server validates against current legal options |
| `OpponentPickBroadcast` | RemoteEvent | S→C | `{position, rarityTier}` | Sends ONLY the border/tier of opponent's pick — never card identity |
| `DraftComplete` | RemoteEvent | S→C | `{yourSquad[11]}` | Full squad confirmation, opponent squad withheld |
| `RequestMatchResolve` | RemoteFunction | C→S | `{}` | Triggered after placement confirm; server runs Match Resolution Engine |
| `MatchResultPayload` | RemoteEvent | S→C | `{zone1, zone2, zone3, finalScore, luckyPulls[]}` | Full deterministic reveal data both clients animate identically |
| `LuckyPullBroadcast` | RemoteEvent | S→C (server-wide) | `{playerName, cardName, OVR}` | Fires server-wide when a 90+ OVR card is drafted anywhere |
| `PayoutGranted` | RemoteEvent | S→C | `{coinsAwarded, newBalance}` | Confirms DataStore write succeeded before client shows the number |

### 2.3 Camera & Table Setup
- Table model contains two `Seat` instances (`SeatA`, `SeatB`) and a `CameraAnchor` Part per seat with a preset CFrame framing the table surface.
- On `Seat.Occupied:GetPropertyChangedSignal("Occupant")` firing with a non-nil Player, the LocalScript tweens `Workspace.CurrentCamera.CFrame` to the corresponding `CameraAnchor.CFrame` over ~0.4s and sets `CameraType = Enum.CameraType.Scriptable`.
- On seat vacancy (player stands/disconnects/match ends), camera reverts to `Enum.CameraType.Custom`.
- Table is mirrored left/right per seat so each player's "near side" cards render toward them — achieved by flipping the SurfaceGui `SizeOffset`/orientation per seat rather than maintaining two separate table models.

### 2.4 SurfaceGUI / Viewport Isolation (Hidden Info)
Since Roblox SurfaceGuis render to anyone who can see the part, hiding info from an opponent sitting across the same physical table needs client-side filtering, not physical occlusion:
- Each player's card-face rendering is done in a **PlayerGui ScreenGui**, not a world SurfaceGui, positioned to visually align with the table via camera-relative offset. This guarantees Player A's ScreenGui is only ever present in Player A's PlayerGui tree — Player B's client never receives that instance at all.
- The physical table only holds a generic "face-down card" mesh/decal (identical for both players) so the 3D space still *looks* populated correctly for spectators or replay/streaming purposes.
- Opponent border indicators (Section 4.2) ARE synced via world SurfaceGui or a shared BillboardGui, since those are intentionally visible to both.
- This means: real stats = PlayerGui-only, server-pushed exclusively to the owning client. Border/tier = shared, low-info, safe to broadcast to both.

---

## 3. Mechanics & Game Logic

### 3.1 11-Player Speed Draft System

**Draft order (fixed):** `GK → CB → CB → LB → RB → CM → CM → CAM → RW → LW → ST`

#### 3.1.1 Pool Model — Independent Rolls, Shared Reservation, Per-Board Identity Lock
Per your spec, this system operates on **two distinct identity levels** per card:
- **`CardID`** — the exact card version (e.g. `"MBAPPE_WC2018"` vs `"MBAPPE_RMADRID2025"` are two different CardIDs).
- **`PlayerIdentity`** — the real-world player the card depicts (e.g. both those CardIDs share `PlayerIdentity = "Mbappe"`).

Two separate rules apply, at two separate scopes:

1. **Match-wide CardID reservation (cross-board):** once a specific `CardID` is drafted by *either* player, it is immediately removed from *both* players' future roll pools for the rest of the match. If you draft `MBAPPE_WC2018`, your opponent can never draft that exact card — but they *can* still draft `MBAPPE_RMADRID2025`, since it's a different CardID.
2. **Per-board PlayerIdentity lock (single-board only):** a player's own 11-card squad can never contain two cards that share the same `PlayerIdentity`, even if they're different CardIDs. You cannot draft both `MBAPPE_WC2018` and `MBAPPE_RMADRID2025` onto *your own* board — once you've drafted one Mbappe variant, every other Mbappe variant is filtered out of *your* future roll options for the rest of the match. Your opponent isn't affected by your identity lock and can still draft a different Mbappe variant onto their own board, as long as it's not the exact CardID you already took (rule 1 still applies).

Net effect: exact card versions are globally unique across the whole table; real players are unique *per board*, not across the table. This means two different Mbappe cards can legitimately face off from opposite sides in the same match, but neither player can stack multiple versions of the same real player on their own side.

```lua
-- ServerScriptService/DraftPoolManager.lua (excerpt)
local DraftPoolManager = {}
DraftPoolManager.__index = DraftPoolManager

-- `sharedReservedCardIds` is a table reference SHARED across both players'
-- DraftPoolManager instances for a given match — this is what enforces the
-- match-wide "exact CardID can only exist once across both boards" rule.
function DraftPoolManager.new(fullCardDatabase, sharedReservedCardIds)
	local self = setmetatable({}, DraftPoolManager)
	self.available = fullCardDatabase -- {[cardId] = cardData}, read-only reference
	self.reservedCardIds = sharedReservedCardIds -- cardId -> true, SHARED across both players
	self.ownedIdentities = {} -- PlayerIdentity -> true, LOCAL to this player only
	return self
end

function DraftPoolManager:RollOptionsForPosition(position, count)
	local candidates = {}
	for cardId, card in pairs(self.available) do
		local isRightPosition = card.Position == position
		local isNotReservedMatchWide = not self.reservedCardIds[cardId]
		local isNotAlreadyOwnedByThisPlayer = not self.ownedIdentities[card.PlayerIdentity]

		-- Rule 1: exact CardID must be free match-wide (checked against shared table)
		-- Rule 2: this player must not already have ANY card for this PlayerIdentity
		--         (checked only against THIS player's ownedIdentities, not the opponent's)
		if isRightPosition and isNotReservedMatchWide and isNotAlreadyOwnedByThisPlayer then
			table.insert(candidates, cardId)
		end
	end
	assert(#candidates >= count, "Not enough legal cards left for position: " .. position)

	-- Fisher-Yates partial shuffle
	for i = #candidates, 2, -1 do
		local j = math.random(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end

	local options = {}
	for i = 1, count do
		table.insert(options, candidates[i])
	end
	return options
end

function DraftPoolManager:ConfirmPick(cardId)
	local card = self.available[cardId]
	self.reservedCardIds[cardId] = true          -- removes this exact version from BOTH boards
	self.ownedIdentities[card.PlayerIdentity] = true -- locks this real player for THIS board only
end

return DraftPoolManager
```

Each duel spins up **two independent `DraftPoolManager` instances that share the same `reservedCardIds` table** (pass the same table reference to both, or use a match-level singleton), while each instance keeps its **own separate `ownedIdentities` table**. That split is what makes the two rules operate at the correct scope: reservation is shared, identity-locking is per-player.

#### 3.1.2 Selection Timer
- Server starts a 3-second window per position via `task.delay` and pushes `DraftOptionsPresented`.
- If `SubmitDraftPick` isn't received in time, server auto-selects a uniform-random option from the 3 presented (never the "best" one — avoids AFK players getting reward for absence, but also doesn't unfairly punish disconnects mid-selection).
- Server is the sole timer authority; client only renders a visual countdown driven by the server timestamp to prevent desync exploits (client-side setTimeout drift is cosmetic only).

### 3.2 Match Resolution Engine (3-Zone Positional Checks)

The engine converts two 11-card squads into a final score. It's split into three sequential zones, each producing an intermediate value the next zone consumes — this is what gives the reveal its natural three-act structure (Section 4.3).

| Zone | Positions Compared | Output | Feeds Into |
|---|---|---|---|
| Zone 1: Midfield | CM, CM, CAM (both sides) | Possession Bonus (%) — modifies chance generation in Zone 2 | Zone 2 |
| Zone 2: Defense vs. Attack | CB, CB, LB, RB vs. LW, RW, ST | Raw Chances Created (integer, per side) | Zone 3 |
| Zone 3: Striker vs. GK | ST vs. GK (1v1 checks per chance) | Goals Scored (final score per side) | Final Score |

```lua
-- ServerScriptService/MatchResolutionEngine.lua (excerpt)
local MatchResolutionEngine = {}

local function averageOVR(cards)
	local sum = 0
	for _, card in ipairs(cards) do sum += card.OVR end
	return sum / #cards
end

function MatchResolutionEngine.ResolveZone1_Midfield(squadA, squadB)
	local midA = averageOVR({squadA.CM1, squadA.CM2, squadA.CAM})
	local midB = averageOVR({squadB.CM1, squadB.CM2, squadB.CAM})
	local diff = midA - midB
	-- Possession bonus scales +/-15%, capped, based on midfield OVR gap
	local possessionBonusA = math.clamp(diff * 0.75, -15, 15) / 100
	local possessionBonusB = -possessionBonusA
	return possessionBonusA, possessionBonusB
end

function MatchResolutionEngine.ResolveZone2_ChancesCreated(attackSquad, defenseSquad, possessionBonus)
	local atk = averageOVR({attackSquad.LW, attackSquad.RW, attackSquad.ST})
	local def = averageOVR({defenseSquad.CB1, defenseSquad.CB2, defenseSquad.LB, defenseSquad.RB})
	local edge = (atk - def) / 100 -- normalized -1..1 range roughly
	local baseChances = 3 -- baseline chances per match
	local chanceRoll = baseChances + math.floor((edge + possessionBonus) * 4 + math.random())
	return math.clamp(chanceRoll, 0, 8)
end

function MatchResolutionEngine.ResolveZone3_FinishingCheck(striker, goalkeeper)
	-- Each created chance becomes a 1v1 probabilistic check
	local finishProb = math.clamp(0.5 + (striker.OVR - goalkeeper.OVR) / 150, 0.05, 0.95)
	return math.random() < finishProb
end

function MatchResolutionEngine.ResolveMatch(squadA, squadB)
	local bonusA, bonusB = MatchResolutionEngine.ResolveZone1_Midfield(squadA, squadB)
	local chancesA = MatchResolutionEngine.ResolveZone2_ChancesCreated(squadA, squadB, bonusA)
	local chancesB = MatchResolutionEngine.ResolveZone2_ChancesCreated(squadB, squadA, bonusB)

	local goalsA, goalsB = 0, 0
	for _ = 1, chancesA do
		if MatchResolutionEngine.ResolveZone3_FinishingCheck(squadA.ST, squadB.GK) then
			goalsA += 1
		end
	end
	for _ = 1, chancesB do
		if MatchResolutionEngine.ResolveZone3_FinishingCheck(squadB.ST, squadA.GK) then
			goalsB += 1
		end
	end

	return {
		zone1 = {bonusA = bonusA, bonusB = bonusB},
		zone2 = {chancesA = chancesA, chancesB = chancesB},
		finalScore = {a = goalsA, b = goalsB},
	}
end

return MatchResolutionEngine
```

This structure is deliberately transparent and tunable — every constant (`0.75`, `15`, `baseChances = 3`, the `/150` finishing divisor) is a single tuning knob you can adjust after MVP playtesting without touching the reveal/animation code, since the client only ever consumes the final `MatchResultPayload`.

---

## 4. UI/UX & Cinematic Reveal Sequence

### 4.1 UI Flow
1. **Lobby Menu** — Play (matchmake), Collection (view owned cards), Cosmetics (equip skins/emotes), Coins balance.
2. **Draft Screen** — Position indicator (top), 3-card choice row (center, tappable/clickable), 3s countdown ring, opponent border-tracker strip (side panel, see 4.2).
3. **Placement/Confirm Screen** — Your 11 cards laid out in formation shape, brief swap window for same-position duplicates.
4. **Reveal Screen** — Full-screen cinematic (Section 4.3), no player input during this phase.
5. **Payout Screen** — Coins awarded, W/L record update, "Play Again" / "Return to Lobby" buttons.
6. **Card Inspector** — Available as a hover/tap overlay from Collection or Draft screen only; never usable mid-reveal.

### 4.2 Opponent Border / Rarity-Tier System (your addition — recommended)
Instead of full opponent-card concealment, the opponent's picks are shown as a **tier border only**, visible in real time as they draft:

| Tier | OVR Range | Border Treatment |
|---|---|---|
| Bronze | 60–69 | Plain brushed-bronze frame |
| Silver | 70–79 | Brushed silver frame |
| Gold | 80–89 | Gold frame, subtle shimmer shader |
| Icon | 90+ | Animated holographic frame + triggers Lucky Pull event (4.3) |

- This is broadcast via `OpponentPickBroadcast` (Section 2.2) — position + tier only, never card name/exact OVR/photo.
- Creates real strategic pressure: seeing your opponent lock in three Golds at CB/CB/LB tells you their defense is strong *before* the reveal, without fully solving the information asymmetry that makes the reveal worth watching.
- UI treatment: a thin vertical strip on the draft screen showing 11 face-down slots that fill in with tier borders as the opponent picks, mirroring your own draft pace.

### 4.3 Server-Wide "Lucky Pull" Event
Fires when *any* player, anywhere on the server, drafts a 90+ OVR ("Icon" tier) card:
- **Visual:** a vertical light beam (`Beam` instance or particle emitter) spawns briefly at the drafting player's table, visible to nearby players.
- **Audio:** localized `Sound` (chime/stinger) plays for players within a radius of that table; a quieter global "ding" plays server-wide.
- **Chat notification:** system message broadcast to all players, e.g. `[LUCKY PULL] PlayerName pulled a 92 OVR card!` (card *name* can be included here since it's a celebratory broadcast happening after the fact, not a live-draft leak — recommend delaying this specific broadcast until that player's draft turn for that position has fully closed, so it can't be reverse-engineered into a live information leak against their current opponent).

### 4.4 Match Reveal Timeline (Second-by-Second, ~70–90s total)

| Time | Phase | What Happens |
|---|---|---|
| 0:00–0:05 | Intro | Camera pulls back from table to a stadium-style wide shot; "MATCH START" title card |
| 0:05–0:20 | Phase A — Sector Reveal (Midfield) | Both midfields flip simultaneously; possession bonus % animates in as a tug-of-war bar |
| 0:20–0:45 | Phase A — Sector Reveal (Def vs Atk) | Defense/attack cards flip; chance-created count animates as a shot-map graphic |
| 0:45–0:65 | Phase B — Suspense Drumroll | Camera pushes in tight on ST vs GK; drumroll SFX; slow-motion "coin flip" tension beat per chance resolved |
| 0:65–0:80 | Phase C — Score Resolution | Goals animate onto scoreboard one at a time with crowd-roar SFX; final score locks |
| 0:80–0:90 | Phase C — Victory | Winning player's table/side triggers confetti VFX + their equipped victory emote plays on their rig |

All of this timeline is driven by the single `MatchResultPayload` the server sends once — both clients play back an identical deterministic animation from the same data, so there's no risk of the two players seeing different outcomes or timings.

---

## 5. Data Schema & Card Pipeline

### 5.1 Card Data Module

```lua
-- ReplicatedStorage/Data/CardDatabase.lua
export type CardRarity = "Bronze" | "Silver" | "Gold" | "Icon"
export type CardPosition = "GK" | "CB" | "LB" | "RB" | "CM" | "CAM" | "RW" | "LW" | "ST"

export type CardData = {
	CardID: string,        -- exact card version, globally unique, reserved match-wide once drafted
	PlayerIdentity: string, -- the underlying "person" this card depicts; locked per-board, not match-wide
	Name: string,           -- display name, may include the variant (e.g. "2018 WC Winner")
	Position: CardPosition,
	OVR: number,
	Rarity: CardRarity,
	RigConfig: {
		BodyColorPalette: {number}, -- indices into a preset color table, NOT real photos
		AccessoryIds: {number},     -- Roblox catalog accessory AssetIds used for the rig
		FaceDecalId: number,        -- stylized/fictional face decal, not a real photo
	},
}

local CardDatabase: {[string]: CardData} = {
	["STRIKER_A_WC2018"] = {
		CardID = "STRIKER_A_WC2018",
		PlayerIdentity = "StrikerA", -- shared across all variants of this fictional player
		Name = "Fictional Striker A (2018 WC Winner)",
		Position = "ST",
		OVR = 91,
		Rarity = "Icon",
		RigConfig = {
			BodyColorPalette = {3, 7, 12},
			AccessoryIds = {},
			FaceDecalId = 0,
		},
	},
	["STRIKER_A_CLUB2025"] = {
		CardID = "STRIKER_A_CLUB2025",
		PlayerIdentity = "StrikerA", -- SAME identity as above — the per-board lock applies between these two
		Name = "Fictional Striker A (2025 Club Star)",
		Position = "ST",
		OVR = 89,
		Rarity = "Icon",
		RigConfig = {
			BodyColorPalette = {3, 7, 14},
			AccessoryIds = {2},
			FaceDecalId = 0,
		},
	},
	-- ... additional entries
}

return CardDatabase
```

### 5.2 ProfileService DataStore Schema

```lua
-- ServerScriptService/PlayerProfileTemplate.lua
local ProfileTemplate = {
	Coins = 100,
	Stats = {
		Wins = 0,
		Losses = 0,
		Draws = 0,
	},
	OwnedCosmetics = {
		CardSkins = {},      -- {["neon_gold"] = true, ...}
		VictoryEmotes = {},  -- {["emote_confetti_dance"] = true, ...}
		TableThemes = {},    -- {["theme_stadium_night"] = true, ...}
		DraftBanners = {},   -- {["banner_champions"] = true, ...}
	},
	EquippedCosmetics = {
		CardSkin = "default",
		VictoryEmote = "default",
		TableTheme = "default",
	},
	Collection = {}, -- CardID -> count owned (if cards persist beyond a single match; optional for MVP)
}

return ProfileTemplate
```

Use **ProfileService** (or DataStore2) for session-locking and auto-retry — do not hand-roll raw `DataStoreService:SetAsync` calls for anything wallet-related; this is the single most common cause of Roblox dupe/rollback exploits in student/solo-dev projects.

---

## 6. Ethical Monetization & Game Economy

Per your direction, monetization is **strictly cosmetic** — nothing sold affects draft odds, card stats, or match outcomes.

| # | Item | Type | What It Does |
|---|---|---|---|
| 1 | Draft Reroll Tokens | Developer Product | Consumable — reroll your *current 3-card choice* for a new random 3, same position, same rarity distribution. Does not let you pick a specific card or skip the shared reservation rule. |
| 2 | Holographic / Neon Card Skin Shaders | Game Pass | Purely visual re-skin of your *own* card borders/frames during draft & reveal (does not change opponent-visible tier border in 4.2 — that stays standardized so the information-asymmetry mechanic isn't undermined by cosmetics). |
| 3 | Draft Pool Theme Banners | In-game Currency / Robux | Cosmetic background/UI theme for your draft screen (e.g., "Champions Night" gold-and-navy theme) — decorative only. |
| 4 | Custom Table Finishes & Victory Emotes | Cosmetics (Robux or unlockable via Coins) | Reskins the physical table model; victory emote plays on your rig during Phase C of the reveal if you win. |

### 6.1 Competitive Integrity Guarantee
- **Card stats, OVR, and rarity are never sold or purchasable.** Every card in the game is obtainable only through the free draft pool.
- **Reroll Tokens reroll options, not outcomes** — the new 3-card set is drawn from the same live pool under the same reservation rules as everyone else; there's no "guaranteed rare" mechanic hidden in a paid reroll.
- **Opponent-visible tier borders (4.2) are cosmetic-locked** — a paying player's frame looks fancier to *them*, but their opponent always sees the same standardized Bronze/Silver/Gold/Icon border regardless of what the drafting player purchased. This prevents cosmetics from leaking extra information (e.g., a flashier frame subtly signaling "I paid, so I probably rerolled for something good").
- Recommend a one-line disclosure in the store UI: *"All purchases are cosmetic only and do not affect card stats, draft odds, or match results."*

---

## 7. Character Card Rendering — Approach & Recommendation

You raised three options: rig-and-photograph an R6/R15 avatar, or use real player photos/poses (as some other games reportedly do). **Recommendation: build a procedural rig rendered live via ViewportFrame — do not use real people's photos or likenesses.**

### 7.1 Why not real player photos
- **Right-of-publicity / consent risk:** using a real, identifiable person's photo or likeness on a monetized card without their consent is a legal exposure point regardless of how other games have handled it — "other games do it" is not the same as it being low-risk, and this is exactly the kind of thing worth avoiding at MVP stage rather than inheriting someone else's liability.
- **Moderation risk:** Roblox's platform moderation is generally strict about real-world photos of real, identifiable people appearing in-experience; this can jeopardize the whole game's ability to stay published, not just one asset.
- **Also avoids** any adjacent trademark/likeness questions tied to real footballers, which the "FC" branding already borders on (see naming note at top).

### 7.2 Recommended approach: Live ViewportFrame Rig Rendering
1. Build a small library of **base R15 rig templates** (a handful of body types/skin-tone presets, fictional, not tied to any real person).
2. Each `CardData.RigConfig` (Section 5.1) specifies: body color palette indices, a list of catalog `AccessoryIds` (hair, jersey-style clothing via layered clothing or classic accessories), and an optional stylized face decal — all fictional/generic, not photographic.
3. At runtime, when a card needs to be displayed (draft screen, inspector, collection), spawn or reuse a pooled rig inside a hidden `WorldModel` positioned off-camera, apply the `RigConfig` (`Humanoid:AddAccessory`, `BodyColors`, pose via `Animator:LoadAnimation` set to a held frame), and render it into a `ViewportFrame` pointed at that WorldModel with its own dedicated `Camera` instance.
4. This is fully proceduralized — no need to pre-render or store card images at all; skins/cosmetics (Section 6) simply swap which accessories/materials the rig loads, so a "Neon Card Skin" game pass can literally change the rig's material to `Neon` or swap its accessory set at render time.
5. Pool a small number of ViewportFrame+rig instances (e.g., 6–8) and reuse them across the 3-card draft choices rather than instantiating fresh rigs per card — keeps this performant on mobile.

This gets you a fully dynamic, scalable card-art pipeline with zero real-world images, zero per-card manual art, and monetizable cosmetic hooks already built in — and it sidesteps the legal/moderation risk of the photo-based approach entirely.

---

## 8. MVP Roadmap & Scope Cut Criteria

### 8.1 Feature Prioritization Matrix

| Priority | Feature |
|---|---|
| **P0 (MVP-Essential)** | Seat-based table join, camera lock, 11-position sequential draft w/ 3s timer, shared-reservation independent-pool RNG, opponent border broadcast, 3-Zone Match Resolution Engine, single deterministic reveal sequence, ProfileService coin/W-L persistence, basic Roblox UI-primitive draft/reveal screens, procedural ViewportFrame rig rendering (Section 7.2) |
| **P1 (Post-Launch Polish)** | Lucky Pull server-wide VFX+chat event, Reroll Token dev product, card skin/table theme cosmetics, victory emotes, card inspector hover-zoom, matchmaking rank/ELO |
| **P2 (Future Updates)** | Spectator mode, replay sharing, seasonal card rotations, clan/tournament brackets, cosmetic trading, leaderboards |

### 8.2 Explicit Scope Cuts for MVP
To hit the 60–120 hour window:
- **No custom 3D player models/animations** — use base R15 rigs with catalog accessories only (Section 7.2); no bespoke rigging or animation authoring.
- **No custom table/environment art** — basic block-and-material Roblox Studio primitives (Parts, MaterialService presets) for the table and lobby; skip sculpted meshes.
- **Use default Roblox UI primitives** (Frame, TextButton, UIListLayout/UIGridLayout) for all screens — no custom 9-slice UI framework or third-party UI libraries.
- **Skip real card art entirely** — rely fully on the procedural rig pipeline (Section 7) rather than commissioning or sourcing card face images.
- **Single reveal camera path** (not per-player customizable cinematography) — one well-tuned camera sequence reused for every match.
- **No matchmaking ELO/rank system at MVP** — simple "join any open table" or friend-invite only; rank/ELO is P1.
- **No card collection persistence beyond stats** — MVP can treat each match's drafted squad as ephemeral (returns to the general pool after the match) unless play testing shows players want to keep/collect specific cards; if so, that's a P1 addition, not a P0 requirement.

---

*End of PRD.*
