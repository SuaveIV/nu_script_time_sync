# world-time.nu

A script to look up the current time in any timezone using the [Time.now API](https://time.now/developer/api). It uses fuzzy matching, so you can just type "tokyo" instead of trying to remember if it's "Asia/Tokyo" or "Japan".

## Why I wrote this

I constantly need to know what time it is in other cities, and opening a browser or Googling it breaks my flow. I just wanted a fast timezone lookup right in the terminal that doesn't hit the network for things it already knows.

## Usage

### Basic lookup

```nushell
nu world-time.nu tokyo
nu world-time.nu london
nu world-time.nu "new york"
```

Output:

```sh
--- World Time API by Time.Now ---
Timezone:    Asia/Tokyo (JST)
Time:        23:15:42
Date:        2026-03-11
Day:         Wednesday (Week 11)
UTC Offset:  +09:00
DST:         Inactive
```

### Exact IANA timezones

```nushell
nu world-time.nu Europe/Paris
nu world-time.nu America/Los_Angeles
```

### Install as a command

Use it as a module in your `config.nu`:

```nushell
use /path/to/world-time.nu
```

Then you can drop the `.nu` and run it from anywhere:

```nushell
world-time sydney
world-time "America/Chicago"
world-time berlin --raw
world-time tokyo -r
```

### See all timezones

```nushell
world-time --list
# or with the alias:
world-time -l
```

### Flags

| Flag | Alias | What it does |
| ---- | ----- | ------------ |
| `--list` | `-l` | Prints all ~600 available IANA timezone strings |
| `--force-cache` | `-f` | Forces a refresh of the cached timezone list |
| `--raw` | `-r` | Returns a raw JSON record for scripting instead of formatted text |

### Scripting

```nushell
# Get raw data for a pipeline
let tokyo_time = (world-time tokyo --raw)
if ($tokyo_time.dst) {
    print "Tokyo is currently observing DST"
}

# Compare two timezones
let utc_offset_tokyo = (world-time tokyo --raw | get utc_offset)
let utc_offset_london = (world-time london --raw | get utc_offset)
```

## How it works

1. **First run**: Fetches the complete list of ~600 IANA timezones from the API and caches it locally.
2. **Matching**: Matches your query (like "paris") against the cached list to find the actual timezone ("Europe/Paris").
3. **Lookup**: Fetches the current time data for that specific timezone.
4. **Caching**: The timezone list gets cached for 180 days in `$nu.cache-dir/time-now-zones.json`.

### Fuzzy matching

```nushell
world-time tokyo       # → Asia/Tokyo
world-time reykjavik   # → Atlantic/Reykjavik
world-time new         # → Multiple matches, picks the best (e.g., America/New_York)
world-time "ho chi"    # → Asia/Ho_Chi_Minh
```

If multiple timezones match your query, the script picks the shortest one and prints the alternatives so you know what else matched.

### Offline fallback

If your network drops but you have a stale cache, the script prints a warning and uses the cached timezone list anyway. You still need internet access to actually fetch the current time, though.

## Requirements

- [Nushell](https://www.nushell.sh/)
- Internet access

## Related tool

This pairs well with `time-sync.nu` from the same repository:

- **time-sync.nu** — Check if your system clock is drifting
- **world-time.nu** — Look up times in other timezones

## Notes

- The timezone list comes from Time.now's `/timezone` endpoint.
- Cache location: `$nu.cache-dir/time-now-zones.json`.
- The cache lasts 180 days since timezone names rarely change.
- The script uses defensive parsing (`?` cell paths, try-catch blocks) so it won't crash if the API response changes.

[World Time API by Time.Now](https://time.now)
