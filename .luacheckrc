-- luacheck configuration. The game runs Lua 5.1.
std = "lua51"
max_line_length = 120
exclude_files = { ".luarocks/", "lua_modules/" }

-- Saved variables and slash command globals the addon owns.
globals = {
  "TrailMateDB", "TrailMateCharDB",
  "SLASH_TRAILMATE1", "SLASH_TRAILMATE2", "SlashCmdList",
  "TrailMate_OnAddonCompartmentClick", "UISpecialFrames", "TrailMate_Inbox",
}

-- Game API the addon reads. Listed one by one on purpose: a typo in a global
-- name is exactly what luacheck should catch.
read_globals = {
  "BackdropTemplateMixin", "C_AddOns", "C_Container", "C_Item", "C_Map", "C_QuestLine", "C_QuestLog",
  "C_SuperTrack", "C_Timer", "C_TooltipInfo", "CreateFrame", "CreateVector2D", "GetAddOnMetadata",
  "GetPlayerFacing",
  "GetBuildInfo", "GetContainerItemInfo", "GetContainerItemQuestInfo",
  "GetContainerNumFreeSlots", "GetContainerNumSlots", "GetInventoryItemID", "GetItemInfo",
  "GetLocale", "GetMoney", "GetNumQuestLogEntries", "GetNumTrainerServices",
  "GetQuestLogTitle", "GetTrainerServiceCost", "GetTrainerServiceInfo",
  "GetTrainerServiceLevelReq", "IsQuestFlaggedCompleted", "NUM_BAG_SLOTS",
  "NUM_REAGENTBAG_SLOTS", "QuestPOIGetIconInfo", "UIParent", "UiMapPoint",
  "UnitClass", "UnitLevel", "UnitXP", "UnitXPMax", "issecretvalue", "time",
  "CanMerchantRepair", "IsTradeskillTrainer", "UnitFactionGroup", "UnitGUID", "UnitName",
  "ChatFontNormal", "GameTooltip", "GetCursorPosition", "Minimap", "date", "IsIndoors", "GetCVar", "GetMinimapShape",
  "UnitCharacterPoints", "GetUnspentTalentPoints", "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents",
  "GetTalentInfo", "GetTalentPrereqs", "InCombatLockdown", "ToggleTalentFrame", "RaidNotice_AddMessage",
  "PlaySound", "SOUNDKIT", "C_ClassTalents", "C_Traits", "C_Spell", "GetSpellInfo", "GetNumSpecializations",
  "GetSpecializationInfo", "C_SpecializationInfo", "UnitOnTaxi", "UnitRace", "C_GossipInfo", "GetNumAvailableQuests",
  "GetAvailableQuestInfo", "GetAvailableTitle", "GetAvailableLevel", "GetQuestID", "GetTitleText", "GetRealZoneText",
  "GetZoneText", "GetSubZoneText", "GetMinimapZoneText", "C_QuestLog", "GetQuestLogSpecialItemInfo", "GetItemIcon", "GameTooltip", "CreateColor", "C_Texture", "C_TaxiMap", "Enum", "GetBindLocation", "GetItemCooldown", "GetItemCount", "GetTaxiMapID", "GetTime",
  "SetBinding", "SaveBindings", "GetBindingAction", "GetCurrentBindingSet", "GetAddOnInfo", "SetCVar",
  "Settings", "SettingsPanel", "HideUIPanel", "InterfaceOptions_AddCategory", "InterfaceOptionsFrame",
  "InterfaceOptionsFrame_OpenToCategory", "PixelUtil",
}

files["spec/"] = { std = "+busted" }

-- Generated data (tools/build_guides.lua, tools/build_dungeons.lua): long
-- lines are fine there.
files["TrailMate/data/Guides.lua"] = { max_line_length = false }
files["TrailMate/data/Dungeons.lua"] = { max_line_length = false }
files["TrailMate/data/GuideQuests.lua"] = { max_line_length = false }
