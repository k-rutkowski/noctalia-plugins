# Spacewatch

A bar widget and notification service that warn you before a disk fills up.

Spacewatch reads Noctalia's native disk statistics, watches the filesystems you
configure (`/` by default), and sends a notification when one crosses a warning
or critical usage threshold. The bar widget shows every monitored filesystem's
usage and can use a custom label per filesystem.

## Plugin

| Field | Value |
| --- | --- |
| ID | `k-rutkowski/spacewatch` |
| Entries | Service: `monitor`; bar widget: `status` |

The `monitor` service samples disk usage and sends alerts. The `status` widget
shows every monitored filesystem's usage in the bar and lists free and total
capacity in its tooltip.

## Features

- Monitors the filesystems you list; `/` is included by default.
- Shows filesystems in the configured order in both the bar and tooltip.
- Optional label per filesystem, shown in the bar instead of the path.
- Bar widget shows the full path (or label) and usage percentage of every
  monitored filesystem.
- Only critically full filesystems turn red in the bar; the rest keep the
  normal text color.
- Warning and critical notifications with configurable thresholds.
- Optional recovery notification when usage drops back below the warning level.
- Alerts fire when severity rises, not on every poll.
- Tooltip shows free and total capacity for each filesystem.
- Click the widget to open Spacewatch's settings.
- No external commands or packages: disk data comes from Noctalia's System
  Monitor.

## Requirements

- Noctalia v5 or newer.
- The System Monitor enabled in Noctalia (`[system.monitor] enabled = true`).
- Disk polling enabled (`disk_poll_seconds` must not be `0`).

Spacewatch samples the paths you configure with `noctalia.diskStats()`, so any
path the System Monitor can read works: physical mounts, network mounts, bind
mounts, or subdirectories. `/` is the default entry; remove it if you do not
want root monitored. Pseudo filesystems such as tmpfs, loop devices, and snap
packages are not probed automatically.

## Usage

Add the **Spacewatch** widget to a bar from Noctalia's widget picker. The
service starts with the plugin and works even without the widget.

## Settings

| Setting | Default | Description |
| --- | --- | --- |
| Warning threshold | `85` | Usage percentage that sends a warning notification. |
| Critical threshold | `95` | Usage percentage that sends a critical notification. |
| Check interval | `30` | Seconds between disk checks. |
| Notify on recovery | `true` | Notify when usage drops back below the warning threshold. |
| Filesystems | `/` | One path per entry, optionally followed by ` = label`. `/` is included by default and can be removed or changed. |

If the critical threshold is lower than the warning threshold, Spacewatch uses
the warning threshold for both levels.

Each filesystem entry is a path, optionally followed by ` = label` (with a
space on either side of `=`). An `=` without surrounding spaces remains part
of the path.
To include the exact separator ` = ` in a path, write `\=` instead of `=`;
write a literal backslash as `\\`. Labels can contain `=` without escaping.
For example, `/mnt/space \= name = Data` monitors `/mnt/space = name` and
displays `Data` in the bar. The settings editor accepts entries directly; in
TOML, single-quoted strings avoid having to double-escape backslashes:

```toml
[plugin_settings."k-rutkowski/spacewatch"]
filesystems = [ '/', '/mnt/data=archive', '/mnt/space \= name = Data' ]
```

If you used the previous separate `filesystem_labels` setting, move each label
into its matching `filesystems` entry using the ` = label` format.

## Local development

Link the plugin into Noctalia's local plugin directory:

```sh
mkdir -p ~/.local/share/noctalia/plugins
ln -sfn "$PWD" ~/.local/share/noctalia/plugins/spacewatch
noctalia msg plugins enable k-rutkowski/spacewatch
```

Add the **Spacewatch** widget to a bar from Noctalia's widget picker. Editing a
`.luau` file hot-reloads the plugin.

Force a check over IPC:

```sh
noctalia msg plugin k-rutkowski/spacewatch:monitor all refresh
```

Preview every notification style using synthetic usage; this does not change
your thresholds or monitor real filesystems:

```sh
noctalia msg plugin k-rutkowski/spacewatch:monitor all simulate all
```

Use `simulate warning`, `simulate critical`, or `simulate recovered` for one at
a time.

To test the alert path without filling a disk, temporarily lower the thresholds
below current usage, wait for the next check, then restore them.

## Tests

The pure helpers and entry scripts have a plain-Lua harness, so they can run
without Noctalia:

```sh
lua tests/severity_test.lua
lua tests/service_test.lua
lua tests/widget_test.lua
```

## License

WTFPL
