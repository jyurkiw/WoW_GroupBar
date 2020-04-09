GroupBarAddon = LibStub("AceAddon-3.0"):NewAddon("GroupBar", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
AceGUI = LibStub("AceGUI-3.0")

debug=1

-- Addon Variables
local GroupBarRoster = {}
-- local healthTimer = nil
healthTimer = nil

function GroupBarAddon:OnInitialize()
  self:CreateReloadButton()
  self:Print("GroupBar:init begin")

  self:RegisterBucketEvent({"GROUP_ROSTER_UPDATE", "RAID_ROSTER_UPDATE"}, 2, "RosterUpdateHandler")
  self:RegisterEvent("GROUP_LEFT", "GroupLeftHandler")

  self:Print("GroupBar:init end")

  if debug == 1
  then
    self:RegisterEvent("PARTY_INVITE_REQUEST", "Debug_PartyInviteHandler")
  end
end

function GroupBarAddon:OnEnable()
  self:Print("GroupBar:Begin Enable")
  if IsInGroup()
  then
    self:BuildRaidRoster()
    self:DisplayBarUI()
  end
  self:Print("GroupBar:End Enable")
end

function GroupBarAddon:OnDisable()
  self:Print("GroupBar:Disabled")
end

-- Addon Functions
function GroupBarAddon:GetRaidMemberHealth(unitId)
  return UnitHealthMax(unitId) / UnitHealth(unitId)
end

function GroupBarAddon:BuildRaidRoster()
  GroupBarRoster = {}
  if not IsInGroup()
  then
    self:Print("Not in group. Aborting roster build...")
    return nil
  end
  self:Print("Building Raid Roster")
  local unitId = nil
  local isRaid = IsInRaid()
  local nameInfo = {}
  local maxIdx = isRaid and 40 or 4
  local baseUnitId = isRaid and "raid" or "party"

  -- for raid
  self:Print(maxIdx, baseUnitId)
  for raidIndex=1,maxIdx,1
  do
    local unitId = baseUnitId..raidIndex
    if UnitExists(unitId)
    then
      local name, server = UnitName(unitId)
      nameInfo[name] = unitId
    end
  end

  if not isRaid
  then
    -- for player
    local name, server = UnitName("player")
    nameInfo[name] = "player"
  end

  for raidIndex=1,maxIdx,1
  do
    name, rank, subgroup, level, class, fileName,
      zone, online, isDead, data, isML, combatRole = GetRaidRosterInfo(raidIndex)
    if name ~= nil
    then
      self:Print(name, rank, subgroup, level, class, fileName, zone, online, isDead, data, isML, combatRole)

      -- If a character is a low enough level, combatRole can be nil. Set to none
      if combatRole == nil then combatRole = "NONE"; self:Print("role to none for "..name) end

      table.insert(GroupBarRoster, {name, class, combatRole, nameInfo[name]})
    end
  end

  if healthTimer == nil then healthTimer = self:ScheduleRepeatingTimer("HealthTimerHandler", 0.2) end
  self:Print("Done building raid roster")
end

-- debug function hooks for UpdateRaidHealth()
gb_UnitHealth = UnitHealth
gb_UnitHealthMax = UnitHealthMax
gb_UnitIsDead = UnitIsDead
-- end debug function hooks for UpdateRaidHealth()

function GroupBarAddon:UpdateRaidHealth()
  health, currentMaxHealth, totalMaxHealth = 0, 0, 0

  -- Loop through possible party/raid members
  -- Will probably need a local table keyed to names
  local roster = {}

  for idx,member in pairs(GroupBarRoster)
  do
    name, class, combatRole, unitId = unpack(member)
    health = health + gb_UnitHealth(unitId)
    local maxHealth = gb_UnitHealthMax(unitId)
    currentMaxHealth = currentMaxHealth + (gb_UnitIsDead(unitId) and 0 or maxHealth)
    totalMaxHealth = totalMaxHealth + maxHealth
  end

  return health, currentMaxHealth, totalMaxHealth
end

-- Event Handlers
function GroupBarAddon:RosterUpdateHandler()
  self:Print("roster updated")
  self:BuildRaidRoster()
  self:DisplayBarUI()
end

function GroupBarAddon:GroupLeftHandler()
  self:Print("group left")
  if healthTimer ~= nil then self:CancelTimer(healthTimer) end
  self:HideBarUI()
end

function GroupBarAddon:HealthTimerHandler()
  health, currentMaxHealth, totalMaxHealth = GroupBarAddon:UpdateRaidHealth()
  self:UpdateBarUI(health, currentMaxHealth, totalMaxHealth)
end

-- UI
function GroupBarAddon:SpawnBarUI()
  local maxBar = CreateFrame("StatusBar",nil,UIParent)
  maxBar:SetFrameStrata("BACKGROUND")
  maxBar:SetWidth(400)
  maxBar:SetHeight(30)
  maxBar:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
  maxBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  maxBar:GetStatusBarTexture():SetHorizTile(false)
  maxBar:GetStatusBarTexture():SetVertTile(false)
  maxBar:SetStatusBarColor(0.65, 0, 0)

  maxBar.bg = maxBar:CreateTexture(nil, "BACKGROUND", nil, 3)
  maxBar.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  maxBar.bg:SetAllPoints(true)
  maxBar.bg:SetVertexColor(0.15, 0.15, 0.15)

  local currBar = CreateFrame("StatusBar",nil,maxBar)
  currBar:SetFrameStrata("BACKGROUND")
  currBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
  currBar:GetStatusBarTexture():SetHorizTile(false)
  currBar:GetStatusBarTexture():SetVertTile(false)
  currBar:SetAllPoints(true)
  currBar:SetStatusBarColor(0, 0.65, 0)

  local barOverlay = currBar:CreateFontString(nil, "OVERLAY")
  barOverlay:SetPoint("CENTER", currBar, "CENTER", 4, 0)
  barOverlay:SetFont("Fonts\\FRIZQT__.TTF", 12, "THICKOUTLINE")
  barOverlay:SetJustifyH("left")
  barOverlay:SetShadowOffset(1, -1)
  barOverlay:SetTextColor(0.2, 0.2, 1)

  maxBar:SetMinMaxValues(0, 100)
  maxBar:SetValue(100)
  currBar:SetMinMaxValues(0, 100)
  currBar:SetValue(100)
  barOverlay:SetText("1/1 (-0%)")

  maxBar:EnableMouse(true)
	maxBar:SetMovable(true)
  maxBar:SetToplevel(true)

  maxBar:SetScript("OnMouseDown", function(f) f:StartMoving() end)
  maxBar:SetScript("OnMouseUp", function(f) f:StopMovingOrSizing() end)

  uiEnabled = true
  return {
    current = currBar,
    max = maxBar,
    overlay = barOverlay,
    totalMax = 1,
  }
end

local healthBarUi = nil
function GroupBarAddon:GetBarUi() return healthBarUi end

function GroupBarAddon:DisplayBarUI()
  if healthBarUi == nil then healthBarUi = GroupBarAddon:SpawnBarUI() end
  healthBarUi.max:Show()
end

function GroupBarAddon:HideBarUI()
  healthBarUi.max:Hide()
end

function GroupBarAddon:UpdateBarUI(health, currentMaxHealth, totalMaxHealth)
  if totalMaxHealth ~= healthBarUi.totalMax
  then
    healthBarUi.current:SetMinMaxValues(0, totalMaxHealth)
    healthBarUi.max:SetMinMaxValues(0, totalMaxHealth)
    healthBarUi.totalMax = totalMaxHealth
  end
  healthBarUi.max:SetValue(currentMaxHealth)
  healthBarUi.current:SetValue(health)
  healthBarUi.overlay:SetText(self:GetOverlayText(health, currentMaxHealth, totalMaxHealth))
end

function GroupBarAddon:GetOverlayText(health, currentMaxHealth, totalMaxHealth)
  healthDefecit = currentMaxHealth - totalMaxHealth
  return health.."/"..currentMaxHealth.." ("..healthDefecit..")"
end

--[[
WoW Events of Note for Partys/Raids

GROUP_FORMED
GROUP_JOINED
GROUP_LEFT
GROUP_ROSTER_UPDATE
INSTANCE_GROUP_SIZE_CHANGED
RAID_ROSTER_UPDATE

Note:
Get Player group role:
  GetSpecializationRoleByID(GetPrimarySpecialization())
]]



-- Really, really basic UI
function GroupBarAddon:CreateBasicUI()
  self:Print("Creating basic ui!")
  frame = nil

  if debug == 1
  then
    frame = AceGUI:Create("Frame")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetTitle("GroupBar")
    frame:SetWidth(400)
    frame:SetHeight(80)
    frame:SetStatusText("1/1")
  end

  return frame
end

-- Fun Debug Stuff
txt = nil
function GroupBarAddon:CreateReloadButton()
  self:Print("Creating reloadui buton!")

  if (debug == 1)
    then
      local frame = AceGUI:Create("Frame")
      frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
      frame:SetTitle("Reload")

      frame:SetWidth(260)
      frame:SetHeight(340)

      local btn = AceGUI:Create("Button")
      btn:SetWidth(120)
      btn:SetHeight(40)
      btn:SetText("ReloadUI")
      btn:SetCallback("OnClick", function() ReloadUI() end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(120)
      btn:SetHeight(20)
      btn:SetText("Invite Target")
      btn:SetCallback("OnClick", function() local n, x=UnitName("target");C_PartyInfo.InviteUnit(n) end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(120)
      btn:SetHeight(20)
      btn:SetText("Leave Party")
      btn:SetCallback("OnClick", function() C_PartyInfo.LeaveParty() end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(120)
      btn:SetHeight(20)
      btn:SetText("Kill Timer")
      btn:SetCallback("OnClick", function() self:CancelAllTimers() end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(120)
      btn:SetHeight(20)
      btn:SetText("Build Roster")
      btn:SetCallback("OnClick", function() GroupBarAddon:BuildRaidRoster() end)
      frame:AddChild(btn)


      -- ---------------------------------------------------------------------

      txt = AceGUI:Create("EditBox")
      txt:SetWidth(180)
      txt:SetHeight(30)
      txt:SetText("1")
      frame:AddChild(txt)

      btn = AceGUI:Create("Button")
      btn:SetWidth(180)
      btn:SetHeight(20)
      btn:SetText("GetRaidRosterInfo(*)")
      btn:SetCallback("OnClick", function() print(GetRaidRosterInfo(txt:GetText())) end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(180)
      btn:SetHeight(20)
      btn:SetText("UnitName(*)")
      btn:SetCallback("OnClick", function() print(UnitName(txt:GetText())) end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(180)
      btn:SetHeight(20)
      btn:SetText("UnitHealth(*)")
      btn:SetCallback("OnClick", function() print(UnitHealth(txt:GetText())) end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(180)
      btn:SetHeight(20)
      btn:SetText("Mock Raid Roster")
      btn:SetCallback("OnClick", function() self:Debug_MockRaidRoster(); self:DisplayBarUI() end)
      frame:AddChild(btn)

      btn = AceGUI:Create("Button")
      btn:SetWidth(180)
      btn:SetHeight(20)
      btn:SetText("Mock Leave Group")
      btn:SetCallback("OnClick", function() self:GroupLeftHandler() end)
      frame:AddChild(btn)
    end
end

function GroupBarAddon:Debug_PartyInviteHandler(event, name)
  self:Print(name)
  self:Print(txt:GetText())
  self:Print(name == txt:GetText())
  if txt:GetText() == name
  then
    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
  end
end

local dbg_rosterData = nil

function GroupBarAddon:Debug_MockRaidRoster()
  self:Print("Mocking the raid roster...")
  table.insert(GroupBarRoster, {"Pawn1", "Warrior", "TANK", "raid1"})
  table.insert(GroupBarRoster, {"Pawn2", "Monk", "HEALER", "raid2"})
  table.insert(GroupBarRoster, {"Pawn3", "Druid", "DAMAGER", "raid3"})
  table.insert(GroupBarRoster, {"Pawn4", "Paladin", "DAMAGER", "raid4"})
  table.insert(GroupBarRoster, {"Pawn5", "Rogue", "DAMAGER", "raid5"})
  table.insert(GroupBarRoster, {"Pawn6", "Warlock", "DAMAGER", "raid6"})
  table.insert(GroupBarRoster, {"Pawn7", "Warrior", "DAMAGER", "raid7"})
  table.insert(GroupBarRoster, {"Pawn8", "Mage", "DAMAGER", "raid8"})
  table.insert(GroupBarRoster, {"Pawn9", "Hunter", "DAMAGER", "raid9"})

  local baseHealth, maxHealth = 100, 125
  dbg_rosterData = {}
  for k, member in pairs(GroupBarRoster)
  do
    local name, class, role, unitId = unpack(member)

    dbg_rosterData[unitId] = {baseHealth, maxHealth, false}

    baseHealth, maxHealth = baseHealth + 10, maxHealth + 125
  end

  -- kill two of the raiders
  dbg_rosterData["raid4"][3] = true
  dbg_rosterData["raid4"][5] = true

  -- debug function hooks for UpdateRaidHealth()
  gb_UnitHealth = function(unitId) return dbg_rosterData[unitId][1] end
  gb_UnitHealthMax = function(unitId) return dbg_rosterData[unitId][2] end
  gb_UnitIsDead = function(unitId) return dbg_rosterData[unitId][3] end
  -- end debug function hooks for UpdateRaidHealth()

  if healthTimer == nil then healthTimer = self:ScheduleRepeatingTimer("HealthTimerHandler", 0.2) end
end
