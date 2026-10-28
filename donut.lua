--[[
	The rings.  Blizzard's Cooldown widget does the sweeping, so a ring can be
	driven by a duration object as well as by a start and a duration: on Retail
	and WoW Forever a cooldown's times are secret in combat, and only the widget
	may read them.  Its edge is the spark.
]]

local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
addon.donut = {}

local TEXTURES = "Interface\\AddOns\\CursorCooldown\\Textures\\"

-- A long, paused cooldown stands still at whatever angle it is given.
local STILL = 1000

-- direction: true fills clockwise from the top as time passes; false fills
-- anticlockwise, back from the top (the cast ring's latency).
function addon.donut:New(direction, radius, thickness, color, bgColor)
	local donut = {}

	function donut:AttachTo(anchor)
		self.bgFrame:SetParent(anchor)
		self.bgFrame:SetAllPoints(anchor)
	end

	function donut:SetRadius(radius)
		self.radius = radius
		self.background:SetSize(radius * 2, radius * 2)
		self.cooldown:SetSize(radius * 2, radius * 2)
	end

	function donut:SetThickness(thickness)
		self.thickness = thickness
		self.background:SetTexture(TEXTURES .. "ring_" .. thickness .. ".tga")
		self.cooldown:SetSwipeTexture(TEXTURES .. "ring_" .. thickness .. ".tga")
	end

	function donut:SetDirection(direction)
		self.direction = direction
		self.cooldown:SetReverse(direction)
	end

	function donut:SetBarColor(color)
		self.cooldown:SetSwipeColor(color.r, color.g, color.b, color.a)
	end

	function donut:SetBackgroundColor(color)
		self.background:SetVertexColor(color.r, color.g, color.b, color.a)
	end

	function donut:SetSparkColor(color)
		self.cooldown:SetEdgeColor(color.r, color.g, color.b, color.a)
	end

	-- The spark alone, without the ring or its background.
	function donut:SetSparkOnly(sparkOnly)
		self.cooldown:SetDrawSwipe(not sparkOnly)
		self.background:SetShown(not sparkOnly)
	end

	function donut:SetSpark(enabled)
		self.cooldown:SetDrawEdge(enabled)
	end

	-- Called when a running ring reaches the end (not when it is hidden).
	function donut:SetOnDone(func)
		self.cooldown:SetScript("OnCooldownDone", function()
			if not self.hiding then
				func()
			end
		end)
	end

	-- Run from start for duration (seconds, GetTime's clock).
	function donut:Start(start, duration)
		self.cooldown:SetPaused(false)
		self.cooldown:SetCooldown(start, duration)
	end

	-- Run from a duration object, which may hold secret times.
	function donut:StartDuration(duration)
		self.cooldown:SetPaused(false)
		self.cooldown:SetCooldownFromDurationObject(duration)
	end

	-- Stand still with degree of the ring filled.
	function donut:SetAngle(degree)
		if degree < 0 then
			degree = 0
		elseif degree > 360 then
			degree = 360
		end

		local filled = degree / 360
		if filled == 0 then
			self.cooldown:Clear()
			return
		end
		-- Filling clockwise shows what has passed; anticlockwise, what is left.
		local elapsed = self.direction and filled or (1 - filled)
		self.cooldown:SetPaused(false)
		self.cooldown:SetCooldown(GetTime() - elapsed * STILL, STILL)
		self.cooldown:SetPaused(true)
	end

	function donut:Show()
		self.bgFrame:Show()
	end

	function donut:Hide()
		self.bgFrame:Hide()
		self.hiding = true
		self.cooldown:Clear()
		self.hiding = false
	end

	local bgFrame = CreateFrame("Frame")
	donut.bgFrame = bgFrame

	donut.background = bgFrame:CreateTexture(nil, "BACKGROUND")
	donut.background:SetPoint("CENTER", bgFrame, "CENTER")

	local cooldown = CreateFrame("Cooldown", nil, bgFrame)
	cooldown:SetPoint("CENTER", bgFrame, "CENTER")
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetDrawBling(false)
	cooldown:SetUseCircularEdge(true)
	donut.cooldown = cooldown

	donut:SetThickness(thickness)
	donut:SetDirection(direction)
	donut:SetRadius(radius)
	donut:SetBarColor(color)
	donut:SetBackgroundColor(bgColor)
	donut:SetSpark(false)

	return donut
end
