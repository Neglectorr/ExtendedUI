local EUI = ExtendedUI
EUI_SoundTweaks = EUI_SoundTweaks or {}
local ST = EUI_SoundTweaks

ST.EmoteLabels = {"HELLO", "THANKYOU", "CHEER", "JOKE", "FLIRT", "NO", "YES", "BYE", "OPENFIRE", "FOLLOW", "FLEE", "CHARGE", "HEALING"}
ST.ErrorList = {}

local function GetRaceGenderKey()
  local _, raceFile = UnitRace("player")
  local genderId = UnitSex("player")
  local gender = (genderId == 2) and "Male" or "Female"
  return raceFile .. gender
end

-- === Soundbank dropdown options: name-key pairs, always sorted together (DYNAMIC, SAFE) ===
local banks = {}
for k, v in pairs(EUI_SoundTweaks) do
  local shortname = tostring(k):match("^SoundBank(.+)")
  if shortname and type(v) == "table" then
    local friendly = v.displayName or shortname:gsub("([a-z])([A-Z])", "%1 %2")
    banks[#banks + 1] = {name = friendly, key = k}
  end
end
table.sort(banks, function(a, b) return a.name < b.name end)
ST.SoundBankNames = {}
ST.SoundBankKeys = {}
for _, entry in ipairs(banks) do
  ST.SoundBankNames[#ST.SoundBankNames+1] = entry.name
  ST.SoundBankKeys[#ST.SoundBankKeys+1] = entry.key
end
ST.selectedSoundBankIndex = 1

-- Build ST.SoundBank with all labels (for lookups in some routines)
ST.SoundBank = {}
for k, v in pairs(EUI_SoundTweaks) do
  if type(v) == "table" and tostring(k):match("^SoundBank") then
    for id, label in pairs(v) do
      ST.SoundBank[id] = label
    end
  end
end

-- Populate error and emote fallback voice files
ST.ErrorVoiceFiles = {}
ST.EmoteVoiceFiles = {}
for k, v in pairs(EUI_SoundTweaks) do
  if type(v) == "table" and k:match("^ErrorVoiceFiles") then
    local comboKey = k:match("^ErrorVoiceFiles(.+)$")
    if comboKey and comboKey ~= "" then
      for errId, arr in pairs(v) do
        ST.ErrorVoiceFiles[errId] = ST.ErrorVoiceFiles[errId] or {}
        ST.ErrorVoiceFiles[errId][comboKey] = arr
      end
    end
  elseif type(v) == "table" and k:match("^EmoteVoiceFiles") then
    local comboKey = k:match("^EmoteVoiceFiles(.+)$")
    if comboKey and comboKey ~= "" then
      ST.EmoteVoiceFiles[comboKey] = v
    end
  end
end

-- Persistent DB routines
local function EnsureDB()
  ExtendedUI_DB = ExtendedUI_DB or {}
  ExtendedUI_DB.profile = ExtendedUI_DB.profile or {}
  ExtendedUI_DB.profile.global = ExtendedUI_DB.profile.global or {}
  ExtendedUI_DB.profile.global.soundTweaks = ExtendedUI_DB.profile.global.soundTweaks or {}
  ExtendedUI_DB.profile.global.emoteTweaks = ExtendedUI_DB.profile.global.emoteTweaks or {}
  ExtendedUI_DB.profile.global.dynamicErrorIds = ExtendedUI_DB.profile.global.dynamicErrorIds or {}
  ExtendedUI_DB.profile.global.dynamicErrorLabels = ExtendedUI_DB.profile.global.dynamicErrorLabels or {}
end

-- Dynamic error table logic
ST._dynamicErrors = {}
ST._dynamicErrorLabels = {}

local function LoadDynamicErrors()
  EnsureDB()
  wipe(ST._dynamicErrors)
  for _, id in ipairs(ExtendedUI_DB.profile.global.dynamicErrorIds) do
    table.insert(ST._dynamicErrors, id)
  end
end

local function SaveDynamicErrors()
  EnsureDB()
  wipe(ExtendedUI_DB.profile.global.dynamicErrorIds)
  for _, id in ipairs(ST._dynamicErrors) do
    table.insert(ExtendedUI_DB.profile.global.dynamicErrorIds, id)
  end
end

local function AddDynamicErrorId(errId)
  for _, v in ipairs(ST._dynamicErrors) do
    if v == errId then return end
  end
  table.insert(ST._dynamicErrors, errId)
  SaveDynamicErrors()
end

local function LoadDynamicErrorLabels()
  EnsureDB()
  wipe(ST._dynamicErrorLabels)
  for id, label in pairs(ExtendedUI_DB.profile.global.dynamicErrorLabels) do
    ST._dynamicErrorLabels[tonumber(id)] = label
  end
end

local function SaveDynamicErrorLabel(errId, label)
  EnsureDB()
  ExtendedUI_DB.profile.global.dynamicErrorLabels[tostring(errId)] = label
  ST._dynamicErrorLabels[errId] = label
end

local function buildErrorMenuList()
  local seen, out = {}, {}
  for _, id in ipairs(ST.ErrorList) do
    if not seen[id] then table.insert(out, id); seen[id]=true end
  end
  for _, id in ipairs(ST._dynamicErrors) do
    if not seen[id] then table.insert(out, id); seen[id]=true end
  end
  EnsureDB()
  for idstr, v in pairs(ExtendedUI_DB.profile.global.soundTweaks) do
    local id = tonumber(idstr)
    if id and not seen[id] then table.insert(out, id); seen[id]=true end
  end
  table.sort(out)
  return out
end

function ST:EnsureConfigMenu()
  if ST.menu then return end
  local w = CreateFrame("Frame", "EUISoundTweaksFrame", UIParent, "BackdropTemplate")
  ST.menu = w
  if EUI_Menu and EUI_Menu.RegisterSubMenuFrame then EUI_Menu.RegisterSubMenuFrame(w) end

  w:SetSize(940, 680)
  w:SetPoint("CENTER")
  w:SetFrameStrata("DIALOG")
  w:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  w:SetBackdropColor(0, 0, 0, 0.96)
  w:EnableMouse(true)
  w:SetMovable(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function() if not InCombatLockdown() then w:StartMoving() end end)
  w:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)

  local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText("ExtendedUI - Sound Tweaks (Error & Character Speech)")

  local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function()
    w:Hide()
    if EUI_Menu and EUI_Menu.hub then EUI_Menu.hub:Show() end
  end)

  local hint = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 28, -44)
  hint:SetText("Errors and emotes: use custom mappings, or fallback to character/race/gender voices.")

  local divider = w:CreateTexture(nil, "ARTWORK")
  divider:SetTexture("Interface\\Buttons\\WHITE8x8")
  divider:SetColorTexture(1,1,1,0.09)
  divider:SetSize(870, 1)
  divider:SetPoint("TOPLEFT", 24, -86)

  local errorHeader = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  errorHeader:SetPoint("TOPLEFT", 24, -70)
  errorHeader:SetText("Error Speech")

  local soundbankHeader = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  soundbankHeader:SetPoint("TOPLEFT", 520, -70)
  soundbankHeader:SetText("Soundbank (Choose race/gender)")

  local emoteHeader = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  emoteHeader:SetPoint("TOPLEFT", 24, -366)
  emoteHeader:SetText("Emote Speech")

  -- Soundbank search field
  local searchBox = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
  searchBox:SetSize(190, 20)
  searchBox:SetPoint("TOPLEFT", 520, -100)
  searchBox:SetAutoFocus(false)
  searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  -- Dropdown for soundbank selection
  local dropDown = CreateFrame("Frame", "STSoundBankSelect", w, "UIDropDownMenuTemplate")
  dropDown:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
  UIDropDownMenu_SetWidth(dropDown, 135)

  -- Soundbank UI (NB! w.sbScroll ipv sbScroll, zie fix)
  local sbScroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  sbScroll:SetSize(340, 530)
  sbScroll:SetPoint("TOPLEFT", 520, -120)
  w.sbScroll = sbScroll
  local sbList = CreateFrame("Frame", nil, sbScroll)
  sbList:SetSize(340, 2000)
  sbScroll:SetScrollChild(sbList)
  w.sbList = sbList
  w.sbRows = {}

  function ST:SoundBankDropDownOnClick(index)
    ST.selectedSoundBankIndex = index
    if ST.menu and ST.menu.sbScroll then
      ST.menu.sbScroll:SetVerticalScroll(0)
    end
    UIDropDownMenu_SetSelectedID(dropDown, index)
    if ST.menu and ST.menu:IsShown() and w.UpdateMenu then w.UpdateMenu() end
  end

  UIDropDownMenu_Initialize(dropDown, function(self, level)
    for i, name in ipairs(ST.SoundBankNames) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = name
      info.value = i
      info.func = function() ST:SoundBankDropDownOnClick(i) end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetSelectedID(dropDown, ST.selectedSoundBankIndex)

  -- Errorlist UI
  local errScroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  errScroll:SetSize(440, 260)
  errScroll:SetPoint("TOPLEFT", 24, -96)
  local errContent = CreateFrame("Frame", nil, errScroll)
  errContent:SetSize(440, 1500)
  errScroll:SetScrollChild(errContent)
  w.errContent = errContent
  w.errRows = {}

  -- Emote UI
  local emoteScroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  emoteScroll:SetSize(440, 260)
  emoteScroll:SetPoint("TOPLEFT", 24, -386)
  local emoteContent = CreateFrame("Frame", nil, emoteScroll)
  emoteContent:SetSize(440, 1200)
  emoteScroll:SetScrollChild(emoteContent)
  w.emoteContent = emoteContent
  w.emoteRows = {}

  local function EnsureErrRow(i)
    if w.errRows[i] then return w.errRows[i] end
    local row = {}
    row.box = CreateFrame("Frame", nil, errContent, "BackdropTemplate")
    row.box:SetPoint("TOPLEFT", 0, -2-(i-1)*26)
    row.box:SetSize(440, 24)
    row.box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
    row.box:SetBackdropColor(1,1,1, (i%2==0) and 0.03 or 0.05)
    local errLabel = row.box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    errLabel:SetPoint("LEFT", 6, 0)
    errLabel:SetWidth(170)
    errLabel:SetJustifyH("LEFT")
    row.errLabel = errLabel

    local edit = CreateFrame("EditBox", nil, row.box, "InputBoxTemplate")
    edit:SetSize(58, 18)
    edit:SetPoint("LEFT", errLabel, "RIGHT", 4, 0)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(9)
    row.edit = edit

    local testBtn = CreateFrame("Button", nil, row.box, "UIPanelButtonTemplate")
    testBtn:SetPoint("LEFT", edit, "RIGHT", 7, 0)
    testBtn:SetSize(52, 20)
    testBtn:SetText("Play")
    row.testBtn = testBtn

    local macroBtn = CreateFrame("Button", nil, row.box, "UIPanelButtonTemplate")
    macroBtn:SetPoint("LEFT", testBtn, "RIGHT", 6, 0)
    macroBtn:SetSize(55, 20)
    macroBtn:SetText("Macro")
    row.macroBtn = macroBtn

    row.box:Hide()
    w.errRows[i] = row
    return row
  end

  local function EnsureEmoteRow(i)
    if w.emoteRows[i] then return w.emoteRows[i] end
    local row = {}
    row.box = CreateFrame("Frame", nil, emoteContent, "BackdropTemplate")
    row.box:SetPoint("TOPLEFT", 0, -2-(i-1)*26)
    row.box:SetSize(440, 24)
    row.box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
    row.box:SetBackdropColor(1,1,1, (i%2==0) and 0.03 or 0.05)
    local emoteLabel = row.box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emoteLabel:SetPoint("LEFT", 6, 0)
    emoteLabel:SetWidth(170)
    emoteLabel:SetJustifyH("LEFT")
    row.emoteLabel = emoteLabel

    local edit = CreateFrame("EditBox", nil, row.box, "InputBoxTemplate")
    edit:SetSize(58, 18)
    edit:SetPoint("LEFT", emoteLabel, "RIGHT", 4, 0)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(9)
    row.edit = edit

    local testBtn = CreateFrame("Button", nil, row.box, "UIPanelButtonTemplate")
    testBtn:SetPoint("LEFT", edit, "RIGHT", 7, 0)
    testBtn:SetSize(52, 20)
    testBtn:SetText("Play")
    row.testBtn = testBtn
    row.box:Hide()
    w.emoteRows[i] = row
    return row
  end

  local function EnsureSBRow(i)
    if w.sbRows[i] then return w.sbRows[i] end
    local row = {}
    row.box = CreateFrame("Frame", nil, sbList, "BackdropTemplate")
    row.box:SetPoint("TOPLEFT", 0, -2-(i-1)*23)
    row.box:SetSize(340, 21)
    row.box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
    row.box:SetBackdropColor(1,1,1, (i%2==0) and 0.02 or 0.04)
    local label = row.box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 8, 0)
    label:SetWidth(170)
    label:SetJustifyH("LEFT")
    row.label = label
    local idlabel = row.box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    idlabel:SetPoint("LEFT", label, "RIGHT", 4, 0)
    idlabel:SetWidth(65)
    row.idlabel = idlabel
    local testBtn = CreateFrame("Button", nil, row.box, "UIPanelButtonTemplate")
    testBtn:SetPoint("LEFT", idlabel, "RIGHT", 6, 0)
    testBtn:SetSize(52, 18)
    testBtn:SetText("Play")
    row.testBtn = testBtn
    row.box:Hide()
    w.sbRows[i] = row
    return row
  end

  function w.UpdateMenu()
    EnsureDB()
    LoadDynamicErrors()
    LoadDynamicErrorLabels()
    local mapping = ExtendedUI_DB.profile.global.soundTweaks
    local emoteMap = ExtendedUI_DB.profile.global.emoteTweaks
    if w.sbScroll then w.sbScroll:SetVerticalScroll(0) end
    local errorIds = buildErrorMenuList()
    for i = 1, #w.errRows do if w.errRows[i] then w.errRows[i].box:Hide() end end
    for i, errId in ipairs(errorIds) do
      local row = EnsureErrRow(i)
      row.box:Show()
      local errTxt = ST._dynamicErrorLabels[errId] or ""
      row.errLabel:SetText(("Err %s%s"):format(tostring(errId), (errTxt ~= "" and " – "..errTxt or "")))
      row.edit:SetText(mapping[errId] or "")
      row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row.edit:SetText(mapping[errId] or "") end)
      row.edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
      row.edit:SetScript("OnTextChanged", function(self)
        local new = tonumber(self:GetText())
        if new and new > 0 then
          mapping[errId] = new
        else
          mapping[errId] = nil
        end
      end)
      row.testBtn:SetScript("OnClick", function()
        local sid = tonumber(row.edit:GetText())
        if sid and sid > 0 then
          PlaySoundFile(sid)
        else
          local key = GetRaceGenderKey()
          local t = ST.ErrorVoiceFiles[errId] and ST.ErrorVoiceFiles[errId][key]
          if t and #t > 0 then
            PlaySoundFile(t[math.random(#t)])
          else
            print("No original error speech found for this error id, race, and gender.")
          end
        end
      end)
      row.macroBtn:SetScript("OnClick", function()
        local sid = tonumber(row.edit:GetText())
        if sid and sid > 0 then
          print("Copy/Paste this macro to test:")
          print("/script PlaySoundFile("..sid..")")
        else
          print("Not a valid FileDataID!")
        end
      end)
    end

    for i = 1, #w.emoteRows do if w.emoteRows[i] then w.emoteRows[i].box:Hide() end end
    for i, emote in ipairs(ST.EmoteLabels) do
      local row = EnsureEmoteRow(i)
      row.box:Show()
      row.emoteLabel:SetText(emote)
      row.edit:SetText(emoteMap[emote] or "")
      row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); row.edit:SetText(emoteMap[emote] or "") end)
      row.edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
      row.edit:SetScript("OnTextChanged", function(self)
        local new = tonumber(self:GetText())
        if new and new > 0 then
          emoteMap[emote] = new
        else
          emoteMap[emote] = nil
        end
      end)
      row.testBtn:SetScript("OnClick", function()
        local sid = tonumber(row.edit:GetText())
        if sid and sid > 0 then
          PlaySoundFile(sid)
        else
          local key = GetRaceGenderKey()
          local t = ST.EmoteVoiceFiles[key] and ST.EmoteVoiceFiles[key][emote]
          if t and #t > 0 then
            PlaySoundFile(t[math.random(#t)])
          else
            print("No original emote voice found for this emote, race, and gender.")
          end
        end
      end)
    end

    local filter = searchBox:GetText() or ""
    local lowerf = filter:lower()
    local sb_sorted = {}
    local selBank = ST.SoundBankKeys[ST.selectedSoundBankIndex]
    if selBank == nil then
      for _, k in ipairs(ST.SoundBankKeys) do
        if k then
          for fid, lbl in pairs(EUI_SoundTweaks[k]) do
            if lowerf == "" or (lbl and lbl:lower():find(lowerf, 1, true)) then
              table.insert(sb_sorted, {id=fid, name=lbl})
            end
          end
        end
      end
    else
      local bank = EUI_SoundTweaks[selBank] or {}
      for fid, lbl in pairs(bank) do
        if lowerf == "" or (lbl and lbl:lower():find(lowerf, 1, true)) then
          table.insert(sb_sorted, {id=fid, name=lbl})
        end
      end
    end
    table.sort(sb_sorted, function(a, b) return (a.name or "") < (b.name or "") end)

    for i = 1, #w.sbRows do if w.sbRows[i] then w.sbRows[i].box:Hide() end end
    if #sb_sorted == 0 then
      local row = EnsureSBRow(1)
      row.box:Show()
      row.label:SetText("No sounds found, please enter a search term.")
      row.idlabel:SetText("")
      row.testBtn:SetScript("OnClick", nil)
      for j = 2, #w.sbRows do if w.sbRows[j] then w.sbRows[j].box:Hide() end end
    else
      for i, v in ipairs(sb_sorted) do
        local row = EnsureSBRow(i)
        row.box:Show()
        row.label:SetText(v.name)
        row.idlabel:SetText("#"..v.id)
        row.testBtn:SetScript("OnClick", function() PlaySoundFile(v.id) end)
      end
    end
  end

  searchBox:SetScript("OnTextChanged", function(self)
    if w.sbScroll then w.sbScroll:SetVerticalScroll(0) end
    if w.UpdateMenu then w.UpdateMenu() end
  end)
  w:SetScript("OnShow", function() if w.UpdateMenu then w.UpdateMenu() end end)
  w:Hide()
end

function ST:ToggleConfigMenu()
  ST:EnsureConfigMenu()
  if ST.menu:IsShown() then
    ST.menu:Hide()
  else
    ST.menu:Show()
  end
end

local initialized
local function InitIfNeeded()
  if not initialized then
    LoadDynamicErrors()
    LoadDynamicErrorLabels()
    initialized = true
  end
end

-- Error/Emote events
local LAST_ERROR_SOUND_AT = 0
local ERROR_SOUND_COOLDOWN = 2 -- seconde, tuneer naar wens

local frame = CreateFrame("Frame")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(self, event, errId, errorText, ...)
  EnsureDB(); InitIfNeeded()
  local mapping = ExtendedUI_DB.profile.global.soundTweaks
  local now = GetTime()
  if errId then
    if errorText and errorText ~= "" then
      SaveDynamicErrorLabel(errId, errorText)
    end
    if not mapping[errId] then
      AddDynamicErrorId(errId)
      if ST.menu and ST.menu:IsShown() and ST.menu.UpdateMenu then
        ST.menu:Hide()
        C_Timer.After(0.11, function() ST.menu:Show() end)
      end
    end
  end
  if mapping[errId] then
    if now - LAST_ERROR_SOUND_AT >= ERROR_SOUND_COOLDOWN then
      LAST_ERROR_SOUND_AT = now
      PlaySoundFile(mapping[errId])
    end
  end
end)

local emoteFrame = CreateFrame("Frame")
emoteFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
emoteFrame:RegisterEvent("CHAT_MSG_EMOTE")
emoteFrame:SetScript("OnEvent", function(self, event, msg, ...)
  EnsureDB(); InitIfNeeded()
  local emoteMap = ExtendedUI_DB.profile.global.emoteTweaks
  for _, emote in ipairs(ST.EmoteLabels) do
    if msg:upper():find(emote) then
      local soundId = emoteMap[emote]
      if soundId and soundId > 0 then
        PlaySoundFile(soundId)
      else
        local key = GetRaceGenderKey()
        local t = ST.EmoteVoiceFiles[key] and ST.EmoteVoiceFiles[key][emote]
        if t and #t > 0 then
          PlaySoundFile(t[math.random(#t)])
        end
      end
      break
    end
  end
end)

InitIfNeeded()