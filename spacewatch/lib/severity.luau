--!nonstrict
-- Pure helpers shared by Spacewatch entries and its tests.
-- Keep this file Lua-compatible so the plain-Lua test harness can load it.

local Severity = {}

local LEVEL_NORMAL = 0
local LEVEL_WARNING = 1
local LEVEL_CRITICAL = 2

local BYTE_UNITS = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }

local function clampThreshold(value, fallback)
  local number = tonumber(value)
  if number == nil then
    number = fallback
  end
  number = math.floor(number)
  if number < 1 then
    return 1
  elseif number > 100 then
    return 100
  end
  return number
end

function Severity.normalizeThresholds(warningThreshold, criticalThreshold)
  local warning = clampThreshold(warningThreshold, 85)
  local critical = clampThreshold(criticalThreshold, 95)
  if critical < warning then
    critical = warning
  end
  return warning, critical
end

function Severity.levelFor(usagePercent, warningThreshold, criticalThreshold)
  local warning, critical = Severity.normalizeThresholds(warningThreshold, criticalThreshold)
  local usage = tonumber(usagePercent) or 0
  if usage >= critical then
    return LEVEL_CRITICAL
  elseif usage >= warning then
    return LEVEL_WARNING
  end
  return LEVEL_NORMAL
end

-- Returns "warning", "critical", or "recovered" when the level change needs an
-- alert, and nil when it does not.
function Severity.announce(previousLevel, currentLevel)
  local previous = tonumber(previousLevel) or LEVEL_NORMAL
  local current = tonumber(currentLevel) or LEVEL_NORMAL

  if current > previous then
    if current >= LEVEL_CRITICAL then
      return "critical"
    elseif current >= LEVEL_WARNING then
      return "warning"
    end
  elseif current == LEVEL_NORMAL and previous > LEVEL_NORMAL then
    return "recovered"
  end

  return nil
end

function Severity.formatBytes(bytes)
  local value = tonumber(bytes)
  if value == nil or value ~= value or value < 0 then
    return "?"
  end

  local unit = 1
  while value >= 1024 and unit < #BYTE_UNITS do
    value = value / 1024
    unit = unit + 1
  end

  if unit == 1 then
    return string.format("%d %s", math.floor(value + 0.5), BYTE_UNITS[unit])
  end
  return string.format("%.1f %s", value, BYTE_UNITS[unit])
end

function Severity.formatPercent(percent)
  local value = tonumber(percent)
  if value == nil or value ~= value then
    return "?"
  end
  if value < 0 then
    value = 0
  elseif value > 100 then
    value = 100
  end
  return string.format("%d", math.floor(value + 0.5))
end

return Severity
