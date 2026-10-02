#!/bin/bash
# Claude Code custom status line (2 lines):
#   1. model | project (branch) | ~LOC | context % + bar | api time | version | +/- lines
#   2. local time | Claude Max plan usage (5-hour and 7-day windows, with reset times)
# Requires: jq, git, curl, python3. Optional: tokei (LOC counter; omitted if missing).
# Plan usage uses your own local Claude Code OAuth token (~/.claude/.credentials.json)
# and queries api.anthropic.com only; it is never sent anywhere else.
set -f              # Prevent glob expansion on filenames in variables
export LC_NUMERIC=C # Ensure awk/printf use '.' as decimal separator

# Read JSON input from stdin
input=$(cat)

# Extract display values
model=$(echo "$input" | jq -r '.model.display_name')
project=$(echo "$input" | jq -r '.workspace.project_dir | split("/") | last')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')

# Resolve the git root of the current working directory (dynamic, for tokei)
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
git_root=$(git -C "${cwd:-$project_dir}" rev-parse --show-toplevel 2>/dev/null)
# Only count LOC inside a git repo; never fall back to a bare cwd (e.g. $HOME scans took 60 s CPU every minute)
[ -z "$git_root" ] && git_root=""

# Get git branch if in a git repo
git_branch=""
if [ -n "$git_root" ] && [ -d "$git_root" ]; then
    git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Count lines of code in project directory (cached for 10 min)
_loc_cache_dir="/tmp/claude-statusline/loc-cache"
mkdir -p "$_loc_cache_dir"
# Key cache file by git root path (replace / with _)
_loc_cache_key=$(echo "$git_root" | tr '/' '_')
_loc_cache_file="$_loc_cache_dir/${_loc_cache_key}.txt"
_loc_stamp_file="$_loc_cache_dir/${_loc_cache_key}.stamp"

loc_display=""
if [ -n "$git_root" ] && [ -d "$git_root" ]; then
    _do_loc_count=1
    if [ -f "$_loc_stamp_file" ]; then
        _loc_age=$(( $(date +%s) - $(stat -c %Y "$_loc_stamp_file" 2>/dev/null || echo 0) ))
        [ "$_loc_age" -lt 600 ] && _do_loc_count=0
    fi

    if [ "$_do_loc_count" -eq 1 ]; then
        _loc_raw=$(command -v tokei >/dev/null 2>&1 && tokei "$git_root" --output json 2>/dev/null \
            | python3 -c "import json,sys; d=json.load(sys.stdin); t=d.get('Total',{}); print(t.get('code',0)+t.get('comments',0))" 2>/dev/null)
        echo "${_loc_raw:-0}" > "$_loc_cache_file"
        touch "$_loc_stamp_file"
    fi

    _loc_total=$(cat "$_loc_cache_file" 2>/dev/null || echo 0)
    _loc_total=$(( _loc_total + 0 ))  # coerce to int

    if [ "$_loc_total" -ge 1000 ]; then
        _loc_k=$(awk "BEGIN{printf \"%.1f\", $_loc_total/1000}")
        loc_display="~${_loc_k}k loc"
    elif [ "$_loc_total" -gt 0 ]; then
        loc_display="~${_loc_total} loc"
    fi
fi

# Determine context used percentage
# Primary: use pre-calculated value from Claude Code
pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Fallback: calculate from current_usage tokens
if [ -z "$pct" ]; then
    window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
    input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
    cache_creation=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
    cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
    total=$(( input_tokens + cache_creation + cache_read ))
    pct=$(( total * 100 / window_size ))
fi

# Clamp to 0-100
[ "$pct" -lt 0 ] 2>/dev/null && pct=0
[ "$pct" -gt 100 ] 2>/dev/null && pct=100

# Create progress bar (20 characters wide)
bar_width=20
filled=$(( pct * bar_width / 100 ))
empty=$(( bar_width - filled ))
bar=$(printf "%${filled}s" | tr ' ' '#')$(printf "%${empty}s" | tr ' ' '-')

# Select percentage color based on thresholds
if [ "$pct" -ge 90 ]; then
    pct_color="\033[31m"       # Red
elif [ "$pct" -ge 70 ]; then
    pct_color="\033[38;5;208m" # Orange
else
    pct_color="\033[32m"       # Green
fi

# Extract token counts for display
token_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
token_cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
token_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
token_total=$(( token_input + token_cache_create + token_cache_read ))
token_max=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
token_used_k=$(( token_total / 1000 ))
token_max_k=$(( token_max / 1000 ))

# Extract API inference time
api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
api_section=""
if [ "$api_ms" -gt 0 ] 2>/dev/null; then
    api_s=$(( api_ms / 1000 ))
    if [ "$api_s" -ge 3600 ]; then
        api_h=$(( api_s / 3600 ))
        api_m=$(( (api_s % 3600) / 60 ))
        api_fmt="${api_h}h${api_m}m"
    elif [ "$api_s" -ge 60 ]; then
        api_m=$(( api_s / 60 ))
        api_rem=$(( api_s % 60 ))
        api_fmt="${api_m}m${api_rem}s"
    else
        api_fmt="${api_s}s"
    fi
    api_section=" | \033[37mapi:${api_fmt}\033[0m"
fi

# Extract Claude Code version
cc_version=$(echo "$input" | jq -r '.version // empty')
version_section=""
if [ -n "$cc_version" ]; then
    version_section=" | \033[90mv${cc_version}\033[0m"
fi

# Extract line diff stats from cost object
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Build diff stats suffix (omit entirely if both are 0)
diff_stats=""
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
    diff_stats=" |"
    [ "$lines_added" -gt 0 ] 2>/dev/null && diff_stats="$diff_stats \033[32m+${lines_added}\033[0m"
    [ "$lines_removed" -gt 0 ] 2>/dev/null && diff_stats="$diff_stats \033[31m-${lines_removed}\033[0m"
fi

# Build LOC section string (dark grey, only when available)
loc_section=""
[ -n "$loc_display" ] && loc_section=" | \033[90m${loc_display}\033[0m"

# Build and output line 1: model / project / context bar
if [ -n "$git_branch" ]; then
    printf "\033[36m%s\033[0m | \033[32m%s\033[0m \033[35m(%s)\033[0m${loc_section} | ${pct_color}%3d%% %dk/%dk\033[0m \033[34m[%s]\033[0m${api_section}${version_section}${diff_stats}\n" \
        "$model" "$project" "$git_branch" "$pct" "$token_used_k" "$token_max_k" "$bar"
else
    printf "\033[36m%s\033[0m | \033[32m%s\033[0m${loc_section} | ${pct_color}%3d%% %dk/%dk\033[0m \033[34m[%s]\033[0m${api_section}${version_section}${diff_stats}\n" \
        "$model" "$project" "$pct" "$token_used_k" "$token_max_k" "$bar"
fi

# ---------------------------------------------------------------------------
# Line 2: Claude Max plan usage (5-hour and 7-day limits)
# ---------------------------------------------------------------------------

# --- Helper: resolve OAuth token ---
get_oauth_token() {
    # 1. Environment variable override
    [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && echo "$CLAUDE_CODE_OAUTH_TOKEN" && return
    # 2. ~/.claude/.credentials.json
    local creds="$HOME/.claude/.credentials.json"
    if [ -f "$creds" ]; then
        local tok
        tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
        [ -n "$tok" ] && echo "$tok" && return
    fi
    # 3. GNOME Keyring fallback
    timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
}

# --- Helper: color for a utilization percentage ---
# $1 = utilization value  $2 = type ("5h" or "7d")
# Echoes an ANSI escape sequence string (no reset included)
usage_color() {
    local u="$1"
    local type="$2"
    if awk "BEGIN{exit !($u >= 100)}"; then
        printf '\033[31m'        # Red  (>= 100%)
    elif [ "$type" = "7d" ]; then
        # Tighter thresholds for 7-day window
        if awk "BEGIN{exit !($u >= 75)}"; then
            printf '\033[31m'        # Red  (>= 75%)
        elif awk "BEGIN{exit !($u >= 50)}"; then
            printf '\033[38;5;208m'  # Orange (>= 50%)
        else
            printf '\033[32m'        # Green (< 50%)
        fi
    else
        # 5h thresholds
        if awk "BEGIN{exit !($u >= 90)}"; then
            printf '\033[31m'        # Red  (>= 90%)
        elif awk "BEGIN{exit !($u >= 70)}"; then
            printf '\033[38;5;208m'  # Orange (>= 70%)
        else
            printf '\033[32m'        # Green (< 70%)
        fi
    fi
}

# --- Helper: format a reset timestamp into a display string ---
# $1 = ISO-8601 timestamp  $2 = utilization value
# If utilization >= 100 → "resets in Xh Ym" countdown
# If reset is within 24 h → "HH:MM <tz>"
# Otherwise            → "DayName HH:MM <tz>"
format_reset() {
    local resets_at="$1"
    local util="$2"
    local now_s reset_s diff_s

    local tz_label
    tz_label=$(date +%Z)
    now_s=$(date -u +%s 2>/dev/null) || { echo "?"; return; }
    reset_s=$(date -d "$resets_at" +%s 2>/dev/null) || { echo "?"; return; }
    diff_s=$(( reset_s - now_s ))

    if awk "BEGIN{exit !($util >= 100)}"; then
        # Countdown mode
        if [ "$diff_s" -le 0 ]; then
            echo "soon"
        elif [ "$diff_s" -lt 60 ]; then
            echo "soon"
        elif [ "$diff_s" -lt 3600 ]; then
            echo "resets in $(( diff_s / 60 ))m"
        else
            local h=$(( diff_s / 3600 ))
            local m=$(( (diff_s % 3600) / 60 ))
            echo "resets in ${h}h ${m}m"
        fi
    elif [ "$diff_s" -le 86400 ]; then
        # Within next 24 hours: show time only
        date -d "$resets_at" +"→ %H:%M" 2>/dev/null || echo "?"
    else
        # Beyond 24 hours: show day + time
        date -d "$resets_at" +"→ %a %H:%M" 2>/dev/null || echo "?"
    fi
}

# --- Cache / lock infrastructure ---
_cache_dir="/tmp/claude-statusline"
_cache_file="$_cache_dir/usage-cache.json"
_attempt_stamp="$_cache_dir/fetch-attempt"
_ratelimited_file="$_cache_dir/ratelimited"
_lock_dir="$_cache_dir/fetch.lock"
mkdir -p "$_cache_dir"

# Default TTL between fetch attempts (seconds)
_ttl=60

# --- Step 1: load existing cache (may be stale — always prefer over silence) ---
_cached_body=""
[ -f "$_cache_file" ] && _cached_body=$(cat "$_cache_file" 2>/dev/null)

# --- Step 2: decide whether to attempt a fresh fetch ---
_do_fetch=1

# Time since last attempt
if [ -f "$_attempt_stamp" ]; then
    _last_attempt=$(stat -c %Y "$_attempt_stamp" 2>/dev/null || echo 0)
    _now=$(date +%s)
    _elapsed=$(( _now - _last_attempt ))
    if [ "$_elapsed" -lt "$_ttl" ]; then
        _do_fetch=0
    fi
fi

# Back-off if we were recently rate-limited
if [ "$_do_fetch" -eq 1 ] && [ -f "$_ratelimited_file" ]; then
    _rl_count=$(cat "$_ratelimited_file" 2>/dev/null || echo 1)
    _rl_count=$(( _rl_count + 0 ))  # coerce to int
    [ "$_rl_count" -lt 1 ] && _rl_count=1
    # backoff = 30 * 2^(count-1), capped at 300 s
    _backoff=$(awk "BEGIN{b=30*(2^($_rl_count-1)); print (b>300)?300:b}" 2>/dev/null || echo 60)
    if [ -f "$_attempt_stamp" ]; then
        _elapsed_rl=$(( $(date +%s) - $(stat -c %Y "$_attempt_stamp" 2>/dev/null || echo 0) ))
        if [ "$_elapsed_rl" -lt "$_backoff" ]; then
            _do_fetch=0
        fi
    fi
fi

# --- Step 3: acquire lock and fetch ---
if [ "$_do_fetch" -eq 1 ]; then
    # Remove stale lock (older than 30 s)
    if [ -d "$_lock_dir" ]; then
        _lock_age=$(( $(date +%s) - $(stat -c %Y "$_lock_dir" 2>/dev/null || echo 0) ))
        [ "$_lock_age" -gt 30 ] && rm -rf "$_lock_dir"
    fi

    if mkdir "$_lock_dir" 2>/dev/null; then
        # We hold the lock — proceed with fetch
        touch "$_attempt_stamp"

        _token=$(get_oauth_token)

        if [ -n "$_token" ]; then
            # Fetch usage; capture body and HTTP status on separate lines
            _response=$(curl -s -m 5 -w "\n%{http_code}" \
                -H "Authorization: Bearer $_token" \
                -H "anthropic-beta: oauth-2025-04-20" \
                "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

            _http_status=$(echo "$_response" | tail -n1)
            _body=$(echo "$_response" | head -n -1)

            if [ "$_http_status" = "200" ]; then
                echo "$_body" > "$_cache_file"
                rm -f "$_ratelimited_file"
                _cached_body="$_body"
            elif [ "$_http_status" = "429" ]; then
                # Increment rate-limit counter
                _prev_count=0
                [ -f "$_ratelimited_file" ] && _prev_count=$(cat "$_ratelimited_file" 2>/dev/null || echo 0)
                echo $(( _prev_count + 1 )) > "$_ratelimited_file"
            fi
            # Any other error: silently fall through to stale cache
        fi

        # Release lock
        rm -rf "$_lock_dir"
    fi
    # If lock acquisition failed, another tab is fetching — use stale cache
fi

# --- Step 4: render line 2 ---

if [ -z "$_cached_body" ]; then
    # No cache at all — check if we're rate-limited
    if [ -f "$_ratelimited_file" ]; then
        printf "\033[90m(plan limits unavailable)\033[0m"
    fi
    # Otherwise: silent fail — print nothing
else
    _five_util=$(echo "$_cached_body"  | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    _five_reset=$(echo "$_cached_body" | jq -r '.five_hour.resets_at   // empty' 2>/dev/null)
    _seven_util=$(echo "$_cached_body"  | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    _seven_reset=$(echo "$_cached_body" | jq -r '.seven_day.resets_at   // empty' 2>/dev/null)

    if [ -n "$_five_util" ] && [ -n "$_seven_util" ]; then
        # Round utilization to integer for display
        _five_pct=$(printf "%.0f" "$_five_util" 2>/dev/null || echo "${_five_util%%.*}")
        _seven_pct=$(printf "%.0f" "$_seven_util" 2>/dev/null || echo "${_seven_util%%.*}")

        # Build 5-hour segment
        _five_color=$(usage_color "$_five_util" "5h")
        _five_reset_str=$(format_reset "$_five_reset" "$_five_util")
        if awk "BEGIN{exit !($_five_util >= 100)}"; then
            _five_label="⚡ 5 Hour Usage:"
        else
            _five_label="5 Hour Usage:"
        fi

        # Build 7-day segment
        _seven_color=$(usage_color "$_seven_util" "7d")
        _seven_reset_str=$(format_reset "$_seven_reset" "$_seven_util")
        if awk "BEGIN{exit !($_seven_util >= 100)}"; then
            _seven_label="⚡ 7 Day Usage:"
        else
            _seven_label="7 Day Usage:"
        fi

        tz_city=$(cat /etc/timezone 2>/dev/null | awk -F'/' '{print $NF}' | tr '_' ' ')
        [ -z "$tz_city" ] && tz_city=$(date +%Z)

        printf "\033[35m%s\033[0m \033[90m%s %s\033[0m | \033[33m%s\033[0m ${_five_color}%s%% %s\033[0m  \033[90m|\033[0m  \033[33m%s\033[0m ${_seven_color}%s%% %s\033[0m" \
            "$tz_city" "$(date +%H:%M)" "$(date +"%a %d %b")" \
            "$_five_label" "$_five_pct" "$_five_reset_str" \
            "$_seven_label" "$_seven_pct" "$_seven_reset_str"
    fi
fi
