--[[
	HideUI: the 👁 HIDE UI button (or X on a keyboard) clears the screen for screenshots and videos.

	Hides every screen GUI of ours (HUD, windows, notifications, the base marker...) and Roblox's own
	(chat, player list, hotbar), on this player's screen only. Steal prompts stay so you can still
	play. Press X again, or tap the small 👁 SHOW UI pill, to bring everything back exactly as it was.
	Anything that opens while the UI is hidden stays hidden until you show it again.
]]

local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Theme = require(script.Parent.Theme)

local HideUI = {}

local KEY = Enum.KeyCode.X
-- Roblox's own GUI that goes away too (the emote wheel and health bar aren't used by the game)
local CORE_GUI = { Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack }
-- Never hidden: our own pill, and the steal prompts (you still need to see "Steal")
local KEEP = { ShowUI = true, ProximityPrompts = true }
local FADE_AFTER = 3 -- seconds before the pill fades out on a keyboard

local hidden = false
local hiddenGuis: { [LayerCollector]: boolean } = {}
local coreSaved: { [Enum.CoreGuiType]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local pill: TextButton? = nil
local pillGui: ScreenGui? = nil
local fadeToken = 0

local function hideOne(gui: Instance)
	if not gui:IsA("LayerCollector") or KEEP[gui.Name] then
		return
	end
	if gui.Enabled then
		hiddenGuis[gui] = true
		gui.Enabled = false
	end
	-- something tried to show itself while the UI is hidden: remember it and keep it hidden
	table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if hidden and gui.Enabled then
			hiddenGuis[gui] = true
			gui.Enabled = false
		end
	end))
end

local function setCore(on: boolean)
	for _, kind in CORE_GUI do
		pcall(function()
			if on then
				if coreSaved[kind] ~= nil then
					StarterGui:SetCoreGuiEnabled(kind, coreSaved[kind])
				end
			else
				coreSaved[kind] = StarterGui:GetCoreGuiEnabled(kind)
				StarterGui:SetCoreGuiEnabled(kind, false)
			end
		end)
	end
	if on then
		table.clear(coreSaved)
	end
end

-- The pill shows clearly for a moment, then (with a keyboard, where X brings the UI back) fades
-- away so screenshots are clean. Hovering it brings it back. On phones it stays, a little faded.
local function showPill(visible: boolean)
	local button = pill
	if not button then
		return
	end
	fadeToken += 1
	button.Visible = visible
	if not visible then
		return
	end
	local function setFade(alpha: number)
		button.BackgroundTransparency = alpha
		for _, d in button:GetDescendants() do
			if d:IsA("TextLabel") then
				d.TextTransparency = alpha
			elseif d:IsA("UIStroke") then
				d.Transparency = alpha
			end
		end
	end
	setFade(0)
	local token = fadeToken
	task.delay(FADE_AFTER, function()
		if token == fadeToken and hidden then
			setFade(if UserInputService.KeyboardEnabled then 1 else 0.55)
		end
	end)
end

function HideUI.IsHidden(): boolean
	return hidden
end

function HideUI.Set(hide: boolean)
	if hide == hidden then
		return
	end
	hidden = hide
	local playerGui = Theme.PlayerGui()
	if hide then
		for _, gui in playerGui:GetChildren() do
			hideOne(gui)
		end
		table.insert(connections, playerGui.ChildAdded:Connect(hideOne))
		setCore(false)
	else
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for gui in hiddenGuis do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		setCore(true)
	end
	if pillGui then
		pillGui.Enabled = hide
	end
	showPill(hide)
end

function HideUI.Toggle()
	HideUI.Set(not hidden)
end

function HideUI.Init()
	local gui = Theme.ScreenGui("ShowUI", 100)
	gui.Enabled = false
	pillGui = gui
	local button = Theme.Button({
		Name = "Show",
		Text = if UserInputService.KeyboardEnabled then "👁 SHOW UI (X)" else "👁 SHOW UI",
		Color = Theme.Colors.Gray,
		Size = UDim2.fromOffset(170, 40),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		TextSize = 20,
		Parent = gui,
	})
	button.Activated:Connect(function()
		HideUI.Set(false)
	end)
	button.MouseEnter:Connect(function()
		if hidden then
			showPill(true)
		end
	end)
	pill = button
	button.Visible = false

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- (processed: typing in chat or a text box, so an X in a message doesn't hide anything)
		if not processed and input.KeyCode == KEY then
			HideUI.Toggle()
		end
	end)
end

return HideUI
