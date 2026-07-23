# Project Context & File Structure

This document provides a map of the codebase, detailing what is stored in the local file directory and how it correlates to the Roblox Studio Explorer tree (since some runtime/client assets are not represented in the local workspace directory).

---

## 1. Local Directory Structure

The local workspace directory contains files synced to Roblox Studio using **Rojo**:

*   📁 **ServerScriptService/**
    *   📄 [QueueManager.server.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ServerScriptService/QueueManager.server.lua) — The central server script controlling matchmaking and player tracking. It listens to `.Touched` events on field spots, anchors/aligns characters, updates floating status billboards, runs starting countdowns, and handles player exit/death releases.
*   📁 **ReplicatedStorage/**
    *   📁 **Data/**
        *   📄 [CardDatabase.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/CardDatabase.lua) — Unified wrapper module exporting typed access to both `AllTime` and `Current` card databases.
        *   📄 [CardDatabaseAllTime.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/CardDatabaseAllTime.lua) — Master card database containing 1,000 all-time historical icons and modern stars ranked by `anothertop1000.txt`.
        *   📄 [CardDatabaseCurrent.lua](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/ReplicatedStorage/Data/CardDatabaseCurrent.lua) — Master card database containing 1,000 active modern players ranked strictly by EA FC 26 ratings.
    *   *(Note: The server automatically instantiates `ExitQueueEvent` remote here at runtime.)*
*   📁 **ServerStorage/**
    *   *(Note: Currently empty, reserved for server-only models/modules.)*
*   📁 **ReplicatedFirst/**
    *   *(Note: Currently empty, reserved for client loading/pre-rendering scripts.)*
*   📄 [FC_Table_Duels_PRD-1.md](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/FC_Table_Duels_PRD-1.md) — The Product Requirements Document outlining features, math engines, UI design, and economic systems.
*   📄 [timeline.md](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/timeline.md) — Progress log detailing tasks completed on the project.
*   📄 [context.md](file:///c:/Users/Nafiz/Labib/Soccer-Squad-Duels/context.md) — This file.

---

## 2. Roblox Studio Explorer Tree

Some assets exist solely in Roblox Studio or are managed programmatically:

### 📁 Workspace
*   📁 **Soccer Field 1** through **Soccer Field 8** (Models)
    *   📁 **Player 1 Spot** (Model) — A boundary-defined box. Touching its parts locks Player 1 into queue.
    *   📁 **Player 2 Spot** (Model) — A boundary-defined box. Touching its parts locks Player 2 into queue (rotated 180 degrees).
    *   ⬜ **StatusAnchor** (Part) — Invisible, anchored part used as the target (`Adornee`) for the status BillboardGui.
    *   ⬜ **CountdownAnchor** (Part) — Invisible, anchored part used as the target (`Adornee`) for the countdown number BillboardGui.
*   ⬜ **FieldExitPoint** (Part) — *(Optional / Reserved)* Used as reference coordinate points to dump players when they exit fields.

### 📁 ReplicatedStorage
*   📡 **ExitQueueEvent** (RemoteEvent) — Server-created remote event that is fired by client UI buttons to request release from a locked queue spot.

### 📁 StarterGui
*   🖥️ **HUD** (ScreenGui) — Standard player HUD. Set to `Enabled = true` by default on spawn and player join.
*   🖥️ **ExitQueue** (ScreenGui) — UI containing exit button that displays only when locked in a spot. Set to `Enabled = false` by default.
    *   📁 **ExitFrame** (Frame)
        *   🔘 **ExitButton** (TextButton)
            *   📜 **ExitScript** (LocalScript) — *Managed exclusively in Studio.* Fires the remote event to exit the queue:
                ```lua
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local exitQueueEvent = ReplicatedStorage:WaitForChild("ExitQueueEvent")
                local button = script.Parent

                button.MouseButton1Click:Connect(function()
                    exitQueueEvent:FireServer()
                end)
                ```
*   🖥️ **DuelGui** (ScreenGui) — Main screen gui for card drafting, squad placement, and match reveals. Set to `Enabled = false` by default; toggles to `true` when a field countdown successfully completes.
