--[[
	VirtualList: a scrolling list that can show thousands of rows while only creating enough row
	frames to fill the visible window (rows are recycled as you scroll).
]]

local VirtualList = {}
VirtualList.__index = VirtualList

export type VirtualList = {
	Frame: ScrollingFrame,
	RowHeight: number,
	Entries: { any },
	Pool: { GuiObject },
	Build: () -> GuiObject,
	Bind: (GuiObject, any, number) -> (),
	SetEntries: (self: VirtualList, entries: { any }) -> (),
	Refresh: (self: VirtualList) -> (),
}

function VirtualList.new(frame: ScrollingFrame, rowHeight: number, build: () -> GuiObject, bind: (GuiObject, any, number) -> ()): VirtualList
	local self = setmetatable({
		Frame = frame,
		RowHeight = rowHeight,
		Entries = {},
		Pool = {},
		Build = build,
		Bind = bind,
	}, VirtualList) :: any
	frame.AutomaticCanvasSize = Enum.AutomaticSize.None
	frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:Refresh()
	end)
	frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		self:Refresh()
	end)
	return self
end

function VirtualList.SetEntries(self: VirtualList, entries: { any })
	self.Entries = entries
	self.Frame.CanvasSize = UDim2.new(0, 0, 0, #entries * self.RowHeight)
	self:Refresh()
end

function VirtualList.Refresh(self: VirtualList)
	local windowHeight = self.Frame.AbsoluteWindowSize.Y
	if windowHeight <= 0 then
		windowHeight = self.Frame.AbsoluteSize.Y
	end
	-- AbsoluteWindowSize is in screen pixels; convert to canvas units if the list is scaled.
	local canvasHeight = self.Frame.AbsoluteCanvasSize.Y
	local ratio = if self.Frame.CanvasSize.Y.Offset > 0 and canvasHeight > 0 then self.Frame.CanvasSize.Y.Offset / canvasHeight else 1
	local needed = math.ceil(windowHeight * ratio / self.RowHeight) + 2
	while #self.Pool < needed do
		local row = self.Build()
		row.Parent = self.Frame
		table.insert(self.Pool, row)
	end
	local first = math.max(1, math.floor(self.Frame.CanvasPosition.Y / self.RowHeight) + 1)
	for i, row in self.Pool do
		local index = first + i - 1
		local entry = self.Entries[index]
		if entry then
			row.Visible = true
			row.Position = UDim2.fromOffset(0, (index - 1) * self.RowHeight)
			self.Bind(row, entry, index)
		else
			row.Visible = false
		end
	end
end

return VirtualList
