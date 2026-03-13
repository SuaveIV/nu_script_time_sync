# time-sync.nu

A Nushell script to check if your system clock is drifting. It queries the [Time.now API](https://time.now/developer/api/ip), compares the result to your local time, and tells you if your clock is out of sync.

## Why I wrote this

System clocks drift. Most of the time NTP handles it, but when it fails (suspended VMs, weird service configs, air-gapped machines), it fails silently and messes up your logs. I wanted a quick sanity check without having to remember the flags for `timedatectl` or parse `ntpq` output.

## Usage

### Run it once

```nushell
nu time-sync.nu
```

### Install as a command

Use it as a module in your `config.nu` to use it anywhere:

```nushell
use /path/to/time-sync.nu
```

Then run it:

```nushell
time-sync
time-sync --max-offset 10sec
time-sync --raw
```

This prints a formatted report:

<img width="400" height="191" alt="image" src="https://github.com/user-attachments/assets/d2651d55-6c48-496d-a2ab-bc4ae45fa111" />

For a one-line summary, use `-1`:

<img width="532" height="65" alt="image" src="https://github.com/user-attachments/assets/7bac54e5-4288-4f86-b645-bf0ad2f4864f" />

### Flags

| Flag | Default | What it does |
| ------ | --------- | -------------- |
| `--max-offset` | `5sec` | Allowed drift before the clock is marked out of sync |
| `--max-rtt` | `2sec` | Network latency cutoff. Above this, the check is flagged as unreliable |
| `--one-line` `-1` | (none) | Single-line output: `IN SYNC  14:32:07 → 14:32:07  312ms` |
| `--raw` `-r` | (none) | Returns a raw record instead of text. Best for scripting. |

### Scripting

```nushell
time-sync --raw | if not $in.synced { print "Clock drift detected!" }
```

The `--raw` flag returns a record with these fields: `local`, `network`, `drift`, `rtt`, `synced`, `reliable`, `timezone`.

## How it works

1. Records the time before and after the API call to measure round-trip latency.
2. Pulls UTC time from `https://time.now/developer/api/ip`.
3. Compares the network time to your local time.
4. Reports the drift, RTT, and sync status.

If the network is slow (RTT above `--max-rtt`), the script flags the result as unreliable. High latency inflates the apparent drift, so a slow API response doesn't actually mean your clock is wrong.

## Requirements

- [Nushell](https://www.nushell.sh/)
- Internet access

## Notes

- The script uses optional cell paths (`?`) to parse the API response. If the API changes its JSON shape slightly, the script shouldn't crash.
- Network errors surface as clean messages instead of raw Nu stack traces.

[World Time API by Time.Now](https://time.now)
