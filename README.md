# Spacewatch for Noctalia

Know when a disk is getting full—before it becomes a problem. **Spacewatch** adds a simple storage monitor to your Noctalia bar and notifies you when a filesystem is running low on space.

## What you get

- See the usage of every filesystem you choose to monitor, right in the bar.
- Get a warning when a filesystem reaches your chosen limit, and a stronger alert when it reaches the critical limit.
- See how much space is free and the total capacity by hovering over the widget.
- Choose the paths to watch. The root filesystem (`/`) is included by default, but you can remove or change it.
- Give a path a short label for the bar, or leave it unlabeled to show its full path.

Alerts are sent when a filesystem crosses a limit—not repeatedly every time Spacewatch checks it. You can also choose whether to be notified when it recovers.

## Install

You’ll need Noctalia v5 or newer, with its System Monitor and disk polling enabled.

1. Open **Settings → Plugins** in Noctalia.
2. Choose **Add source** and enter the URL of this GitHub repository.
3. Find **Spacewatch** in the plugin list and enable it.
4. Add the **Spacewatch** widget to your bar using the widget picker.

The monitor runs once the plugin is enabled. The bar widget is where you see the live usage; hover over it for free and total capacity.

## Make it yours

Open Spacewatch’s settings to adjust the warning and critical limits, how often it checks, and whether to notify you when space becomes available again. The defaults are **85%** for a warning, **95%** for critical, and **30 seconds** between checks.

In **Filesystems**, add one path per entry. To give it a shorter name in the bar, append ` = ` and a label:

```text
/
/boot
/mnt/data=archive = Storage
```

This shows `/`, `/boot`, and `Storage` in the bar. Without a label, Spacewatch shows the full path. A path can contain `=`; if it contains the exact sequence ` = `, write `\=` instead of `=` so it isn’t mistaken for a label separator. Write a literal backslash in a path as `\\`. The path must be available to Noctalia’s System Monitor.

## License

[WTFPL](LICENSE)
