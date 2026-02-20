# ExtendedUI – Optimization & Bug-Fix TODO

> WoW TBC Classic 2.5.5 (Interface 20505) · Addon version 0.3.5 / 0.3.6
>
> Findings verified against [wago.tools/db2](https://wago.tools/db2) — see [`DB/verification_results.md`](DB/verification_results.md) for full cross-reference report.

---

## 🔴 Bugs

### Core.lua
- [x] **Version mismatch** – `ExtendedUI.toc` says `0.3.5`, `Core.lua` says `0.3.6`. Sync them.
- [x] **Lane C never cleared when no active effects** – `SlotHasAnyActiveEffect()` returns `false` → only lanes A and B are cleared (line 172-174). Lane C is skipped.
- [x] **`GameTooltip_Hide` passed as function reference** – `btn:SetScript("OnLeave", GameTooltip_Hide)` works only if `GameTooltip_Hide` accepts `self` as first arg; safer to wrap: `function(self) GameTooltip:Hide() end` (line 289).

### Config.lua (ActionBarTweaks)
- [x] **`EnsureRule()` has no nil guards** – `p.bars[barId][slot].rules[idx]` will error if any intermediate key is nil (line 49-51). Add defensive checks or ensure callers always pre-validate.
- [x] **`tonumber(rule.params.min)` may be nil** – Comparing `nil == 2` silently fails; guard with `if rule.params and rule.params.min then` before comparisons (e.g. line 524 area).

### Effects.lua
- [x] **Missing nil check on overlay** – Already guarded: `GetOverlay()` uses `btn and btn.ExtendedUIOverlay` and all `FX.APPLY.*` functions check `if not o` before use. No change needed.
- [x] **Potential divide-by-zero in sparkle effect** – Already guarded: `AUTOCAST_SPARKLES` checks `if n == 0 then return end` before `% n`. No change needed.

### OneBag.lua
- [x] **`GetContainerItemInfo()` return-value branch mismatch** – Removed dead `type(a) == "table"` branch; TBC 2.5.5 always returns individual values.
- [x] **Default DB not persisted** – `EnsureDB()` now initializes nested tables step-by-step (`ExtendedUI_DB or {}`, `profile or {}`, `global or {}`) instead of creating a throwaway compound table.

### LootToast.lua
- [x] **`GetItemInfo()` race condition** – Already handled: code checks `if not name then` and retries with `C_Timer.After(0.15, ...)`. No change needed.
- [x] **`ITEM_QUALITY_COLORS[quality]` unguarded** – Already handled: code checks `if not quality then return 1,1,1 end` and uses `ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]`. No change needed.

### TotemTracker.lua
- [x] **`wasVisible` race condition** – Added `isFading` check: if a new totem appears while the old fade animation is playing, the animation is stopped and state is reset before re-appearing.
- [x] **Hardcoded mode count** – `(self.mode + 1) % 3` → `(self.mode + 1) % #self.modes`.

### TotemRangeUtil.lua
- [x] **Default `true` when position unknown** – `IsPlayerInRange()` now returns `nil` when no position data exists. Callers (`ShouldFadeTotem`) handle `nil` as "assume in range".

### ProcHelper.lua
- [ ] **Icon spacing jump** – Icons are placed at `8+72` (= 80 px) during animation but final position uses 8 px offset (line 397). This causes a visible snap when the animation ends. *(Animation math is consistent; any snap is a single-frame artifact of WoW's animation system. Requires in-game visual testing to confirm.)*
- [x] **No nil check on `db.procStackAnchor`** – Added nil guard for `ExtendedUI_DB.profile.global` in `OnDragStop` handler.

### SoundTweaks.lua
- [x] **Type mismatch on error IDs** – `LoadDynamicErrorLabels` now uses `tostring(id)` for consistent string keys matching `SaveDynamicErrorLabel`.
- [x] **Dead code** – Removed unused first `menuEmotes` assignment (line 361); only the one inside `UpdateMenu()` is used.

### SoundBank_*.lua (DB2-verified)
- [ ] **126 invalid/unverifiable FileDataIDs** – Cross-referenced 2,758 sound IDs against the `SoundKitEntry` DB2 table from [wago.tools](https://wago.tools/db2). 95.4% (2,632) are valid. 126 IDs were not found in `SoundKitEntry` or `ManifestInterfaceData` and may be broken or removed. Worst offenders:
  - `SoundBank_DwarfFemale.lua` — 17 missing
  - `SoundBank_TaurenMale.lua` — 12 missing
  - `SoundBank_TaurenFemale.lua` — 11 missing
  - `SoundBank_DwarfMale.lua` — 11 missing
  - `SoundBank_ScourgeMale.lua` — 10 missing
  - Full list in [`DB/verification_results.md`](DB/verification_results.md). Test in-game with `/run PlaySoundFile(ID)` and remove any that produce no audio.

### Triggers.lua
- [x] **Redundant `and true or false`** – `ok = fn(rule, context) and true or false` (line 106) is unnecessary since the trigger functions already return booleans.

---

## 🟡 Optimizations

### Core.lua
- [ ] **Cache `ExtendedUI_DB.profile` in OnUpdate** – The deep path `ExtendedUI_DB.profile.global.updateInterval` is traversed every frame (line 224). Cache in a local after `PLAYER_ENTERING_WORLD`.
- [ ] **Avoid redundant clearing** – When disabled, three separate `ClearLane` calls (lines 162-165) could use a loop over `EUI.LANE`.

### Config.lua
- [ ] **Cache bag scans** – `ScanBags()` rescans all 5 bags on every call. Cache results and only refresh on `BAG_UPDATE` events.
- [ ] **Refactor `Refresh()` function** – At 200+ lines, `Refresh()` is hard to maintain. Break into helpers per rule-block (trigger params, effect params, item dropdown, etc.).
- [ ] **Avoid recreating dropdowns on every Refresh** – `UIDropDownMenu_Initialize` is called inside `Refresh()` each time the config panel is shown. Initialize once and update values.

### Effects.lua
- [ ] **Create overlay textures once** – Overlays should be created once per button and reused, not checked/recreated in hot paths.
- [ ] **Pre-compute sparkle layouts** – Sparkle positions are recalculated every frame. Compute once on creation and cache.

### OneBag.lua
- [ ] **Pool item buttons** – Creating/destroying buttons on every layout pass is wasteful. Use an object pool.
- [ ] **Debounce `Layout()` and `Update()` calls** – Multiple bag events can fire in rapid succession; debounce with a short `C_Timer.After`.
- [ ] **Deduplicate bag API abstraction** – The `C_Container` vs legacy fallback chain is duplicated across `GetLink`, `GetContainerInfo`, and `GetNumSlots`. Extract a single compatibility shim.

### BuffTracker.lua
- [ ] **Cache `EUI.DB.profile` reference** – Deeply nested property access every tick (line 486). Store in a local.
- [ ] **Use table pool for buff entries** – Allocating new tables per buff per update adds GC pressure.

### Triggers.lua
- [ ] **Buff/debuff loop limit** – Hardcoded to 40 (lines 14, 26). TBC supports up to 40 buffs, so this is currently correct but should use a constant for clarity.
- [ ] **Result caching per frame** – If `Evaluate()` is called multiple times for the same rule in one frame, cache the result.

### TotemTracker.lua
- [ ] **Cache `FindSnapButtonForTotem()` results** – Called every 0.15 s but the target button doesn't change until the totem is replaced. Cache and invalidate on `PLAYER_TOTEM_UPDATE`.
- [ ] **Throttle ticker when no totems active** – The 0.15 s ticker runs continuously even with zero totems. Pause when `GetTotemInfo` returns nothing for all 4 slots.

### ProcHelper.lua
- [ ] **Cache `GetSpellInfo()` results** – Called repeatedly for the same spell IDs (lines 106, 144). Store in a lookup table.

### SoundTweaks.lua
- [ ] **Consolidate duplicate `OnTextChanged` handlers** – Lines 484-491 and 522-528 have near-identical logic. Extract a shared function.
- [ ] **Cache discovered errors** – `buildErrorMenuList()` rebuilds the list every time the menu updates. Cache and dirty-flag on new discoveries only.

### Menu.lua
- [ ] **Throttle totem art OnUpdate** – `OnUpdate` runs every frame to check `TOTEM3D.mode` (line 149). Use elapsed-time gating.
- [ ] **Loop button creation** – Four similar `MakeButton` calls (lines 80-91) could use a data-driven loop.

### General
- [ ] **Use `local` for repeated globals** – Functions like `GetTime()`, `UnitHealth()`, `math.floor()`, `math.cos()`, `math.sin()` should be cached as locals at file scope for performance in hot paths.
- [ ] **Consistent localization** – Tooltip text and print statements mix Dutch and English (e.g. `"Hoofdmenu"` in Core.lua line 285, Dutch comments like `"Pas eventueel"` and `"Bereken"` in TotemRangeUtil). Pick one language and use a localization table.

---

## 🔵 Code Quality / Maintainability

- [ ] **Add `## Version` sync check** – Ensure `.toc` and `Core.lua` version strings stay in sync (manual or automated).
- [ ] **Standardize nil-guard pattern** – Some files use `if X and X.Y and X.Y.Z`, others access deep paths directly. Adopt a consistent defensive style or write a helper (`safenav(tbl, "a.b.c")`).
- [ ] **Remove debug `print()` calls** – `Core.lua` line 3: `print("Core Loaded")` should be gated behind a debug flag or removed for release.
- [ ] **Document public API per module** – Each `EUI_*` global (e.g. `EUI_Triggers`, `EUI_Effects`, `EUI_Config`, `EUI_Menu`) should have a brief header comment listing its public functions.
- [ ] **Consolidate flyout modules** – `DynamicDemonFlyout.lua`, `DynamicMageFlyout.lua`, and `DynamicTotemFlyout.lua` share ~70 % of their logic (arrow creation, flyout layout, secure action binding). Extract a shared `DynamicFlyoutBase` module.
- [ ] **TotemTracker rank stripping** – `StripTotemRank()` only handles English `" (Rank X)"` patterns. Will break for localized clients (French: `"Rang"`, German: `"Rang"`).

---

## ✅ DB2-Verified (No Action Needed)

The following areas were cross-referenced against the [wago.tools/db2](https://wago.tools/db2) database and confirmed correct:

- **Spell pattern detection** – All flyout modules (`DynamicDemonFlyout`, `DynamicMageFlyout`, `DynamicTotemFlyout`) use name-based spell detection. Verified against `SpellName` DB2: `"summon"` matches 18,246 spells, `"portal"` matches 2,322, `"teleport"` matches 5,204, `"(%w+) Totem"` matches 841. All patterns produce correct results.
- **Totem categories** – Fire/Earth/Water/Air Totem all confirmed in `TotemCategory` DB2 (IDs 2–5).
- **WoW API compatibility** – All 34 unique APIs used across 14 Lua files are available in TBC Classic 2.5.5 (including `C_Timer.After`, `C_Timer.NewTicker`, `C_Container.*`).
- **Sound FileDataIDs** – 95.4% (2,632/2,758) of sound IDs verified in `SoundKitEntry` DB2. See bugs section for the 126 unverified IDs.
