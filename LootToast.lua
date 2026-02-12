local EUI = ExtendedUI

local LT = {}
EUI.LootToast = LT

local function EnsureDB()
  if not (ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global) then return end
  local g = ExtendedUI_DB.profile.global
  if g.lootToastEnabled == nil then g.lootToastEnabled = false end
  g.lootToast = g.lootToast or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
end

local function GetRarityColor(itemLink)
  if not itemLink then return 1, 1, 1 end
  local _, _, quality = GetItemInfo(itemLink)
  if not quality then return 1, 1, 1 end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

function LT:EnsureFrames()
  if self.frame then return end
  EnsureDB()

  local f = CreateFrame("Frame", "ExtendedUILootToastFrame", UIParent)
  self.frame = f
  f:SetSize(260, 34)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:Hide()

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(28, 28)
  f.icon:SetPoint("LEFT", 0, 0)
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.text:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
  f.text:SetJustifyH("LEFT")

  -- Animation state
  f._euiAnim = {
    playing = false,
    t = 0,
    duration = 1.4,   -- total time
    rise = 28,        -- pixels to move up
    fadeStart = 0.15, -- start fading after this fraction
  }

  f:SetScript("OnUpdate", function(selfFrame, dt)
    local a = selfFrame._euiAnim
    if not a or not a.playing then return end

    a.t = a.t + dt
    local p = a.t / a.duration
    if p >= 1 then
      a.playing = false
      selfFrame:Hide()
      return
    end

    -- smoothstep-ish easing
    local eased = p * p * (3 - 2 * p)

    -- Move up
    local y = a.baseY + (a.rise * eased)
    selfFrame:ClearAllPoints()
    selfFrame:SetPoint(a.point, UIParent, a.relPoint, a.baseX, y)

    -- Fade out
    local alpha
    if p <= a.fadeStart then
      alpha = 1
    else
      local fp = (p - a.fadeStart) / (1 - a.fadeStart)
      alpha = 1 - fp
      if alpha < 0 then alpha = 0 end
    end
    selfFrame:SetAlpha(alpha)
  end)

  -- Placeholder shown only in OneBag menu + setting enabled
  local p = CreateFrame("Frame", "ExtendedUILootToastPlaceholder", UIParent)
  self.placeholder = p
  p:SetSize(260, 34)
  p:SetFrameStrata("DIALOG")
  p:SetClampedToScreen(true)
  p:EnableMouse(true)
  p:SetMovable(true)
  p:RegisterForDrag("LeftButton")
  p._dragging = false

  p:SetScript("OnDragStart", function()
    if InCombatLockdown and InCombatLockdown() then return end
    p._dragging = true
    p:StartMoving()
  end)

  p:SetScript("OnDragStop", function()
    p:StopMovingOrSizing()
    EnsureDB()
    local db = ExtendedUI_DB.profile.global.lootToast
    local point, _, relPoint, x, y = p:GetPoint(1)
    db.point = point or "CENTER"
    db.relPoint = relPoint or "CENTER"
    db.x = x or 0
    db.y = y or 0
    p._dragging = false
  end)

  p.bg = p:CreateTexture(nil, "BACKGROUND")
  p.bg:SetAllPoints(p)
  p.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  p.bg:SetVertexColor(1, 1, 1, 0.08)

  p.icon = p:CreateTexture(nil, "ARTWORK")
  p.icon:SetSize(28, 28)
  p.icon:SetPoint("LEFT", 0, 0)
  p.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  p.text = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  p.text:SetPoint("LEFT", p.icon, "RIGHT", 8, 0)
  p.text:SetText("Loot Toast Position")
  p.text:SetTextColor(1, 1, 1)

  p:Hide()
end

function EUI:UpdateLootToastAnchor(oneBagMenuOpen)
  EnsureDB()
  LT:EnsureFrames()

  local g = ExtendedUI_DB.profile.global
  local enabled = g.lootToastEnabled and true or false

  if oneBagMenuOpen and enabled then
    local db = g.lootToast
    if not LT.placeholder._dragging then
      LT.placeholder:ClearAllPoints()
      LT.placeholder:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)
    end
    LT.placeholder:Show()
  else
    LT.placeholder:Hide()
  end
end

function LT:ShowToast(itemLink, iconTex, name)
  EnsureDB()
  self:EnsureFrames()
  if not ExtendedUI_DB.profile.global.lootToastEnabled then return end

  local db = ExtendedUI_DB.profile.global.lootToast

  self.frame.icon:SetTexture(iconTex or "Interface\\Icons\\INV_Misc_QuestionMark")

  local r, g, b = GetRarityColor(itemLink)
  self.frame.text:SetText(name or "")
  self.frame.text:SetTextColor(r, g, b)

  -- Anchor + start animation
  local a = self.frame._euiAnim
  a.point = db.point or "CENTER"
  a.relPoint = db.relPoint or "CENTER"
  a.baseX = db.x or 0
  a.baseY = db.y or 0
  a.t = 0
  a.playing = true

  self.frame:ClearAllPoints()
  self.frame:SetPoint(a.point, UIParent, a.relPoint, a.baseX, a.baseY)
  self.frame:SetAlpha(1)
  self.frame:Show()
end

-- Loot listener: Filter alleen eigen loot!
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", function(_, _, msg)
  EnsureDB()
  if not (ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global and ExtendedUI_DB.profile.global.lootToastEnabled) then
    return
  end

  -- Eigen naam ophalen (zonder realm)
  local playerName = UnitName("player")
  -- EN en NL evt. beide filteren
  local selfPatternEN = "^You receive"
  local selfPatternNL = "^Je ontvangt"
  local selfPatternDirect = "^" .. playerName .. " receives"
  
  -- Filter alleen lootberichten die verwijzen naar jezelf
  if (msg:find(selfPatternEN) or msg:find(selfPatternNL) or msg:find(selfPatternDirect)) then
    local itemLink = msg and msg:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then return end

    local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemLink)
    if not name then
      -- retry shortly if cache missing
      if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
          local n, _, _, _, _, _, _, _, _, ic = GetItemInfo(itemLink)
          if n then
            LT:ShowToast(itemLink, ic, n)
          end
        end)
      end
      return
    end

    LT:ShowToast(itemLink, icon, name)
  end
end)