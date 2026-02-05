-- Hello Cursor Core Events Handler

local HC = HelloCursor
if not HC then return end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == HC.ADDON_NAME then
    HelloCursorDB = HC.CopyDefaults(HelloCursorDB, HC.DEFAULTS)
    HelloCursorDB.colorHex = HC.NormalizeHex(HelloCursorDB.colorHex) or HC.DEFAULTS.colorHex

    -- Normalise ring size: clamp into the authored range, then
    -- fall back to 96 if the value doesn't match a known size.
    local size = HC.Clamp(tonumber(HelloCursorDB.size) or HC.DEFAULTS.size, 96, 192)
    if size ~= 96 and size ~= 128 and size ~= 192 then
      size = 96
    end

    -- Keep both the core DB field and the Settings-backed
    -- "HelloCursor_size" variable in sync, so the dropdown
    -- never shows a "Custom" value after upgrading.
    HelloCursorDB.size = size
    HelloCursorDB["HelloCursor_size"] = size

    if HC.SyncRingStyleFlags then
      HC.SyncRingStyleFlags()
    end

    HC.CaptureCursorNow()

    HC.RefreshVisualsImmediate()
    HC.UpdateVisibility()

    if not HC.settingsCategory then
      HC.settingsCategory = HC.CreateSettingsPanel()
    end

    print("|cFF00FF00HelloCursor:|r v" .. HC.VERSION .. " Loaded. Use |cFFFFA500/hc|r to open options.")
    return
  end

  HC.ApplyTintIfNeeded(false)
  HC.UpdateVisibility()
end)

SLASH_HELLOCURSOR1 = "/hc"
SLASH_HELLOCURSOR2 = "/hellocursor"

SlashCmdList.HELLOCURSOR = function(msg)
  if msg == "toggle" then
    local nsKey = "HelloCursor_enabled"
    local current = HC.IsAddonEnabled()
    local newValue = not current
    HelloCursorDB.enabled = newValue
    HelloCursorDB[nsKey] = newValue
    HC.UpdateVisibility()
    print(("HelloCursor: %s"):format(HelloCursorDB.enabled and "enabled" or "disabled"))
    return
  end

  if HC.settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(HC.settingsCategory:GetID())
  end
end
