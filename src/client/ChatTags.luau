--[[
	Chat tags: players with a donor title (from tipping, see ProductService) get it in front of
	their name in chat, in the title's colour, e.g. "[Ultimate Donor] Flightly33: hi".
	The server sets the "DonorTitle" / "DonorTitleColor" attributes on each player.
]]

local Players = game:GetService("Players")

local ChatTags = {}

function ChatTags.Init()
	local ok, TextChatService = pcall(game.GetService, game, "TextChatService")
	if not ok or not TextChatService then
		return
	end
	(TextChatService :: TextChatService).OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = if source then Players:GetPlayerByUserId(source.UserId) else nil
		local title = if sender then sender:GetAttribute("DonorTitle") else nil
		if sender and type(title) == "string" then
			local color = sender:GetAttribute("DonorTitleColor")
			local hex = if typeof(color) == "Color3" then color:ToHex() else "ff8ad0"
			properties.PrefixText = `<font color="#{hex}">[{title}]</font> {message.PrefixText}`
		end
		return properties
	end
end

return ChatTags
