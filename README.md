# time-sync.nu

A Nushell script that checks whether your system clock is drifting. It hits the [Time.now API](https://time.now/developer/api/ip), compares the result to your local time, and tells you if something's off.

## Why bother?

System clocks drift. NTP usually handles it, but sometimes it doesn't — suspended VMs, misconfigured services, air-gapped machines. This script gives you a quick sanity check without digging through `timedatectl` or `ntpq` output.

## Usage

### One-off

```nushell
nu time-sync.nu
```

### As a shell command

Source it in your `config.nu` to use `time-sync` as a regular command:

```nushell
source /path/to/time-sync.nu
```

Then just run it directly from anywhere:

```nushell
time-sync
time-sync --max-offset 10sec
time-sync --raw
```

That prints a human-readable report:

```sh
--- World Time API by Time.Now ---
Status:      IN SYNC
Reliability: Reliable (Low Latency)
Timezone:    America/New_York
Local:       14:32:07
Network:     14:32:07
Drift:       312ms
RTT:         204ms
```

### Flags

| Flag | Default | What it does |
| ------ | --------- | -------------- |
| `--max-offset` | `5sec` | How much drift is allowed before marking as out of sync |
| `--max-rtt` | `2sec` | Round-trip time cutoff — above this, the check is flagged as unreliable |
| `--one-line` `-1` | — | Compact single-line output: `IN SYNC  14:32:07 → 14:32:07  312ms` |
| `--raw` `-r` | — | Returns a raw record instead of printing. Useful for scripting. |

### Automation / piping

```nushell
time-sync --raw | if not $in.synced { print "Clock drift detected!" }
```

The `--raw` flag returns a record with these fields: `local`, `network`, `drift`, `rtt`, `synced`, `reliable`, `timezone`.

## How it works

1. Records the time before and after the API call to measure round-trip latency
2. Pulls UTC time from `https://time.now/developer/api/ip`
3. Compares network time to local time
4. Reports drift, RTT, and sync status

If the RTT is high (above `--max-rtt`), the result is flagged as unreliable — network delay inflates the apparent drift, so a slow response isn't necessarily meaningful.

## Requirements

- [Nushell](https://www.nushell.sh/) — tested on recent stable versions
- Internet access to reach the Time.now API

## Notes

- The script uses optional cell paths (`?`) when parsing the API response, so it won't crash if the response shape changes slightly
- Errors from the network call surface with a helpful message rather than a raw stack trace
