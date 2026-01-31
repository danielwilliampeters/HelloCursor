-- HelloCursor Core Events Handler

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
    HelloCursorDB.size = HC.Clamp(tonumber(HelloCursorDB.size) or HC.DEFAULTS.size, 64, 128)

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
