#!/usr/bin/env nu

# Look up current time in any timezone using the Time.now API.
# nu-lint-ignore: print_and_return_data
def world-time [
    query?: string              # City, region, or IANA timezone (e.g., "tokyo", "Europe/Paris")
    --force-cache (-f)          # Force refresh of cached timezone list
    --raw (-r)                  # Output raw record for automation
    --list (-l)                 # List all available timezones
]: [
    nothing -> record           # Logic path for --raw
    nothing -> nothing          # Logic path for terminal display
] {
    # Handle --list flag
    if $list {
        let zones = get-timezone-list --force-refresh=$force_cache
        for zone in $zones { print $zone }
        return
    }

    # Require query if not listing
    if ($query | is-empty) {
        error make {
            msg: "Missing timezone query"
            label: {text: "No query provided", span: (metadata $query).span}
            help: "Usage: world-time tokyo  or  world-time \"Europe/London\""
        }
    }

    let zones = get-timezone-list --force-refresh=$force_cache
    let matched = if $raw {
        find-timezone $query $zones --raw
    } else {
        find-timezone $query $zones
    }

    let time_data = try {
        fetch-timezone-time $matched
    } catch {
        error make {
            msg: "Failed to fetch time data"
            label: {text: "Request failed for this timezone", span: (metadata $matched).span}
            help: "Check your internet connection or try again later."
        }
    }

    if $raw { $time_data } else { display-time $time_data }
}

# --- Helper Functions ---

def should-use-cache [
    config: record  # {cache_file: path, force_refresh: bool, cache_age: duration}
]: nothing -> bool {
    if $config.force_refresh {
        return false
    }
    
    if not ($config.cache_file | path exists) {
        return false
    }
    
    let cache_modified = try { ls $config.cache_file | get modified | first } catch { date now }
    let now = date now
    let age_duration = $now - $cache_modified
    $age_duration < $config.cache_age
}

# nu-lint-ignore: dont_mix_different_effects
def fetch-zones-with-fallback [
    cache_file: path
]: nothing -> list<string> {
    let zones = try {
        http get --max-time 10sec https://time.now/developer/api/timezone
    } catch {
        # If fetch fails and we have stale cache, use it
        if ($cache_file | path exists) {
            print $"(ansi yellow_italic)Warning: Using stale timezone cache \(offline mode\)(ansi reset)"
            return (try { open $cache_file } catch { 
                error make {
                    msg: "Network unreachable and cache corrupted"
                    label: {
                        text: "Cache file invalid"
                        span: (metadata $cache_file).span
                    }
                    help: "Cannot fetch timezone list and local cache is invalid."
                }
            })
        }
        
        error make {
            msg: "Network unreachable"
            label: {
                text: "Network request failed"
                span: (metadata $cache_file).span
            }
            help: "Cannot fetch timezone list. Check your internet connection."
        }
    }

    # Cache the result
    try {
        $zones | save --force $cache_file
    } catch {
        # Non-fatal if cache save fails
    }
    $zones
}

def get-timezone-list [
    --force-refresh
]: nothing -> list<string> {
    let cache_file = $"($nu.cache-dir)/time-now-zones.json"
    let cache_age = 180day  # Biannual refresh - TZ names rarely change

    let config = {
        cache_file: $cache_file,
        force_refresh: $force_refresh,
        cache_age: $cache_age
    }

    if (should-use-cache $config) {
        try {
            return (open $cache_file)
        } catch {
            # Cache file corrupted, fall through to fetch
        }
    }
    
    fetch-zones-with-fallback $cache_file
}

def score-timezone-matches [
    ctx: record
]: list<string> -> list<record> {
    each {|z|
        let full_dist = ($z | str downcase | str distance $ctx.query_lower)
        let loc_name = ($z | split row / | last | str downcase)
        let loc_dist = ($loc_name | str distance $ctx.query_lower)
        let min_dist = if $full_dist < $loc_dist { $full_dist } else { $loc_dist }
        
        let is_loc_prefix = ($loc_name | str starts-with $ctx.query_lower)
        let is_substring = ($z =~ ('(?i)' + $ctx.escaped))
        let is_subseq = ($z =~ ('(?i)' + $ctx.fuzzy_pattern))
        
        # Scoring: Give massive distance reductions for high-quality matches
        let final_dist = if $is_loc_prefix {
            $min_dist - 300
        } else if $is_substring {
            $min_dist - 200
        } else if $is_subseq {
            $min_dist - 100
        } else {
            $min_dist
        }
        
        {zone: $z, dist: $final_dist}
    } | sort-by dist
}

# nu-lint-ignore: list_param_to_variadic, max_function_body_length
def find-timezone [query: string, zones: list<string>, --raw]: nothing -> string {
    let query_lower = ($query | str downcase)
    # Escape regex metacharacters in query for safe matching
    let escaped = ($query | str replace --all --regex "([\\[\\]\\(\\)\\*\\+\\?\\^\\$\\.\\|\\\\])" \$1)

    # 1. Try exact match first (case-insensitive)
    let exact = $zones | where $it =~ ('(?i)^' + $escaped + '$')
    if ($exact | is-not-empty) {
        return ($exact | first)
    }

    # 2. Fuzzy match: combine subsequence (abbreviation) and Levenshtein distance (typos)
    let fuzzy_pattern = ($query | split chars | where $it != "" | each {|c| 
        $c | str replace --all --regex "([\\[\\]\\(\\)\\*\\+\\?\\^\\$\\.\\|\\\\])" \$1 
    } | str join ".*")
    
    let ctx = {
        query_lower: $query_lower,
        escaped: $escaped,
        fuzzy_pattern: $fuzzy_pattern
    }
    let scored_zones = ($zones | score-timezone-matches $ctx)

    let best_match = $scored_zones | first
    
    # Allow reasonable typo distance: Length/2 + 2. Valid subsequence/substring matches easily pass (dist < 0).
    let max_allowed_dist = (($query | str length) / 2 | math floor) + 2
    
    if $best_match.dist > $max_allowed_dist {
        error make {
            msg: $"No timezone found matching '($query)'"
            label: {
                text: "Invalid timezone query"
                span: (metadata $query).span
            }
            help: "Try: world-time --list  to see all available timezones"
        }
    }

    # Show alternatives for ambiguous matches (within reasonable point range)
    let margin = if $best_match.dist < 0 { 15 } else { 2 }
    let close_matches = $scored_zones | where dist <= ($best_match.dist + $margin) | get zone

    if not $raw {
        if ($close_matches | length) > 1 {
            print $"(ansi yellow_italic)Multiple fuzzy matches found. Using: ($best_match.zone)(ansi reset)"
            let other_options = $close_matches | skip 1 | take 5 | str join ', '
            print $"(ansi dark_gray)Other options: ($other_options)(ansi reset)\n"
        } else if $best_match.dist >= 0 {
            print $"(ansi yellow_italic)Typo corrected. Using: ($best_match.zone)(ansi reset)\n"
        }
    }

    $best_match.zone
}

def fetch-timezone-time [
    timezone: string
]: nothing -> record {
    # The API accepts the timezone identifier directly, even if it has no slashes (e.g., 'Zulu', 'Poland')
    # or multiple slashes (e.g., 'America/Indiana/Indianapolis').

    try {
        http get --max-time 5sec $"https://time.now/developer/api/timezone/($timezone)"
    } catch {
        error make {
            msg: "Failed to fetch timezone data"
            label: {
                text: "API request failed"
                span: (metadata $timezone).span
            }
            help: "Check your internet connection or verify the timezone exists."
        }
    }
}

def display-time [
    data: record
]: nothing -> nothing {
    # Create the clickable link using the correct 'antml:link' syntax
    let header_link = ("https://time.now" | ansi link --text "World Time API by Time.Now")

    # Extract data defensively
    let timezone = $data.timezone? | default Unknown
    let datetime = $data.datetime? | default "" | into datetime
    let utc_offset = $data.utc_offset? | default +00:00
    let abbreviation = $data.abbreviation? | default ""
    let dst = $data.dst? | default false
    let day_of_week_num = $data.day_of_week? | default 0
    let week_num = $data.week_number? | default 0

    # Format day of week
    let days = [Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
    let day_of_week = $days | get --optional $day_of_week_num | default Unknown

    # Format time and date
    let time = $datetime | format date %H:%M:%S
    let date = $datetime | format date %Y-%m-%d
    
    # DST indicator
    let dst_status = if $dst {
        $"(ansi green)Active(ansi reset)"
    } else {
        $"(ansi dark_gray)Inactive(ansi reset)"
    }

    print $"
(ansi blue_bold)--- ($header_link) ---(ansi reset)
Timezone:    ($timezone) \(($abbreviation)\)
Time:        (ansi green_bold)($time)(ansi reset)
Date:        ($date)
Day:         ($day_of_week) \(Week ($week_num)\)
UTC Offset:  ($utc_offset)
DST:         ($dst_status)
"
}
