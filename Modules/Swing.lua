--[[
	Most of the functionality was taken from the Quartz - Swing Module. Credits go to Nymbia and Nevcairiel
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("swing")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local swingFrame
local options
local ringMod

local playerClass, playerGUID

-- Where swings come from.  WoW Forever reports each one (PLAYER_SWING); the
-- Classic clients still let addons read the combat log.  Retail has neither,
-- so it shows Auto Shot alone.
local hasSwingEvent = C_SwingTimer ~= nil
local CombatLogInfo = (C_CombatLog and C_CombatLog.GetCurrentEventInfo) or CombatLogGetCurrentEventInfo

local AUTO_SHOT, SHOOT, SLAM = 75, 5019, 1464
local slamStart

-- The main ring is the main hand, or ranged; the off hand has its own, inside it.
local rings = {main = {}, off = {}}

local defaults = {
	profile = {
		barColor = {r = 1, g = 1, b = 1, a = 0.8},
		backgroundColor = {r = 0.4, g = 0.4, b = 0.4, a = 0.8},
		sparkColor = {r = 0.9, g = 0.8, b = 1, a = 1},
		radius = 18,
		thickness = 25,
		sparkOnly = false
	}
}

function module:OnEnable()
	playerGUID = UnitGUID("player")
	self:ApplyOptions()
	if hasSwingEvent then
		self:RegisterEvent("PLAYER_SWING")
	else
		if CombatLogInfo then
			self:RegisterEvent("PLAYER_ENTER_COMBAT")
			self:RegisterEvent("PLAYER_LEAVE_COMBAT")
			if playerClass == "WARRIOR" then
				self:RegisterEvent("UNIT_SPELLCAST_START")
				self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
			end
		end
		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	end
end

function module:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
end

function module:FixDatabase()
	if self.db.profile.version then
	-- nothing to do yet
	end
	self.db.profile.version = dbVersion
end

function module:OnInitialize()
	self.db = addon.db:RegisterNamespace("Swing", defaults)
	self:FixDatabase()
	ringMod = addon:GetModule("ring", true)
	playerClass = select(2, UnitClass("player"))
end

function module:GetOptions()
	options = {
		name = "Swing",
		type = "group",
		args = {
			sources = {
				name = L["Melee swings come from the combat log on Classic and from the swing timer on WoW Forever. Retail has neither, so it shows Auto Shot alone."],
				type = "description",
				order = 0.5
			},
			sparkOnly = {
				name = L["Show spark only"],
				type = "toggle",
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				get = function(info)
					return self.db.profile.sparkOnly
				end,
				set = function(info, val)
					self.db.profile.sparkOnly = val
					self:ApplyOptions()
				end,
				order = 1
			},
			radius = {
				name = L["Radius"],
				type = "range",
				min = 10,
				max = 256,
				step = 1,
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				get = function(info)
					return self.db.profile.radius
				end,
				set = function(info, val)
					self.db.profile.radius = val
					self:ApplyOptions()
				end,
				order = 2
			},
			thickness = {
				name = L["Thickness"],
				type = "range",
				min = 15,
				max = 25,
				step = 5,
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				get = function(info)
					return self.db.profile.thickness
				end,
				set = function(info, val)
					self.db.profile.thickness = val
					self:ApplyOptions()
				end,
				order = 3
			},
			colors = {
				name = L["Colors"],
				type = "header",
				order = 10
			},
			barColor = {
				name = L["Bar"],
				type = "color",
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				get = function(info)
					return self.db.profile.barColor.r, self.db.profile.barColor.g, self.db.profile.barColor.b, self.db.profile.barColor.a
				end,
				set = function(info, r, g, b, a)
					self.db.profile.barColor = {r = r, g = g, b = b, a = a}
					self:ApplyOptions()
				end,
				hasAlpha = true,
				order = 11
			},
			bgColor = {
				name = L["Background"],
				type = "color",
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				get = function(info)
					return self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a
				end,
				set = function(info, r, g, b, a)
					self.db.profile.backgroundColor = {r = r, g = g, b = b, a = a}
					self:ApplyOptions()
				end,
				hasAlpha = true,
				order = 12
			},
			sparkColor = {
				name = L["Spark"],
				type = "color",
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				get = function(info)
					return self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a
				end,
				set = function(info, r, g, b, a)
					self.db.profile.sparkColor = {r = r, g = g, b = b, a = a}
					self:ApplyOptions()
				end,
				hasAlpha = true,
				order = 13
			},
			misc = {
				name = L["Miscellaneous"],
				type = "header",
				order = 20
			},
			defaults = {
				name = L["Restore defaults"],
				type = "execute",
				disabled = function()
					return not addon.db.profile.modules.swing
				end,
				func = function()
					self.db:ResetProfile()
					self:ApplyOptions()
				end,
				order = 21
			}
		}
	}
	return options
end

function module:Show()
	addon:Show("swing")
	if ringMod and ringMod:IsEnabled() then
		ringMod:Show("swing")
	end
	swingFrame:Show()
end

function module:Hide()
	for _, ring in pairs(rings) do
		ring.start, ring.duration = nil, nil
		if ring.donut then
			ring.donut:Hide()
		end
	end
	swingFrame:Hide()

	if ringMod and ringMod:IsEnabled() then
		ringMod:Hide("swing")
	end
	addon:Hide("swing")
end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

-- Start a ring's swing, now.  Attack speeds can be secret on some clients;
-- such a swing isn't shown.
function module:StartSwing(which, duration)
	if not duration or IsSecret(duration) or duration <= 0 then
		return
	end
	local ring = rings[which]
	ring.start, ring.duration = GetTime(), duration
	ring.donut:Show()
	ring.donut:Start(ring.start, ring.duration)
	self:Show()
end

-- A ring's swing, moved: delayed by Slam, or cut short by a parry.
local function MoveSwing(ring, start, duration)
	ring.start, ring.duration = start, duration
	ring.donut:Start(start, duration)
end

local function EndSwing(which)
	local ring = rings[which]
	ring.start, ring.duration = nil, nil
	ring.donut:Hide()
	for _, other in pairs(rings) do
		if other.start then
			return
		end
	end
	module:Hide()
end

-- WoW Forever: every auto attack, with how long until the next.
function module:PLAYER_SWING(event, swingDuration, swingType)
	if swingType == Enum.PlayerSwingType.OffHand then
		self:StartSwing("off", swingDuration)
	else
		self:StartSwing("main", swingDuration)
	end
end

-- Classic: melee swings come from the combat log while we auto attack.
function module:PLAYER_ENTER_COMBAT()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function module:PLAYER_LEAVE_COMBAT()
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function module:COMBAT_LOG_EVENT_UNFILTERED()
	local _, subEvent, _, srcGUID, _, _, _, dstGUID, _, _, _, arg12, arg13, _, _, _, _, _, _, _, arg21 = CombatLogInfo()
	if srcGUID == playerGUID then
		local offHand
		if subEvent == "SWING_DAMAGE" then
			offHand = arg21
		elseif subEvent == "SWING_MISSED" then
			offHand = arg13
		else
			return
		end
		local mainSpeed, offSpeed = UnitAttackSpeed("player")
		if offHand then
			self:StartSwing("off", offSpeed)
		else
			self:StartSwing("main", mainSpeed)
		end
	elseif dstGUID == playerGUID and subEvent == "SWING_MISSED" and arg12 == "PARRY" then
		local ring = rings.main
		if ring.start then
			MoveSwing(ring, ring.start, ring.duration * 0.6)
		end
	end
end

local function IsSlam(spellID)
	local slam = C_Spell.GetSpellInfo(SLAM)
	local spell = C_Spell.GetSpellInfo(spellID)
	return slam and spell and slam.name == spell.name
end

-- Ranged: each Auto Shot (or wand Shoot) starts the next.
function module:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
	if unit ~= "player" then
		return
	end
	if spellID == AUTO_SHOT or spellID == SHOOT then
		self:StartSwing("main", (UnitRangedDamage("player")))
	elseif slamStart and IsSlam(spellID) then
		-- Slam holds the swing while it is cast.
		local ring = rings.main
		if ring.start then
			MoveSwing(ring, ring.start + GetTime() - slamStart, ring.duration)
		end
		slamStart = nil
	end
end

function module:UNIT_SPELLCAST_START(event, unit, castGUID, spellID)
	if unit == "player" and IsSlam(spellID) then
		slamStart = GetTime()
	end
end

function module:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID)
	if unit == "player" and slamStart and IsSlam(spellID) then
		slamStart = nil
	end
end

local function ApplyRing(ring, radius, db)
	if not ring.donut then
		ring.donut = addon.donut:New(true, radius, db.thickness, db.barColor, db.backgroundColor)
		ring.donut:AttachTo(swingFrame)
		ring.donut:SetSpark(true)
	end
	local donut = ring.donut
	donut:SetRadius(radius)
	donut:SetThickness(db.thickness)
	donut:SetBarColor(db.barColor)
	donut:SetBackgroundColor(db.backgroundColor)
	donut:SetSparkColor(db.sparkColor)
	donut:SetSparkOnly(db.sparkOnly)
end

function module:ApplyOptions()
	local anchor = addon.anchor
	if self:IsEnabled() then
		if not swingFrame then
			swingFrame = CreateFrame("Frame")
			swingFrame:SetParent(anchor)
			swingFrame:SetAllPoints()
		end

		local db = self.db.profile
		ApplyRing(rings.main, db.radius, db)
		-- The off hand's ring sits just inside the main hand's.
		ApplyRing(rings.off, db.radius * (1 - db.thickness / 256) - 1, db)
		rings.main.donut:SetOnDone(function() EndSwing("main") end)
		rings.off.donut:SetOnDone(function() EndSwing("off") end)
		self:Hide()
	end
end

function module:Unlock(cursor)
	if not self.db.profile.sparkOnly then
		swingFrame:SetParent(cursor)
		swingFrame:SetAllPoints()
		swingFrame:Show()
		rings.main.donut:Show()
		rings.main.donut:SetAngle(115)
	end
end

function module:Lock()
	if not self.db.profile.sparkOnly then
		self:Hide()
		swingFrame:SetParent(addon.anchor)
		swingFrame:SetAllPoints()
	end
end
