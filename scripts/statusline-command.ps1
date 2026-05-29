<#
.SYNOPSIS
Claude Code statusLine command - colorful one-liner with model, dir, git branch + dirty
state, and a context-usage fill bar.

.DESCRIPTION
Reads session state JSON from stdin (provided by Claude Code's statusLine hook) and emits
a colored status line:
  [model] dir (branch) <mark> <bar> NN% | NNNk left

Fields / colors:
  [model]    Magenta  - model.display_name (e.g. "Opus 4.8")
  dir        Cyan     - basename of workspace.current_dir
  (branch)   Green    - git branch, truncated to 24 chars with an ellipsis
  <mark>     Green check = clean working tree; Yellow dot = uncommitted changes
  <bar> NN%  Fill bar, eighth-block sub-cell precision; green <50%, yellow 50-79%, red >=80%
  NNNk left  Tokens remaining (context_window_size - total_input_tokens)

Notes:
  - Uses [char]27 for ESC ("`e" only works in PowerShell 6+; this host targets Windows PS 5.1).
  - Forces UTF-8 console output so the block glyphs are not mangled by the OEM code page.

Fallback: model defaults to "Claude" and the bar shows "?%" if JSON is malformed or missing.

.LINK
https://github.com/UseTheForceLuke/Claude-Code-set-up
#>

$ErrorActionPreference = "SilentlyContinue"

# Emit UTF-8 so the block characters in the context bar aren't mangled by the OEM code page.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# ANSI helpers ([char]27 = ESC; "`e" only works in PowerShell 6+, this host is 5.1)
$esc     = [char]27
$reset   = "$esc[0m"
$magenta = "$esc[35m"
$cyan    = "$esc[36m"
$green   = "$esc[32m"
$yellow  = "$esc[33m"
$red     = "$esc[31m"

$input_json = $input | Out-String

$data = $null
try { $data = $input_json | ConvertFrom-Json } catch { }

# --- Model ---
$model_str = "Claude"
if ($data -and $data.model -and $data.model.display_name) {
    $model_str = [string]$data.model.display_name
}

# --- Directory basename ---
$dir_str = "?"
if ($data -and $data.workspace -and $data.workspace.current_dir) {
    $dir_str = [System.IO.Path]::GetFileName([string]$data.workspace.current_dir)
    if (-not $dir_str) { $dir_str = [string]$data.workspace.current_dir }
}

# --- Git branch + dirty state (from cwd reported by Claude Code) ---
$branch_str = $null
$git_root   = $null
$repo_dir = $null
if ($data -and $data.workspace -and $data.workspace.current_dir) {
    $repo_dir = [string]$data.workspace.current_dir
}
if ($repo_dir -and (Test-Path "$repo_dir\.git" -ErrorAction SilentlyContinue)) {
    $git_root = $repo_dir
} elseif ($repo_dir) {
    # Walk up looking for .git
    $check = $repo_dir
    while ($check -and $check -ne [System.IO.Path]::GetPathRoot($check)) {
        if (Test-Path "$check\.git" -ErrorAction SilentlyContinue) { $git_root = $check; break }
        $check = [System.IO.Path]::GetDirectoryName($check)
    }
}
$dirty = $false
if ($git_root) {
    $branch_str = & git -C "$git_root" rev-parse --abbrev-ref HEAD 2>$null
    if (& git -C "$git_root" status --porcelain 2>$null) { $dirty = $true }
}

# Truncate long branch names (keeps type + ticket, trims the slug tail).
$branch_max = 24
if ($branch_str -and $branch_str.Length -gt $branch_max) {
    $branch_str = $branch_str.Substring(0, $branch_max - 1) + ([char]0x2026)  # ellipsis
}

# --- Context % + tokens remaining ---
$used_pct = $null; $remaining_k = $null
if ($data -and $data.context_window) {
    $ctx = $data.context_window
    if ($null -ne $ctx.used_percentage) { $used_pct = [Math]::Round([double]$ctx.used_percentage) }
    if ($ctx.context_window_size -and $null -ne $ctx.total_input_tokens) {
        $remaining_k = [Math]::Round(($ctx.context_window_size - $ctx.total_input_tokens) / 1000)
    }
}
# Build a fancy fill bar with sub-cell (eighth-block) precision for a smooth leading edge.
# Color: green < 50%, yellow 50-79%, red >= 80%.
$bar_width   = 10
$empty_block = ([char]0x2591).ToString()   # light shade
if ($null -ne $used_pct) {
    $pct = [Math]::Max(0, [Math]::Min(100, $used_pct))
    $eighths = [int][Math]::Round($pct / 100 * $bar_width * 8)
    $full    = [int][Math]::Floor($eighths / 8)
    $rem     = $eighths % 8
    $bar_color = if ($pct -ge 80) { $red } elseif ($pct -ge 50) { $yellow } else { $green }
    $fill  = ([char]0x2588).ToString() * $full       # full blocks
    $cells = $full
    if ($rem -gt 0) { $fill += ([char](0x2590 - $rem)).ToString(); $cells++ }  # partial leading edge
    $bar = "${bar_color}${fill}${reset}" + ($empty_block * ($bar_width - $cells))
    $ctx_str = "$bar ${pct}%"
} else {
    $ctx_str = ($empty_block * $bar_width) + " ?%"
}
$remaining_str = if ($null -ne $remaining_k) { "${remaining_k}k left" } else { "?k left" }

# --- Assemble ---
# Branch with a dirty/clean marker: yellow dot = uncommitted changes, green check = clean.
$branch_part = ""
if ($branch_str) {
    $mark = if ($dirty) { "${yellow}" + ([char]0x25CF) } else { "${green}" + ([char]0x2713) }
    $branch_part = " ${green}(${branch_str})${reset} ${mark}${reset}"
}

"${magenta}[${model_str}]${reset} ${cyan}${dir_str}${reset}${branch_part} ${ctx_str} | ${remaining_str}"
