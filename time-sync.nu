#!/usr/bin/env nu

# Check system time accuracy using the official Time.now API.
def time-sync [
    --max-offset: duration = 5sec  # Threshold for 'out of sync' status
    --max-rtt: duration = 2sec     # Maximum latency allowed for a reliable check
    --raw                          # Output raw record for automation
]: [
    nothing -> record   # Logic path for --raw
    nothing -> nothing  # Logic path for terminal display
] {
    let start_time = (date now)
    let network_data = fetch-network-time
    let end_time = (date now)

    let rtt = ($end_time - $start_time)

    # Defensive Programming: Handle potential nulls in typed flags
    let ctx = {
        rtt: $rtt,
        threshold: ($max_offset | default 5sec),
        rtt_limit: ($max_rtt | default 2sec)
    }

    let report = calculate-drift $network_data $ctx

    # Use if/else expression to satisfy multi-signature return paths
    if $raw {
        $report
    } else {
        display-report $report
    }
}

# --- Helper Functions ---

def fetch-network-time []: nothing -> record {
    let api = "https://time.now/developer/api/ip"
    try {
        http get --max-time 5sec $api
    } catch {
        error make {
            msg: "Network unreachable"
            label: {
                text: "Request failed here"
                span: (metadata $api).span
            }
            help: "Check your internet connection or the Time.now service status."
        }
    }
}

def calculate-drift [
    data: record,
    ctx: record
]: nothing -> record {
    let local = (date now)

    # Defensive Extraction with optional cellpath '?'
    let network = ($data.utc_datetime?
        | default ($data.datetime?)
        | default ($local | into string)
        | into datetime)

    let drift = ($network - $local | math abs)

    {
        local: $local,
        network: $network,
        drift: $drift,
        rtt: $ctx.rtt,
        synced: ($drift < $ctx.threshold),
        reliable: ($ctx.rtt < $ctx.rtt_limit),
        timezone: ($data.timezone? | default Unknown)
    }
}

def display-report [report: record]: nothing -> nothing {
    let status_color = if $report.synced { "green_bold" } else { "red_bold" }

    # Create the clickable link using the correct 'ansi link' syntax
    let header_link = ("https://time.now" | ansi link --text "World Time API by Time.Now")

    # Escape parentheses \( \) to prevent Nushell execution
    let reliability_note = if $report.reliable {
        $"(ansi green)Reliable \(Low Latency\)(ansi reset)"
    } else {
        $"(ansi yellow_italic)Unreliable \(High Latency: ($report.rtt)\)(ansi reset)"
    }

    print $"
(ansi $status_color)--- ($header_link) ---(ansi reset)
Status:      (if $report.synced { 'IN SYNC' } else { 'OUT OF SYNC' })
Reliability: ($reliability_note)
Timezone:    ($report.timezone)
Local:       ($report.local | format date %H:%M:%S)
Network:     ($report.network | format date %H:%M:%S)
Drift:       ($report.drift)
RTT:         ($report.rtt)
"
}
