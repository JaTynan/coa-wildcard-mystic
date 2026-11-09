# Fits the pinned mod-ollama-chat module to the CoA core.
# Run by the build (step "Apply our patch scripts") from the workspace root, after the modules are checked out.
# Each part edits the source by exact anchor and throws if the anchor is gone, so a CoA or SQUID change that
# breaks a patch stops the build with the part's name instead of building something wrong. Listed in CHANGES.md.
$ErrorActionPreference = 'Stop'

# ---- Fit mod-ollama-chat to the CoA core (its WorldSession::IsHeadless is IsBot here)
Write-Host "Patch: Fit mod-ollama-chat to the CoA core (its WorldSession::IsHeadless is IsBot here)"
& {
$file = 'core/modules/mod-ollama-chat/src/mod-ollama-chat_world.cpp'
$text = Get-Content $file -Raw
if ($text -notmatch 'session->IsHeadless\(\)') { throw 'mod-ollama-chat changed: IsHeadless call not found' }
Set-Content $file ($text -replace 'session->IsHeadless\(\)', 'session->IsBot()') -NoNewline
}
