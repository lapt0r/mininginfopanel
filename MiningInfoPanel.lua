MiningInfoPanel = {}
local MIP = MiningInfoPanel

-- Database version constants
local DB_VERSION = 2
local DB_VERSION_KEY = "dbVersion"

-- Mining spell IDs for TWW
local MINING_SPELL_IDS = {
	[2575] = true,   -- Mining (base skill)
	[195122] = true, -- Prospecting
	[265841] = true, -- Additional mining spell
}

-- Ore item ID lookup table for node type identification
-- This table maps ore item IDs to their canonical ore type
local ORE_LOOKUP = {
	-- The War Within Ores
	[210931] = 210931, -- Bismuth (Quality 2)
	[210930] = 210931, -- Bismuth (Quality 1) -> maps to Quality 2
	[210936] = 210936, -- Ironclaw Ore (Quality 1)
	[210937] = 210936, -- Ironclaw Ore (Quality 2) -> maps to Quality 1
	[210938] = 210936, -- Ironclaw Ore (Beta) -> maps to Quality 1
	[210934] = 210934, -- Aqirite (Quality 2)
	[210933] = 210934, -- Aqirite (Beta) -> maps to Quality 2
	[210935] = 210934, -- Aqirite (Beta variant) -> maps to Quality 2
	
	-- Dragonflight Ores
	[190396] = 190396, -- Serevite Ore (Quality 2)
	[190395] = 190396, -- Serevite Ore (Quality 1) -> maps to Quality 2
	[188658] = 188658, -- Draconium Ore
	[189143] = 188658, -- Draconium Ore (alternate ID) -> maps to main ID
	[190312] = 190312, -- Khaz'gorite Ore
	
	-- Shadowlands Ores
	[171829] = 171829, -- Solenium Ore
	[171833] = 171833, -- Elethium Ore
	[171832] = 171832, -- Sinvyr Ore
	[171831] = 171831, -- Phaedrum Ore
	[171828] = 171828, -- Laestrite Ore
	[171830] = 171830, -- Oxxein Ore
	
	-- Legacy Ores (Classic through Legion)
	[2770] = 2770,   -- Copper Ore
	[2771] = 2771,   -- Tin Ore
	[2772] = 2772,   -- Iron Ore
	[2775] = 2775,   -- Silver Ore
	[2776] = 2776,   -- Gold Ore
	[3858] = 3858,   -- Mithril Ore
	[10620] = 10620, -- Thorium Ore
	[23424] = 23424, -- Fel Iron Ore
	[23425] = 23425, -- Adamantite Ore
	[36909] = 36909, -- Cobalt Ore
	[36912] = 36912, -- Saronite Ore
	[36910] = 36910, -- Titanium Ore
	[53038] = 53038, -- Obsidium Ore
	[52183] = 52183, -- Pyrite Ore
	[52185] = 52185, -- Elementium Ore
	[72092] = 72092, -- Ghost Iron Ore
	[72093] = 72093, -- Kyparite
	[72094] = 72094, -- Black Trillium Ore
	[72103] = 72103, -- White Trillium Ore
	[109119] = 109119, -- True Iron Ore
	[109118] = 109118, -- Blackrock Ore
	[123918] = 123918, -- Leystone Ore
	[123919] = 123919, -- Felslate
	[151564] = 151564, -- Empyrium
	[152512] = 152512, -- Monelite Ore
	[152513] = 152513, -- Platinum Ore
	[152579] = 152579, -- Storm Silver Ore
	[168185] = 168185, -- Osmenite Ore
}

-- Function to identify node type from loot items
local function IdentifyNodeType(lootItems)
	-- lootItems is a table of {itemID = count, ...}
	for itemID, _ in pairs(lootItems) do
		local nodeType = ORE_LOOKUP[itemID]
		if nodeType then
			return nodeType -- Return first ore found (nodes only contain one ore type)
		end
	end
	return nil -- No ore found in loot
end

-- Initialize saved variables structure with versioning
local function InitDB()
	-- Create new database if none exists
	if not MiningInfoPanelDB then
		print("|cff00ff00MiningInfoPanel:|r Creating new database (v" .. DB_VERSION .. ")...")
		MiningInfoPanelDB = {
			[DB_VERSION_KEY] = DB_VERSION,
			allTime = {}, -- [zone][itemID] = count
			currentSession = {},
			sessionStart = time(),
			-- Skill-based tracking
			bySkill = {}, -- [skillRange][itemID] = count
			-- Configuration settings
			config = {
				showYieldMessages = true,
				debugLogging = false,
				autoOpen = true,
				showMinimapButton = true,
			},
			-- Node tracking
			nodeHistory = {}, -- Array of {time = timestamp, yields = {[itemID] = count}, nodeType = itemID}
			-- Total nodes mined
			totalNodes = 0,
			-- Yield tracking for averages
			yieldsByItem = {}, -- [itemID] = {total = count, nodes = nodeCount}
			-- Node type tracking
			nodeTypes = {}, -- [zoneOrSkillRange][nodeTypeItemID] = count
			sessionNodeTypes = {} -- [zone][nodeTypeItemID] = count
		}
	else
		-- Existing database - check version and migrate if needed
		local currentVersion = MiningInfoPanelDB[DB_VERSION_KEY] or 1
		if currentVersion < DB_VERSION then
			print(
				"|cff00ff00MiningInfoPanel:|r Migrating database from v"
					.. currentVersion
					.. " to v"
					.. DB_VERSION
					.. "..."
			)
			
			-- Migration from v1 to v2: Reset node tracking for new ore lookup system
			if currentVersion == 1 then
				-- Clear old node tracking data since it used unreliable detection
				MiningInfoPanelDB.nodeHistory = {}
				MiningInfoPanelDB.totalNodes = 0
				MiningInfoPanelDB.yieldsByItem = {}
				MiningInfoPanelDB.nodeTypes = {}
				MiningInfoPanelDB.sessionNodeTypes = {}
				print("|cff00ff00MiningInfoPanel:|r Node tracking data reset for improved accuracy")
			end
			
			-- Update version
			MiningInfoPanelDB[DB_VERSION_KEY] = DB_VERSION
			print("|cff00ff00MiningInfoPanel:|r Database migration complete")
		elseif currentVersion > DB_VERSION then
			print(
				"|cffffff00MiningInfoPanel Warning:|r Database version "
					.. currentVersion
					.. " is newer than addon supports (v"
					.. DB_VERSION
					.. "). Some features may not work correctly."
			)
		end
	end

	-- Reset session data on login (always done regardless of version)
	MiningInfoPanelDB.currentSession = {}
	MiningInfoPanelDB.sessionStart = time()
	-- Clear ephemeral session data
	MiningInfoPanelDB.nodeHistory = {}
	MiningInfoPanelDB.totalNodes = 0
	MiningInfoPanelDB.yieldsByItem = {}
	MiningInfoPanelDB.sessionNodeTypes = {}
end

-- Default configuration values
local DEFAULT_CONFIG = {
	showYieldMessages = true,
	debugLogging = false,
	autoOpen = true,
	showMinimapButton = true,
}

-- Settings facade for safe config access
function MIP:GetConfig(key)
	-- Ensure database and config exist
	if not MiningInfoPanelDB then
		return DEFAULT_CONFIG[key]
	end

	if not MiningInfoPanelDB.config then
		MiningInfoPanelDB.config = {}
	end

	-- Return value or default
	local value = MiningInfoPanelDB.config[key]
	if value == nil then
		return DEFAULT_CONFIG[key]
	end

	return value
end

-- Settings facade for safe config setting
function MIP:SetConfig(key, value)
	-- Ensure database and config exist
	if not MiningInfoPanelDB then
		return
	end

	if not MiningInfoPanelDB.config then
		MiningInfoPanelDB.config = {}
	end

	MiningInfoPanelDB.config[key] = value
end

-- State
MIP.showingAllTime = false
MIP.showingBySkill = false
MIP.currentZone = ""
MIP.currentSkillRange = ""
MIP.oreRows = {}
MIP.currentNodeYields = {} -- Track yields from current node being mined
MIP.lastMiningCastTime = 0 -- Track when we last cast a mining spell
MIP.autoOpened = false

-- Minimap button setup
local minimapButton = CreateFrame("Button", "MiningInfoPanelMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton")

-- Set normal, pushed and highlight textures to match WoW style
minimapButton:SetNormalTexture("Interface\\Minimap\\UI-Minimap-ZoomButton")
minimapButton:SetPushedTexture("Interface\\Minimap\\UI-Minimap-ZoomButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Get textures and resize them
local normalTexture = minimapButton:GetNormalTexture()
local pushedTexture = minimapButton:GetPushedTexture()
local highlightTexture = minimapButton:GetHighlightTexture()

if normalTexture then normalTexture:SetSize(52, 52) end
if pushedTexture then pushedTexture:SetSize(52, 52) end
if highlightTexture then highlightTexture:SetSize(52, 52) end

-- Minimap button icon
local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture(136248) -- Mining pick icon

-- Minimap button position
local function UpdateMinimapButtonPosition()
	local angle = math.rad(MiningInfoPanelDB.minimapPos or 225)
	-- Calculate radius based on minimap size
	local minimapSize = Minimap:GetWidth()
	local radius = minimapSize / 2 + 10  -- Place button slightly outside minimap edge
	local x, y = math.cos(angle) * radius, math.sin(angle) * radius
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Minimap button dragging
minimapButton:SetMovable(true)
minimapButton:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", function(self)
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		px, py = px / scale, py / scale
		local angle = math.deg(math.atan2(py - my, px - mx))
		-- Normalize angle to 0-360
		if angle < 0 then angle = angle + 360 end
		MiningInfoPanelDB.minimapPos = angle
		UpdateMinimapButtonPosition()
	end)
end)

minimapButton:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
end)

-- Minimap button tooltip
minimapButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Mining Info Panel", 1, 1, 1)
	GameTooltip:AddLine("Left click: Toggle panel", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Right click: Toggle skill view", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
	GameTooltip:Hide()
end)

-- Minimap button click handlers
minimapButton:SetScript("OnClick", function(self, button)
	if button == "LeftButton" then
		MIP:ToggleFrame()
	elseif button == "RightButton" then
		MIP:ToggleSkillView()
	end
end)

-- Show/hide minimap button
function MIP:UpdateMinimapButton()
	if MIP:GetConfig("showMinimapButton") then
		minimapButton:Show()
		UpdateMinimapButtonPosition()
	else
		minimapButton:Hide()
	end
end

-- Get current location
local function GetCurrentLocation()
	local zone = GetRealZoneText() or "Unknown"
	return zone
end

-- Get current mining skill
local function GetMiningSkill()
	local prof1, prof2 = GetProfessions()
	local profs = {prof1, prof2}

	for _, index in ipairs(profs) do
		if index then
			local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier =
				GetProfessionInfo(index)
			-- Check if this is Mining
			if skillLine == 186 then -- Mining skill line ID
				-- Total skill includes base skill + modifiers
				local totalSkill = (skillLevel or 0) + (skillModifier or 0)
				return totalSkill, skillLevel, skillModifier
			end
		end
	end
	return 0, 0, 0
end

-- Get skill range for grouping (e.g., "1-50", "51-100", etc.)
-- Modern WoW mining caps at 300 skill
local function GetSkillRange(skill)
	if skill <= 50 then
		return "1-50"
	elseif skill <= 100 then
		return "51-100"
	elseif skill <= 150 then
		return "101-150"
	elseif skill <= 200 then
		return "151-200"
	elseif skill <= 250 then
		return "201-250"
	elseif skill <= 300 then
		return "251-300"
	else
		return "300+"
	end
end

-- Calculate nodes per hour based on 5-minute window
local function GetNodesPerHour()
	if not MiningInfoPanelDB.nodeHistory then
		return 0
	end

	local currentTime = time()
	local cutoffTime = currentTime - 300 -- 5 minutes
	local recentNodes = 0

	-- Count nodes in the last 5 minutes
	for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
		if node.time > cutoffTime then
			recentNodes = recentNodes + 1
		end
	end

	-- Calculate nodes per hour based on 5-minute window
	if recentNodes > 0 and #MiningInfoPanelDB.nodeHistory > 0 then
		local oldestRecentNode = currentTime
		for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
			if node.time > cutoffTime and node.time < oldestRecentNode then
				oldestRecentNode = node.time
			end
		end

		local timeWindow = currentTime - oldestRecentNode
		if timeWindow > 0 then
			local nodesPerSecond = recentNodes / timeWindow
			return nodesPerSecond * 3600 -- Convert to per hour
		end
	end

	return 0
end

-- Calculate node types per hour
local function GetNodeTypesPerHour()
	if not MiningInfoPanelDB.nodeHistory or #MiningInfoPanelDB.nodeHistory == 0 then
		return {}
	end

	local currentTime = time()
	local cutoffTime = currentTime - 300 -- 5 minutes
	local recentNodeTypes = {} -- [nodeType] = count

	-- Count node types in the last 5 minutes
	for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
		if node.time > cutoffTime and node.nodeType then
			recentNodeTypes[node.nodeType] = (recentNodeTypes[node.nodeType] or 0) + 1
		end
	end

	-- Calculate nodes per hour for each type
	local nodesPerHour = {}
	if next(recentNodeTypes) then
		-- Find the oldest node in the window
		local oldestNodeTime = currentTime
		for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
			if node.time > cutoffTime and node.time < oldestNodeTime then
				oldestNodeTime = node.time
			end
		end

		local timeWindow = currentTime - oldestNodeTime
		if timeWindow > 0 then
			for nodeType, count in pairs(recentNodeTypes) do
				nodesPerHour[nodeType] = (count / timeWindow) * 3600
			end
		end
	end

	return nodesPerHour
end

-- Calculate yield per hour for all items
local function GetYieldPerHour()
	if not MiningInfoPanelDB.nodeHistory or #MiningInfoPanelDB.nodeHistory == 0 then
		return {}
	end

	local currentTime = time()
	local cutoffTime = currentTime - 300 -- 5 minutes
	local recentYields = {} -- [itemID] = count

	-- Sum up yields in the last 5 minutes
	for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
		if node.time > cutoffTime then
			for itemID, count in pairs(node.yields) do
				recentYields[itemID] = (recentYields[itemID] or 0) + count
			end
		end
	end

	-- Calculate yield per hour for each item
	local yieldsPerHour = {}
	if next(recentYields) then
		-- Find the oldest node in the window
		local oldestNodeTime = currentTime
		for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
			if node.time > cutoffTime and node.time < oldestNodeTime then
				oldestNodeTime = node.time
			end
		end

		local timeWindow = currentTime - oldestNodeTime
		if timeWindow > 0 then
			for itemID, count in pairs(recentYields) do
				yieldsPerHour[itemID] = (count / timeWindow) * 3600
			end
		end
	end

	return yieldsPerHour
end

-- Calculate average yield per node for an item
local function GetAverageYield(itemID)
	local yieldData = MiningInfoPanelDB.yieldsByItem[itemID]
	if not yieldData or yieldData.nodes == 0 then
		return 0
	end
	return yieldData.total / yieldData.nodes
end

-- Get mining percentage by node (what % of nodes yield this item)
local function GetMiningPercentageByNode(itemID, zone)
	-- For session data, check how many nodes yielded this item
	local sessionNodes = 0
	local nodesWithItem = 0

	if MiningInfoPanelDB.nodeHistory then
		for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
			sessionNodes = sessionNodes + 1
			if node.yields[itemID] and node.yields[itemID] > 0 then
				nodesWithItem = nodesWithItem + 1
			end
		end
	end

	if sessionNodes == 0 then
		return 0
	end

	return (nodesWithItem / sessionNodes) * 100
end

-- Record an ore yield from current node
function MIP:RecordYield(itemID, count)
	-- Add to current node yields
	MIP.currentNodeYields[itemID] = (MIP.currentNodeYields[itemID] or 0) + count

	-- Yield logging (if enabled)
	if MIP:GetConfig("showYieldMessages") then
		local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
		local totalSkill, baseSkill, modifier = GetMiningSkill()

		local skillText
		if modifier > 0 then
			skillText = string.format("(%d+%d)", baseSkill, modifier)
		else
			skillText = string.format("(%d)", baseSkill)
		end

		local countText = count > 1 and string.format(" x%d", count) or ""
		print(string.format("|cff00ff00MiningInfoPanel:|r Mined %s%s %s", itemName, countText, skillText))
	end
end

-- Complete a mining node and record all yields
function MIP:CompleteNode()
	if not next(MIP.currentNodeYields) then
		return -- No yields to record
	end

	local zone = GetCurrentLocation()
	local totalSkill, baseSkill, modifier = GetMiningSkill()
	local skillRange = GetSkillRange(totalSkill)

	-- Determine node type using ore lookup table
	local nodeType = IdentifyNodeType(MIP.currentNodeYields)

	-- Initialize structures if needed
	MiningInfoPanelDB.allTime[zone] = MiningInfoPanelDB.allTime[zone] or {}
	MiningInfoPanelDB.currentSession[zone] = MiningInfoPanelDB.currentSession[zone] or {}
	MiningInfoPanelDB.bySkill[skillRange] = MiningInfoPanelDB.bySkill[skillRange] or {}
	MiningInfoPanelDB.nodeTypes = MiningInfoPanelDB.nodeTypes or {}
	MiningInfoPanelDB.nodeTypes[zone] = MiningInfoPanelDB.nodeTypes[zone] or {}
	MiningInfoPanelDB.nodeTypes[skillRange] = MiningInfoPanelDB.nodeTypes[skillRange] or {}
	MiningInfoPanelDB.sessionNodeTypes[zone] = MiningInfoPanelDB.sessionNodeTypes[zone] or {}

	-- Record node in history
	table.insert(MiningInfoPanelDB.nodeHistory, {
		time = time(),
		yields = MIP.currentNodeYields,
		nodeType = nodeType
	})

	-- Update total nodes count
	MiningInfoPanelDB.totalNodes = MiningInfoPanelDB.totalNodes + 1

	-- Track node type counts
	if nodeType then
		MiningInfoPanelDB.nodeTypes[zone][nodeType] = (MiningInfoPanelDB.nodeTypes[zone][nodeType] or 0) + 1
		MiningInfoPanelDB.nodeTypes[skillRange][nodeType] = (MiningInfoPanelDB.nodeTypes[skillRange][nodeType] or 0) + 1
		MiningInfoPanelDB.sessionNodeTypes[zone][nodeType] = (MiningInfoPanelDB.sessionNodeTypes[zone][nodeType] or 0) + 1
	end

	-- Update yield tracking
	for itemID, count in pairs(MIP.currentNodeYields) do
		-- Update all-time and session counts
		MiningInfoPanelDB.allTime[zone][itemID] = (MiningInfoPanelDB.allTime[zone][itemID] or 0) + count
		MiningInfoPanelDB.currentSession[zone][itemID] = (MiningInfoPanelDB.currentSession[zone][itemID] or 0) + count
		MiningInfoPanelDB.bySkill[skillRange][itemID] = (MiningInfoPanelDB.bySkill[skillRange][itemID] or 0) + count

		-- Update yield tracking for averages
		MiningInfoPanelDB.yieldsByItem[itemID] = MiningInfoPanelDB.yieldsByItem[itemID] or {total = 0, nodes = 0}
		MiningInfoPanelDB.yieldsByItem[itemID].total = MiningInfoPanelDB.yieldsByItem[itemID].total + count
		MiningInfoPanelDB.yieldsByItem[itemID].nodes = MiningInfoPanelDB.yieldsByItem[itemID].nodes + 1
	end

	-- Clean up old node history (keep only last 5 minutes)
	local cutoffTime = time() - 300 -- 5 minutes in seconds
	local newHistory = {}
	for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
		if node.time > cutoffTime then
			table.insert(newHistory, node)
		end
	end
	MiningInfoPanelDB.nodeHistory = newHistory

	-- Debug logging (if enabled)
	if MIP:GetConfig("debugLogging") then
		local nodeYieldText = {}
		for itemID, count in pairs(MIP.currentNodeYields) do
			local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
			table.insert(nodeYieldText, string.format("%s x%d", itemName, count))
		end
		local nodeTypeName = nodeType and (GetItemInfo(nodeType) or ("NodeType " .. nodeType)) or "Unknown"
		print(string.format("|cff00ff00MiningInfoPanel Debug:|r Completed node in %s: %s | Node Type: %s (Total: %d [Base: %d + Modifier: %d])",
			zone, table.concat(nodeYieldText, ", "), nodeTypeName, totalSkill, baseSkill, modifier))
	end

	-- Clear current node yields
	MIP.currentNodeYields = {}

	-- Update display if showing current zone
	if MiningInfoPanelFrame:IsShown() then
		MIP:UpdateDisplay()
	end
end

-- Calculate session-based yield rate per hour using timestamps
local function GetSessionYieldPerHour()
	if not MiningInfoPanelDB.sessionStart then
		return {}
	end
	
	local currentTime = time()
	local sessionDuration = currentTime - MiningInfoPanelDB.sessionStart -- in seconds
	
	if sessionDuration <= 0 then
		return {}
	end
	
	local zone = GetCurrentLocation()
	local sessionData = MiningInfoPanelDB.currentSession[zone]
	
	if not sessionData then
		return {}
	end
	
	local yieldsPerHour = {}
	for itemID, totalCount in pairs(sessionData) do
		-- Calculate items per hour based on session duration
		yieldsPerHour[itemID] = (totalCount / sessionDuration) * 3600
	end
	
	return yieldsPerHour
end

-- Get percentage of nodes that contained a specific non-ore item
local function GetNodeContainmentPercentage(itemID)
	if not MiningInfoPanelDB.nodeHistory or #MiningInfoPanelDB.nodeHistory == 0 then
		return 0
	end
	
	local nodesWithItem = 0
	local totalNodes = #MiningInfoPanelDB.nodeHistory
	
	for _, node in ipairs(MiningInfoPanelDB.nodeHistory) do
		if node.yields[itemID] and node.yields[itemID] > 0 then
			nodesWithItem = nodesWithItem + 1
		end
	end
	
	return totalNodes > 0 and (nodesWithItem / totalNodes) * 100 or 0
end

-- Calculate combined ore and non-ore data
local function GetCombinedMiningData(zone, useAllTime)
	local data = useAllTime and MiningInfoPanelDB.allTime or MiningInfoPanelDB.currentSession
	local allTimeData = MiningInfoPanelDB.allTime[zone]
	local nodeData = useAllTime and MiningInfoPanelDB.nodeTypes[zone] or MiningInfoPanelDB.sessionNodeTypes[zone]
	local allTimeNodeData = MiningInfoPanelDB.nodeTypes and MiningInfoPanelDB.nodeTypes[zone]
	
	-- If no data exists, return empty
	if not data[zone] and not nodeData then
		return {}
	end
	
	local combinedData = {}
	local totalNodes = 0
	
	-- Calculate total nodes for current view
	if nodeData then
		for nodeType, count in pairs(nodeData) do
			totalNodes = totalNodes + count
		end
	end
	
	-- Process ore types (node-based tracking)
	local nodesToProcess = {}
	if nodeData then
		-- Add all current node data
		for nodeType, count in pairs(nodeData) do
			nodesToProcess[nodeType] = count
		end
		
		-- If showing session, add any all-time nodes not in session with 0 count
		if not useAllTime and allTimeNodeData then
			for nodeType, _ in pairs(allTimeNodeData) do
				if not nodesToProcess[nodeType] then
					nodesToProcess[nodeType] = 0
				end
			end
		end
		
		-- Build ore data with node percentages
		for nodeType, nodeCount in pairs(nodesToProcess) do
			local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = GetItemInfo(nodeType)
			local currentPct = totalNodes > 0 and (nodeCount / totalNodes) * 100 or 0
			local color = { 1, 1, 1 } -- white default
			
			-- Get total count for this ore type
			local totalCount = 0
			if data[zone] and data[zone][nodeType] then
				totalCount = data[zone][nodeType]
			end
			
			-- Compare to all-time if showing session
			if not useAllTime and allTimeNodeData then
				local allTimeTotalNodes = 0
				for _, c in pairs(allTimeNodeData) do
					allTimeTotalNodes = allTimeTotalNodes + c
				end
				
				if allTimeTotalNodes > 0 then
					local allTimePct = ((allTimeNodeData[nodeType] or 0) / allTimeTotalNodes) * 100
					-- Only apply color if the node type was mined this session
					if nodeCount > 0 then
						if currentPct > allTimePct + 0.5 then
							color = { 0, 1, 0 } -- green - above average
						elseif currentPct < allTimePct - 0.5 then
							color = { 1, 0, 0 } -- red - below average
						end
					else
						-- Node types not mined this session show in gray
						color = { 0.5, 0.5, 0.5 }
					end
				end
			end
			
			table.insert(combinedData, {
				itemID = nodeType,
				name = itemName or ("Node Type " .. nodeType),
				icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
				nodeCount = nodeCount,
				totalCount = totalCount,
				percentage = currentPct,
				color = color,
				isNodeType = true
			})
		end
	end
	
	-- Process non-ore items (containment percentage tracking)
	if data[zone] then
		local itemsToProcess = {}
		
		-- Add all current data items
		for itemID, count in pairs(data[zone]) do
			if not ORE_LOOKUP[itemID] then -- Only non-ore items
				itemsToProcess[itemID] = count
			end
		end
		
		-- If showing session, add any all-time items not in session with 0 count
		if not useAllTime and allTimeData then
			for itemID, _ in pairs(allTimeData) do
				if not ORE_LOOKUP[itemID] and not itemsToProcess[itemID] then
					itemsToProcess[itemID] = 0
				end
			end
		end
		
		-- Build non-ore data with containment percentages
		for itemID, count in pairs(itemsToProcess) do
			local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
			local containmentPct = 0
			
			-- For session data, calculate containment percentage
			if not useAllTime then
				containmentPct = GetNodeContainmentPercentage(itemID)
			else
				-- For all-time data, we don't have node history, so show 0
				containmentPct = 0
			end
			
			local color = { 1, 1, 1 } -- white default
			
			-- Gray out items not found this session when showing session
			if not useAllTime and count == 0 then
				color = { 0.5, 0.5, 0.5 }
			end
			
			-- Check if item is stone/gray quality or a gem (legacy stone grouping)
			local isStone = itemQuality == 0 or (itemName and (string.find(itemName:lower(), "stone") or string.find(itemName:lower(), "gem")))
			
			table.insert(combinedData, {
				itemID = itemID,
				name = itemName or "Loading...",
				icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
				nodeCount = 0, -- Non-ore items don't have node counts
				totalCount = count,
				percentage = containmentPct,
				color = color,
				isNodeType = false,
				isStone = isStone
			})
		end
	end
	
	-- Sort by ore types first (by node count), then non-ore items (by total count)
	table.sort(combinedData, function(a, b)
		if a.isNodeType and not b.isNodeType then
			return true -- Ore types first
		elseif not a.isNodeType and b.isNodeType then
			return false -- Non-ore items second
		elseif a.isNodeType and b.isNodeType then
			return a.nodeCount > b.nodeCount -- Sort ore by node count
		else
			return a.totalCount > b.totalCount -- Sort non-ore by total count
		end
	end)
	
	return combinedData
end

-- Calculate percentages and get ore data
local function GetOreData(zone, useAllTime)
	local data = useAllTime and MiningInfoPanelDB.allTime or MiningInfoPanelDB.currentSession
	local allTimeData = MiningInfoPanelDB.allTime[zone]

	-- If showing session, but no all-time data exists, use session data only
	if not useAllTime and not allTimeData then
		if not data[zone] then
			return {}
		end
	elseif not data[zone] then
		-- If showing all-time and no data, return empty
		if useAllTime then
			return {}
		end
		-- If showing session and no session data, create empty structure
		data[zone] = {}
	end

	local oreData = {}
	local stoneData = {
		itemID = "STONE",
		name = "Stone & Gems",
		icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02", -- Generic gem icon
		count = 0,
		percentage = 0,
		color = { 0.5, 0.5, 0.5 }, -- Gray color for stone
	}
	local total = 0

	-- Calculate total for current view
	if data[zone] then
		for itemID, count in pairs(data[zone]) do
			total = total + count
		end
	end

	-- When showing session, include all items from all-time with 0 counts
	local itemsToProcess = {}

	-- First, add all current data items
	if data[zone] then
		for itemID, count in pairs(data[zone]) do
			itemsToProcess[itemID] = count
		end
	end

	-- If showing session, add any all-time items not in session with 0 count
	if not useAllTime and allTimeData then
		for itemID, _ in pairs(allTimeData) do
			if not itemsToProcess[itemID] then
				itemsToProcess[itemID] = 0
			end
		end
	end

	-- Build ore data with percentages
	for itemID, count in pairs(itemsToProcess) do
		local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)

		-- Check if item is stone/gray quality or a gem
		if itemQuality == 0 or (itemName and (string.find(itemName:lower(), "stone") or string.find(itemName:lower(), "gem"))) then
			stoneData.count = stoneData.count + count
		else
			local currentPct = total > 0 and (count / total) * 100 or 0
			local color = { 1, 1, 1 } -- white default

			-- Compare to all-time if showing session
			if not useAllTime and MiningInfoPanelDB.allTime[zone] then
				local allTimeData = MiningInfoPanelDB.allTime[zone]
				local allTimeTotal = 0
				for _, c in pairs(allTimeData) do
					allTimeTotal = allTimeTotal + c
				end

				if allTimeTotal > 0 then
					local allTimePct = ((allTimeData[itemID] or 0) / allTimeTotal) * 100
					-- Only apply color if the item was mined this session
					if count > 0 then
						if currentPct > allTimePct + 0.5 then
							color = { 0, 1, 0 } -- green - above average
						elseif currentPct < allTimePct - 0.5 then
							color = { 1, 0, 0 } -- red - below average
						end
					else
						-- Items not mined this session show in gray
						color = { 0.5, 0.5, 0.5 }
					end
				end
			end

			table.insert(oreData, {
				itemID = itemID,
				name = itemName or "Loading...",
				icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
				count = count,
				percentage = currentPct,
				color = color,
			})
		end
	end

	-- Check if stone exists in all-time data when showing session
	local allTimeStoneExists = false
	if not useAllTime and allTimeData then
		for itemID, _ in pairs(allTimeData) do
			local itemName, _, itemQuality = GetItemInfo(itemID)
			if itemQuality == 0 or (itemName and (string.find(itemName:lower(), "stone") or string.find(itemName:lower(), "gem"))) then
				allTimeStoneExists = true
				break
			end
		end
	end

	-- Add stone data if any stone was found (current or historical)
	if stoneData.count > 0 or allTimeStoneExists then
		stoneData.percentage = total > 0 and (stoneData.count / total) * 100 or 0

		-- Compare stone percentage to all-time if showing session
		if not useAllTime and MiningInfoPanelDB.allTime[zone] then
			local allTimeData = MiningInfoPanelDB.allTime[zone]
			local allTimeTotal = 0
			local allTimeStoneCount = 0

			-- Calculate all-time totals and stone count
			for itemID, count in pairs(allTimeData) do
				allTimeTotal = allTimeTotal + count
				local itemName, _, itemQuality = GetItemInfo(itemID)
				if itemQuality == 0 or (itemName and (string.find(itemName:lower(), "stone") or string.find(itemName:lower(), "gem"))) then
					allTimeStoneCount = allTimeStoneCount + count
				end
			end

			if allTimeTotal > 0 then
				local allTimeStonePct = (allTimeStoneCount / allTimeTotal) * 100
				-- Only apply colors if stone was mined this session
				if stoneData.count > 0 then
					if stoneData.percentage < allTimeStonePct - 0.5 then
						stoneData.color = { 0, 1, 0 } -- green - lower stone than usual
					elseif stoneData.percentage > allTimeStonePct + 0.5 then
						stoneData.color = { 1, 0, 0 } -- red - higher stone than usual
					else
						stoneData.color = { 1, 1, 1 } -- white - same as usual
					end
				else
					-- No stone mined this session, show in gray
					stoneData.color = { 0.5, 0.5, 0.5 }
				end
			end
		end

		table.insert(oreData, stoneData)
	end

	-- Sort by count descending
	table.sort(oreData, function(a, b)
		return a.count > b.count
	end)

	return oreData
end

-- Calculate combined data by skill range
local function GetCombinedDataBySkill(skillRange)
	local data = MiningInfoPanelDB.bySkill[skillRange]
	local nodeData = MiningInfoPanelDB.nodeTypes and MiningInfoPanelDB.nodeTypes[skillRange]
	
	if not data and not nodeData then
		return {}
	end
	
	local combinedData = {}
	local totalNodes = 0
	
	-- Calculate total nodes
	if nodeData then
		for nodeType, count in pairs(nodeData) do
			totalNodes = totalNodes + count
		end
	end
	
	-- Process ore types (node-based tracking)
	if nodeData then
		for nodeType, nodeCount in pairs(nodeData) do
			local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = GetItemInfo(nodeType)
			local currentPct = totalNodes > 0 and (nodeCount / totalNodes) * 100 or 0
			
			-- Get total count for this ore type
			local totalCount = 0
			if data and data[nodeType] then
				totalCount = data[nodeType]
			end
			
			table.insert(combinedData, {
				itemID = nodeType,
				name = itemName or ("Node Type " .. nodeType),
				icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
				nodeCount = nodeCount,
				totalCount = totalCount,
				percentage = currentPct,
				color = { 1, 1, 1 },
				isNodeType = true
			})
		end
	end
	
	-- Process non-ore items
	if data then
		for itemID, count in pairs(data) do
			if not ORE_LOOKUP[itemID] then -- Only non-ore items
				local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)
				
				-- Check if item is stone/gray quality or a gem
				local isStone = itemQuality == 0 or (itemName and (string.find(itemName:lower(), "stone") or string.find(itemName:lower(), "gem")))
				
				table.insert(combinedData, {
					itemID = itemID,
					name = itemName or "Loading...",
					icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
					nodeCount = 0,
					totalCount = count,
					percentage = 0, -- No containment percentage for skill view
					color = { 1, 1, 1 },
					isNodeType = false,
					isStone = isStone
				})
			end
		end
	end
	
	-- Sort by ore types first, then non-ore items
	table.sort(combinedData, function(a, b)
		if a.isNodeType and not b.isNodeType then
			return true
		elseif not a.isNodeType and b.isNodeType then
			return false
		elseif a.isNodeType and b.isNodeType then
			return a.nodeCount > b.nodeCount
		else
			return a.totalCount > b.totalCount
		end
	end)
	
	return combinedData
end

-- Calculate percentages and get ore data by skill
local function GetOreDataBySkill(skillRange)
	local data = MiningInfoPanelDB.bySkill[skillRange]

	if not data then
		return {}
	end

	local oreData = {}
	local stoneData = {
		itemID = "STONE",
		name = "Stone & Gems",
		icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02",
		count = 0,
		percentage = 0,
		color = { 0.5, 0.5, 0.5 },
	}
	local total = 0

	-- Calculate total
	for itemID, count in pairs(data) do
		total = total + count
	end

	if total == 0 then
		return {}
	end

	-- Build ore data with percentages
	for itemID, count in pairs(data) do
		local itemName, _, itemQuality, _, _, _, _, _, _, itemIcon = GetItemInfo(itemID)

		-- Check if item is stone/gray quality or a gem
		if itemQuality == 0 or (itemName and (string.find(itemName:lower(), "stone") or string.find(itemName:lower(), "gem"))) then
			stoneData.count = stoneData.count + count
		else
			local currentPct = (count / total) * 100

			table.insert(oreData, {
				itemID = itemID,
				name = itemName or "Loading...",
				icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
				count = count,
				percentage = currentPct,
				color = { 1, 1, 1 },
			})
		end
	end

	-- Add stone data if any stone was found
	if stoneData.count > 0 then
		stoneData.percentage = (stoneData.count / total) * 100
		table.insert(oreData, stoneData)
	end

	-- Sort by count descending
	table.sort(oreData, function(a, b)
		return a.count > b.count
	end)

	return oreData
end

-- Update the display
function MIP:UpdateDisplay()
	local oreData

	if MIP.showingBySkill then
		-- Show data by skill range
		local totalSkill = GetMiningSkill()
		local skillRange = GetSkillRange(totalSkill)
		MIP.currentSkillRange = skillRange

		-- Update zone info for skill view
		local baseSkill, modifier
		totalSkill, baseSkill, modifier = GetMiningSkill()

		MiningInfoPanelFrameZoneInfoZoneName:SetText("Skill Range: " .. skillRange)
		if modifier > 0 then
			MiningInfoPanelFrameZoneInfoSubzoneName:SetText(
				string.format("Mining Skill: %d (+%d) = %d", baseSkill, modifier, totalSkill)
			)
		else
			MiningInfoPanelFrameZoneInfoSubzoneName:SetText("Mining Skill: " .. baseSkill)
		end

		-- Update toggle button
		MiningInfoPanelFrameToggleButton:SetText("Show by Zone")

		-- Get combined ore and non-ore data by skill
		oreData = GetCombinedDataBySkill(skillRange)
	else
		-- Show data by zone
		local zone = GetCurrentLocation()
		MIP.currentZone = zone

		-- Update zone info
		MiningInfoPanelFrameZoneInfoZoneName:SetText(zone)
		MiningInfoPanelFrameZoneInfoSubzoneName:SetText("")

		-- Update toggle button
		local buttonText = MIP.showingAllTime and "Show Current Session" or "Show All Time"
		MiningInfoPanelFrameToggleButton:SetText(buttonText)

		-- Get combined ore and non-ore data
		oreData = GetCombinedMiningData(zone, MIP.showingAllTime)
	end

	-- Clear existing rows
	for _, row in ipairs(MIP.oreRows) do
		row:Hide()
	end

	-- Create/update rows
	local yOffset = 0
	for i, ore in ipairs(oreData) do
		local row = MIP.oreRows[i]

		if not row then
			row = CreateFrame("Frame", nil, MiningInfoPanelFrameScrollFrameScrollChild)
			row:SetSize(420, 30)

			-- Icon
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(24, 24)
			row.icon:SetPoint("LEFT", 5, 0)

			-- Name
			row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
			row.name:SetWidth(120)
			row.name:SetJustifyH("LEFT")

			-- Nodes count (for ores only)
			row.nodeCount = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.nodeCount:SetPoint("LEFT", row, "LEFT", 180, 0)
			row.nodeCount:SetWidth(40)
			row.nodeCount:SetJustifyH("CENTER")

			-- Total count
			row.totalCount = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.totalCount:SetPoint("LEFT", row, "LEFT", 225, 0)
			row.totalCount:SetWidth(40)
			row.totalCount:SetJustifyH("CENTER")

			-- Percentage
			row.percentage = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.percentage:SetPoint("LEFT", row, "LEFT", 270, 0)
			row.percentage:SetWidth(40)
			row.percentage:SetJustifyH("CENTER")

			-- Rate per hour
			row.ratePerHour = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			row.ratePerHour:SetPoint("LEFT", row, "LEFT", 315, 0)
			row.ratePerHour:SetWidth(60)
			row.ratePerHour:SetJustifyH("RIGHT")

			MIP.oreRows[i] = row
		end

		row:SetPoint("TOPLEFT", 0, -yOffset)
		row.icon:SetTexture(ore.icon)
		row.name:SetText(ore.name)
		
		-- Show node count for ore types, hide for non-ore items
		if ore.isNodeType then
			row.nodeCount:SetText(ore.nodeCount or "0")
			row.nodeCount:Show()
		else
			row.nodeCount:SetText("---")
			row.nodeCount:SetTextColor(0.5, 0.5, 0.5)
			row.nodeCount:Show()
		end
		
		row.totalCount:SetText(ore.totalCount or ore.count or "0")
		row.percentage:SetText(string.format("%.1f%%", ore.percentage))
		row.percentage:SetTextColor(unpack(ore.color))

		-- Display yield per hour using session timestamp calculation
		local sessionYieldsPerHour = GetSessionYieldPerHour()
		local ratePerHour = sessionYieldsPerHour[ore.itemID] or 0
		if ratePerHour > 0 then
			if ratePerHour >= 100 then
				row.ratePerHour:SetText(string.format("%.0f", ratePerHour))
			elseif ratePerHour >= 10 then
				row.ratePerHour:SetText(string.format("%.1f", ratePerHour))
			else
				row.ratePerHour:SetText(string.format("%.2f", ratePerHour))
			end
			-- Color code based on rate
			if ratePerHour >= 50 then
				row.ratePerHour:SetTextColor(0, 1, 0) -- Green - high rate
			elseif ratePerHour >= 20 then
				row.ratePerHour:SetTextColor(1, 1, 0) -- Yellow - medium rate
			elseif ratePerHour >= 5 then
				row.ratePerHour:SetTextColor(1, 0.5, 0) -- Orange - low rate
			else
				row.ratePerHour:SetTextColor(0.7, 0.7, 1.0) -- Light blue - very low rate
			end
		else
			row.ratePerHour:SetText("---")
			row.ratePerHour:SetTextColor(0.5, 0.5, 0.5) -- Gray
		end

		row:Show()

		yOffset = yOffset + 32
	end

	-- Update scroll child height
	MiningInfoPanelFrameScrollFrameScrollChild:SetHeight(math.max(290, yOffset))

	-- Update mining statistics display
	local nodesPerHour = GetNodesPerHour()
	local yieldsPerHour = GetYieldPerHour()
	local totalNodes = MiningInfoPanelDB.totalNodes or 0

	-- Calculate total yields per hour
	local totalYieldsPerHour = 0
	for _, yph in pairs(yieldsPerHour) do
		totalYieldsPerHour = totalYieldsPerHour + yph
	end

	local statsText
	local nodeCount = MiningInfoPanelDB.nodeHistory and #MiningInfoPanelDB.nodeHistory or 0

	if nodeCount == 0 then
		statsText = string.format("Nodes/hr: %.1f | Yields/hr: %.1f | Total nodes: %d", nodesPerHour, totalYieldsPerHour, totalNodes)
	else
		statsText = string.format("Nodes/hr: %.1f | Yields/hr: %.1f | Total nodes: %d |cff00ff00 [%d recent nodes]|r",
			nodesPerHour, totalYieldsPerHour, totalNodes, nodeCount)
	end

	MiningInfoPanelFrameMiningRateFrameText:SetText(statsText)
end

-- Toggle between session and all-time view
function MIP:ToggleView()
	if MIP.showingBySkill then
		-- Switch back to zone view
		MIP.showingBySkill = false
	else
		-- Toggle between session and all-time in zone view
		MIP.showingAllTime = not MIP.showingAllTime
	end
	MIP:UpdateDisplay()
end

-- Toggle to skill-based view
function MIP:ToggleSkillView()
	MIP.showingBySkill = not MIP.showingBySkill
	MIP:UpdateDisplay()
end

-- Toggle yield messages
function MIP:ToggleYieldMessages()
	MIP:SetConfig("showYieldMessages", not MIP:GetConfig("showYieldMessages"))
	local status = MIP:GetConfig("showYieldMessages") and "enabled" or "disabled"
	print("|cff00ff00MiningInfoPanel:|r Yield messages " .. status)
end

-- Toggle debug logging
function MIP:ToggleDebugLogging()
	MIP:SetConfig("debugLogging", not MIP:GetConfig("debugLogging"))
	local status = MIP:GetConfig("debugLogging") and "enabled" or "disabled"
	print("|cff00ff00MiningInfoPanel:|r Debug logging " .. status)
end

-- Toggle auto open/close
function MIP:ToggleAutoOpen()
	MIP:SetConfig("autoOpen", not MIP:GetConfig("autoOpen"))
	local status = MIP:GetConfig("autoOpen") and "enabled" or "disabled"
	print("|cff00ff00MiningInfoPanel:|r Auto open/close " .. status)
end

-- Toggle minimap button
function MIP:ToggleMinimapButton()
	MIP:SetConfig("showMinimapButton", not MIP:GetConfig("showMinimapButton"))
	MIP:UpdateMinimapButton()
	local status = MIP:GetConfig("showMinimapButton") and "enabled" or "disabled"
	print("|cff00ff00MiningInfoPanel:|r Minimap button " .. status)
end

-- Show welcome message with all commands
function MIP:ShowWelcomeMessage()
	print("|cff00ff00=== Mining Info Panel v1.0.0 ===|r")
	print("|cffff9900Available Commands:|r")
	print("  |cff00ff00/mip|r - Toggle panel visibility")
	print("  |cff00ff00/mip skill|r - Toggle skill-based view")
	print("  |cff00ff00/mip yield|r - Toggle yield messages")
	print("  |cff00ff00/mip debug|r - Toggle debug logging")
	print("  |cff00ff00/mip auto|r - Toggle auto open/close on mining")
	print("  |cff00ff00/mip minimap|r - Toggle minimap button")
	print("  |cff00ff00/mip config|r - Show current settings")
	print("  |cff00ff00/mip help|r - Show this help message")
	print("|cffff9900Happy mining!|r")
end

-- Show configuration
function MIP:ShowConfig()
	print("|cff00ff00MiningInfoPanel Configuration:|r")
	print("  Yield messages: " .. (MIP:GetConfig("showYieldMessages") and "enabled" or "disabled"))
	print("  Debug logging: " .. (MIP:GetConfig("debugLogging") and "enabled" or "disabled"))
	print("  Auto open/close: " .. (MIP:GetConfig("autoOpen") and "enabled" or "disabled"))
	print("  Minimap button: " .. (MIP:GetConfig("showMinimapButton") and "enabled" or "disabled"))
	print("  Database version: " .. (MiningInfoPanelDB[DB_VERSION_KEY] or "unknown"))
end

-- Toggle frame visibility
function MIP:ToggleFrame()
	if MiningInfoPanelFrame:IsShown() then
		MiningInfoPanelFrame:Hide()
		-- Reset auto-opened flag when manually closed
		MIP.autoOpened = false
	else
		MiningInfoPanelFrame:Show()
		MIP:UpdateDisplay()
	end
end

-- Calculate total items in cache
local function GetCacheSize()
	local totalItems = 0
	if MiningInfoPanelDB and MiningInfoPanelDB.allTime then
		for zone, items in pairs(MiningInfoPanelDB.allTime) do
			for itemID, count in pairs(items) do
				totalItems = totalItems + count
			end
		end
	end
	return totalItems
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == "MiningInfoPanel" then
			InitDB()

			-- Set up backdrop
			MiningInfoPanelFrame:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
				tile = false,
				edgeSize = 32,
				insets = { left = 11, right = 12, top = 12, bottom = 11 },
			})
			MiningInfoPanelFrame:SetBackdropColor(1, 1, 1, 1)

			-- Initialize minimap button
			MIP:UpdateMinimapButton()

			-- Register slash command
			SLASH_MININGINFO1 = "/mininginfo"
			SLASH_MININGINFO2 = "/mip"
			SlashCmdList["MININGINFO"] = function(msg)
				msg = msg:lower():trim()
				if msg == "skill" then
					MIP:ToggleSkillView()
				elseif msg == "yield" then
					MIP:ToggleYieldMessages()
				elseif msg == "debug" then
					MIP:ToggleDebugLogging()
				elseif msg == "auto" then
					MIP:ToggleAutoOpen()
				elseif msg == "minimap" then
					MIP:ToggleMinimapButton()
				elseif msg == "config" then
					MIP:ShowConfig()
				elseif msg == "help" then
					MIP:ShowWelcomeMessage()
				else
					MIP:ToggleFrame()
				end
			end

			local cacheSize = GetCacheSize()
			MIP:ShowWelcomeMessage()
			print(string.format("|cff00ff00Cache: %d yields loaded|r", cacheSize))
		end
	elseif event == "UNIT_SPELLCAST_START" then
		local unit, _, spellID = ...
		if unit == "player" then
			-- Always debug player casts to help identify mining spells
			if MiningInfoPanelDB.config.debugLogging then
				print(string.format("|cff00ff00MiningInfoPanel Debug:|r Player cast started - spell ID: %s", tostring(spellID)))
			end

			if spellID and (MINING_SPELL_IDS[spellID] ~= nil) then
				if MiningInfoPanelDB.config.debugLogging then
					print("|cff00ff00MiningInfoPanel Debug:|r Mining cast detected - recording timestamp")
				end

				-- Record the time of this mining cast for fallback detection
				MIP.lastMiningCastTime = GetTime()

				-- Auto-open panel if enabled
				if MIP:GetConfig("autoOpen") and not MiningInfoPanelFrame:IsShown() then
					MiningInfoPanelFrame:Show()
					MIP:UpdateDisplay()
					MIP.autoOpened = true
					if MiningInfoPanelDB.config.debugLogging then
						print("|cff00ff00MiningInfoPanel Debug:|r Auto-opened panel")
					end
				end
			end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Auto-close panel if it was auto-opened and combat started
		if MIP.autoOpened and MIP:GetConfig("autoOpen") and MiningInfoPanelFrame:IsShown() then
			MiningInfoPanelFrame:Hide()
			MIP.autoOpened = false
			if MiningInfoPanelDB.config.debugLogging then
				print("|cff00ff00MiningInfoPanel Debug:|r Auto-closed panel (combat started)")
			end
		end
	elseif event == "LOOT_OPENED" then
		-- Always debug loot events to help identify issues
		if MiningInfoPanelDB.config.debugLogging then
			print("|cff00ff00MiningInfoPanel Debug:|r LOOT_OPENED event triggered")
		end

		local numItems = GetNumLootItems()

		if MiningInfoPanelDB.config.debugLogging then
			print(string.format("|cff00ff00MiningInfoPanel Debug:|r Loot items: %d", numItems))
		end
		local isMiningLoot = false
		-- Debug all loot items
		for i = 1, numItems do
			local itemLink = GetLootSlotLink(i)
			if itemLink then
				local itemID = tonumber(itemLink:match("item:(%d+)"))
				if itemID then
					local itemName = GetItemInfo(itemID)
					local _, _, quantity = GetLootSlotInfo(i)
					if MiningInfoPanelDB.config.debugLogging then
						print(string.format("|cff00ff00MiningInfoPanel Debug:|r Loot item %d: %s (ID: %s) x%d",
							i, tostring(itemName), tostring(itemID), quantity or 1))
					end
					if GetItemFamily(itemID) == 1024 then
						isMiningLoot = true
					end
				end
			end
		end

		if isMiningLoot then
			for i = 1, numItems do
				local itemLink = GetLootSlotLink(i)
				if itemLink then
					local itemID = tonumber(itemLink:match("item:(%d+)"))
					if itemID then
						-- Get quantity
						local _, _, quantity = GetLootSlotInfo(i)
						local actualQuantity = quantity or 1
						if MiningInfoPanelDB.config.debugLogging then
							print(string.format("|cff00ff00MiningInfoPanel Debug:|r Recording yield: Item %s x%d", tostring(itemID), actualQuantity))
						end
						MIP:RecordYield(itemID, actualQuantity)
						MIP.expectingLoot = true
					end
				end
			end
		end


	elseif event == "LOOT_CLOSED" then
		if MiningInfoPanelDB.config.debugLogging then
			print("|cff00ff00MiningInfoPanel Debug:|r LOOT_CLOSED event triggered")
		end
		-- Complete the node when loot window closes after mining
		if MIP.expectingLoot then
			if MiningInfoPanelDB.config.debugLogging then
				print("|cff00ff00MiningInfoPanel Debug:|r Completing mining node")
			end
			MIP:CompleteNode()
			MIP.expectingLoot = false
		else
			if MiningInfoPanelDB.config.debugLogging then
				print("|cff00ff00MiningInfoPanel Debug:|r No mining loot expected - ignoring")
			end
		end
	elseif event:find("ZONE_CHANGED") then
		if MiningInfoPanelFrame:IsShown() then
			MIP:UpdateDisplay()
		end
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		-- Update display when item info becomes available
		if MiningInfoPanelFrame:IsShown() then
			MIP:UpdateDisplay()
		end
	end
end)
