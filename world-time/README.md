# world-time.nu

Look up the current time in any timezone using the [Time.now API](https://time.now/developer/api). Fuzzy matching lets you type casual queries like "tokyo" instead of "Asia/Tokyo".

## Why this exists

Sometimes you just need to know "what time is it in London?" without opening a browser. This script gives you instant, terminal-based timezone lookups with smart caching.

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

### Using exact IANA timezone strings

```nushell
nu world-time.nu Europe/Paris
nu world-time.nu America/Los_Angeles
```

### As a shell command

Source it in your `config.nu`:

```nushell
source /path/to/world-time.nu
```

Then use it directly:

```nushell
world-time sydney
world-time "America/Chicago"
world-time berlin --raw
world-time tokyo -r
```

### List all available timezones

```nushell
world-time --list
# or with aliased command:
world-time -l
```

### Flags

| Flag | Alias | What it does |
| ---- | ----- | ------------ |
| `--list` | `-l` | Show all ~600 available IANA timezone strings |
| `--force-cache` | `-f` | Force refresh the cached timezone list (normally cached for 180 days) |
| `--raw` | `-r` | Return raw JSON record for scripting (no terminal formatting) |

### Scripting / automation

```nushell
# Get raw data for pipeline processing
let tokyo_time = (world-time tokyo --raw)
if ($tokyo_time.dst) {
    print "Tokyo is currently observing DST"
}

# Compare timezones
let utc_offset_tokyo = (world-time tokyo --raw | get utc_offset)
let utc_offset_london = (world-time london --raw | get utc_offset)
```

## How it works

1. **First run**: Fetches the complete list of ~600 IANA timezones from the Time.now API and caches it locally
2. **Fuzzy matching**: Your query (like "paris") is matched against the cached list to find "Europe/Paris"
3. **Time lookup**: Fetches current time data for the matched timezone
4. **Caching**: The timezone list is cached for 180 days in `$nu.cache-dir/time-now-zones.json`

### Fuzzy matching examples

```nushell
world-time tokyo       # → Asia/Tokyo
world-time reykjavik   # → Atlantic/Reykjavik
world-time new         # → Multiple matches, picks best (e.g., America/New_York)
world-time "ho chi"    # → Asia/Ho_Chi_Minh
```

If multiple timezones match your query, the script picks the shortest/most specific one and shows you the alternatives.

### Offline mode

If the network is unreachable but you have a stale cache, the script will warn you and use the cached timezone list. Time lookups still require internet access.

## Requirements

- [Nushell](https://www.nushell.sh/) — tested on recent stable versions
- Internet access to reach the Time.now API

## Complementary tool

This pairs well with `time-sync.nu` from the same repository:

- **time-sync.nu** — Check if your system clock is drifting
- **world-time.nu** — Look up times in other timezones

## Notes

- The timezone list is fetched from Time.now's `/timezone` endpoint and includes all valid IANA timezone identifiers
- Cache location: `$nu.cache-dir/time-now-zones.json`
- Cache lifetime: 180 days (biannual refresh - timezone names rarely change)
- The script uses defensive programming patterns (optional cellpaths, try-catch) so it won't crash on unexpected API responses

[World Time API by Time.Now](https://time.now)
