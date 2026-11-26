# BloxStrike Full Recon
**GameId**: 7633926880 | **PlaceId**: 114234929420007 | **Version**: v9965  
**Mode**: Private server, passive reads only. No shots fired, no namecall hooks.

---

## Entry Point

`Players.LocalPlayer.PlayerScripts.Startup`  
- Loads every ModuleScript in `RS.Controllers:GetChildren()` via a phased startup system
- Each controller gets `Initialize` called synchronously, then `Start` queued on a background thread
- Uses `RS.Shared.Profiler` for perf marks

---

## Module Paths (all confirmed)

```
RS.Components.Common.PlayerHitPrediction   ← hit record/consume anti-rewind
RS.Components.Common.CharacterResolver
RS.Components.Common.GetCharacterVelocity
RS.Components.Common.Participants
RS.Components.Common.ReplicateCharacterAction

RS.Components.Weapon                       ← full weapon logic entry
RS.Components.Weapon.Classes.Bullet        ← BulletClass (sub-module of Weapon)
RS.Components.C4                           ← C4 plant/defuse logic

RS.Controllers.CameraController            ← spring-based sway + recoil
RS.Controllers.AimAssistController         ← recoil assist scale
RS.Controllers.ESPController               ← game's own ESP (exists client-side)

RS.Classes.WeaponComponent                 ← base weapon class

RS.Database.Components.GameState           ← workspace-attribute game state
RS.Database.Components.Common.RecoilPatterns ← deterministic spray patterns
RS.Database.Custom.Weapons.SprayPatterns   ← folder of Parts (spray keyframes)
RS.Database.Custom.Types

RS.Database.Security.Remotes               ← AC remote wrapper (wraps BAC)
RS.Database.Security.Router                ← AC routing layer
RS.Database.Security.Network               ← BufferCodec child — packet encoding

RS.Shared.Profiler
RS.Packages.Observers
```

---

## PlayerHitPrediction (RS.Components.Common.PlayerHitPrediction)

Simple ring buffer — records predicted hits, consumes them on server confirmation.

```lua
-- Record(shotSeq, victimUserId, hitPartName, position)
--   Stores up to 64 entries, prunes entries older than 1 second
v1.Record(shotSeq, victimUserId, hitPartName, position)

-- Consume(shotSeq, victimUserId, hitPartName, position) → boolean
--   Returns true if a matching record exists within 6 studs, removes it
v1.Consume(shotSeq, victimUserId, hitPartName, position)
```

**Key limits**: 64-entry cap, 1-second TTL, 6-stud position tolerance.  
This is NOT an AC — it's the weapon system's lag compensation bookkeeping.

---

## GameState (RS.Database.Components.GameState)

State stored as `workspace:GetAttribute("GameState")`.

**Valid states**:
```
"Map Voting"
"Game Ending"
"Warmup"
"Round In Progress"
"Buy Period"
"Intermission"
```

**Other workspace attributes**:
- `ScheduledGameState` — next state queued
- `ScheduledGameStateServerTime` — when it triggers
- `PreviousGameState` — last state
- `GameStateTransitionServerTime` — transition timestamp

**Read from client**:
```lua
workspace:GetAttribute("GameState")  -- current state string
```

---

## Character Structure

**Rig**: R15 + extras. **NO Humanoid instance.**  
Health is attribute-based on the character Model.

**Bones (all confirmed)**:
```
Head
UpperTorso
LowerTorso
HumanoidRootPart
LeftFoot, LeftLowerLeg, LeftUpperLeg
RightFoot, RightLowerLeg, RightUpperLeg
LeftHand, LeftLowerArm, LeftUpperArm
RightHand, RightLowerArm, RightUpperArm
CameraPart          ← extra, ~0.5 studs above Head
```

**Character children (non-bones)**:
```
CharacterArmor      (Model)
WeaponModel         (Folder)
WeaponAttachments   (Folder)
AnimationController
```

**Position reference** (approximate, standing):
- HumanoidRootPart: ~Y 11.5
- Head: ~Y 12.92
- CameraPart: ~Y 13.41

---

## Player Attributes (all confirmed)

Read from `player.Character:GetAttribute(key)` or `player:GetAttribute(key)`.  
Health/combat attrs are on the **Character Model**, not the Player instance.

| Attribute | Type | Notes |
|-----------|------|-------|
| Health | number string | Current HP |
| MaxHealth | number string | Max HP |
| Armor | JSON | `{"Health":100,"Type":"Kevlar + Helmet"}` |
| Dead | bool string | "true"/"false" |
| Team | string | "Terrorists" or "Counter-Terrorists" |
| Kills | number string | |
| Deaths | number string | |
| Assists | number string | |
| Score | number string | |
| Money | number string | |
| Ping | number string | |
| IsCrouching | bool string | |
| IsJumping | bool string | |
| IsWalking | bool string | |
| IsClimbing | bool string | |
| IsSniperScoped | bool string | |
| IsSpectating | bool string | |
| SpectatePerspective | bool string | |
| Spectators | number string | count of spectators on this player |
| HasDefuseKit | bool string | |
| HasRescueKit | bool string | |
| CurrentEquipped | JSON | `{"Identifier":"...","_id":"T Knife_Stock","Name":"T Knife","Skin":"Stock","Float":0,"Charm":false,"StatTrack":false,"NameTag":false,"Stickers":[]}` |
| Slot2 | JSON | `{"Weapon":"Glock-18","Skin":"Stock","Charm":false,...}` |
| Slot3 | JSON | knife slot |
| PresentationCharacterName | string | skin/model name e.g. "Anarchist" |
| PresentationEquippedGloves | JSON | `{"Name":"T Glove","Skin":"Stock","SkinIdentifier":"...","Float":0}` |
| PresentationSpawnPosition | Vector3 string | |
| PresentationSpawnYaw | number string | |
| PresentationGeneration | number string | |
| CharacterGeneration | number string | increments on respawn |
| SpawnIndex | number string | |
| SK | bool string | (unknown, likely stat-track flag) |
| ScopeIncrement | number string | zoom level |
| BuyMenu | bool string | whether buy menu is open |
| CanUseVIPMenu | bool string | |
| DataLoaded | bool string | |
| PinVerified | bool string | |
| MinimumNextRoundIncome | number string | |
| DailyMissionCreditRewardMultiplier | number string | |
| HourlyMissionCreditRewardMultiplier | number string | |
| WeeklyMissionCreditRewardMultiplier | number string | |
| MonthlyMissionCreditRewardMultiplier | number string | |

---

## Workspace Structure

```
Workspace
├── Characters
│   ├── Terrorists          ← folder of character Models
│   ├── Counter-Terrorists  ← folder of character Models
│   ├── Hostages
│   └── <username>          ← local player's own character
├── Debris
│   ├── __PreparedRagdoll_<name>
│   ├── __PooledRagdoll
│   ├── Magazines
│   ├── BulletMarkers
│   └── ImpactMarkers
├── Map
│   ├── Geometry            ← 3297+ parts
│   └── Ambience
└── Camera                  ← contains Glock-18 viewmodel
```

**Locating enemies**:
```lua
-- All enemy characters are under their team folder
workspace.Characters["Terrorists"]       -- or "Counter-Terrorists"
-- Each child is a character Model with the player's display name
-- Check player:GetAttribute("Dead") == "false" before drawing
```

**C4 bomb sites**: Parts tagged `"PlantArea"` with attribute `"Site"` (string, site name).  
Raycast from character position downward -5Y to detect valid plant zone.

---

## C4 System (RS.Components.C4)

**Plant detection**: Raycast down 5 studs, check for `CollectionService:HasTag("PlantArea")` and `instance:GetAttribute("Site")`.

**Plant remote sequence**:
```lua
Remotes.C4.Start.Send(identifier)       -- begin plant animation
-- ... animation completes ...
Remotes.C4.Planted.Send(identifier)     -- confirm plant
```

**All C4 remotes** (`RS.NetworkRemotes.C4.*`):
```
Planted
Cancel
ForceCancel
Start
StartDefuse
Defused
CancelDefuse
```

**C4 ESP approach**: Listen to `RS.NetworkRemotes.C4.Planted` inbound (FireServer call) to track when/where C4 is planted. Scan workspace for planted C4 model after event fires.

---

## RecoilPatterns (RS.Database.Components.Common.RecoilPatterns)

Deterministic spray — NOT random. Returns a function per weapon.

**Data source**: `RS.Database.Custom.Weapons.SprayPatterns` — folder of Parts per weapon.  
Each Part's WorldCFrame position encodes the spray offset as X/Z → Vector2.

**Usage**:
```lua
local patterns = require(RS.Database.Components.Common.RecoilPatterns)
-- patterns["Glock-18"] = function(weaponData) → function(elapsedTime) → Vector2
local getOffset = patterns[weaponName](weaponData)
local offset = getOffset(elapsedTime)  -- Vector2 recoil offset at given time
```

**weaponData** needs `FireRate` and `Rounds` fields.

---

## Security / AC Layer

**AC remote**: `RS.Remotes.BAC` (single RemoteEvent)  
**Network layer**: `RS.Database.Security.Network` (has `BufferCodec` child)  
**Router**: `RS.Database.Security.Router`  
**Remotes wrapper**: `RS.Database.Security.Remotes` — all game remotes go through this

**Key rule**: Never fire `RS.Remotes.BAC` directly. All normal remotes go through the Security.Remotes wrapper which handles encoding. Calling raw `:FireServer()` on game remotes bypasses the codec and trips the AC.

---

## All RemoteEvents

### Anti-Cheat
- `RS.Remotes.BAC`

### C4
`RS.NetworkRemotes.C4.{Planted, Cancel, ForceCancel, Start, StartDefuse, Defused, CancelDefuse}`

### Weapons / Inventory
```
ShootWeapon, ReloadWeapon, DropWeapon, PickupWeapon
BuyMenuPurchase, ReturnBuyMenuPurchase, LoadoutResponse
CreateMagazine, EquipSpecialItem, WeaponEquipResolved
UpdateWeaponSuppressor, UpdateScopeIncrement
CreateGameLoadout, CleanupGameLoadout, RefillAmmo
UpdateStatTrack, UpdateWeaponCharm, RemoveWeaponCharm
SwapLoadoutSkins, EquipLoadoutSkin
SpectatedPlayerInventory, RequestSpectatedPlayerInventory
NewInventoryItem, RemoveInventoryItem
```

### Character
`CharacterDied, CharacterDamaged, Action`

### Projectile
`Resolve, Bounce, Spawn`

### VFX
```
CreateMarker, ReplicateFinisher, CreateBloodSplatter
BreakGlass, FlashPlayer, CreateTracer
CreateCharacterMuzzleFlash, CreateImpact
CreateVoxelFire, CreateVoxelSmoke, DestroyVoxelFire, DestroyVoxelSmoke
DisruptVoxelSmoke, CleanupDebris, UpdateVoxelFire
```

### Player
```
ReportPlayerConnect, PressedPlay, AFKTeleport
UpdatePlayerSettings, SubmitPlayerReport, BlankRequest
SetViewmodelHand, MarkTutorialPrompted, MarkShopVersionViewed
NewInventoryItemsSeen, SubmitUserPlatformAnalytics, UpdateMobileButtons
```

### UI
```
RoundMVP, UIPlayerKilled, ShowDeathCard, ShowNotification
CreateDamageIndicator, RoundDamageMatrix, RoundWinner
TeammateGrenades, CreateMenuNotification
EquipCreatorCode, UpdateCreatorCode
```

### Match / Map Vote
`EndScreen, UpdateMapVote, SubmitMapVote, StartMapVote, RequestMapVote, EndMapVote`

### Sound
`StopSoundAtPosition, ReplicateSound`

### Hostage
`StartRescue, PickedUp, CancelRescue`

### Spectate
`StopSpectating, SpectatePlayer, SetSpectatePerspective, StartSpectating`

### Vote Kick
`CallVote, StartVote, EndVote, VoteYes, VoteNo, VoteYesUpdate, VoteNoUpdate`

### Chat
```
ChatPlayerLeave, ChatPlayerBanned, ChatGrenadeThrow, ChatTeamJoin
ServerChat, ClientChat, ServerTeamChat, ChatSystemMessage
ChatDefuseStart, ChatMoneyReward, ChatPlayerKilled, ChatTradeUp
ChatCaseOpened, ChatTeamDamage
```

### VIP
`ExecuteAction, SyncState, SetSetting, RequestData, DataResponse`

### Ping / Position
`CreatePlayerPositionPing`

### Modes / Servers
`SendPlayerCounts, FetchServers, SelectGamemode, FetchPlayerCounts`

### Bomb Site Hints
`BombSiteExited, BombSiteEntered, ClearHint`

### Entity
`InteractWithEntity, CreateEntity, DestroyEntity`

### Survival Mode
`CollectCandy, StartRevive, CancelRevive, CandyVacuum, CandyDrop`

### Horde Mode
`Clear, Remove, Sync, Hit, Death, Spawn`  
`HordeStream` (UnreliableRemoteEvent)

### Halloween
`Spin, SpinResult`

### Career / Stats
`MatchDetails, Statistics, RequestStatistics, RequestMatchDetails`

### Store / Marketplace
`OpenCase, PurchaseCase, TradeUpItems`  
`GlobalMarketplace.*` (multiple)

---

## CameraController Notes (RS.Controllers.CameraController)

- Spring-based camera sway system
- Base CFrame stored as `u88` internally
- Multiple Spring instances compose final camera CFrame
- Uses `AimAssistController` to scale recoil assist
- **Do not hook this for aimbot** — recoil compensation should be done at the offset level (RecoilPatterns), not by fighting the spring system

---

## Require Fixes for bloxstrike.lua

Three broken requires at top of script. Correct paths:

```lua
-- WRONG (old):
-- local BulletClass = require(RS.BulletClass)           -- didn't exist
-- local WeaponClass = require(RS.WeaponClass)           -- didn't exist
-- local CameraController = require(RS.CameraController) -- wrong path

-- CORRECT:
local BulletClass = require(RS.Components.Weapon.Classes.Bullet)
local WeaponClass = require(RS.Classes.WeaponComponent)
local CameraController = require(RS.Controllers.CameraController)
```