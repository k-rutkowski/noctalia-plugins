local severity = dofile("spacewatch/lib/severity.luau")
local realRequire = require
require = function(path)
  if path == "./lib/severity.luau" then
    return severity
  end
  return realRequire(path)
end

local gib = 1024 * 1024 * 1024
local state = {}
local watchers = {}
local interval = nil
local settingsOpened = false
local view = {}
local translations = {
  ["widget.capacity"] = "{free} free of {total}",
  ["widget.mount"] = "{path} {percent}%",
  ["widget.no_data"] = "--",
  ["widget.waiting"] = "Waiting for disk statistics.",
}

noctalia = {
  setUpdateInterval = function(ms)
    interval = ms
  end,
  state = {
    get = function(key)
      return state[key]
    end,
    watch = function(key, callback)
      watchers[key] = callback
    end,
  },
  tr = function(key, substitutions)
    local value = translations[key] or key
    for name, replacement in pairs(substitutions or {}) do
      value = value:gsub("{" .. name .. "}", tostring(replacement))
    end
    return value
  end,
  openSettings = function()
    settingsOpened = true
  end,
}

barWidget = {
  render = function(value)
    view.tree = value
  end,
  isVertical = function()
    return false
  end,
  setTooltip = function(value)
    view.tooltip = value
  end,
}

ui = {
  row = function(props, children)
    return { kind = "row", props = props, children = children }
  end,
  column = function(props, children)
    return { kind = "column", props = props, children = children }
  end,
  label = function(props)
    return { kind = "label", props = props }
  end,
  glyph = function(props)
    return { kind = "glyph", props = props }
  end,
}

state.report = {
  updatedAt = 1000,
  mounts = {
    {
      path = "/home",
      usagePercent = 96,
      level = 2,
      totalBytes = 200 * gib,
      freeBytes = 9 * gib,
      availableBytes = 8 * gib,
    },
    {
      path = "/",
      usagePercent = 50,
      level = 0,
      totalBytes = 500 * gib,
      freeBytes = 260 * gib,
      availableBytes = 250 * gib,
    },
  },
}

local chunk = assert(loadfile("spacewatch/widget.luau"))
chunk()

local function check(condition, message)
  if not condition then
    error(message, 2)
  end
end

check(interval == 60000, "widget should use a slow fallback refresh")
check(view.tree.kind == "row", "horizontal bar should render a row")
check(#view.tree.children == 3, "widget should show the glyph and every mount")
check(view.tree.children[1].props.name == "alert-triangle", "critical widget should use the alert glyph")
check(view.tree.children[1].props.color == "error", "critical glyph should use the error color")
check(view.tree.children[2].props.text == "/home 96%", "widget should show every mount's full path and usage")
check(view.tree.children[2].props.color == "error", "critical mount text should be red")
check(view.tree.children[3].props.text == "/ 50%", "healthy mounts should still be listed")
check(view.tree.children[3].props.color == "on_surface", "healthy mount text should keep the default color")
check(type(view.tooltip) == "table" and #view.tooltip == 2, "tooltip should list every mount")
check(view.tooltip[1].key == "/home", "tooltip should lead with the worst mount")
check(view.tooltip[1].value == "8.0 GiB free of 200.0 GiB", "tooltip should show free and total capacity")
check(not view.tooltip[1].value:find("%%"), "tooltip should not show a percentage")
check(view.tooltip[2].key == "/", "tooltip should list the next mount")

watchers.report({
  updatedAt = 2000,
  mounts = {
    {
      path = "/",
      usagePercent = 50,
      level = 0,
      totalBytes = 500 * gib,
      freeBytes = 260 * gib,
      availableBytes = 250 * gib,
    },
  },
})
check(view.tree.children[1].props.name == "database", "healthy widget should use the database glyph")
check(view.tree.children[1].props.color == "on_surface", "healthy glyph should use the default color")
check(view.tree.children[2].props.text == "/ 50%", "healthy widget should show its usage")
check(view.tree.children[2].props.color == "on_surface", "healthy widget should keep the default text color")

watchers.report({
  updatedAt = 3000,
  mounts = {
    {
      path = "/mnt/data",
      label = "Backups",
      usagePercent = 40,
      level = 0,
      totalBytes = 100 * gib,
      freeBytes = 60 * gib,
      availableBytes = 59 * gib,
    },
    {
      path = "/",
      label = "",
      usagePercent = 30,
      level = 0,
      totalBytes = 500 * gib,
      freeBytes = 350 * gib,
      availableBytes = 349 * gib,
    },
  },
})
check(view.tree.children[2].props.text == "Backups 40%", "labels should replace the path on the bar")
check(view.tree.children[3].props.text == "/ 30%", "empty labels should fall back to the path")

watchers.report(nil)
check(view.tree.children[1].props.name == "database", "empty state should keep the glyph")
check(view.tree.children[2].props.text == "--", "empty state should show the no-data text")
check(view.tooltip == "Waiting for disk statistics.", "empty state should explain the missing data")

onClick()
check(settingsOpened, "clicking should open plugin settings")

print("widget: checks passed")
