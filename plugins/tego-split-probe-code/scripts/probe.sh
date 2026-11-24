#!/bin/sh
# tego-split-probe-code: on each hook event, log where this plugin finds the key
# that the separate tego-split-probe-config plugin holds.
#   sibling  the config plugin's tego.env, read from a folder next to this plugin
#   dropped  the copy the config plugin's SessionStart hook left under $HOME
# No network. Fake key only. Always exits 0.
exec >/dev/null 2>&1
in=$(cat)
ev=$(printf '%s' "$in" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
key() { sed -n 's/^TEGO_HOOK_API_KEY=//p' "$1" 2>/dev/null | head -1; }

# Layouts tried: org-synced (<dir>/<plugin>[~gN]/) and the marketplace cache
# (cache/<marketplace>/<plugin>/<version>/). An unmatched glob stays literal.
# Every match is logged, so stale copies of the config plugin show up too.
sibling=""
for f in "$root"/../tego-split-probe-config*/tego.env \
  "$root"/../../../*/tego-split-probe-config*/*/tego.env; do
  [ -r "$f" ] && sibling="$sibling $(key "$f")@$f"
done

# Hooks of one event run in parallel, so on SessionStart the copy may not be
# there yet: wait up to 3 s and log how long it took (waited x 0.2 s).
drop="$HOME/.tego-split-probe/env"
dropped=$(key "$drop")
waited=0
if [ "$ev" = SessionStart ]; then
  while [ -z "$dropped" ] && [ "$waited" -lt 15 ]; do
    sleep 0.2
    dropped=$(key "$drop")
    waited=$((waited + 1))
  done
fi

line="$(date +%H:%M:%S) code_ver=0.0.1 ev=$ev entry=${CLAUDE_CODE_ENTRYPOINT:-} sibling=[${sibling# }] dropped=${dropped:-none} waited=$waited root=$root next_to_me=[$(ls -a "$root/.." 2>/dev/null | tr '\n' ' ')]"
for log in /tmp/tego-split-probe.log "$HOME/tego-split-probe.log"; do printf '%s\n' "$line" >> "$log"; done
exit 0
