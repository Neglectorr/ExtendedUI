local EUI = ExtendedUI
EUI_BuffTracker = {}
local BT = EUI_BuffTracker
EUI.BuffTracker = BT

local GetTime = GetTime
local UnitBuff = UnitBuff
local GetTotemInfo = GetTotemInfo
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local pairs = pairs
local ipairs = ipairs
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local math_floor = math.floor
local string_format = string.format
local table_insert = table.insert
local table_sort = table.sort
local wipe = wipe

local MAX_AURAS = 40

local COLS, ROWS = 8, 6
local SPELLS_PER_PAGE = COLS * ROWS
local FADER_TIME = 0.5
local TOTEM_SLOTS = 4

local TotemRangeUtil = _G.TotemRangeUtil

local duration_patterns = {
  "[Ll]asts%s*(%d+)%s*(%a+)",
  "for%s*(%d+)%s*(%a+)",
  "over%s*(%d+)%s*(%a+)",
}

local function StripTotemRank(name)
  if not name then return nil end
  local out = name
  out = out:gsub(" %u+$", "")
  out = out:gsub(" %(Rank %d+%)", "")
  out = out:gsub(" %(Rang %d+%)", "")
  out = out:gsub("^%s*(.-)%s*$", "%1")
  return out
end

local function SpellTooltipDuration(spellId)
  if not spellId then return nil end
  local tip = CreateFrame("GameTooltip", "EUI_BuffScanTooltip", nil, "GameTooltipTemplate")
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:SetSpellByID(spellId)
  for i=2, tip:NumLines() do
    local text = _G[tip:GetName().."TextLeft"..i]:GetText()
    if text then
      for _, p in ipairs(duration_patterns) do
        local num, unit = text:match(p)
        if num and unit then
          num = tonumber(num)
          unit = unit:lower()
          if unit == "sec" or unit == "secs" then
            return num
          elseif unit == "min" or unit == "mins" then
            return num * 60
          end
        end
      end
    end
  end
  return nil
end

local function GetSpellListFiltered()
  local spellList = {}
  for tab=1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for idx=1, numSpells do
      local slot = offset + idx
      local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
      local type, spellId = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
      if spellId and type == "SPELL" then
        local dura = SpellTooltipDuration(spellId)
        if dura then
          table.insert(spellList, {
            name=name,
            spellId=spellId,
            icon=GetSpellTexture(spellId),
            duration=dura
          })
        end
      end
    end
  end
  table.sort(spellList, function(a, b) return a.name < b.name end)
  return spellList
end

local function GetSpellListAll()
  local spellList = {}
  for tab=1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for idx=1, numSpells do
      local slot = offset + idx
      local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
      local type, spellId = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
      if spellId and type == "SPELL" then
        table.insert(spellList, {
          name=name,
          spellId=spellId,
          icon=GetSpellTexture(spellId)
        })
      end
    end
  end
  table.sort(spellList, function(a, b) return a.name < b.name end)
  return spellList
end

function BT:EnsureConfigMenu()
  if self.menu then return end
  local f = CreateFrame("Frame", "EUIBuffTrackerConfig", UIParent, "BasicFrameTemplateWithInset")
  self.menu = f
  f:SetFrameStrata("DIALOG")
  f:SetSize(90*COLS, 66*ROWS)
  f:SetPoint("CENTER")
  f:SetFrameLevel(4)
  --f:SetBackdrop({
  --  bgFile = "Interface\\Buttons\\WHITE8x8",
  --  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  --  tile = true, tileSize = 16, edgeSize = 16,
  --  insets = { left = 4, right = 4, top = 4, bottom = 4 }
  --})
  --f:SetBackdropColor(0,0,0,0.93)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -5)
  title:SetText("Buff Tracker")
  --local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  --close:SetPoint("TOPRIGHT", -6, -6)
  --close:SetScript("OnClick", function()
  -- f:Hide()
  --  if EUI_Menu and EUI_Menu.hub then EUI_Menu.hub:Show() end
  --end)
  f.filterMode = "detected"
  f.currentPage = 1
  local filterButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  filterButton:SetSize(170, 22)
  filterButton:SetPoint("BOTTOMLEFT", 16, 16)
  f.filterButton = filterButton
  local function UpdateButtonLabel()
    if f.filterMode == "detected" then
      filterButton:SetText("Show all spells")
    else
      filterButton:SetText("Show detected buffs only")
    end
  end
  f.spells_all = {}
  f.spells_detected = {}
  f.currentList = {}
  f.refreshList = function()
    f.spells_detected = GetSpellListFiltered()
    f.spells_all = GetSpellListAll()
    if f.filterMode == "detected" then
      f.currentList = f.spells_detected
    else
      f.currentList = f.spells_all
    end
  end
  local buttons = {}
  local ICON_SIZE, PADDING_X, PADDING_Y = 44, 8, 8
  for i=1, COLS*ROWS do
    local btn = CreateFrame("Button", "EUIBuffTrackerSpell" .. i, f)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.glow = btn:CreateTexture(nil, "OVERLAY")
    btn.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    btn.glow:SetAllPoints(btn)
    btn.glow:SetBlendMode("ADD")
    btn.glow:Hide()
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:Hide()
    table.insert(buttons, btn)
  end
  local function ShowTooltip(btn, spellId)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(spellId)
    GameTooltip:Show()
  end
  local function NumPages()
    return math.ceil(#f.currentList/(COLS*ROWS))
  end
  local function RenderGrid()
    for i, btn in ipairs(buttons) do btn:Hide() end
    f.tracked = EUI.DB and EUI.DB.profile.global.buffTrackerList or {}
    local page = f.currentPage or 1
    for i=1, COLS*ROWS do
      local spellIdx = (page-1)*COLS*ROWS + i
      local spell = f.currentList[spellIdx]
      local btn = buttons[i]
      if spell then
        local c = ((i-1)%COLS)
        local r = math.floor((i-1)/COLS)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT",
          24 + c*(ICON_SIZE+PADDING_X),
          -48 - r*(ICON_SIZE+PADDING_Y)
        )
        btn.icon:SetTexture(spell.icon)
        btn.spellId = spell.spellId
        btn:Show()
        if (EUI.DB.profile.global.buffTrackerList and EUI.DB.profile.global.buffTrackerList[spell.spellId]) then
          btn.glow:Show()
        else
          btn.glow:Hide()
        end
        btn:SetScript("OnEnter", function(self) ShowTooltip(self, spell.spellId) end)
        btn:SetScript("OnClick", function(self)
          local lst = EUI.DB.profile.global.buffTrackerList or {}
          if lst[spell.spellId] then
            lst[spell.spellId] = nil
          else
            lst[spell.spellId] = true
          end
          EUI.DB.profile.global.buffTrackerList = lst
          RenderGrid()
        end)
      else
        btn:Hide()
      end
    end
    f.pageLabel:SetText(string.format("Page %d / %d", page, math.max(1,NumPages())))
    f.prevBtn:SetEnabled(page>1)
    f.nextBtn:SetEnabled(page<NumPages())
  end
  local prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  prevBtn:SetSize(40, 22)
  prevBtn:SetPoint("BOTTOMLEFT", 250, 16)
  prevBtn:SetText("<")
  prevBtn:SetScript("OnClick", function()
    f.currentPage = math.max(1, (f.currentPage or 1)-1)
    RenderGrid()
  end)
  f.prevBtn = prevBtn
  local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  nextBtn:SetSize(40, 22)
  nextBtn:SetPoint("BOTTOMLEFT", 350, 16)
  nextBtn:SetText(">")
  nextBtn:SetScript("OnClick", function()
    f.currentPage = math.min(NumPages(), (f.currentPage or 1)+1)
    RenderGrid()
  end)
  f.nextBtn = nextBtn
  local pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pageLabel:SetPoint("BOTTOMLEFT", 315, 23)
  pageLabel:SetText("Page 1/1")
  f.pageLabel = pageLabel
  filterButton:SetScript("OnClick", function()
    if f.filterMode == "detected" then
      filterButton:SetText("Show all spells")
    else
      filterButton:SetText("Show detected buffs only")
    end
    f.filterMode = (f.filterMode=="detected") and "all" or "detected"
    f.currentPage = 1
    f.refreshList()
    RenderGrid()
  end)
  local placeholder = CreateFrame("Frame", "EUIBuffTrackerAnchor", UIParent, "BackdropTemplate")
  placeholder:SetSize(180, 36)
  placeholder:SetFrameStrata("DIALOG")
  placeholder:SetMovable(true)
  placeholder:SetClampedToScreen(true)
  placeholder:EnableMouse(true)
  placeholder:RegisterForDrag("LeftButton")
  placeholder:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
  placeholder:SetBackdropColor(0.15,0.4,0.15,0.18)
  placeholder.text = placeholder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  placeholder.text:SetPoint("CENTER")
  placeholder.text:SetText("BuffTracker position")
  placeholder:SetScript("OnDragStart", function() placeholder:StartMoving() end)
  placeholder:SetScript("OnDragStop", function()
    placeholder:StopMovingOrSizing()
    EUI.DB.profile.global.buffTrackerAnchor = {select(1,placeholder:GetPoint()),select(4,placeholder:GetPoint())}
  end)
  placeholder:Hide()
  f.placeholder = placeholder
  f:SetScript("OnShow", function()
    if not EUI.DB then EUI.DB = ExtendedUI_DB end
    if not EUI.DB.profile.global.buffTrackerList then EUI.DB.profile.global.buffTrackerList = {} end
    f.refreshList()
    f.currentPage = 1
    UpdateButtonLabel()
    RenderGrid()
    local a = EUI.DB.profile.global.buffTrackerAnchor
    placeholder:ClearAllPoints()
    if a then
      placeholder:SetPoint(unpack(a))
    else
      placeholder:SetPoint("CENTER")
    end
    placeholder:Show()
  end)
  f:SetScript("OnHide", function() placeholder:Hide() end)
  local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  closeBtn:SetSize(100, 22)
  closeBtn:SetPoint("BOTTOMRIGHT", -16, 16)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function()
    f:Hide()
    if EUI_Menu and EUI_Menu.hub then EUI_Menu.hub:Show() end
  end)
  f:Hide()
end

function BT:ToggleConfigMenu()
  self:EnsureConfigMenu()
  if self.menu:IsShown() then self.menu:Hide() else self.menu:Show() end
end

function BT:EnsureTrackerFrame()
  if self.frame then return end
  local f = CreateFrame("Frame", "EUIBuffTrackerFrame", UIParent)
  self.frame = f
  f:SetSize(220, 48)
  f:SetFrameStrata("HIGH")
  f:SetMovable(false)
  f:SetClampedToScreen(true)
  f.bars = {}
end

function BT:UpdateAnchor()
  local db = EUI.DB.profile.global
  local a = db and db.buffTrackerAnchor
  self:EnsureTrackerFrame()
  local f = self.frame
  f:ClearAllPoints()
  if a then
    f:SetPoint(unpack(a))
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
  end
end

-- Reusable table pool for buff entries to reduce GC pressure
local _buffPool = {}
local _buffPoolSize = 0
local function AcquireBuff()
  if _buffPoolSize > 0 then
    local b = _buffPool[_buffPoolSize]
    _buffPool[_buffPoolSize] = nil
    _buffPoolSize = _buffPoolSize - 1
    return b
  end
  return {}
end
local function ReleaseBuff(b)
  wipe(b)
  _buffPoolSize = _buffPoolSize + 1
  _buffPool[_buffPoolSize] = b
end

local function PlayerHasTotemBuff(slot)
  for i = 1, MAX_AURAS do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if name and name:lower():find("totem") then
      return true
    end
  end
  return false
end

local function TrackActiveTotems(buffs, tracked)
  if not GetTotemInfo then return end
  for slot=1,TOTEM_SLOTS do
    local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
    if haveTotem and name and duration and duration > 0 then
      local slotname = StripTotemRank(name)
      for spellId in pairs(tracked) do
        local spellBookName = GetSpellInfo(spellId)
        local trackedname = StripTotemRank(spellBookName)
        if slotname and trackedname and slotname == trackedname then
          local remains = (startTime + duration) - GetTime()
          if remains > 0 then
            local fade = false
            if not TotemRangeUtil:IsPlayerInRange(slot) then
              fade = true
            end
            if (IsInInstance and IsInInstance()) and not PlayerHasTotemBuff(slot) then
              fade = true
            end
            buffs["_TOTEMSLOT_"..slot] = {
              icon = icon,
              duration = duration,
              remains = remains,
              trackedName = name,
              trackedSlot = slot,
              fade = fade
            }
          end
        end
      end
    end
  end
end

local _lastBuffs = {}

local function GetActiveTrackedBuffs()
  -- Release previously allocated buff entries back to pool
  for i = #_lastBuffs, 1, -1 do
    ReleaseBuff(_lastBuffs[i])
    _lastBuffs[i] = nil
  end

  local db = EUI.DB and EUI.DB.profile and EUI.DB.profile.global
  local tracked = db and db.buffTrackerList or {}
  local buffs = {}

  for i = 1, MAX_AURAS do
    local _, icon, count, _, duration, expires, _, _, _, spellId = UnitBuff("player", i)
    if spellId and tracked[spellId] then
      local remains = expires and (expires - GetTime()) or 0
      if remains > 0 then
        local entry = AcquireBuff()
        entry.icon = icon
        entry.duration = duration
        entry.expires = expires
        entry.remains = remains
        entry.count = count or 0
        buffs[spellId] = entry
      end
    end
  end

  TrackActiveTotems(buffs, tracked)

  local b = {}
  for _, v in pairs(buffs) do b[#b + 1] = v end
  table_sort(b, function(a, b) return a.remains > b.remains end)
  _lastBuffs = b
  return b
end

function BT:UpdateTrackerBars()
  if not self.frame then self:EnsureTrackerFrame() end
  local f = self.frame
  local buffs = GetActiveTrackedBuffs()
  local barHeight, spacing = 26, 4
  local iconW, padX = 26, 8
  for i, info in ipairs(buffs) do
    local bar = f.bars[i]
    if not bar then
      bar = CreateFrame("Frame", nil, f)
      bar:SetSize(200, barHeight)
      bar.icon = bar:CreateTexture(nil, "ARTWORK")
      bar.icon:SetSize(iconW, iconW)
      bar.icon:SetPoint("LEFT", padX, 0)
      bar.prog = bar:CreateTexture(nil, "OVERLAY")
      bar.prog:SetHeight(barHeight-6)
      bar.prog:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
      bar.progBaseW = 120
      bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      bar.time:ClearAllPoints()
      bar.time:SetPoint("LEFT", bar.prog, "LEFT", 6, 0)
      bar.time:SetJustifyH("LEFT")
      bar.fadeGroup = bar:CreateAnimationGroup()
      local move = bar.fadeGroup:CreateAnimation("Translation")
      move:SetOffset(0, 24)
      move:SetDuration(FADER_TIME)
      move:SetSmoothing("OUT")
      local fade = bar.fadeGroup:CreateAnimation("Alpha")
      fade:SetFromAlpha(1)
      fade:SetToAlpha(0)
      fade:SetDuration(FADER_TIME)
      fade:SetSmoothing("OUT")
      bar.fadeGroup:SetScript("OnFinished", function()
        bar:Hide()
        bar:SetAlpha(1)
        bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((i-1)*(barHeight+spacing)))
        bar.inFade = nil
      end)
      -- Charge text overlay
      bar.charge = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      bar.charge:SetPoint("TOPRIGHT", bar.icon, "CENTER", 4, 6)
      bar.charge:SetJustifyH("RIGHT")
      bar.charge:SetTextColor(1,1,0)
      bar.charge:Hide()
      f.bars[i] = bar
    end
    bar:Show()
    bar.inFade = nil

    -- UI fade: bar and elements transparent when info.fade is active
    local fadedAlpha = (info.fade and info.fade == true) and 0.26 or 1
    bar:SetAlpha(fadedAlpha)
    bar.icon:SetAlpha(fadedAlpha)
    bar.prog:SetAlpha(fadedAlpha)
    bar.time:SetAlpha(fadedAlpha)
    if bar.charge then bar.charge:SetAlpha(fadedAlpha) end

    bar.icon:SetTexture(info.icon)
    bar.prog:ClearAllPoints()
    bar.prog:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
    local frac = math.max(0, math.min(1, (info.remains/(info.duration or 1))))
    bar.prog:SetWidth(bar.progBaseW*frac)
    bar.prog:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar.prog:SetVertexColor(1-frac, frac, 0, 0.93)
    bar.time:SetText(string.format("%.0f", info.remains))
    bar.time:Show()
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((i-1)*(barHeight+spacing)))
    bar:SetHeight(barHeight)
    -- Charge/stack display
    if info.count and info.count > 1 then
      bar.charge:SetText(info.count)
      bar.charge:Show()
    else
      bar.charge:Hide()
    end
  end
  for i=#buffs+1, #f.bars do
    local bar=f.bars[i]
    if bar and bar:IsShown() and not bar.inFade then
      bar.inFade = true
      if bar.fadeGroup then bar.fadeGroup:Play() else bar:Hide() end
    end
  end
  f:SetSize(220, (#buffs)*(barHeight+spacing)+8)
end

local updateTicker = nil
function BT:StartTrackerLoop()
  if updateTicker then updateTicker:Cancel() end
  updateTicker = C_Timer.NewTicker(0.15, function()
    if not EUI.DB then EUI.DB = ExtendedUI_DB end
    self:UpdateAnchor()
    self:UpdateTrackerBars()
    self.frame:Show()
  end)
end

function BT:StopTrackerLoop()
  if updateTicker then updateTicker:Cancel() end
  if self.frame then self.frame:Hide() end
end

local autoFrame = CreateFrame("Frame")
autoFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
autoFrame:RegisterEvent("UNIT_AURA")
autoFrame:RegisterEvent("PLAYER_LOGOUT")
autoFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
autoFrame:SetScript("OnEvent", function(_, event, unit, _, spellId)
  if event == "UNIT_AURA" and unit ~= "player" then return end
  if event == "PLAYER_LOGOUT" then BT:StopTrackerLoop(); return end
  if not ExtendedUI_DB or not ExtendedUI_DB.profile or not ExtendedUI_DB.profile.global then return end
  if (ExtendedUI_DB.profile.global.buffTrackerList and next(ExtendedUI_DB.profile.global.buffTrackerList)) then
    BT:StartTrackerLoop()
  else
    BT:StopTrackerLoop()
  end
end)