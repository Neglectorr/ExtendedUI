ProcHelper = ProcHelper or {}
local PH = ProcHelper

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local UnitBuff = UnitBuff
local GetActionInfo = GetActionInfo
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local table_insert = table.insert
local table_remove = table.remove
local math_max = math.max

-- Spell info cache to avoid repeated GetSpellInfo calls for the same IDs
local _spellInfoCache = {}
local function CachedGetSpellInfo(id)
  local cached = _spellInfoCache[id]
  if cached then return cached[1], cached[2], cached[3] end
  local name, rank, icon = GetSpellInfo(id)
  if name then _spellInfoCache[id] = { name, rank, icon } end
  return name, rank, icon
end

local PROC_ICON_SIZE = 38
local PROC_ICON_SPACING = 8

function PH:InitDB()
    ExtendedUI_DB = ExtendedUI_DB or {}
    ExtendedUI_DB.profile = ExtendedUI_DB.profile or {}
    local p = ExtendedUI_DB.profile
    p.procs = p.procs or {}
    p.global = p.global or {}
end

function PH:GetProcs()
    self:InitDB()
    return ExtendedUI_DB.profile.procs
end

function PH:AddProcEntry()
    local procs = self:GetProcs()
    table.insert(procs, { buff = "", missing = false })
    self:RefreshConfig()
    self:Update()
end

function PH:DeleteProcEntry(idx)
    local procs = self:GetProcs()
    table.remove(procs, idx)
    self:RefreshConfig()
    self:Update()
end

function PH:UpdateProcEntry(idx, buff, missing)
    local procs = self:GetProcs()
    local entry = procs[idx]
    if entry then
        entry.buff = buff or entry.buff
        if missing ~= nil then entry.missing = missing end
        self:Update()
    end
end

-- === ANCHOR ===
function PH:GetAnchorCoords()
    local db = ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global
    if not db then return "CENTER", "CENTER", 0, 0 end
    local anch = db.procStackAnchor
    if anch then
        return anch.point or "CENTER", anch.relPoint or "CENTER", anch.x or 0, anch.y or 0
    end
    return "CENTER", "CENTER", 0, 0
end

function PH:EnsureAnchorFrame()
    if self.anchorFrame then return self.anchorFrame end
    local f = CreateFrame("Frame", "ExtendedUIProcAnchorFrame", UIParent, "BackdropTemplate")
    f:SetSize(PROC_ICON_SIZE, PROC_ICON_SIZE)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetFrameLevel(1)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    f:SetBackdropColor(0.8, 0.8, 1, 0.13)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints(f)
    f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon:SetAlpha(0.26)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f.text:SetText("Proc Stack Anchor")
    f._isDragging = false
    f:SetScript("OnDragStart", function()
        if InCombatLockdown and InCombatLockdown() then return end
        f._isDragging = true
        f:StartMoving()
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f._isDragging = false
        local db = ExtendedUI_DB and ExtendedUI_DB.profile and ExtendedUI_DB.profile.global
        if not db then return end
        local point, _, relPoint, x, y = f:GetPoint()
        db.procStackAnchor = { point=point or "CENTER", relPoint=relPoint or "CENTER", x=x or 0, y=y or 0 }
    end)
    f:Hide()
    self.anchorFrame = f
    return f
end

function PH:ShowAnchorFrame()
    local anchor = self:EnsureAnchorFrame()
    anchor:Show()
end
function PH:HideAnchorFrame()
    if self.anchorFrame then self.anchorFrame:Hide() end
end

function PH:GetActionbarIconBySpellName(spellName)
    if not spellName or spellName == "" then return nil end
    -- Search all main actionbar slots (1-120, including multibars)
    for slot = 1, 120 do
        local type, id, subType = GetActionInfo(slot)
        if type == "spell" and id then
            local name = CachedGetSpellInfo(id)
            if name == spellName then
                local btn
                if slot <= 12 then
                    btn = _G["ActionButton" .. slot]
                elseif slot <= 24 then
                    btn = _G["MultiBarBottomLeftButton" .. (slot - 12)]
                elseif slot <= 36 then
                    btn = _G["MultiBarBottomRightButton" .. (slot - 24)]
                elseif slot <= 48 then
                    btn = _G["MultiBarRightButton" .. (slot - 36)]
                elseif slot <= 60 then
                    btn = _G["MultiBarLeftButton" .. (slot - 48)]
                end
                local icon = btn and btn.icon and btn.icon:GetTexture()
                if icon and icon ~= "" and icon ~= "Interface\\Icons\\INV_Misc_QuestionMark" then
                    return icon
                end
                -- Second fallback: GetSpellTexture (returns string in Classic/TBC for known spells)
                local spellIcon = GetSpellTexture(id)
                if spellIcon and spellIcon ~= "" and spellIcon ~= "Interface\\Icons\\INV_Misc_QuestionMark" then
                    return spellIcon
                end
            end
        end
        -- Can be extended for macros etc. if desired
    end
    return nil
end


-- =========== BUFF-DETECTIE ===========
function PH:_BuffActuallyActive(entry)
    local key = entry.buff
    if not key or key == "" then return false end
    local tryId = tonumber(key)
    local wantName, forceIcon
    if tryId then
        local name, _, icon = CachedGetSpellInfo(tryId)
        wantName = name or key
        forceIcon = icon
    else
        wantName = key
    end
    for i = 1, 40 do
        local name, icon, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if name == wantName then
            local useIcon = icon
            if (not useIcon or useIcon == "" or useIcon == "Interface\\Icons\\INV_Misc_QuestionMark") and spellId then
                useIcon = GetSpellTexture(spellId)
            end
            if (not useIcon or useIcon == "" or useIcon == "Interface\\Icons\\INV_Misc_QuestionMark") then
                useIcon = PH.GetActionbarIconBySpellName and PH:GetActionbarIconBySpellName(wantName) or nil
            end
            if (not useIcon or useIcon == "" or useIcon == "Interface\\Icons\\INV_Misc_QuestionMark") then
                useIcon = PH.GetSpellbookIconByName and PH:GetSpellbookIconByName(wantName) or nil
            end
            if (not useIcon or useIcon == "" or useIcon == "Interface\\Icons\\INV_Misc_QuestionMark") then
                useIcon = forceIcon
            end
            return true, useIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
        end
    end
    -- No buff active: try to find icons, preferring spell ID if the user entered one
    local icon
    if tryId then
        icon = GetSpellTexture(tryId)
    end
    if (not icon or icon == "" or icon == "Interface\\Icons\\INV_Misc_QuestionMark") then
        icon = PH.GetActionbarIconBySpellName and PH:GetActionbarIconBySpellName(wantName) or nil
    end
    if (not icon or icon == "" or icon == "Interface\\Icons\\INV_Misc_QuestionMark") then
        icon = PH.GetSpellbookIconByName and PH:GetSpellbookIconByName(wantName) or nil
    end
    if (not icon or icon == "" or icon == "Interface\\Icons\\INV_Misc_QuestionMark") then
        icon = forceIcon
    end
    return false, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function PH:GetSpellbookIconByName(searchName)
    -- Scan the spellbook for a spell matching searchName and return its texture
    searchName = tostring(searchName)
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for idx = 1, numSpells do
            local slot = offset + idx
            local spellName = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
            if spellName == searchName then
                local texture = GetSpellBookItemTexture(slot, BOOKTYPE_SPELL)
                if texture then return texture end
            end
        end
    end
    return nil
end

-- ======== PROC ICONEN ========
function PH:EnsureProcIconFrame(i)
    self.procStackIcons = self.procStackIcons or {}
    if self.procStackIcons[i] then return self.procStackIcons[i] end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(PROC_ICON_SIZE, PROC_ICON_SIZE)
    f:SetFrameStrata("DIALOG")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints(f)
    -- Fade/fly anim
    f.animGroup = f:CreateAnimationGroup()
    f.animFade = f.animGroup:CreateAnimation("Alpha")
    f.animTrans = f.animGroup:CreateAnimation("Translation")
    f:Hide()
    f._fadeState = nil
    self.procStackIcons[i] = f
    return f
end

function PH:ShowConfig()
    if self.ConfigFrame then
        self.ConfigFrame:Show()
        self:RefreshConfig()
        return
    end

    local frame = CreateFrame("Frame", "ProcHelperConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(410, 380)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
	frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(4)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 10, 0)
    frame.title:SetText("ProcStack Tracking Settings")

    -- Show anchor checkbox
    frame.showAnchorChk = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.showAnchorChk:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -36)
    frame.showAnchorChk.text = frame.showAnchorChk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.showAnchorChk.text:SetPoint("LEFT", frame.showAnchorChk, "RIGHT", 6, 0)
    frame.showAnchorChk.text:SetText("Show Anchor to move")
    frame.showAnchorChk:SetScript("OnClick", function(btn)
        PH.showAnchor = btn:GetChecked()
        PH:Update()
    end)

    -- Scrollframe/list
    frame.listScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.listScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -64)
    frame.listScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 52)
    frame.listContent = CreateFrame("Frame", nil, frame)
    frame.listContent:SetSize(350, 500)
    frame.listScroll:SetScrollChild(frame.listContent)
    frame.procRows = {}

    -- + button
    frame.addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.addBtn:SetSize(24, 24)
    frame.addBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)
    frame.addBtn:SetText("+")
    frame.addBtn:SetScript("OnClick", function()
        PH:AddProcEntry()
    end)

    -- Close button
    frame.closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.closeBtn:SetSize(70, 24)
    frame.closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 14)
    frame.closeBtn:SetText("Close")
    frame.closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.ConfigFrame = frame
    self:RefreshConfig()
    frame:Show()
end

function PH:RefreshConfig()
    if not self.ConfigFrame then return end
    local f = self.ConfigFrame
    -- Sync anchor checkbox state
    f.showAnchorChk:SetChecked(self.showAnchor)

    -- Clear all existing rows
    for _, row in ipairs(f.procRows or {}) do
        if row and row.bg then row.bg:Hide() end
        if row and row.buffEdit then row.buffEdit:Hide() end
        if row and row.missChk then row.missChk:Hide() end
        if row and row.delBtn then row.delBtn:Hide() end
    end
    f.procRows = {}

    local procs = self:GetProcs()
    local y = -6
    for i, entry in ipairs(procs) do
        local row = f.procRows[i] or {}
        -- Background/bar
        if not row.bg then
            row.bg = CreateFrame("Frame", nil, f.listContent, "InsetFrameTemplate3")
            row.bg:SetSize(320, 32)
        end
        row.bg:Show()
        row.bg:ClearAllPoints()
        row.bg:SetPoint("TOPLEFT", f.listContent, "TOPLEFT", 0, y)
        -- Buff/spellId editbox
        if not row.buffEdit then
            row.buffEdit = CreateFrame("EditBox", nil, row.bg, "InputBoxTemplate")
            row.buffEdit:SetSize(105, 26)
            row.buffEdit:SetAutoFocus(false)
            row.buffEdit:SetFontObject("GameFontHighlightSmall")
        end
        row.buffEdit:Show()
        row.buffEdit:SetPoint("LEFT", row.bg, "LEFT", 7, 0)
        row.buffEdit:SetText(entry.buff or "")
        row.buffEdit:SetScript("OnTextChanged", function(self2)
            PH:UpdateProcEntry(i, self2:GetText(), nil)
        end)
        -- Missing checkbox
        if not row.missChk then
            row.missChk = CreateFrame("CheckButton", nil, row.bg, "UICheckButtonTemplate")
        end
        row.missChk:Show()
        row.missChk:SetPoint("LEFT", row.buffEdit, "RIGHT", 9, 0)
        row.missChk:SetChecked(entry.missing or false)
        if not row.missChk.label then
            row.missChk.label = row.missChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.missChk.label:SetPoint("LEFT", row.missChk, "RIGHT", 2, -1)
            row.missChk.label:SetText("Missing")
        end
        row.missChk:SetScript("OnClick", function(btn)
            PH:UpdateProcEntry(i, nil, btn:GetChecked())
        end)
        -- Delete row button
        if not row.delBtn then
            row.delBtn = CreateFrame("Button", nil, row.bg, "UIPanelButtonTemplate")
            row.delBtn:SetSize(24, 22)
            row.delBtn:SetText("X")
        end
        row.delBtn:Show()
        row.delBtn:SetPoint("LEFT", row.missChk, "RIGHT", 140, 0)
        row.delBtn:SetScript("OnClick", function() PH:DeleteProcEntry(i) end)

        f.procRows[i] = row
        y = y - 36
    end
end


function PH:UpdateProcIconsDisplay(activeProcs)
    -- Anchor
    local anchor = self:EnsureAnchorFrame()
    if anchor and not anchor._isDragging then
        local point, relPoint, x, y = self:GetAnchorCoords()
        anchor:ClearAllPoints()
        anchor:SetPoint(point, UIParent, relPoint, x, y)
    end
    -- Show anchor if no procs or if "show anchor" checkbox is active
    if not activeProcs or self.showAnchor then
        anchor.icon:SetAlpha(0.26)
        anchor.text:Show()
        anchor:Show()
    else
        anchor:Hide()
    end

    -- Always ensure enough frames
    for i = 1, math.max(#activeProcs, #(self.procStackIcons or {})) do
        self:EnsureProcIconFrame(i)
    end

    self._lastProcState = self._lastProcState or {}

    for i = 1, math.max(#activeProcs, #(self.procStackIcons or {})) do
        local cur = activeProcs[i]
        local f = self.procStackIcons[i]
        local wasActive = self._lastProcState[i]
        local isActive = cur ~= nil

        if isActive and not wasActive then
            -- Fade-in/fly-in van rechts
            f:SetAlpha(0)
            f.icon:SetTexture(cur.iconTex)
            f:Show()
            f:ClearAllPoints()
            if i == 1 then
                f:SetPoint("LEFT", anchor, "LEFT", 72, 0) -- fly-in (van rechts)
            else
                f:SetPoint("LEFT", self.procStackIcons[i-1], "RIGHT", 8+72, 0)
            end
            f.animGroup:Stop()
            f.animFade:SetFromAlpha(0)
            f.animFade:SetToAlpha(1)
            f.animFade:SetDuration(0.15)
            f.animTrans:SetOffset(-72, 0)
            f.animTrans:SetDuration(0.22)
            f.animGroup:Play()
            f._fadeState = "fading_in"
            f.animGroup:SetScript("OnFinished", function()
                f:ClearAllPoints()
                if i == 1 then
                    f:SetPoint("LEFT", anchor, "LEFT", 0, 0)
                else
                    f:SetPoint("LEFT", self.procStackIcons[i-1], "RIGHT", 8, 0)
                end
                f:SetAlpha(1)
                f._fadeState = "shown"
            end)
        elseif not isActive and wasActive then
            -- Fade-out/fly-out naar links
            f.animGroup:Stop()
            f.animFade:SetFromAlpha(1)
            f.animFade:SetToAlpha(0)
            f.animFade:SetDuration(0.15)
            f.animTrans:SetOffset(-72, 0)
            f.animTrans:SetDuration(0.22)
            f.animGroup:Play()
            f._fadeState = "fading_out"
            f.animGroup:SetScript("OnFinished", function()
                f:Hide()
                f._fadeState = nil
            end)
        elseif isActive and wasActive then
            -- Existing proc
            if f._fadeState == "shown" or not f._fadeState then
                if f.icon:GetTexture() ~= cur.iconTex then
                    f.icon:SetTexture(cur.iconTex)
                end
                f:ClearAllPoints()
                if i == 1 then
                    f:SetPoint("LEFT", anchor, "LEFT", 0, 0)
                else
                    f:SetPoint("LEFT", self.procStackIcons[i-1], "RIGHT", 8, 0)
                end
                f:SetAlpha(1)
            end
        else
            -- Not active / no longer needed
            if f:IsShown() and (not f._fadeState or f._fadeState == "shown") then
                f:Hide()
                f._fadeState = nil
            end
        end

        self._lastProcState[i] = isActive
    end
    -- Hide excess icons
    for i = (#activeProcs+1), #(self.procStackIcons or {}) do
        local f = self.procStackIcons[i]
        if f and f:IsShown() and (not f._fadeState or f._fadeState=="shown") then
            f:Hide()
            f._fadeState = nil
            self._lastProcState[i] = nil
        end
    end
end

function PH:Update()
    self:InitDB()
    local procs = self:GetProcs()
    local activeProcs = {}

    -- Same as old core: all matches, horizontal row
    for _, entry in ipairs(procs) do
        if entry and entry.buff and entry.buff ~= "" then
            local have, icon = self:_BuffActuallyActive(entry)
            if entry.missing then
                if not have then
                    table.insert(activeProcs, { iconTex = icon or "Interface\\Icons\\INV_Misc_QuestionMark" })
                end
            else
                if have then
                    table.insert(activeProcs, { iconTex = icon or "Interface\\Icons\\INV_Misc_QuestionMark" })
                end
            end
        end
    end

    self:UpdateProcIconsDisplay(activeProcs)
end

-- === LIVE UPDATE ===
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:SetScript("OnEvent", function(self, event, unit)
    if not PH then return end
    if event == "UNIT_AURA" and unit ~= "player" then return end
    PH:Update()
end)