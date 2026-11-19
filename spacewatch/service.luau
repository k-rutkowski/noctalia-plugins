--!nonstrict
-- Spacewatch monitor service.
--
-- Samples every configured filesystem twice at startup so the first reading is
-- available quickly, then settles into the configured poll interval. Alerts are
-- sent only when a filesystem's severity rises, plus an optional recovery notice.

local severity = require("./lib/severity.luau")

local WARMUP_INTERVAL_MS = 2000
local WARMUP_ATTEMPTS = 5

local lastLevels = {}
local settled = false
local warmupAttempts = 0

local function pollIntervalMs()
  local seconds = tonumber(noctalia.getConfig("poll_seconds")) or 30
  if seconds < 10 then
    seconds = 10
  elseif seconds > 3600 then
    seconds = 3600
  end
  return math.floor(seconds * 1000)
end

local function recoveryEnabled()
  return noctalia.getConfig("notify_recovery") ~= false
end

local function normalizePath(path)
  if type(path) ~= "string" then
    return nil
  end
  path = noctalia.string.trim(path)
  if path == "" then
    return nil
  end
  path = noctalia.expandPath(path) or path
  if #path > 1 then
    path = path:gsub("/+$", "")
  end
  if path:sub(1, 1) ~= "/" then
    noctalia.log("spacewatch: ignoring non-absolute filesystem path '" .. path .. "'")
    return nil
  end
  return path
end

local function normalizeLabel(label)
  if type(label) == "string" then
    label = noctalia.string.trim(label)
    if label == "" then
      return nil
    end
    return label
  end
  return nil
end

local function addTarget(targets, seen, path, label)
  if seen[path] then
    return
  end
  seen[path] = true
  targets[#targets + 1] = {
    path = path,
    label = normalizeLabel(label),
  }
end

-- Entries are "path" or "path = label". Within a path, \= and \\
-- represent literal equals signs and backslashes, respectively.
local function splitEntry(entry)
  local path = {}
  local i = 1
  while i <= #entry do
    local char = entry:sub(i, i)
    local nextChar = entry:sub(i + 1, i + 1)
    if char == "\\" and (nextChar == "=" or nextChar == "\\") then
      path[#path + 1] = nextChar
      i = i + 2
    elseif entry:sub(i, i + 2) == " = " then
      return table.concat(path), entry:sub(i + 3)
    else
      path[#path + 1] = char
      i = i + 1
    end
  end
  return table.concat(path), nil
end

local function monitorTargets()
  local targets = {}
  local seen = {}
  local filesystems = noctalia.getConfig("filesystems")
  if type(filesystems) ~= "table" then
    return targets
  end

  for _, entry in ipairs(filesystems) do
    if type(entry) == "string" then
      local path, label = splitEntry(entry)
      local normalizedPath = normalizePath(path)
      if normalizedPath ~= nil then
        addTarget(targets, seen, normalizedPath, label)
      end
    end
  end

  return targets
end

local function alert(event, path, usagePercent, stats, force)
  local substitutions = {
    path = path,
    percent = severity.formatPercent(usagePercent),
    free = severity.formatBytes(stats.availableBytes or stats.freeBytes),
    total = severity.formatBytes(stats.totalBytes),
  }

  if event == "critical" then
    noctalia.notifyError(
      noctalia.tr("alert.critical.title"),
      noctalia.tr("alert.critical.body", substitutions)
    )
  elseif event == "warning" then
    noctalia.notify(
      noctalia.tr("alert.warning.title"),
      noctalia.tr("alert.warning.body", substitutions)
    )
  elseif event == "recovered" and (force or recoveryEnabled()) then
    noctalia.notify(
      noctalia.tr("alert.recovered.title"),
      noctalia.tr("alert.recovered.body", substitutions)
    )
  end
end

local function previewStats(usagePercent)
  local rootStats = noctalia.diskStats("/")
  local total = rootStats ~= nil and tonumber(rootStats.totalBytes) or 1024 * 1024 * 1024 * 1024
  local free = math.floor(total * (100 - usagePercent) / 100)
  return {
    totalBytes = total,
    freeBytes = free,
    availableBytes = free,
  }
end

local function previewNotification(event)
  if type(event) ~= "string" then
    return
  end
  event = event:lower()

  if event == "all" then
    previewNotification("warning")
    previewNotification("critical")
    previewNotification("recovered")
    return
  end

  local warning, critical =
    severity.normalizeThresholds(noctalia.getConfig("warning_threshold"), noctalia.getConfig("critical_threshold"))
  local usage
  if event == "warning" then
    usage = warning
  elseif event == "critical" then
    usage = critical
  elseif event == "recovered" then
    usage = math.max(1, warning - 10)
  else
    return
  end

  alert(event, "/", usage, previewStats(usage), true)
end

local function sample()
  local warningThreshold, criticalThreshold =
    severity.normalizeThresholds(noctalia.getConfig("warning_threshold"), noctalia.getConfig("critical_threshold"))

  local targets = monitorTargets()
  local readings = {}
  local seen = {}

  for _, target in ipairs(targets) do
    local path = target.path
    if type(path) == "string" and path ~= "" then
      seen[path] = true
      local stats = noctalia.diskStats(path)
      local usage = stats ~= nil and tonumber(stats.usagePercent) or nil

      if usage ~= nil then
        local level = severity.levelFor(usage, warningThreshold, criticalThreshold)
        local previous = lastLevels[path] or 0
        local event = severity.announce(previous, level)

        if event ~= nil then
          alert(event, path, usage, stats)
        end

        lastLevels[path] = level
        readings[#readings + 1] = {
          path = path,
          label = target.label,
          usagePercent = usage,
          level = level,
          totalBytes = stats.totalBytes,
          freeBytes = stats.freeBytes,
          availableBytes = stats.availableBytes,
        }
      end
    end
  end

  for path in pairs(lastLevels) do
    if not seen[path] then
      lastLevels[path] = nil
    end
  end

  noctalia.state.set("report", {
    mounts = readings,
    updatedAt = noctalia.nowMs(),
  })

  return #readings > 0
end

noctalia.setUpdateInterval(WARMUP_INTERVAL_MS)
sample()

function update()
  local hasData = sample()
  warmupAttempts = warmupAttempts + 1

  if not settled and (hasData or warmupAttempts >= WARMUP_ATTEMPTS) then
    settled = true
    noctalia.setUpdateInterval(pollIntervalMs())
  end
end

function onConfigChanged()
  settled = true
  noctalia.setUpdateInterval(pollIntervalMs())
  sample()
end

function onIpc(event, payload)
  if event == "refresh" or event == "check" then
    sample()
  elseif event == "simulate" then
    previewNotification(payload)
  end
end
