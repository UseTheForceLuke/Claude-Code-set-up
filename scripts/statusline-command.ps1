<#
.SYNOPSIS
Claude Code statusLine command - prints "session-id | NN% ctx | NNNk left".

.DESCRIPTION
Reads session state JSON from stdin (provided by Claude Code's statusLine
hook) and emits a one-line status string suitable for display in the
terminal footer.

Output fields:
  session-id    Full UUID from the session_id field
  NN% ctx       Percent of context window used (rounded)
  NNNk left     Tokens remaining (rounded to thousands)

Fallback: "?% ctx | ?k left" if the JSON is malformed or missing fields.

.LINK
https://github.com/UseTheForceLuke/Claude-Code-set-up
#>

$ErrorActionPreference = "SilentlyContinue"

$input_json = $input | Out-String

$data = $null
try { $data = $input_json | ConvertFrom-Json } catch { }

# --- Session ID (full UUID) ---
$session_id = "--------"
if ($data -and $data.session_id) {
    $session_id = [string]$data.session_id
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
$ctx_pct_str   = if ($null -ne $used_pct)    { "${used_pct}% ctx" }     else { "?% ctx" }
$remaining_str = if ($null -ne $remaining_k) { "${remaining_k}k left" } else { "?k left" }

"$session_id | $ctx_pct_str | $remaining_str"
