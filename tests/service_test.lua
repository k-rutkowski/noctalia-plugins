local severity = dofile("spacewatch/lib/severity.luau")
local realRequire = require
require = function(path)
  if path == "./lib/severity.luau" then
    return severity
  end
  return realRequire(path)
end

local gib = 1024 * 1024 * 1024
local config = {
  warning_threshold = 85,
  critical_threshold = 95,
  poll_seconds = 30,
  notify_recovery = true,
  filesystems = { "/", "/home", "/mnt/missing" },
}

local stats = {
  ["/"] = {
    usagePercent = 50,
    totalBytes = 500 * gib,
    freeBytes = 260 * gib,
    availableBytes = 250 * gib,
  },
  ["/home"] = {
    usagePercent = 90,
    totalBytes = 200 * gib,
    freeBytes = 22 * gib,
    availableBytes = 20 * gib,
  },
}

local state = {}
local intervals = {}
local notifications = {}
local errors = {}
local now = 1000

noctalia = {
  getConfig = function(key)
    return config[key]
  end,
  setUpdateInterval = function(ms)
    intervals[#intervals + 1] = ms
  end,
  diskStats = function(path)
    return stats[path]
  end,
  nowMs = function()
    return now
  end,
  expandPath = function(path)
    if path == "~" then
      return "/home/kr"
    elseif path:sub(1, 2) == "~/" then
      return "/home/kr" .. path:sub(2)
    end
    return path
  end,
  string = {
    trim = function(value)
      return (value:gsub("^%s+", ""):gsub("%s+$", ""))
    end,
  },
  log = function() end,
  tr = function(key)
    return key
  end,
  notify = function(title, body)
    notifications[#notifications + 1] = { title = title, body = body }
  end,
  notifyError = function(title, body)
    errors[#errors + 1] = { title = title, body = body }
  end,
  state = {
    set = function(key, value)
      state[key] = value
    end,
    get = function(key)
      return state[key]
    end,
  },
}

local chunk = assert(loadfile("spacewatch/service.luau"))
chunk()

local function check(condition, message)
  if not condition then
    error(message, 2)
  end
end

local function findMount(path)
  for _, mount in ipairs(state.report.mounts) do
    if mount.path == path then
      return mount
    end
  end
  return nil
end

check(#notifications == 1, "initial sample should send one warning")
check(notifications[1].title == "alert.warning.title", "initial notification should be the warning")
check(#errors == 0, "initial sample should not send a critical error")
check(intervals[1] == 2000, "service should start with the warmup interval")
check(type(state.report) == "table", "service should publish a report")
check(#state.report.mounts == 2, "filesystems without a sample should be omitted")
check(state.report.mounts[1].path == "/home", "report should be sorted by usage")
check(state.report.mounts[1].level == 1, "home should be at warning level")
check(state.report.mounts[2].path == "/", "reports should include healthy filesystems")
check(state.report.updatedAt == now, "report should carry the sample time")

update()
check(intervals[2] == 30000, "first successful update should settle into the poll interval")
check(#notifications == 1 and #errors == 0, "an unchanged warning should not repeat")

stats["/home"].usagePercent = 96
update()
check(#errors == 1, "crossing the critical threshold should send an error")
check(errors[1].title == "alert.critical.title", "critical notification should use the critical title")

update()
check(#errors == 1, "a repeated critical sample should not repeat the alert")

stats["/home"].usagePercent = 84
update()
check(#notifications == 2, "dropping back to normal should send a recovery notice")
check(notifications[2].title == "alert.recovered.title", "recovery should use the recovery title")

config.notify_recovery = false
stats["/home"].usagePercent = 97
update()
check(#errors == 2, "a new critical crossing should alert again")
stats["/home"].usagePercent = 80
update()
check(#notifications == 2, "recovery can be disabled")

config.filesystems = { "/" }
update()
check(#state.report.mounts == 1, "removed filesystems should leave the report")
check(findMount("/home") == nil, "unlisted filesystems should not be monitored")

config.filesystems = { "/", "/home", "/mnt/missing" }
stats["/home"].usagePercent = 97
update()
check(#errors == 3, "returning a filesystem should be treated as a new critical state")

config.poll_seconds = 60
onConfigChanged()
check(intervals[#intervals] == 60000, "config changes should update the poll interval")

-- Every configured path is monitored; root is not forced.
config.filesystems = { "/home" }
onConfigChanged()
check(findMount("/home") ~= nil, "configured filesystems should be monitored")
check(findMount("/") == nil, "root should be removed when it is not configured")

config.filesystems = { "/", "/home" }
onConfigChanged()
check(findMount("/") ~= nil, "root should be monitored when it is configured")

-- Labels are optional, trimmed, and attached to the report.
stats["/mnt/extra"] = {
  usagePercent = 20,
  totalBytes = 100 * gib,
  freeBytes = 80 * gib,
  availableBytes = 79 * gib,
}
stats["/home/kr/backups"] = {
  usagePercent = 10,
  totalBytes = 50 * gib,
  freeBytes = 45 * gib,
  availableBytes = 44 * gib,
}
stats["/mnt/data=archive"] = {
  usagePercent = 15,
  totalBytes = 80 * gib,
  freeBytes = 68 * gib,
  availableBytes = 67 * gib,
}
for _, path in ipairs({ "/mnt/space = name", [[/mnt/slash\=name]], [[/mnt/backslash\plain]] }) do
  stats[path] = {
    usagePercent = 15,
    totalBytes = 80 * gib,
    freeBytes = 68 * gib,
    availableBytes = 67 * gib,
  }
end
config.filesystems = {
  "  / =  Root  ",
  "/mnt/extra/ = ",
  "/mnt/extra",
  "~/backups = Backups",
  "/mnt/data=archive = Archive = 2026",
  [[/mnt/space \= name]],
  [[/mnt/slash\\=name = Slash]],
  [[/mnt/backslash\plain]],
  "relative/path",
}
onConfigChanged()
check(findMount("/").label == "Root", "labels should be trimmed and stored")
check(findMount("/mnt/extra") ~= nil, "trailing slashes should be normalized")
check(findMount("/mnt/extra").label == nil, "empty labels should be omitted")
check(findMount("/home/kr/backups").label == "Backups", "~ should expand in configured paths")
check(findMount("/mnt/data=archive") ~= nil, "equals signs in paths should be preserved")
check(findMount("/mnt/data=archive").label == "Archive = 2026", "labels may contain equals signs")
check(findMount("/mnt/space = name") ~= nil, "escaped separators should remain in the path")
check(findMount("/mnt/space = name").label == nil, "escaped separators should not create a label")
check(findMount([[/mnt/slash\=name]]).label == "Slash", "escaped backslashes should remain in the path")
check(findMount([[/mnt/backslash\plain]]) ~= nil, "backslashes before ordinary characters should remain in the path")
check(findMount("relative/path") == nil, "relative paths should be ignored")
check(#state.report.mounts == 7, "each configured path should appear once")

config.filesystems = { "/mnt/data=archive", [[/mnt/space \= name = Space]] }
onConfigChanged()
check(findMount("/mnt/data=archive").label == nil, "an unlabelled equals sign should remain part of the path")
check(findMount("/mnt/space = name").label == "Space", "a label should follow an escaped separator in a path")

-- An empty list means nothing is monitored.
config.filesystems = {}
onConfigChanged()
check(#state.report.mounts == 0, "an empty filesystem list should publish no mounts")

local infoCount = #notifications
local errorCount = #errors
onIpc("simulate", "warning")
check(#notifications == infoCount + 1, "preview should show the warning")
check(notifications[#notifications].title == "alert.warning.title", "preview warning title")
onIpc("simulate", "critical")
check(#errors == errorCount + 1, "preview should show the critical error")
check(errors[#errors].title == "alert.critical.title", "preview critical title")
onIpc("simulate", "recovered")
check(#notifications == infoCount + 2, "preview should show recovery even when disabled")
check(notifications[#notifications].title == "alert.recovered.title", "preview recovery title")
onIpc("simulate", "all")
check(#notifications == infoCount + 4, "preview all should show both informational alerts")
check(#errors == errorCount + 2, "preview all should show the critical alert")
onIpc("simulate", "unknown")
check(#notifications == infoCount + 4 and #errors == errorCount + 2, "unknown preview should do nothing")

print("service: checks passed")
