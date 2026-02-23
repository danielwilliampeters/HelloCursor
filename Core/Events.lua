-- Hello Cursor Core Events Handler

local HC = HelloCursor
if not HC then return end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == HC.ADDON_NAME then
    -- Ensure SavedVariables table exists
    HelloCursorDB = HelloCursorDB or {}

    -- Migrate legacy visibility flags before seeding defaults.
    if HC.SyncVisibilityFlagsFromLegacy then
      HC.SyncVisibilityFlagsFromLegacy()
    end

    -- Now layer defaults on top for any keys that are still nil.
    HelloCursorDB = HC.CopyDefaults(HelloCursorDB, HC.DEFAULTS)
    if HC.GetNormalizedColorHex then
      HelloCursorDB.colorHex = HC.GetNormalizedColorHex()
    else
      HelloCursorDB.colorHex = (HC.NormalizeHex and HC.NormalizeHex(HelloCursorDB.colorHex))
        or (HC.DEFAULTS and HC.DEFAULTS.colorHex)
    end

    -- Legacy migration only (authoritative normalization lives in core)
    local size = tonumber(HelloCursorDB.size)
    if size == 192 then
      HelloCursorDB.size = 128
    end

    if HC.SyncRingStyleFlags then
      HC.SyncRingStyleFlags()
    end

    -- Run color mode migration now that SavedVariables are loaded,
    -- so legacy useClassColor is correctly reflected in colorMode.
    if HC.SyncColorModeFromLegacy then
      HC.SyncColorModeFromLegacy()
    end

    -- After all migrations have run, clean up any legacy-only
    -- SavedVariables that are no longer used.
    if HC.CleanupLegacySavedVariables then
      HC.CleanupLegacySavedVariables()
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

  -- For target changes we generally only need to refresh the tint, so
  -- avoid kicking the full visibility pipeline unless necessary.
  if event == "PLAYER_TARGET_CHANGED" then
    if HelloCursorDB and (
      HelloCursorDB.colorMode == "reaction" or
      HelloCursorDB.aggroMode == "hostile" or
      HelloCursorDB.aggroMode == "threat"
    ) then
      HC.ApplyTintIfNeeded(false)
    end
    return
  end

  -- When using hostile or threat aggro display, threat changes can
  -- affect whether the ring should be red even if the target stays
  -- the same.
  if event == "UNIT_THREAT_SITUATION_UPDATE" then
    if HelloCursorDB
      and (HelloCursorDB.aggroMode == "hostile" or HelloCursorDB.aggroMode == "threat")
      and arg1 == "player" then
      HC.ApplyTintIfNeeded(false)
    end
    return
  end

  HC.ApplyTintIfNeeded(false)
  HC.UpdateVisibility()
end)

SLASH_HELLOCURSOR1 = "/hc"
SLASH_HELLOCURSOR2 = "/hellocursor"

SlashCmdList.HELLOCURSOR = function(msg)
  if msg == "toggle" then
    local current = HC.IsAddonEnabled()
    local newValue = not current
    HelloCursorDB.enabled = newValue
    HC.UpdateVisibility()
    print(("HelloCursor: %s"):format(HelloCursorDB.enabled and "enabled" or "disabled"))
    return
  end

  if HC.settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(HC.settingsCategory:GetID())
  end
end
