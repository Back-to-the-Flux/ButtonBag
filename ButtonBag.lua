-- ButtonBag: gathers the AddOn buttons from around the minimap into one bag button. Click the bag
-- and a panel drops down holding all of them; click again, press Escape or move the mouse away
-- and it folds up.
-- Buttons are found by what they are, not by which AddOn made them: named buttons on the minimap
-- that can be dragged, or whose name says they're a minimap button. The game's own minimap
-- buttons stay where they are, and any button can be kept on the minimap from the settings.
-- WoW 1.12 / Lua 5.0.

local defaults = { enabled = true, button = true, btnAngle = 45, cols = 4,
  closeOnClick = true, closeOnLeave = true, keep = {},
  size = 1, hoverOpen = false, direction = "auto", sortMode = "az", order = {}, closeDelay = 1.5,
  roundLook = true, style = "icons" }
local db

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffd9a441Button|rBag " .. msg) end

-- ---------------------------------------------------------------- the look
-- Drawn to match the game's own Options window, as BattleMarks' and ClearHits' are: near-black
-- panels with thin gold edges, gold labels, square checkboxes and dark red for what's selected.
local WHITE = "Interface\\Buttons\\WHITE8X8"
local UI = {
  top = { 0.078, 0.059, 0.035, 0.90 }, bottom = { 0.031, 0.024, 0.016, 0.93 },   -- window shading
  well = { 0.012, 0.012, 0.008 },
  selTop = { 0.231, 0.051, 0.043 }, selBottom = { 0.102, 0.020, 0.020 },
  pressTop = { 0.227, 0.031, 0.024 }, pressBottom = { 0.133, 0.016, 0.016 },
  outer = { 0.427, 0.333, 0.145 }, dim = { 0.427, 0.333, 0.145 }, edge = { 0.690, 0.541, 0.227 },
  hot = { 0.973, 0.824, 0.416 }, panelEdge = { 0.169, 0.129, 0.071 },
  gold = { 0.973, 0.824, 0.416 }, title = { 0.973, 0.824, 0.416 }, chosen = { 1, 0.914, 0.659 },
  text = { 0.949, 0.902, 0.788 }, muted = { 0.725, 0.663, 0.510 },
}
local UI_FONT, TITLE_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\MORPHEUS.TTF"
local SELECTED = { top = UI.selTop, bottom = UI.selBottom }
local PRESSED = { top = UI.pressTop, bottom = UI.pressBottom }

local function Solid(f, layer, c)
  local t = f:CreateTexture(nil, layer)
  t:SetTexture(WHITE)
  t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  return t
end

-- shaded top to bottom, as the game's panels and red buttons are
local function Shade(t, top, bottom)
  t:SetVertexColor(1, 1, 1, top[4] or 1)
  if t.SetGradient then
    t:SetGradient("VERTICAL", bottom[1], bottom[2], bottom[3], top[1], top[2], top[3])
  else
    t:SetVertexColor(top[1], top[2], top[3], top[4] or 1)
  end
  -- this client's gradient keeps no see-through of its own; the texture's own alpha does
  t:SetAlpha(((top[4] or 1) + (bottom[4] or 1)) / 2)
end

-- A rounded rectangle from pieces that never overlap: a tall strip, two side bands and four
-- quarter circles (corner.tga, flipped for each corner). r = 0 gives a plain rectangle.
local MEDIA = "Interface\\AddOns\\ButtonBag\\media\\"
local CORNERS = {   -- point, x sign, y sign, texture coordinates
  { "TOPLEFT", 1, -1, 0, 1, 0, 1 }, { "TOPRIGHT", -1, -1, 1, 0, 0, 1 },
  { "BOTTOMLEFT", 1, 1, 0, 1, 1, 0 }, { "BOTTOMRIGHT", -1, 1, 1, 0, 1, 0 },
}
-- quarter rings for the edges' corners, by how much of the radius the edge is (ring08 ... ring50)
local RINGS = { 8, 16, 31, 40, 42, 50 }
local function RoundRect(f, layer, inset, r)
  local shape = { tall = Solid(f, layer, { 1, 1, 1 }) }
  if r <= 0 then
    shape.tall:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    shape.tall:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    return shape
  end
  shape.tall:SetPoint("TOPLEFT", f, "TOPLEFT", inset + r, -inset)
  shape.tall:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset - r, inset)
  shape.left = Solid(f, layer, { 1, 1, 1 })
  shape.left:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset - r)
  shape.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", inset, inset + r)
  shape.left:SetWidth(r)
  shape.right = Solid(f, layer, { 1, 1, 1 })
  shape.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -inset, -inset - r)
  shape.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset + r)
  shape.right:SetWidth(r)
  shape.corners = {}
  for i, c in ipairs(CORNERS) do
    local t = f:CreateTexture(nil, layer)
    t:SetTexture(MEDIA .. "corner")
    t:SetTexCoord(c[4], c[5], c[6], c[7])
    t:SetWidth(r)
    t:SetHeight(r)
    t:SetPoint(c[1], f, c[1], c[2] * inset, c[3] * inset)
    shape.corners[i] = t
  end
  return shape
end

-- an edge of the given width around a rounded rectangle: four strips and the four corners
local function RoundRing(f, layer, width, r)
  local shape = { strips = {} }
  local cut = math.max(r, 0)
  local sides = {
    { "TOPLEFT", cut, 0, "TOPRIGHT", -cut, 0, "height" }, { "BOTTOMLEFT", cut, 0, "BOTTOMRIGHT", -cut, 0, "height" },
    { "TOPLEFT", 0, -cut, "BOTTOMLEFT", 0, cut, "width" }, { "TOPRIGHT", 0, -cut, "BOTTOMRIGHT", 0, cut, "width" },
  }
  for i, sd in ipairs(sides) do
    local t = Solid(f, layer, { 1, 1, 1 })
    t:SetPoint(sd[1], f, sd[1], sd[2], sd[3])
    t:SetPoint(sd[4], f, sd[4], sd[5], sd[6])
    if sd[7] == "height" then t:SetHeight(width) else t:SetWidth(width) end
    shape.strips[i] = t
  end
  if r > 0 then
    -- the ring image nearest this edge's share of the radius
    local share, best = width / r * 100, nil
    for _, pct in ipairs(RINGS) do
      if not best or math.abs(pct - share) < math.abs(best - share) then best = pct end
    end
    shape.corners = {}
    for i, c in ipairs(CORNERS) do
      local t = f:CreateTexture(nil, layer)
      t:SetTexture(MEDIA .. "ring" .. (best < 10 and "0" or "") .. best)
      t:SetTexCoord(c[4], c[5], c[6], c[7])
      t:SetWidth(r)
      t:SetHeight(r)
      t:SetPoint(c[1], f, c[1], 0, 0)
      shape.corners[i] = t
    end
  end
  return shape
end

-- colors a shape with one color, or shades it from a top color to a bottom one
local function Color(shape, c)
  local top, bottom = c.top or c, c.bottom or c
  for _, t in ipairs(shape.strips or { shape.tall, shape.left, shape.right }) do
    if c.top then
      Shade(t, top, bottom)
    else
      if t.SetGradient then t:SetGradient("VERTICAL", 1, 1, 1, 1, 1, 1) end
      t:SetAlpha(1)   -- a shaded look may have left its own see-through on the texture
      t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    end
  end
  if shape.corners then
    for i, t in ipairs(shape.corners) do
      local k = i <= 2 and top or bottom
      t:SetVertexColor(k[1], k[2], k[3], k[4] or 1)
    end
  end
end

-- a box with rounded corners and an edge around its background. Paint recolors either part.
local function Box(f, bg, edge, width, radius)
  width, radius = width or 1, radius or 0
  local b = { edge = RoundRing(f, "BACKGROUND", width, radius),
    fill = RoundRect(f, "BORDER", width, math.max(0, radius - width)) }
  b.Paint = function(bgc, edgec)
    if bgc then Color(b.fill, bgc) end
    if edgec then Color(b.edge, edgec) end
  end
  b.Paint(bg, edge)
  return b
end

local function Text(parent, size, color, font)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(font or UI_FONT, size, "")
  s:SetShadowColor(0, 0, 0, 1)
  s:SetShadowOffset(1, -1)
  s:SetTextColor(color[1], color[2], color[3])
  return s
end

-- whether the mouse is over a frame (MouseIsOver isn't in every 1.12 client)
local function Over(f)
  if not f or not f:IsVisible() then return end
  local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
  if not l then return end
  local s = f:GetEffectiveScale()
  local x, y = GetCursorPosition()
  x, y = x / s, y / s
  return x >= l and x <= r and y >= b and y <= t
end

-- ---------------------------------------------------------------- the bag
local CELL, PAD = 36, 8
local launcher     -- the bag button on the minimap, made further down
local Refresh      -- redraws the settings window, made further down
local ButtonLook   -- dims the bag button while collecting is off, made further down

local bag = CreateFrame("Frame", "ButtonBagFrame", UIParent)
bag:SetFrameStrata("DIALOG")
bag:SetClampedToScreen(true)
bag:EnableMouse(true)
bag:SetWidth(120)
bag:SetHeight(52)
bag:Hide()
table.insert(UISpecialFrames, "ButtonBagFrame")   -- Escape closes it
Box(bag, { top = UI.top, bottom = UI.bottom }, UI.outer, 1, 6)
local empty = Text(bag, 11, UI.muted)
empty:SetPoint("CENTER", bag, "CENTER", 0, 0)
empty:SetText("No buttons yet")

-- every AddOn button seen, in the order found: { button, name, label, ... }
local found, byButton = {}, {}
local inBag = {}   -- button -> true while it sits in the bag

-- "LibDBIcon10_Foo" and "FooMinimapButton" both read as "Foo"
local function Label(name)
  local s = string.gsub(name, "^LibDBIcon%d*_", "")
  s = string.gsub(s, "[_%-]?[Mm]ini[Mm]ap[_%-]?[Bb]utton$", "")
  s = string.gsub(s, "[_%-]?[Bb]utton$", "")
  if s == "" then s = name end
  return s
end

-- The game's own minimap buttons keep their place.
local OWN = { "^MiniMap", "^Minimap", "^GameTime", "^ButtonBag" }

local function Candidate(b)
  if b == launcher or byButton[b] or not b.GetObjectType then return end
  local kind = b:GetObjectType()
  if kind ~= "Button" and kind ~= "CheckButton" then return end
  local name = b:GetName()
  if not name then return end
  for _, pat in ipairs(OWN) do
    if string.find(name, pat) then return end
  end
  local w, h = b:GetWidth(), b:GetHeight()
  if not w or not h or w < 12 or h < 12 or w > 48 or h > 48 then return end
  return b:GetScript("OnDragStart") or string.find(name, "[Mm]ini[Mm]ap") or string.find(name, "LibDBIcon")
end

local function Scan()
  for _, parent in ipairs({ Minimap, MinimapCluster }) do
    if parent and parent.GetChildren then
      for _, child in ipairs({ parent:GetChildren() }) do
        if Candidate(child) then
          local name = child:GetName()
          local rec = { button = child, name = name, label = Label(name) }
          table.insert(found, rec)
          byButton[child] = rec
        end
      end
    end
  end
end

-- While a button is in the bag its own AddOn can't move it: its SetPoint and ClearAllPoints do
-- nothing, and the bag places it through the ones saved here. The wrapper stays for good and
-- passes everything through once the button is let go.
local function Wrap(rec)
  if rec.wrapped then return end
  rec.wrapped = true
  local b = rec.button
  rec.setPoint, rec.clearPoints = b.SetPoint, b.ClearAllPoints
  b.SetPoint = function(self, ...)
    if inBag[self] then return end
    return rec.setPoint(self, unpack(arg))
  end
  b.ClearAllPoints = function(self)
    if inBag[self] then return end
    return rec.clearPoints(self)
  end
end

local Layout

local function Capture(rec)
  local b = rec.button
  Wrap(rec)
  rec.parent, rec.strata, rec.level = b:GetParent(), b:GetFrameStrata(), b:GetFrameLevel()
  rec.scale = b:GetScale()
  rec.points = {}
  for i = 1, b:GetNumPoints() do
    local p1, p2, p3, p4, p5 = b:GetPoint(i)
    table.insert(rec.points, { p1, p2, p3, p4, p5 })
  end
  -- no dragging it around the rim from inside the bag
  rec.dragStart, rec.dragStop = b:GetScript("OnDragStart"), b:GetScript("OnDragStop")
  b:SetScript("OnDragStart", nil)
  b:SetScript("OnDragStop", nil)
  -- its own click runs first; a left-click then folds the bag up
  rec.click = b:GetScript("OnClick")
  rec.ourClick = function()
    if rec.click then rec.click() end
    if inBag[b] and db.closeOnClick and arg1 == "LeftButton" then bag:Hide() end
  end
  b:SetScript("OnClick", rec.ourClick)
  inBag[b] = true
  b:SetParent(bag)
  b:SetFrameStrata("DIALOG")
  b:SetFrameLevel(bag:GetFrameLevel() + 5)
end

local function Release(rec)
  local b = rec.button
  inBag[b] = nil
  b:SetParent(rec.parent)
  b:SetFrameStrata(rec.strata)
  b:SetFrameLevel(rec.level)
  b:SetScale(rec.scale)   -- the Names view shrinks it
  b:ClearAllPoints()
  for _, p in ipairs(rec.points) do b:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
  if not b:GetScript("OnDragStart") then b:SetScript("OnDragStart", rec.dragStart) end
  if not b:GetScript("OnDragStop") then b:SetScript("OnDragStop", rec.dragStop) end
  if b:GetScript("OnClick") == rec.ourClick then b:SetScript("OnClick", rec.click) end
end

-- ---------------------------------------------------------------- the round look
-- A button that doesn't wear the minimap's round gold ring gets one while it's in the bag, so the
-- bag looks even: its backdrop textures (BACKGROUND and BORDER layers) are hidden, its icon is
-- centered on a dark disc, and the ring goes over it. Letting it go puts all of that back.
local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local ICON_SIZE, DISC_R = 20, 11
local RING_X, RING_Y = 16.5, -15   -- the middle of the ring, from the top left of a 31 by 31 button

local function HasRing(b)
  for _, r in ipairs({ b:GetRegions() }) do
    local path = r.GetTexture and r:GetTexture()
    if type(path) == "string" and string.find(string.lower(path), "trackingborder") then return true end
  end
end

local function Skin(rec)
  if rec.skinned then return end
  local b = rec.button
  if rec.hasRing == nil then rec.hasRing = HasRing(b) or false end
  if rec.hasRing then return end
  rec.skinned = true
  if not rec.skin then
    -- made once per button: a ring on a frame over it, a dark disc under its icon
    local skin = CreateFrame("Frame", nil, b)
    skin:SetWidth(31)
    skin:SetHeight(31)
    skin:SetPoint("CENTER", b, "CENTER", 0, 0)
    local ring = skin:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(RING)
    ring:SetWidth(53)
    ring:SetHeight(53)
    ring:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
    -- the blue glow round minimap buttons get on hover; the bag shows it (see its OnUpdate)
    local over = CreateFrame("Frame", nil, skin)
    over:SetAllPoints(skin)
    local glow = over:CreateTexture(nil, "ARTWORK")
    glow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(over)
    glow:Hide()
    rec.glow = glow
    rec.disc = {}
    for _, c in ipairs(CORNERS) do
      local t = b:CreateTexture(nil, "BACKGROUND")
      t:SetTexture(MEDIA .. "corner")
      t:SetTexCoord(c[4], c[5], c[6], c[7])
      t:SetVertexColor(0.05, 0.04, 0.025, 1)
      t:SetWidth(DISC_R)
      t:SetHeight(DISC_R)
      t:SetPoint(c[1], skin, "TOPLEFT", RING_X - c[2] * DISC_R, RING_Y - c[3] * DISC_R)
      table.insert(rec.disc, t)
    end
    rec.skin = skin
  end
  -- what the button had: backdrops hidden, icons moved onto the disc
  rec.hidden, rec.icons = {}, {}
  for _, r in ipairs({ b:GetRegions() }) do
    local ours = false
    for _, t in ipairs(rec.disc) do
      if t == r then ours = true end
    end
    if not ours and r.GetTexture and r.GetDrawLayer then
      local layer = r:GetDrawLayer()
      if layer == "BACKGROUND" or layer == "BORDER" then
        if r:IsShown() then
          table.insert(rec.hidden, r)
          r:Hide()
        end
      elseif layer == "ARTWORK" or layer == "OVERLAY" then
        local icon = { tex = r, w = r:GetWidth(), h = r:GetHeight(), points = {} }
        for i = 1, r:GetNumPoints() do
          local p1, p2, p3, p4, p5 = r:GetPoint(i)
          table.insert(icon.points, { p1, p2, p3, p4, p5 })
        end
        r:ClearAllPoints()
        r:SetWidth(ICON_SIZE)
        r:SetHeight(ICON_SIZE)
        r:SetPoint("CENTER", rec.skin, "TOPLEFT", RING_X, RING_Y)
        table.insert(rec.icons, icon)
      end
    end
  end
  for _, t in ipairs(rec.disc) do t:Show() end
  rec.skin:Show()
end

local function Unskin(rec)
  if not rec.skinned then return end
  rec.skinned = nil
  rec.glow:Hide()
  rec.skin:Hide()
  for _, t in ipairs(rec.disc) do t:Hide() end
  for _, r in ipairs(rec.hidden) do r:Show() end
  for _, icon in ipairs(rec.icons) do
    local r = icon.tex
    r:ClearAllPoints()
    if icon.w and icon.w > 0 then r:SetWidth(icon.w) end
    if icon.h and icon.h > 0 then r:SetHeight(icon.h) end
    for _, p in ipairs(icon.points) do r:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
  end
end

-- every button found, A to Z or in the order set in the settings (new ones go last, A to Z)
local function Ordered()
  local rank = {}
  if db.sortMode == "custom" then
    for i, name in ipairs(db.order) do rank[name] = i end
  end
  local list = {}
  for _, rec in ipairs(found) do table.insert(list, rec) end
  table.sort(list, function(a, b)
    local ra, rb = rank[a.name] or 10000, rank[b.name] or 10000
    if ra ~= rb then return ra < rb end
    return string.lower(a.label) < string.lower(b.label)
  end)
  return list
end

-- the buttons in the bag that their AddOn shows, in order
local function Shown()
  local list = {}
  for _, rec in ipairs(Ordered()) do
    if inBag[rec.button] and rec.button:IsShown() then table.insert(list, rec) end
  end
  return list
end

-- An AddOn may set its button's strata or level again (one does on leaving its layout mode),
-- which would draw it under the bag's panel, looking greyed out. A button below the bag is lifted
-- back over it; one an AddOn raised higher is left there.
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
  FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function Lift(b)
  local mine, theirs = STRATA[bag:GetFrameStrata()] or 5, STRATA[b:GetFrameStrata()] or 0
  if theirs < mine then b:SetFrameStrata(bag:GetFrameStrata()) end
  if theirs <= mine and b:GetFrameLevel() < bag:GetFrameLevel() + 5 then
    b:SetFrameLevel(bag:GetFrameLevel() + 5)
  end
end

-- runs one of a button's own scripts as if the mouse were on the button itself
local function Forward(b, script, which)
  local f = b:GetScript(script)
  if not f then return end
  local oldThis, oldArg = this, arg1
  this, arg1 = b, which
  f()
  this, arg1 = oldThis, oldArg
end

-- The Names view: one row per button, its icon shrunk on the left and its name beside it. The
-- whole row clicks and hovers as the button does; the button itself sits on top of the row.
local ROW_H, LIST_SCALE = 26, 0.7
local nameRows = {}
local function NameRow(i)
  if nameRows[i] then return nameRows[i] end
  local row = CreateFrame("Button", nil, bag)
  row:SetHeight(ROW_H)
  row:SetFrameLevel(bag:GetFrameLevel() + 2)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local hot = Solid(row, "BACKGROUND", UI.selTop)
  hot:SetAllPoints(row)
  hot:Hide()
  row.hot = hot
  local name = Text(row, 12, UI.text)
  name:SetPoint("LEFT", row, "LEFT", ROW_H + 6, 0)
  name:SetJustifyH("LEFT")
  row.name = name
  row:SetScript("OnClick", function() if this.rec then Forward(this.rec.button, "OnClick", arg1) end end)
  row:SetScript("OnEnter", function() if this.rec then Forward(this.rec.button, "OnEnter") end end)
  row:SetScript("OnLeave", function() if this.rec then Forward(this.rec.button, "OnLeave") end end)
  nameRows[i] = row
  return row
end

-- puts a bagged button's middle at x, y from the bag's top left (offsets count in its own scale)
local function Place(rec, scale, x, y)
  local b = rec.button
  if b:GetScale() ~= scale then b:SetScale(scale) end
  Lift(b)
  rec.clearPoints(b)
  rec.setPoint(b, "CENTER", bag, "TOPLEFT", x / scale, y / scale)
end

Layout = function()
  local list = Shown()
  local n = table.getn(list)
  local names = db.style == "names"
  for i = n + 1, table.getn(nameRows) do
    nameRows[i].rec = nil
    nameRows[i]:Hide()
  end
  if n == 0 then
    empty:Show()
    bag:SetWidth(120)
    bag:SetHeight(52)
    return
  end
  empty:Hide()
  if names then
    local widest = 0
    for i, rec in ipairs(list) do
      local row = NameRow(i)
      row.rec = rec
      row.name:SetText(rec.label)
      widest = math.max(widest, row.name:GetStringWidth())
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", bag, "TOPLEFT", PAD, -(PAD + ROW_H * (i - 1)))
      row:Show()
      Place(rec, rec.scale * LIST_SCALE, PAD + ROW_H / 2, -(PAD + ROW_H * (i - 0.5)))
    end
    local w = math.max(120, ROW_H + 6 + math.ceil(widest) + 12)
    for i = 1, n do nameRows[i]:SetWidth(w) end
    bag:SetWidth(PAD * 2 + w)
    bag:SetHeight(PAD * 2 + ROW_H * n)
    return
  end
  for i = 1, table.getn(nameRows) do
    nameRows[i].rec = nil
    nameRows[i]:Hide()
  end
  local cols = math.min(db.cols, n)
  local rows = math.ceil(n / cols)
  for i, rec in ipairs(list) do
    local c, r = math.mod(i - 1, cols), math.floor((i - 1) / cols)
    Place(rec, rec.scale, PAD + CELL * (c + 0.5), -(PAD + CELL * (r + 0.5)))
  end
  bag:SetWidth(PAD * 2 + CELL * cols)
  bag:SetHeight(PAD * 2 + CELL * rows)
end

-- takes in or lets go of each button, as the settings say
local function Sync()
  for _, rec in ipairs(found) do
    local want = db.enabled and not db.keep[rec.name]
    if want and not inBag[rec.button] then
      Capture(rec)
    elseif not want and inBag[rec.button] then
      Release(rec)
    end
    if inBag[rec.button] and db.roundLook then Skin(rec) else Unskin(rec) end
  end
  if not db.enabled then bag:Hide() end
  Layout()
  if ButtonLook then ButtonLook() end
  if Refresh then Refresh() end
end

-- opens from the bag button the way the settings say; Auto drops toward the middle of the screen
local function OpenBag()
  Scan()
  Sync()
  -- the buttons keep the size they had on the minimap, times the Bag size setting
  bag:SetScale(Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale() * db.size)
  Layout()
  local anchor = launcher:IsVisible() and launcher or Minimap
  local x, y = anchor:GetCenter()
  local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
  x, y = x * s, y * s
  -- which side of the screen the bag button is on: the bag lines up with that side
  local v = y > UIParent:GetHeight() / 2 and "TOP" or "BOTTOM"
  local h = x > UIParent:GetWidth() / 2 and "RIGHT" or "LEFT"
  local dir = db.direction
  if dir == "auto" then dir = v == "TOP" and "down" or "up" end
  bag:ClearAllPoints()
  if dir == "down" then
    bag:SetPoint("TOP" .. h, anchor, "BOTTOM" .. h, 0, -4)
  elseif dir == "up" then
    bag:SetPoint("BOTTOM" .. h, anchor, "TOP" .. h, 0, 4)
  elseif dir == "left" then
    bag:SetPoint(v .. "RIGHT", anchor, v .. "LEFT", -4, 0)
  else
    bag:SetPoint(v .. "LEFT", anchor, v .. "RIGHT", 4, 0)
  end
  bag:Show()
end

local function ToggleBag()
  if bag:IsShown() then bag:Hide() else OpenBag() end
end

-- an AddOn may show or hide its button while the bag is open; the bag folds up once the mouse
-- has been away from it a moment (not while a menu from one of its buttons is open)
local tick, away = 0, 0
bag:SetScript("OnShow", function() tick, away = 0, 0 end)
bag:SetScript("OnUpdate", function()
  tick = tick + arg1
  if Over(bag) or Over(launcher) or (DropDownList1 and DropDownList1:IsShown()) then
    away = 0
  else
    away = away + arg1
  end
  if db.closeOnLeave and away > db.closeDelay then
    bag:Hide()
    return
  end
  -- a button given the round look glows under the mouse like the round ones do
  for _, rec in ipairs(found) do
    if rec.skinned then
      if Over(rec.button) then rec.glow:Show() else rec.glow:Hide() end
    end
  end
  -- and in the Names view the row under the mouse lights up
  for _, row in ipairs(nameRows) do
    if row.rec and Over(row) then row.hot:Show() else row.hot:Hide() end
  end
  if tick < 0.5 then return end
  tick = 0
  Layout()
end)

-- ---------------------------------------------------------------- the settings window
local ToggleConfig
do
local SCALE = 0.65   -- the sizes below are the game's Options window's; this brings them to screen size
local W = 600
local THICK = 1.25   -- buttons, checkboxes and panels have a heavier edge than the window
local CX = 250       -- where every control starts, clear of the longest label

local cfg = CreateFrame("Frame", "ButtonBagConfig", UIParent)
cfg:SetWidth(W)
cfg:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
cfg:SetFrameStrata("DIALOG")
cfg:SetToplevel(true)
cfg:SetMovable(true)
cfg:SetClampedToScreen(true)
cfg:EnableMouse(true)
cfg:RegisterForDrag("LeftButton")
cfg:SetScript("OnDragStart", function() this:StartMoving() end)
cfg:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
cfg:SetScale(SCALE)
cfg:Hide()
table.insert(UISpecialFrames, "ButtonBagConfig")   -- Escape closes it
Box(cfg, { top = UI.top, bottom = UI.bottom }, UI.outer, 1, 12)

local title = Text(cfg, 36, UI.title, TITLE_FONT)
title:SetPoint("TOP", cfg, "TOP", 0, -14)
title:SetText("ButtonBag")

local panel = CreateFrame("Frame", nil, cfg)
panel:SetPoint("TOPLEFT", cfg, "TOPLEFT", 26, -69)
panel:SetPoint("BOTTOMRIGHT", cfg, "BOTTOMRIGHT", -26, 72)
Box(panel, { 0, 0, 0, 0.38 }, UI.panelEdge, THICK, 4)

-- the line along the bottom says what the setting under the mouse does
local help = Text(cfg, 13, UI.muted)
help:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -10)
help:SetWidth(W - 26 - 230 - 14)   -- stops short of the Look again and Done buttons
help:SetHeight(50)
help:SetJustifyH("LEFT")
help:SetJustifyV("TOP")
local function Help(text) help:SetText(text or "Hover a setting to see what it does.") end

local function Hover(f, desc, onEnter, onLeave)
  f:SetScript("OnEnter", function()
    Help(type(desc) == "function" and desc() or desc)
    if onEnter then onEnter() end
  end)
  f:SetScript("OnLeave", function()
    Help(nil)
    if onLeave then onLeave() end
  end)
end

-- one column down the panel: headings and rows stack downward
local col = { y = -12, width = W - 52 }
local controls, grouped = {}, {}

local function Heading(text)
  if col.y < -12 then col.y = col.y - 8 end
  local h = Text(panel, 16, UI.title, TITLE_FONT)
  h:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, col.y - 4)
  h:SetText(text)
  local line = Solid(panel, "ARTWORK", UI.dim)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, col.y - 24)
  line:SetWidth(col.width - 30)
  col.y = col.y - 30
end

-- one setting: the gold label on the left, its control at CX
local function Row(label, desc, height)
  local row = CreateFrame("Frame", nil, panel)
  row:SetHeight(height or 30)
  row:SetWidth(col.width)
  row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, col.y)
  row:EnableMouse(true)
  col.y = col.y - (height or 30) - 2
  local l = Text(row, 14, UI.gold)
  l:SetPoint("LEFT", row, "LEFT", 15, 0)
  l:SetText(label)
  row.label = l
  Hover(row, desc)
  return row
end

-- a square checkbox on a row; get and set read and write what it stands for
local function CheckBox(row, desc, get, set)
  local b = CreateFrame("Button", nil, row)
  b:SetWidth(21)
  b:SetHeight(21)
  b:SetPoint("LEFT", row, "LEFT", CX, 0)
  local box = Box(b, UI.well, UI.edge, THICK, 2.5)
  local mark = Solid(b, "ARTWORK", UI.hot)
  mark:SetPoint("TOPLEFT", b, "TOPLEFT", 4.25, -4.25)
  mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4.25, 4.25)
  Hover(b, desc, function() box.Paint(nil, UI.hot) end, function() box.Paint(nil, UI.edge) end)
  b:SetScript("OnClick", function()
    if row.off then return end
    set(not get())
    Sync()
  end)
  b.Refresh = function() if get() then mark:Show() else mark:Hide() end end
  table.insert(controls, b)
  return b
end

-- a checkbox for a setting; when, if given, greys the row out while it's false
local function Check(key, label, desc, onChange, when)
  local row = Row(label, desc)
  CheckBox(row, desc, function() return db[key] end, function(v)
    db[key] = v
    if onChange then onChange() end
  end)
  if when then
    row.when = when
    table.insert(grouped, row)
  end
end

-- a row of buttons, one per choice ({ value, text, description }), the chosen one dark red
local function Choice(key, label, choices, desc, when)
  local row = Row(label, desc)
  if when then
    row.when = when
    table.insert(grouped, row)
  end
  local x = CX
  for _, c in ipairs(choices) do
    local value = c[1]
    local b = CreateFrame("Button", nil, row)
    local t = Text(b, 13, UI.gold)
    t:SetPoint("CENTER", b, "CENTER", 0, 0)
    t:SetText(c[2])
    local w = math.max(math.ceil(t:GetStringWidth()) + 18, 30)
    b:SetWidth(w)
    b:SetHeight(25)
    b:SetPoint("LEFT", row, "LEFT", x, 0)
    x = x + w + 5.5
    local box = Box(b, UI.well, UI.dim, 1, 2.5)
    Hover(b, c[3] or desc, function() if db[key] ~= value then box.Paint(nil, UI.edge) end end,
      function() if db[key] ~= value then box.Paint(nil, UI.dim) end end)
    b:SetScript("OnClick", function()
      if row.off then return end
      db[key] = value
      Sync()
    end)
    b.Refresh = function()
      local on = db[key] == value
      box.Paint(on and SELECTED or UI.well, on and UI.hot or UI.dim)
      t:SetTextColor(unpack(on and UI.chosen or UI.gold))
    end
    table.insert(controls, b)
  end
end

local function On() return db.enabled end

Heading("Bag")
Check("enabled", "Collect buttons", "Gathers the AddOn buttons around the minimap into the bag. Turn it off to put every button back where it was.")
Check("button", "Show bag button", "Shows the bag button on the minimap. Drag it around the edge to move it. Without it, /bbag open opens the bag.",
  function() if db.button then launcher:Show() else launcher:Hide(); bag:Hide() end end)
Check("hoverOpen", "Open on hover", "Opens the bag as soon as you point at the bag button, without a click. Right-click still opens these settings.", nil, On)
Choice("direction", "Open direction", { { "auto", "Auto", "Opens down when the bag button is in the top half of the screen, up when it's in the bottom half." },
  { "down", "Down" }, { "up", "Up" }, { "left", "Left" }, { "right", "Right" } },
  "Which way the bag opens from the bag button.", On)
Choice("size", "Bag size", { { 0.75, "Small" }, { 1, "Normal" }, { 1.25, "Large" }, { 1.5, "Huge" } },
  "How big the buttons in the bag are. Normal is the size they have on the minimap.", On)
Check("roundLook", "Round look", "Gives buttons that aren't round, like square ones, the same round gold ring as the rest while they're in the bag. Off shows each button as its AddOn drew it.", nil, On)
Choice("style", "Bag shows", { { "icons", "Icons", "The buttons side by side, as they look on the minimap." },
  { "names", "Names", "A list: each button's icon, smaller, with its AddOn's name beside it. Click or point anywhere on a row." } },
  "Whether the bag shows the buttons as icons or as a list of names.", On)
Choice("cols", "Buttons per row", { { 1, "1" }, { 2, "2" }, { 3, "3" }, { 4, "4" }, { 5, "5" }, { 6, "6" } },
  "How many buttons sit side by side in the bag before a new row starts. The Names list is always one column.",
  function() return db.enabled and db.style ~= "names" end)
Check("closeOnClick", "Close after a click", "Folds the bag up after you left-click one of its buttons. Right-clicks leave it open.", nil, On)
Check("closeOnLeave", "Close when the mouse leaves", "Folds the bag up a moment after the mouse leaves it.", nil, On)
Choice("closeDelay", "Close after", { { 0.5, "0.5s" }, { 1, "1s" }, { 1.5, "1.5s" }, { 3, "3s" }, { 5, "5s" } },
  "How long the mouse can be away from the bag before it folds up.", function() return db.enabled and db.closeOnLeave end)

Heading("Buttons")
Choice("sortMode", "Button order", { { "az", "A to Z", "Buttons sit in the bag in A to Z order." },
  { "custom", "My order", "Buttons sit in the order of the list below. Use Up and Down to move them; new buttons go last." } },
  "The order the buttons sit in the bag.", On)
local note = Text(panel, 13, UI.muted)
note:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, col.y - 2)
note:SetWidth(col.width - 30)
note:SetJustifyH("LEFT")
note:SetText("Ticked buttons go in the bag. Untick one to keep it on the minimap.")
col.y = col.y - 24

-- the list shows the buttons in their bag order; Refresh fills this
local listed = {}

-- moves the button at place i of the list one place up (-1) or down (1)
local function Move(i, delta)
  local j = i + delta
  if not listed[i] or not listed[j] then return end
  listed[i], listed[j] = listed[j], listed[i]
  db.order = {}
  for _, rec in ipairs(listed) do table.insert(db.order, rec.name) end
  Sync()
end

-- a small boxed text button on a list row
local function SmallButton(row, text, x, desc, onClick)
  local b = CreateFrame("Button", nil, row)
  local t = Text(b, 12, UI.gold)
  t:SetPoint("CENTER", b, "CENTER", 0, 0)
  t:SetText(text)
  b:SetWidth(54)
  b:SetHeight(23)
  b:SetPoint("LEFT", row, "LEFT", x, 0)
  local box = Box(b, UI.well, UI.dim, 1, 2.5)
  Hover(b, desc, function() box.Paint(nil, UI.edge) end, function() box.Paint(nil, UI.dim) end)
  b:SetScript("OnClick", function()
    if row.off then return end
    onClick()
  end)
  return b
end

-- one row per button found, made as they turn up
local listTop = col.y
local listRows = {}
local function ListRow(i)
  if listRows[i] then return listRows[i] end
  col.y = listTop - (i - 1) * 32
  local row = Row("", nil)
  row.index = i
  local function Rec() return listed[row.index] end
  row.up = SmallButton(row, "Up", CX + 40, "Moves this button one place earlier in the bag.",
    function() Move(row.index, -1) end)
  row.down = SmallButton(row, "Down", CX + 100, "Moves this button one place later in the bag.",
    function() Move(row.index, 1) end)
  local desc = function()
    local rec = Rec()
    return rec and ("Keeps " .. rec.label .. "'s button in the bag (frame " .. rec.name .. ").") or nil
  end
  Hover(row, desc)
  CheckBox(row, desc, function()
    local rec = Rec()
    return rec and not db.keep[rec.name]
  end, function(v)
    local rec = Rec()
    if rec then db.keep[rec.name] = (not v) or nil end
  end)
  row.when = On
  table.insert(grouped, row)
  listRows[i] = row
  return row
end

local none = Text(panel, 13, UI.text)
none:SetPoint("TOPLEFT", panel, "TOPLEFT", 15, listTop - 8)
none:SetText("No AddOn buttons found on the minimap yet.")

local function BigButton(text, x, width, onClick)
  local b = CreateFrame("Button", nil, cfg)
  b:SetWidth(width)
  b:SetHeight(34)
  b:SetPoint("BOTTOMRIGHT", cfg, "BOTTOMRIGHT", x, 21)
  local box = Box(b, SELECTED, UI.edge, THICK, 3)
  local t = Text(b, 15, UI.gold)
  t:SetPoint("CENTER", b, "CENTER", 0, 0)
  t:SetText(text)
  b:SetScript("OnEnter", function() box.Paint(nil, UI.hot) end)
  b:SetScript("OnLeave", function() box.Paint(SELECTED, UI.edge) end)
  b:SetScript("OnMouseDown", function() box.Paint(PRESSED) end)
  b:SetScript("OnMouseUp", function() box.Paint(SELECTED) end)
  b:SetScript("OnClick", onClick)
  return b
end
BigButton("Done", -26, 76, function() cfg:Hide() end)
local rescan = BigButton("Look again", -110, 120, function()
  Scan()
  Sync()
end)
Hover(rescan, "Looks for buttons again, for an AddOn that made its button late.",
  function() end, function() end)

Refresh = function()
  if not db or not cfg:IsShown() then return end
  listed = Ordered()
  local n = table.getn(listed)
  local custom = db.sortMode == "custom"
  for i = 1, n do
    local row = ListRow(i)
    row.label:SetText(listed[i].label)
    row:Show()
    -- Up and Down only in My order, and not past either end
    if custom and i > 1 then row.up:Show() else row.up:Hide() end
    if custom and i < n then row.down:Show() else row.down:Hide() end
  end
  for i = n + 1, table.getn(listRows) do listRows[i]:Hide() end
  if n == 0 then none:Show() else none:Hide() end
  for i = 1, table.getn(controls) do controls[i].Refresh() end
  for _, row in ipairs(grouped) do
    row.off = not row.when()
    row:SetAlpha(row.off and 0.35 or 1)
  end
  -- the panel is as tall as what's in it
  local listHeight = math.max(n, 1) * 32
  cfg:SetHeight(69 + (12 - listTop) + listHeight + 10 + 72)
end
cfg:SetScript("OnShow", function()
  Help(nil)
  Refresh()
end)

ToggleConfig = function()
  if cfg:IsShown() then
    cfg:Hide()
  else
    Scan()
    cfg:Show()
  end
end
end

-- ---------------------------------------------------------------- the bag button
local function SquareMinimap()
  if type(GetMinimapShape) == "function" then
    local ok, shape = pcall(GetMinimapShape)
    if ok and shape then return shape == "SQUARE" end
  end
end

launcher = CreateFrame("Button", "ButtonBagMinimapButton", Minimap)
launcher:SetWidth(31)
launcher:SetHeight(31)
launcher:SetFrameStrata("MEDIUM")
launcher:SetFrameLevel(Minimap:GetFrameLevel() + 8)
launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local btnIcon = launcher:CreateTexture(nil, "BACKGROUND")
btnIcon:SetWidth(20)
btnIcon:SetHeight(20)
btnIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
btnIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btnIcon:SetPoint("TOPLEFT", launcher, "TOPLEFT", 6, -5)
local btnRing = launcher:CreateTexture(nil, "OVERLAY")
btnRing:SetWidth(53)
btnRing:SetHeight(53)
btnRing:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btnRing:SetPoint("TOPLEFT", launcher, "TOPLEFT", 0, 0)

-- angle in degrees, 0 = east, counterclockwise; on a square minimap it sits on the square's edge
local function PlaceButton()
  local a = math.rad(db.btnAngle)
  local x, y = math.cos(a), math.sin(a)
  if SquareMinimap() then
    local m = math.max(math.abs(x), math.abs(y))
    x, y = x / m, y / m
  end
  local r = (Minimap:GetWidth() or 140) / 2 + 8
  launcher:ClearAllPoints()
  launcher:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

-- the bag, dimmed while collecting is off
ButtonLook = function()
  if db.enabled then btnIcon:SetVertexColor(1, 1, 1) else btnIcon:SetVertexColor(0.35, 0.35, 0.35) end
end

launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
launcher:RegisterForDrag("LeftButton")
launcher:SetScript("OnClick", function()
  if not db then return end
  GameTooltip:Hide()
  if arg1 == "RightButton" or not db.enabled then
    ToggleConfig()
  else
    ToggleBag()
  end
end)
launcher:SetScript("OnDragStart", function()
  bag:Hide()
  this:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local s = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    db.btnAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
    PlaceButton()
  end)
end)
launcher:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
launcher:SetScript("OnEnter", function()
  if bag:IsShown() then return end
  if db.enabled and db.hoverOpen then
    OpenBag()
    return
  end
  local n = 0
  for _, rec in ipairs(found) do
    if inBag[rec.button] then n = n + 1 end
  end
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine("ButtonBag", 0.85, 0.64, 0.25)
  if db.enabled then
    GameTooltip:AddLine(n .. (n == 1 and " button" or " buttons") .. " in the bag", 0.73, 0.66, 0.51)
    GameTooltip:AddLine("Left-click: open the bag", 1, 1, 1)
  else
    GameTooltip:AddLine("Collecting is off", 0.73, 0.66, 0.51)
  end
  GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
  GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
  GameTooltip:Show()
end)
launcher:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ---------------------------------------------------------------- starting up
-- AddOns make and place their buttons as they load and as the world comes in, some a little
-- later, so the bag looks several times over the first seconds.
local LOOKS = { 1, 4, 10 }
local main = CreateFrame("Frame")
main:RegisterEvent("VARIABLES_LOADED")
main:RegisterEvent("PLAYER_ENTERING_WORLD")
local since, nextLook
main:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    ButtonBagDB = ButtonBagDB or {}
    db = ButtonBagDB
    for k, v in pairs(defaults) do
      if db[k] == nil then db[k] = type(v) == "table" and {} or v end
    end
    PlaceButton()
    if db.button then launcher:Show() else launcher:Hide() end
    ButtonLook()
  elseif event == "PLAYER_ENTERING_WORLD" and db then
    since, nextLook = 0, 1
  end
end)
main:SetScript("OnUpdate", function()
  if not since then return end
  since = since + arg1
  if since < LOOKS[nextLook] then return end
  Scan()
  Sync()
  nextLook = nextLook + 1
  if not LOOKS[nextLook] then since = nil end
end)

-- ---------------------------------------------------------------- /bbag
SLASH_BUTTONBAG1 = "/bbag"
SLASH_BUTTONBAG2 = "/buttonbag"
SlashCmdList["BUTTONBAG"] = function(msg)
  if not db then return end
  local cmd = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
  if cmd == "open" then
    if db.enabled then ToggleBag() else Print("collecting is off; turn it on in /bbag.") end
  elseif cmd == "scan" then
    Scan()
    Sync()
    local n = 0
    for _, rec in ipairs(found) do
      if inBag[rec.button] then n = n + 1 end
    end
    Print(n .. " of " .. table.getn(found) .. " buttons in the bag.")
  elseif cmd == "" then
    ToggleConfig()
  else
    Print("/bbag: settings. /bbag open: open or close the bag. /bbag scan: look for buttons again.")
  end
end
