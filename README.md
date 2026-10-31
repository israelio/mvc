# mvc

**Move or rename a folder without losing your Claude Code history.**

`mvc` is a drop-in replacement for `mv` (for directories) that also migrates the
state [Claude Code](https://claude.com/claude-code) keeps about that folder, so
`claude -c` and `claude -r` pick up right where you left off, from the new location.

```sh
mvc ~/work/old-name ~/work/new-name
cd ~/work/new-name && claude -c      # your conversation is still there
```

> If this saved you a lost session, please **⭐ star the repo**. It helps others find it.

---

## The problem

Claude Code ties every conversation to the **absolute path** of the folder you ran it in.
It stores your sessions under `~/.claude/projects/`, in a directory whose name is the
folder path with every non-alphanumeric character replaced by `-`:

```
/Users/me/work/my-app   →   ~/.claude/projects/-Users-me-work-my-app/
```

Each session file also records the `cwd` it ran in, and the same path is used as a key in
`~/.claude.json` (trust prompts, allowed tools, MCP servers) and in `~/.claude/history.jsonl`.

So when you run a plain `mv` or rename the folder in Finder or Explorer:

- `claude -c` finds **no conversation** (it looks up the new path, which has no history).
- `claude -r` doesn't list your old sessions.
- Folder trust, allowed tools and per-project MCP settings are **gone**, and you get asked again.
- Project memory stored with the sessions is orphaned under the old name.

Your history isn't deleted. It's stranded under the old path, and nothing tells you.
Fixing it by hand means renaming a mangled directory name, editing `cwd` in every session file,
and patching two other files. `mvc` does all of that for you.

## Install

```sh
git clone https://github.com/israelio/mvc.git mvc && cd mvc
./install.sh              # symlinks mvc into ~/.local/bin
./install.sh /some/bin    # or another directory
./install.sh --uninstall  # remove the symlink
```

Requires Python 3 (no other dependencies). Make sure the bin directory is on your `PATH`.
The symlink points at your clone, so keep the folder where it is (or re-run the installer).

## Usage

```sh
mvc [-v] [-n] [--history=merge|overwrite|abort] SRC DEST
```

- Same semantics as `mv`: if `DEST` is an existing directory, `SRC` is moved inside it.
- Silent on success, like `mv`. Errors go to stderr.
- `-v`, `--verbose`: show each step.
- `-n`, `--dry-run`: show what would change without changing anything (implies `-v`).
- `--history=merge|overwrite|abort`: what to do if the destination already has Claude history (see below).

```sh
$ mvc -v ~/work/old-name ~/work/new-name
/Users/me/work/old-name -> /Users/me/work/new-name
project: -Users-me-work-old-name -> -Users-me-work-new-name
~/.claude.json: 1 project entry
history.jsonl: updated
done. cd '/Users/me/work/new-name' && claude -c
```

## What it updates

| Location | Change |
|---|---|
| `~/.claude/projects/<encoded-path>/` | renamed to match the new path; `cwd` fields in session `.jsonl` files rewritten |
| `~/.claude.json` | `projects` keys remapped (trust, allowed tools, MCP settings) |
| `~/.claude/history.jsonl` | `project` fields rewritten |

- Sub-folders of `SRC` that have their own Claude projects are migrated too.
- Edited files get a one-time `*.mvc-bak` backup next to them.
- Paths are resolved through symlinks (e.g. `/var` → `/private/var` on macOS), matching how Claude records them.
- `CLAUDE_CONFIG_DIR` is honored.

## When the destination already has history

`mv` refuses to overwrite an existing folder, but Claude history can outlive a folder, for example if
you deleted a project and now reuse the name. If `DEST` already has Claude Code history, `mvc` checks
**before moving anything** and asks:

```
[m]erge both, [o]verwrite destination history, [a]bort?
```

| Choice | Result |
|---|---|
| **merge** | Both sets of sessions end up in the same project. Settings entries are combined. On a name clash, the existing destination copy wins and the source copy is left in place. |
| **overwrite** | The source history replaces the destination's. The old destination history is saved to `~/.claude/mvc-backups/`, not deleted. |
| **abort** | Nothing is moved or changed. |

Skip the prompt with `--history=merge|overwrite|abort`. With no terminal (scripts, CI) and no flag,
`mvc` aborts rather than guess. `-n` shows the conflict without prompting.

## Limitations

- Don't run it while a `claude` session is open in `SRC`.
- Old paths mentioned inside past conversation text and tool calls are left as-is (it's history).
- Project dirs are matched by the `cwd` recorded in their sessions, so a project with no sessions only matches by its encoded name.
- Claude Code's on-disk layout is not a public, stable API. If a future version changes it, `mvc` may need an update. Issues and PRs welcome.

## Contributing

Bug reports, ideas and pull requests are welcome. If you hit a Claude Code state file that
`mvc` doesn't migrate yet, please open an issue.

## License

[MIT](LICENSE). Free to use, modify and distribute.

---

If `mvc` helped you, **⭐ star the repo** and tell a friend who renames folders.
