# Debugging Other Sessions via tmux

When the user is logged into a different TTY or display manager session, you can inspect their terminal output through tmux without needing sudo or direct TTY access.

## Pattern: Capture LightDM / Display Manager Logs

If the user reports a login loop or display manager issue, they may have a tmux pane open with `sudo systemctl status lightdm` or a log viewer.

```bash
# Map all panes across all sessions
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} [#{pane_current_command}] #{pane_current_path}'

# Capture the relevant pane (e.g., a sudo/systemctl pane)
tmux capture-pane -p -J -t %3 -S -100

# The -J flag joins wrapped lines — always use it for grep/parsing
```

## Why This Works

- The user's TTY session has a tmux server running
- Agent terminal sessions share the same user namespace
- `tmux list-panes -a` shows ALL panes across all sessions
- No sudo needed — tmux IPC is user-scoped

## Common Scenarios

| Scenario | What to look for |
|----------|-----------------|
| Login loop | Pane running `sudo systemctl status lightdm` or tailing `/var/log/lightdm/lightdm.log` |
| Display issues | Pane with `startx` or `xinit` output |
| Audio problems | Pane with `wpctl status` or `pactl list` |
| Config errors | Pane editing the relevant config file |

## Gotcha

If the pane ID changes (user killed and reopened), re-run `list-panes -a` to find the new ID. Pane IDs (%N) are stable for the life of the pane but renumber after close.
