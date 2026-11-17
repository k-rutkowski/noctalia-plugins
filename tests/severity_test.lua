local Severity = dofile("spacewatch/lib/severity.luau")

local checks = 0

local function eq(actual, expected, message)
  checks = checks + 1
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
  end
end

local warning, critical = Severity.normalizeThresholds(85, 95)
eq(warning, 85, "default warning")
eq(critical, 95, "default critical")

warning, critical = Severity.normalizeThresholds(nil, nil)
eq(warning, 85, "nil warning falls back")
eq(critical, 95, "nil critical falls back")

warning, critical = Severity.normalizeThresholds(120, -5)
eq(warning, 100, "warning clamps high")
eq(critical, 100, "critical follows warning")

warning, critical = Severity.normalizeThresholds(90, 80)
eq(warning, 90, "warning kept")
eq(critical, 90, "critical clamps to warning")

eq(Severity.levelFor(84.9, 85, 95), 0, "below warning")
eq(Severity.levelFor(85, 85, 95), 1, "at warning")
eq(Severity.levelFor(94.9, 85, 95), 1, "below critical")
eq(Severity.levelFor(95, 85, 95), 2, "at critical")
eq(Severity.levelFor(100, 85, 95), 2, "above critical")

eq(Severity.announce(0, 1), "warning", "normal to warning")
eq(Severity.announce(1, 2), "critical", "warning to critical")
eq(Severity.announce(0, 2), "critical", "normal to critical")
eq(Severity.announce(2, 2), nil, "critical stays critical")
eq(Severity.announce(2, 1), nil, "critical down to warning is silent")
eq(Severity.announce(1, 0), "recovered", "warning to normal")
eq(Severity.announce(0, 0), nil, "normal stays normal")

eq(Severity.formatBytes(0), "0 B", "zero bytes")
eq(Severity.formatBytes(512), "512 B", "plain bytes")
eq(Severity.formatBytes(1024), "1.0 KiB", "one KiB")
eq(Severity.formatBytes(1024 * 1024 * 1024), "1.0 GiB", "one GiB")
eq(Severity.formatBytes(9.5 * 1024 * 1024 * 1024), "9.5 GiB", "fractional GiB")
eq(Severity.formatBytes(nil), "?", "missing bytes")

eq(Severity.formatPercent(85.4), "85", "round down")
eq(Severity.formatPercent(85.6), "86", "round up")
eq(Severity.formatPercent(-1), "0", "clamp low")
eq(Severity.formatPercent(120), "100", "clamp high")
eq(Severity.formatPercent(nil), "?", "missing percent")

print(string.format("severity: %d checks passed", checks))
