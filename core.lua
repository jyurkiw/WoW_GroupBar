GroupBarAddon = LibStub("AceAddon-3.0"):NewAddon("GroupBar", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
AceGUI = LibStub("AceGUI-3.0")

debug=1

-- Addon Variables
local GroupBarRoster = {}
-- local healthTimer = nil
healthTimer = nil
local basicUi = nil

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
  local unitIdBase = IsInRaid() and "raid" or "party"
  local unitId = nil

  for raidIndex=1, 40, 1
  do
    name, rank, subgroup, level, class, fileName,
      zone, online, isDead, combatRole, isML = GetRaidRosterInfo(raidIndex)
    self:Print(name, rank, subgroup, level, class, fileName, zone, online, isDead, combatRole, isML)
    if name == nil then break end

    -- If a character is a low enough level, combatRole can be nil. Set to none
    if combatRole == nil then combatRole = "NONE" end

    unitId = unitIdBase..raidIndex
    table.insert(GroupBarRoster, {name, class, combatRole})
  end

  if healthTimer == nil then healthTimer = self:ScheduleRepeatingTimer("HealthTimerHandler", 5) end
  self:Print("Done building raid roster")
end

function GroupBarAddon:UpdateRaidHealth()
  self:Print("Getting raid health")
  health, maxHealth = 0, 0

  for k,member in pairs(GroupBarRoster)
  do
    self:Print("===================")
    name, class, combatRole = unpack(member)
    self:Print(name, class, combatRole)
    self:Print("===================")
  end

  -- Loop through possible party/raid members
  -- Will probably need a local table keyed to names
  local nameRoleRoster = {}
  local rosterCount = 0
  for k,member in pairs(GroupBarRoster)
  do
    name, class, combatRole = unpack(member)
    nameRoleRoster[name] = {class=class, role=combatRole}
    rosterCount = rosterCount + 1
  end

  if IsInRaid()
  then
    for i=1,rosterCount,1
    do
      health = health + UnitHealth("raid"..i)
      maxHealth = maxHealth + UnitHealthMax("raid"..i)
      -- name, realm = UnitName("raid"..i)
      -- class, role = unpack(nameRoleRoster[name])
    end
  else
    for i=1,rosterCount-1,1
    do
      health = health + UnitHealth("party"..i)
      maxHealth = maxHealth + UnitHealthMax("party"..i)
      -- name, realm = UnitName("party"..i)
      -- class, role = unpack(nameRoleRoster[name])
    end
    health = health + UnitHealth("player")
    maxHealth = maxHealth + UnitHealthMax("player")
    -- name, realm = UnitName("player")
    -- class, role = unpack(nameRoleRoster[name])
  end

  self:Print("Done getting raid health")
  return health, maxHealth
end

-- Event Handlers
function GroupBarAddon:RosterUpdateHandler()
  self:Print("roster updated")
  self:BuildRaidRoster()
  if basicUi == nil then basicUi = self:CreateBasicUI() end
end

function GroupBarAddon:GroupLeftHandler()
  self:Print("group left")
  if healthTimer ~= nil then self:CancelTimer(healthTimer) end
  basicUi:Release()
  basicUi = nil
end

function GroupBarAddon:HealthTimerHandler()
  self:Print("Starting health timer logic...")
  health, maxHealth = GroupBarAddon:UpdateRaidHealth()
  basicUi:SetStatusText(health.."/"..maxHealth)
  self:Print("Raid Health at "..health.."/"..maxHealth)
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
      frame:SetHeight(300)

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
