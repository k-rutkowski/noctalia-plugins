--!nonstrict
-- Spacewatch bar widget: shows every monitored filesystem in the bar and a
-- per-mount tooltip. Only critically full filesystems turn red. Clicking opens
-- the plugin's settings.

local severity = require("./lib/severity.luau")

local TEXT_COLOR = "on_surface"

local report = noctalia.state.get("report")

local function displayPath(path)
  local trimmed = path:gsub("/+$", "")
  if trimmed == "" then
    return "/"
  end
  return trimmed
end

local function mountName(mount)
  if type(mount.label) == "string" and mount.label ~= "" then
    return mount.label
  end
  return displayPath(mount.path)
end

local function isCritical(mount)
  return (tonumber(mount.level) or 0) >= 2
end

local function glyph(name, color)
  return ui.glyph({ name = name, color = color })
end

local function tree(children)
  if barWidget.isVertical() then
    return ui.column({ gap = 1, align = "center" }, children)
  end
  return ui.row({ gap = 9, align = "center" }, children)
end

local function render()
  if type(report) ~= "table" or type(report.mounts) ~= "table" or #report.mounts == 0 then
    barWidget.render(
      tree({
        glyph("database", TEXT_COLOR),
        ui.label({ text = noctalia.tr("widget.no_data"), color = TEXT_COLOR, maxLines = 1 }),
      })
    )
    barWidget.setTooltip(noctalia.tr("widget.waiting"))
    return
  end

  local critical = isCritical(report.mounts[1])

  local children = {
    critical and glyph("alert-triangle", "error") or glyph("database", TEXT_COLOR),
  }
  local rows = {}
  for _, mount in ipairs(report.mounts) do
    children[#children + 1] = ui.label({
      text = noctalia.tr("widget.mount", {
        path = mountName(mount),
        percent = severity.formatPercent(mount.usagePercent),
      }),
      color = isCritical(mount) and "error" or TEXT_COLOR,
      maxLines = 1,
    })
    rows[#rows + 1] = {
      key = mount.path,
      value = noctalia.tr("widget.capacity", {
        free = severity.formatBytes(mount.availableBytes or mount.freeBytes),
        total = severity.formatBytes(mount.totalBytes),
      }),
    }
  end

  barWidget.render(tree(children))
  barWidget.setTooltip(rows)
end

noctalia.setUpdateInterval(60000)

noctalia.state.watch("report", function(value)
  report = value
  render()
end)

render()

function update()
  render()
end

function onClick()
  noctalia.openSettings()
end
