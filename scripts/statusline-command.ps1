<#
.SYNOPSIS
Claude Code statusLine command - monochrome grey one-liner: model, dir, branch, a context
fill bar, tokens remaining, and session cost.

.DESCRIPTION
Reads session state JSON from stdin (provided by Claude Code's statusLine hook) and emits
a grey status line:
  [model] dir (branch) <mark> <bar> NN% | NNNk left | $cost

Everything is grey. The only contrast is the bar: a lighter-grey fill on a darker-grey
track so the fill stays visible.

Fields:
  [model]    model.display_name (e.g. "Opus 4.8")
  dir        full path of workspace.current_dir
  (branch)   git branch, truncated to 24 chars with an ellipsis
  <mark>     check = clean working tree; dot = uncommitted changes (state shown by glyph)
  <bar> NN%  context-usage fill bar, eighth-block sub-cell precision on a solid track
  NNNk left  tokens remaining (context_window_size - total_input_tokens)
  $cost      session spend so far (cost.total_cost_usd), shown as $N.NN

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
$esc      = [char]27
$reset    = "$esc[0m"
$grey     = "$esc[38;5;245m"   # all text
$grey_fill= "$esc[38;5;250m"   # bar fill (lighter, so it pops against the track)
$track_bg = "$esc[48;5;238m"   # dim grey background = the empty track

$input_json = $input | Out-String

$data = $null
try { $data = $input_json | ConvertFrom-Json } catch { }

# --- Model ---
$model_str = "Claude"
if ($data -and $data.model -and $data.model.display_name) {
    $model_str = [string]$data.model.display_name
}

# --- Directory full path ---
$dir_str = "?"
if ($data -and $data.workspace -and $data.workspace.current_dir) {
    $dir_str = [string]$data.workspace.current_dir
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
# Fill bar with sub-cell (eighth-block) precision on a solid track. Lighter-grey fill on a
# darker-grey track is the only contrast; the partial leading-edge cell blends in (no gap).
$bar_width = 10
if ($null -ne $used_pct) {
    $pct = [Math]::Max(0, [Math]::Min(100, $used_pct))
    $eighths = [int][Math]::Round($pct / 100 * $bar_width * 8)
    $full    = [int][Math]::Floor($eighths / 8)
    $rem     = $eighths % 8
    $fill  = ([char]0x2588).ToString() * $full          # full (filled) cells
    $cells = $full
    if ($rem -gt 0) { $fill += ([char](0x2590 - $rem)).ToString(); $cells++ }  # partial edge: ink on track
    $fill += " " * ($bar_width - $cells)                 # empty cells: dark track shows through
    $bar = "${track_bg}${grey_fill}${fill}${reset}"
    $ctx_str = "$bar ${grey}${pct}%${reset}"
} else {
    $bar = "${track_bg}" + (" " * $bar_width) + "${reset}"
    $ctx_str = "$bar ${grey}?%${reset}"
}
$remaining_str = if ($null -ne $remaining_k) { "${remaining_k}k left" } else { "?k left" }

# --- Session cost (money spent so far) ---
$cost_str = $null
if ($data -and $data.cost -and ($null -ne $data.cost.total_cost_usd)) {
    $cost_str = '$' + ('{0:N2}' -f [double]$data.cost.total_cost_usd)
}

# --- Assemble (everything grey; clean/dirty shown by the marker glyph) ---
$branch_part = ""
if ($branch_str) {
    $mark = if ($dirty) { ([char]0x25CF) } else { ([char]0x2713) }
    $branch_part = " ${grey}(${branch_str}) ${mark}${reset}"
}

$cost_part = if ($cost_str) { " | ${grey}${cost_str}${reset}" } else { "" }

"${grey}[${model_str}] ${dir_str}${reset}${branch_part} ${ctx_str} ${grey}| ${remaining_str}${reset}${cost_part}"
