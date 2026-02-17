-- Close.lua: ExtendedUI - Close all windows

local function ExtendedUI_CloseAll()
    -- Main hub/frame in Menu.lua
    if EUI_Menu and EUI_Menu.CloseAll then
        EUI_Menu.CloseAll()
    end

    -- Actionbar config frame
    if EUI_Config and EUI_Config.win and EUI_Config.win:IsShown() then
        EUI_Config.win:Hide()
    end

    -- OneBag settings window
    if EUI_Menu and EUI_Menu.onebag and EUI_Menu.onebag:IsShown() then
        EUI_Menu.onebag:Hide()
    end
    -- OneBag main bag window
    if ExtendedUI and ExtendedUI.OneBag and ExtendedUI.OneBag.frame and ExtendedUI.OneBag.frame:IsShown() then
        ExtendedUI.OneBag.frame:Hide()
    end

    -- BuffTracker menu
    if EUI_BuffTracker and EUI_BuffTracker.menu and EUI_BuffTracker.menu:IsShown() then
        EUI_BuffTracker.menu:Hide()
    end

    -- SoundTweaks config
    if EUI_SoundTweaks and EUI_SoundTweaks.menu and EUI_SoundTweaks.menu:IsShown() then
        EUI_SoundTweaks.menu:Hide()
    end

    -- ProcHelper config
    if ProcHelper and ProcHelper.ConfigFrame and ProcHelper.ConfigFrame:IsShown() then
        ProcHelper.ConfigFrame:Hide()
    end

    -- ProcHelper anchor frame
    if ProcHelper and ProcHelper.anchorFrame and ProcHelper.anchorFrame:IsShown() then
        ProcHelper.anchorFrame:Hide()
    end

    -- Totem3D tracker window
    if TOTEM3D and TOTEM3D.frame and TOTEM3D.frame:IsShown() then
        TOTEM3D.frame:Hide()
    end

    -- LootToast placeholder
    if ExtendedUI and ExtendedUI.LootToast and ExtendedUI.LootToast.placeholder and ExtendedUI.LootToast.placeholder:IsShown() then
        ExtendedUI.LootToast.placeholder:Hide()
    end
end

-- Slash command: /euiclose
SLASH_EUICLOSE1 = "/euiclose"
SlashCmdList["EUICLOSE"] = function()
    ExtendedUI_CloseAll()
end