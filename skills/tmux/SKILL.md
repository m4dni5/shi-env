---
name: tmux
description: "Collaborate with the user through their tmux workspace — observe panes, inject commands, extract text, coordinate long-running work. Invoke when you need to see what's happening in a pane, run something in tmux, capture output, or manage panes/windows/sessions."
user-invocable: true
---

# tmux — Agent Collaboration Reference

Drive the user's tmux workspace from the shell. This is about collaboration — seeing what they see, helping without disrupting, extracting what you need, coordinating work across panes.

## When to Use tmux

Use tmux when you need to:
- **See what the user is doing** — capture their pane output, check running processes
- **Send commands into their workspace** — run things they can see and interact with
- **Extract specific text** — search scrollback, copy regions, save to file
- **Coordinate long-running work** — watch builds, wait for completions, manage companion panes
- **Let the user observe** — they can attach and see what you're doing live

Don't use tmux when `terminal()` suffices — one-shot commands where you don't need the user to see the output or the process to persist across calls.

## Mental Model

```
Server → Session(s) → Window(s) → Pane(s)
```

- **Session**: named container (e.g. `0`, `dev`, `build`)
- **Window**: tab within a session, numbered 0, 1, 2...
- **Pane**: terminal split within a window, numbered 0, 1, 2...

Target format: `session:window.pane` (e.g. `0:1.0`, `dev:build.2`)

### Target Syntax — Prefer IDs

| Target | Means |
|--------|-------|
| `0` | Session `0`, current window, current pane |
| `0:1` | Session `0`, window 1, current pane |
| `0:1.0` | Session `0`, window 1, pane 0 — fully qualified |
| `%12` | Pane by unique ID — **preferred for anything you'll revisit** |
| `@5` | Window by unique ID |
| `$2` | Session by unique ID |
| `0:build` | Session `0`, window named `build` |

Indexes shift when panes/windows are closed. `%` IDs are stable for the life of the pane. Always prefer them.

## Debugging Other Sessions

When the user is in a different TTY or display manager session, you can inspect their terminal output through tmux. See `references/debugging-other-sessions.md` for the pattern (capture LightDM logs, diagnose login loops, etc.).

## Local Facts

These are specific to this machine. Re-verify if tmux config changes.

- **Version:** 3.5a
- **Prefix:** C-b (default, not remapped)
- **Config:** `~/.tmux.conf`
- **Mode keys:** vi (affects copy mode bindings)
- **History limit:** 10000 lines per pane
- **Mouse:** on
- **Plugins:** tmux-yank, tmux-logging, tmux-gruvbox
- **My pane:** check `$TMUX_PANE` — it's `%2` as of last check, but verify at runtime

### Knowing Who I Am

```bash
echo $TMUX_PANE                    # my pane ID (if running inside tmux)
tmux display-message -p '#{pane_id}'  # same, from tmux's perspective
```

Never target my own pane with send-keys unless intentionally feeding myself input.

---

## OBSERVE — See What's Happening

### Workspace Map

```bash
tmux list-sessions                                        # all sessions
tmux list-windows -a                                      # all windows, all sessions
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} [#{pane_current_command}] #{pane_current_path}'
```

The last one is your go-to — a full map of every pane: where it is, what's running, what directory.

### Quick Probes

Lightweight checks before doing a full capture:

```bash
tmux display-message -p -t %12 '#{pane_current_command}'   # what's running
tmux display-message -p -t %12 '#{pane_current_path}'      # working directory
tmux display-message -p -t %12 '#{pane_dead}'              # 1 if process exited
tmux display-message -p -t %12 '#{pane_width}x#{pane_height}'  # pane size
tmux display-message -p -t %12 '#{pane_in_mode}'           # 1 if in copy/choose mode
```

### Capture Pane Output

```bash
# Visible screen only
tmux capture-pane -p -t %12

# Last N lines of history + visible screen
tmux capture-pane -p -t %12 -S -500

# Everything in scrollback + visible
tmux capture-pane -p -t %12 -S - -E -

# Join wrapped lines — ALMOST ALWAYS USE THIS
tmux capture-pane -p -J -t %12 -S -500

# Include ANSI escape sequences (colors, formatting)
tmux capture-pane -p -J -t %12 -e

# Alternate screen (what vim/less/htop is showing)
tmux capture-pane -p -J -t %12 -a
```

**The `-J` flag is critical.** Without it, long lines wrap at the pane width, breaking mid-word. Any grep, pattern matching, or line-oriented parsing will fail on wrapped lines. Make `-J` your default.

**`-p` sends to stdout.** Without `-p`, capture goes to a tmux paste buffer — almost never what you want from a script.

### Alternate Screen Awareness

When the user is in vim, less, htop, etc., they're on the "alternate screen." `capture-pane` without `-a` shows the normal buffer (what was there before the app launched). With `-a`, you see what the app is displaying. If the user just quit vim and you need what they were editing, don't use `-a` — you want the normal buffer that reappears.

### Pane Size Matters

If the pane is narrow (say 80 cols), long lines wrap. Even `-J` can't fully undo that — the original line boundary is lost. Check `#{pane_width}` and account for it. For detached sessions, the default is 80x24 unless you set `-x`/`-y` on creation.

---

## ACT — Inject Commands

### Send Keys

```bash
# Run a command (Enter is a separate argument)
tmux send-keys -t %12 'ls -la' Enter

# Send Ctrl+C to interrupt
tmux send-keys -t %12 C-c

# Send literal text (no key-name interpretation)
tmux send-keys -t %12 -l 'text with $vars and the word Enter in it'

# Combine: paste literal text, then press Enter separately
tmux send-keys -t %12 -l 'echo "hello world"' Enter

# Special keys
tmux send-keys -t %12 C-c C-c     # double interrupt
tmux send-keys -t %12 C-d         # EOF
tmux send-keys -t %12 Escape      # escape key
tmux send-keys -t %12 C-l         # clear screen
```

**Rules:**
- `Enter` is a SEPARATE argument. `'echo hello\n'` does NOT work.
- `-l` (literal) sends characters exactly — no key-name lookup. Use it whenever the text might contain a substring that matches a key name (e.g. the word "Enter", "Space", "Tab" in code you're pasting).
- For pasting multi-line code, use `-l` for each line, then `Enter` between them.

### The Async Problem

`send-keys` returns immediately. The command has NOT finished. Strategies, from best to worst:

**1. wait-for (when you control both sides):**
```bash
tmux send-keys -t %12 'long_build; tmux wait-for -S build-done' Enter
tmux wait-for build-done          # blocks until signal fires
```

**2. Marker + poll (when you can inject a marker):**
```bash
MARKER="__DONE_$$__"
tmux send-keys -t %12 "long_command; echo $MARKER" Enter
while ! tmux capture-pane -p -J -t %12 -S -200 | grep -q "$MARKER"; do sleep 1; done
```

**3. pane_current_command poll (quick but unreliable for short commands):**
```bash
while [ "$(tmux display-message -p -t %12 '#{pane_current_command}')" != "bash" ]; do sleep 1; done
```

**4. Fixed sleep (last resort — fragile):**
```bash
tmux send-keys -t %12 'make -j8' Enter
sleep 10
tmux capture-pane -p -J -t %12 -S -100
```

Prefer wait-for when you control the command. Marker polling is the general-purpose fallback.

### Spawning

**New detached session:**
```bash
tmux new-session -d -s build -x 200 -y 50    # wide terminal for headless work
tmux new-session -d -s build -c /path/to/project
```

**New window in existing session:**
```bash
tmux new-window -t 0 -n logs                 # empty shell
tmux new-window -t 0 -n build 'make -j8'     # runs command; window closes on exit
```

**Split pane:**
```bash
tmux split-window -t %12 -h                   # new pane to the RIGHT
tmux split-window -t %12 -v                   # new pane BELOW
tmux split-window -t %12 -h -p 30             # new pane gets 30% of space
tmux split-window -t %12 -h -l 60             # new pane gets 60 columns
tmux split-window -t %12 -h -b                # new pane to the LEFT instead
```

The `-h`/`-v` naming is counterintuitive: `-h` means horizontal *separator* (panes side by side), `-v` means vertical *separator* (panes stacked). New pane goes right/below by default; `-b` flips it left/above.

**Companion pane pattern — work alongside the user without disrupting them:**
```bash
# Spawn a helper pane, capture its ID
tmux split-window -t %12 -h -p 30
HELPER=$(tmux display-message -p -t %12 '#{pane_id}')
# ... do work in $HELPER ...
# Clean up when done
tmux kill-pane -t $HELPER
```

### Killing

```bash
tmux kill-pane -t %12
tmux kill-window -t 0:2
tmux kill-session -t old_session
tmux kill-server                              # NUCLEAR — kills everything. Confirm first.
```

Always `tmux ls` before `kill-server` and confirm with the user.

---

## EXTRACT — Get Specific Text

### Copy Mode (Programmatic)

Drive copy mode with `send-keys -X` — enter copy mode, navigate, search, select, copy, exit. This is how you extract specific content without dumping the entire scrollback.

With vi mode keys (this machine's config):

```bash
# Enter copy mode
tmux send-keys -t %12 Enter
# (or: tmux copy-mode -t %12)

# Search backward for "error"
tmux send-keys -t %12 -X search-backward "error"

# Search forward
tmux send-keys -t %12 -X search-forward "TODO"

# Repeat last search
tmux send-keys -t %12 -X search-again

# Go to top of history
tmux send-keys -t %12 -X history-top

# Go to bottom (visible screen)
tmux send-keys -t %12 -X history-bottom

# Select line under cursor
tmux send-keys -t %12 -X select-line

# Begin/end selection (like vi visual mode)
tmux send-keys -t %12 -X begin-selection
# ... move cursor ...
# (cursor movement: send-keys -X cursor-up, cursor-down, cursor-left, cursor-right)

# Copy selection and exit copy mode
tmux send-keys -t %12 -X copy-selection-and-cancel

# Copy and pipe to a shell command (e.g., save to file)
tmux send-keys -t %12 -X copy-pipe-and-cancel 'cat > /tmp/selected.txt'

# Exit copy mode without copying
tmux send-keys -t %12 -X cancel
```

**Common pattern — search and extract matching lines:**
```bash
tmux copy-mode -t %12
tmux send-keys -t %12 -X search-backward "ERROR"
tmux send-keys -t %12 -X select-line
tmux send-keys -t %12 -X copy-pipe-and-cancel 'cat >> /tmp/errors.txt'
```

**Copy mode movement commands (vi-style):**
- `cursor-up`, `cursor-down`, `cursor-left`, `cursor-right`
- `halfpage-up` (C-u), `halfpage-down` (C-d)
- `page-up`, `page-down`
- `next-word`, `previous-word`, `next-word-end`
- `start-of-line`, `end-of-line`
- `jump-forward f`, `jump-backward F` — jump to character

### Buffers Pipeline

```bash
# Capture to buffer (no -p)
tmux capture-pane -t %12 -S -200

# Show most recent buffer
tmux show-buffer

# Save buffer to file
tmux save-buffer /tmp/pane-capture.txt

# List all buffers
tmux list-buffers

# Paste buffer into a pane
tmux paste-buffer -t %12

# Delete a buffer
tmux delete-buffer -b buffer0001
```

For most agent work, `capture-pane -p` direct to stdout is simpler. Buffers are useful when you need to paste into a pane or manage multiple captures.

### Full Scrollback to File

When you need everything — deep inspection, archiving, searching:

```bash
tmux capture-pane -p -J -t %12 -S - -E - > /tmp/pane-full.txt
```

Then read and search it with read_file/search_files.

---

## COORDINATE — Manage Workflows

### Wait-For Signals

Block until a signal fires — cleaner than polling:

```bash
# Side that runs the work:
tmux send-keys -t %12 'make -j8; tmux wait-for -S build-done' Enter

# Your side (blocks until signal):
tmux wait-for build-done

# Locking — prevent concurrent access:
tmux wait-for -L deploy-lock        # acquire lock (blocks if held)
tmux wait-for -U deploy-lock        # release lock
```

### Pipe Pane — Continuous Logging

Start a transcript of a pane's output to a file. Useful for monitoring long-running processes:

```bash
# Start logging
tmux pipe-pane -t %12 -o 'cat >> /tmp/pane-%s-%I-%P.log'

# Stop logging
tmux pipe-pane -t %12

# Tail the log from another terminal
tail -f /tmp/pane-0-0-0.log
```

`-o` means "only open if not already piping" — idempotent toggle. `%s`, `%I`, `%P` expand to session name, window index, pane index.

Does NOT persist across `respawn-pane` — re-enable after respawning.

### Synchronize Panes

Send the same input to all panes in a window. Useful for running a command across multiple SSH sessions:

```bash
tmux set-option -w -t 0:1 synchronize-panes on
tmux send-keys -t 0:1 'hostname' Enter     # goes to ALL panes in that window
tmux set-option -w -t 0:1 synchronize-panes off   # ALWAYS turn off when done
```

Leaving this on silently mangles later work. Always clean up.

### Respawn Dead Panes

When a pane's process exits and it's sitting dead:

```bash
tmux respawn-pane -t %12 -k 'new_command'   # -k kills any lingering process
tmux respawn-pane -t %12                     # re-runs the original command
```

### Join Pane — Merge Windows

Move a pane from one window into another:

```bash
tmux join-pane -s 0:3.0 -t %12 -h            # pull window 3, pane 0 next to me
tmux select-layout -t 0:2 even-horizontal     # rebalance after joining
```

**join-pane has no `-p` percentage flag.** Use `-l` for fixed size, or `select-layout` after to rebalance.

### Options On the Fly

```bash
# Check current value
tmux show -g history-limit
tmux show -w -t %12 remain-on-exit
tmux show -p -t %12 window-style

# Set options
tmux set -g history-limit 50000              # server-wide (new panes only)
tmux set -w -t %12 remain-on-exit on         # keep pane after process exits
tmux set -p -t %12 window-style bg=red       # pane-level

# Session vs window vs pane: -g = global, -w = window, -p = pane
```

### Environment Variables

```bash
# Set env for new processes in a session
tmux set-environment -t 0 NODE_ENV production

# Show session environment
tmux show-environment -t 0

# Remove from environment before starting new processes
tmux set-environment -t 0 -r DISPLAY
```

---

## COMMAND CHAINING AND QUOTING

### Semicolons — Command Sequences

Multiple tmux commands in one call, separated by `\;`:

```bash
tmux new-window -t 0 \; split-window -h -t 0:2
```

From the shell, semicolons MUST be escaped or quoted — the shell will otherwise interpret them as shell command separators:

```bash
# Any of these work:
tmux neww \; splitw
tmux neww ';' splitw
tmux neww "\\;" splitw

# WRONG — shell eats the semicolon:
tmux neww ; splitw
```

### Braces — Complex Arguments

Braces avoid double-escaping when passing tmux commands as arguments (to if-shell, bind-key, etc.):

```bash
# With braces — no escaping needed:
tmux bind-key r if-shell "true" {
    display "reloading..."
    source-file ~/.tmux.conf
}

# Without braces — escaping nightmare:
tmux bind-key r if-shell "true" "display 'reloading...'; source-file ~/.tmux.conf"
```

### if-shell / run-shell

Conditional and background execution within tmux:

```bash
# If pane is dead, respawn it
tmux if-shell -F '#{pane_dead}' 'respawn-pane -k' '' -t %12

# -F: treat first arg as format, not shell command (faster, no /bin/sh)
# -b: run in background (non-blocking)

# Run a shell command and display output
tmux run-shell 'uptime'
```

---

## GOTCHAS

1. **Always use `-t` explicitly.** Without it, tmux targets the "current" session/window/pane, which depends on context and may not be what you expect. From outside tmux, it's the most-recently-used — unpredictable.

2. **`send-keys` is async.** It returns before the command starts. Always pair with a wait strategy — wait-for, marker poll, or at minimum a sleep if nothing else works.

3. **`-J` on every capture.** Without `-J`, wrapped lines break at the pane boundary. Your grep will miss matches that span the wrap. This is the #1 capture-pane mistake.

4. **`-l` for any text containing key names.** `send-keys -t %12 'print("Enter pressed")' Enter` — the word "Enter" inside the string is fine because it's a single argument, but if you ever send code where a key name could be ambiguous, use `-l` for the text and `Enter` as a separate key argument.

5. **Double quoting through send-keys.** Your outer shell interprets quotes once, then the pane's shell interprets them again. When in doubt: `send-keys -l 'your text here'` to bypass the first interpretation, then `Enter` separately.

6. **Default size is 80x24** for detached sessions. Programs that adapt to terminal width (ripgrep, fzf, less -S) will format for 80 cols. Set `-x 200 -y 50` on `new-session -d` if you need wider output.

7. **Pane indexes shift.** After killing a pane, remaining panes may renumber. Use `%pane_id` — it's stable for the pane's lifetime.

8. **`-h` means horizontal separator, not horizontal split.** `-h` splits into left+right panes. `-v` splits into top+bottom. The naming describes the divider, not the layout.

9. **`pipe-pane` doesn't survive respawn.** If you `respawn-pane -k`, the pipe is gone. Re-enable it.

10. **`kill-session` without `-t` is dangerous.** From outside tmux it's usually harmless (no current session), but be defensive and always pass `-t`.

11. **Copy mode is per-pane.** You can't enter copy mode on a pane that's already in copy mode. Check `#{pane_in_mode}` first if unsure.

12. **Scrollback is capped at `history-limit`.** Default is 10000 on this machine (set in .tmux.conf). Content beyond that is gone. If you need more, set `history-limit` higher BEFORE running the command — it only affects new panes.

13. **`capture-pane -a` for alternate screen.** When the user is in vim/less/htop, the normal capture shows what was there before the app. Use `-a` to see what the app is displaying. But if the alternate screen doesn't exist, it errors — add `-q` to suppress: `capture-pane -p -J -a -q -t %12`. Always pair `-a -q` since you rarely know if the user is in an alternate-screen app.

14. **Sending keys to a pane in copy mode.** The keys go to copy mode, not the underlying shell. If you need to send to the shell, exit copy mode first: `send-keys -t %12 -X cancel`.

15. **Don't send-keys into your own pane.** If `$TMUX_PANE` is `%2`, `send-keys -t %2 'echo hello' Enter` will type that command into your own agent process's terminal. The user will see ghost typing. Always target a different pane, or use `terminal()` for commands you need to run yourself.

16. **`capture-pane -b` only works without `-p`.** With `-p`, output goes to stdout and `-b` is ignored. To capture into a named buffer: `tmux capture-pane -J -t %12 -S -200 -b mybuf` (no `-p`). Then `tmux show-buffer -b mybuf`.

17. **Named buffers persist until deleted.** Unlike auto-named buffers (subject to `buffer-limit`), explicitly named buffers created with `-b` are never auto-cleaned. Clean up with `tmux delete-buffer -b name` when done.

18. **Python f-strings eat `#{}`.** When using `execute_code` with tmux format variables like `#{pane_id}`, use string concatenation instead of f-strings: `"tmux display -t " + pane_id + " '#{pane_current_command}'"`. F-strings will try to interpret `#{}` as Python expressions.

---

## FORMAT VARIABLES — Quick Reference

The most useful variables for `display-message -p` and `-F` flags:

### Pane
```
#{pane_id}              # unique ID (%0, %1...) — use for targeting
#{pane_index}           # position in window (0, 1...)
#{pane_current_command} # running process name
#{pane_current_path}    # working directory
#{pane_pid}             # PID of first process
#{pane_width}           # columns
#{pane_height}          # rows
#{pane_dead}            # 1 if process exited
#{pane_dead_status}     # exit code
#{pane_in_mode}         # 1 if in copy/choose/customize mode
#{pane_title}           # pane title (set by application)
#{pane_start_command}   # command pane was started with
```

### Window
```
#{window_id}            # unique ID (@0, @1...)
#{window_index}         # position in session
#{window_name}          # window name
#{window_active}        # 1 if this is the active window
#{window_panes}         # number of panes
#{window_layout}        # layout description
```

### Session
```
#{session_name}         # session name
#{session_id}           # unique ID ($0, $1...)
#{session_windows}      # window count
#{session_attached}     # number of attached clients
```

### Format Operators (for advanced use)
```
#{?var,truthy,falsey}              # conditional
#{==:#{host},myhost}              # string equality → 1 or 0
#{e|+|:3,4}                        # arithmetic (3+4=7)
#{=5:longstring}                   # truncate to first 5 chars
#{=-5:longstring}                  # last 5 chars
#{t:#{window_activity}}            # timestamp to human-readable
#{b:#{pane_current_path}}          # basename
#{d:#{pane_current_path}}          # dirname
#{q:var}                           # shell-escape
#{S:format}                        # loop over sessions
#{W:format,active_format}          # loop over windows
```

---

## RECIPES

### See what the user is doing right now
```bash
# Quick: what's running in their active pane?
tmux display-message -p '#{pane_current_command} in #{pane_current_path}'

# Full: capture their screen
tmux capture-pane -p -J -t $(tmux display-message -p '#{pane_id}')
```

### Run a command the user can see, wait for it, capture result
```bash
MARKER="__DONE_$$__"
tmux send-keys -t %12 "your_command; echo $MARKER" Enter
while ! tmux capture-pane -p -J -t %12 -S -200 | grep -q "$MARKER"; do sleep 1; done
tmux capture-pane -p -J -t %12 -S -500 > /tmp/command-output.txt
```

### Spawn a build and watch it
```bash
tmux new-session -d -s build -x 200 -y 50 -c /path/to/project
tmux send-keys -t build 'make -j8 2>&1 | tee /tmp/build.log; tmux wait-for -S build-done' Enter
tmux wait-for build-done
# or check on it later:
tmux capture-pane -p -J -t build -S -100
```

### Search scrollback for errors and extract
```bash
tmux copy-mode -t %12
tmux send-keys -t %12 -X search-backward "ERROR"
tmux send-keys -t %12 -X select-line
tmux send-keys -t %12 -X copy-pipe-and-cancel 'cat >> /tmp/errors.txt'
```

### Run three things in parallel in one window
```bash
tmux new-session -d -s dev -x 220 -y 60 'nvim'
tmux split-window -t dev -h -p 50 'npm run dev'
tmux split-window -t dev:0.1 -v -p 50 'npm run test:watch'
```

### Reading service/systemctl output from a user's pane

When the user has a pane running sudo or systemctl, you can capture
that output directly — useful for diagnosing service failures, login
loops, or config errors without running the commands yourself:

```bash
# Find the pane running sudo/systemctl
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} [#{pane_current_command}]'
# Look for [sudo] or [systemctl] in the command column

# Capture its output (pane ID is stable, window index may shift)
tmux capture-pane -p -J -t %3 -S -100
```

**Pattern:** User says "check pane :1.1" → list panes → find the matching
`%ID` → capture with `-J -S -N`. Works for any long-running command the
user has visible in tmux.

### Check if a process is still running
```bash
tmux display-message -p -t %12 '#{pane_current_command}'
# Returns e.g. "cmake", "node", "python3". If "bash"/"zsh", the command finished.
```

### Open a companion pane, do work, clean up
```bash
tmux split-window -t %12 -h -p 30
HELPER=$(tmux list-panes -t %12 -F '#{pane_id}' | tail -1)
tmux send-keys -t $HELPER 'some_analysis_command' Enter
sleep 5
tmux capture-pane -p -J -t $HELPER -S -50
tmux kill-pane -t $HELPER
```
