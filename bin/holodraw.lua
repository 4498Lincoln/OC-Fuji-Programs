local component = require("component")
local term = require("term")
local event = require("event")
local computer = require("computer")
local unicode = require("unicode")
local h = component.hologram
local gpu = component.gpu

local args = {...}
local layer
local blockChar = unicode.char(0x2588)

-- Function for checking whether something is in a fully inclusive interval or not
local function isInInterval(val, intStart, intEnd)
  return (val >= intStart) and (val <= intEnd)
end

-- Function for iterating through the 48x48 resolution
local function iterHolo(func)
  for i = 1, 48 do
    for i2 = 1, 48 do
      func(i, i2)
    end
  end
end

-- Function for updating the display by the hologram projector
local function updateDisplay()
  term.clear()
  iterHolo(function(i, i2)
    if h.get(i, layer, i2) ~= 0 then
      gpu.set(i, i2, blockChar)
    end
  end)
end

-------------------------------------------------------------------------------------------------------

if (not args[1]) or (not args[2]) then
  print("Usage: <layer> <clr>")
  print("Layer is a number in the interval [1, 32] specifying the y coordinate to use")
  print("clr is y/n specifying whether to clear the hologram or not")
  os.exit()
end

------- Keybinds -------

local curMode = true -- true means write
local oldResX
local oldResY

local keybindDescriptions = {
  q = "quit",
  h = "show keybinds",
  c = "clear",
  e = "switch modes",
  t = "generate noise",
  g = "switch layer"
}

-- For showing all of the keybinds
local function showKeybinds()
  print("Keybinds:")
  for k, v in pairs(keybindDescriptions) do
    print(k .. ": " .. v)
  end
  print("OK: ")
  event.pull("key_down")
end

showKeybinds()

local keyList = {
  -- Quit
  q = function()
    gpu.setResolution(oldResX, oldResY)
    term.clear()
    os.exit()
  end,
  -- Clear
  c = function()
    term.clear()
    iterHolo(function(i, i2)
      h.set(i, layer, i2, false)
    end)
  end,
  -- Switch modes
  e = function()
    if curMode then -- Switch to erase mode
      curMode = false
      gpu.setForeground(0xFF0022)
      iterHolo(function(i, i2)
        if gpu.get(i, i2) ~= " " then -- If it is a block char, turn it red
          gpu.set(i, i2, " ")
          gpu.set(i, i2, blockChar)
        end
      end)
    else            -- Switch to write mode
      curMode = true
      gpu.setForeground(0x00AAFF)
      iterHolo(function(i, i2)
        if gpu.get(i, i2) ~= " " then -- If it is a block char, turn it blue
          gpu.set(i, i2, " ")
          gpu.set(i, i2, blockChar)
        end
      end)
    end
  end,
  -- Generate noise
  t = function()
    iterHolo(function(i, i2)
      local randomness = math.random(0, 1) == 1
      if randomness then
        gpu.set(i, i2, blockChar)
        h.set(i, layer, i2, true)
      else
        gpu.set(i, i2, " ")
        h.set(i, layer, i2, false)
      end
    end)
  end,
  -- Switch between layers
  g = function()
    term.clear()
    
    local function doLayerError(msg)
      term.clear()
      gpu.setResolution(gpu.maxResolution())
      error(msg)
    end
    term.write("Layer: ")
    layer = tonumber(io.read())
    -- Make sure the layer is valid
    if not layer then
      doLayerError("Layer must be a number")
    end
    if not isInInterval(layer, 1, 32) then
      doLayerError("Layer must be in the interval [1, 32]")
    end
    term.clear()
    updateDisplay()
  end,
  -- Show keybinds
  h = function()
    term.clear()
    showKeybinds()
    updateDisplay()
  end
}

setmetatable(keyList, {
  __call = function(t, toSearch)
    for k, v in pairs(t) do
      if k == toSearch then
        return true
      end
    end
    return false
  end
})

------- ________ -------

-- Clear screen or not
if args[2] == "y" then
  h.clear()
end

-- Layer to use
layer = assert(tonumber(args[1]), "Layer must be a number")
if not isInInterval(layer, 1, 32) then
  error("Layer must be in the interval [1, 32]")
end







-- Start drawing
gpu.setForeground(0x00AAFF)
gpu.setBackground(0x000000)
term.clear()
oldResX, oldResY = gpu.getResolution()
gpu.setResolution(48, 48)

-- Update to match hologram
updateDisplay()

while true do
  local evname, _, tX, tY = event.pullMultiple("touch", "drag", "key_down")
  -- Activate keybinds
  if evname == "key_down" then
    local charPressed = string.lower(unicode.char(tX))
    if keyList(charPressed) then
      keyList[charPressed]()
    end
  end
  
  -- Change voxels
  local isSuccess = pcall(function()
    if curMode then -- If write mode
      gpu.set(tX, tY, blockChar)
      h.set(tX, layer, tY, true)
    else                           -- If erase mode
      gpu.set(tX, tY, " ")
      h.set(tX, layer, tY, false)
    end
  end)
  if not isSuccess then
    computer.beep(1500, 0.25)
  end
end
