# Agent usage archive (ccusage)

Statistics on how Claude Code and Codex are used, collected daily on the Mac and
archived locally. macOS only.

| | |
|---|---|
| Tool | [`ccusage`](https://github.com/ccusage/ccusage) from Homebrew (native binary, no Node) |
| Script | [`ansible/roles/desktop/files/agent-usage-snapshot`](../ansible/roles/desktop/files/agent-usage-snapshot) → `~/.local/bin/agent-usage-snapshot` |
| Install/schedule | [`ansible/roles/desktop/tasks/agent_usage.yml`](../ansible/roles/desktop/tasks/agent_usage.yml) |
| LaunchAgent | `~/Library/LaunchAgents/com.homelab.agent-usage.plist` (template: `ansible/roles/desktop/templates/`) |
| Archive | `~/.local/share/agent-usage/history.ndjson` |
| Weekly digest | `~/.local/share/agent-usage/reports/latest.md` (and `YYYY-Www.md`) |
| State | `~/.local/share/agent-usage/state.json` |
| Log | `~/Library/Logs/agent-usage.log` |

---

## Why an archive, not a report

Claude Code **deletes its own transcripts after 30 days** (`cleanupPeriodDays: 30` in
`~/.claude/settings.json`, which `~/.claude-personal` symlinks to). `ccusage` only reads what is on
disk, so it can never show more than roughly the last month of Claude usage. Anything a monthly or
yearly view needs has to be **saved before it disappears**.

So the job snapshots `ccusage`'s JSON into an append-only archive every day, and every report is
rendered *from the archive*, never from a fresh `ccusage` call.

Codex is different: its rollout files (`~/.codex/sessions`) show no pruning, so the Codex history goes
back to July 2026. Only the Claude side is retention-bounded.

## What runs, and when

- **Daily at 18:30 local time**, plus once whenever the agent is loaded (login / first install).
  A run missed while the Mac slept fires once on wake.
- Each run re-reads the **last 14 days** and upserts by `(profile, date)`. That is deliberately far
  inside the 30-day retention, so it never touches a partially-pruned day. Because the run is
  idempotent, a sleeping laptop, a missed fire, a vacation, or a manual re-run all self-heal; the
  schedule is not safety-critical. The only real deadline is that the archive must not go silent for
  more than ~30 days.
- **A profile with no rows in the archive is read in full**, not just 14 days: a fresh install, a newly
  added profile, a deleted archive, or a first run that partly failed all recover on their own. (An
  archive that was *truncated* but still has rows for a profile is not detected; run
  `agent-usage-snapshot --backfill` by hand.)
- **Sessions use a 35-day window**, longer than Claude's 30-day retention. `ccusage` *clips* a session to
  `--since` (a session that spans the window edge comes back with only its in-window part), so a shorter
  window would under-count long sessions. A profile with no session rows is read in full, so adding
  session archiving to an existing archive backfills it on the next run by itself.
- **Weekly digest is state-driven, not schedule-driven.** Whenever last full ISO week has no
  `reports/YYYY-Www.md`, one is rendered and a macOS notification shows the headline. A missed Monday
  simply appears on the next run.
- If the last successful snapshot is more than 20 days old, the next run warns loudly (log +
  notification): Claude data older than 30 days is already unrecoverable.

## Data sources

| Series | Read from | Notes |
|---|---|---|
| `claude-default` | `~/.claude` | default `claude` profile |
| `claude-personal` | `~/.claude-personal` | the `claude-personal` alias |
| `codex` | `~/.codex` | `~/.codex-personal/sessions` is a **symlink** to this, so one dir is enough |

Each is run as its own `ccusage claude|codex daily --json` (plus `... session --json` for the
per-session detail) with `CLAUDE_CONFIG_DIR` / `CODEX_HOME` set explicitly. This matters when running
`ccusage` by hand:

> `CLAUDE_CONFIG_DIR` **replaces** ccusage's default lookup. A shell started via the `claude-personal`
> alias has it set to `~/.claude-personal`, so a bare `ccusage` there silently misses `~/.claude`.
> Use `CLAUDE_CONFIG_DIR=$HOME/.claude,$HOME/.claude-personal ccusage ...` for a combined view.

Verified when this was built (2026-09-21): the two Claude profiles do not overlap (separate runs sum
exactly to the combined run), and ccusage de-duplicates the Codex symlink (both-dirs output is
byte-identical to one dir), so passing only `~/.codex` is a choice for clarity, not a workaround.

## Archive format

`history.ndjson`, one JSON object per line, sorted, keys sorted, so a re-run is byte-identical.

| `kind` | One row per | Use it for |
|---|---|---|
| `day` | profile × date | **Authoritative** totals and cost |
| `model` | profile × date × model | Token mix by model |
| `session` | profile × session | Anonymised per-session totals, for the digest's *Top sessions* |

Fields: `date`, `profile`, `agent`, `input`, `output`, `cacheCreate`, `cacheRead`, `reasoning`,
`total`, `cost`; `model` rows add `model` and `estimated`; `session` rows add `sid`, `hours` and `model`
(the dominant model).

- **Session rows** carry whole-session totals and are dated by the day the session **last ran**, so a
  session spanning several days is counted in full in that day's week. Weekly session cost therefore differs
  slightly from the daily totals; the digest labels it accordingly. `hours` is the wall-clock span from first
  to last activity (idle gaps included), and is `null` for Codex, which does not report a first activity.
- **`sid` is anonymous.** It is the first 10 hex characters of the SHA-256 of the session id: stable (the same
  session keeps the same `sid` in every run and every weekly digest) and not reversible without the original
  id. The session rows are built from a whitelist of numeric fields; `projectPath`, `directory` and
  `sessionFile` are never read.

- **Codex has no per-model cost** in ccusage's output, so Codex `model` rows have `cost: null`. Use `day`
  rows for cost.
- `estimated: true` marks a Codex model that ccusage priced with a *fallback* rate (not in its price
  table). Treat those costs as estimates of estimates.
- **No project names.** The job never uses `--instances`, so the archive contains aggregates only.
- **Upsert rules:** a re-run replaces the rows for each `(profile, date)` (day/model) or `(profile, sid)`
  (session) it sees; it **never deletes** a row ccusage no longer returns (that day or session was pruned at
  the source); and it **never lets a day's or a session's total shrink**, so a partially-pruned one cannot
  overwrite a complete one.

Costs are **API list-price estimates**, not what a subscription actually bills. Read them as a
relative measure of usage.

```bash
A=~/.local/share/agent-usage/history.ndjson

# Cost per month, per profile
jq -s 'map(select(.kind=="day")) | group_by([.date[0:7], .profile])
       | map({month: .[0].date[0:7], profile: .[0].profile, cost: (map(.cost)|add|.*100|round/100)})' "$A"

# Token mix by model, all time
jq -s 'map(select(.kind=="model")) | group_by(.model)
       | map({model: .[0].model, tokens: (map(.total)|add)}) | sort_by(-.tokens)' "$A"

# The ten most expensive sessions, all time
jq -s 'map(select(.kind=="session")) | sort_by(-.cost) | .[0:10]
       | map({sid, profile, date, cost: (.cost*100|round/100), hours, output})' "$A"
```

## The weekly digest

`reports/YYYY-Www.md`, rendered from the archive. Sections: *By profile*, *Model mix*, **Top sessions**,
*Cache and busiest day*, an 8-week *Trend*, and *Notes* (missing prices, skipped sources, warnings).

**Top sessions (anonymised)** answers "where did the money go, and was it reading or writing?":

- The 5 most expensive sessions that ended that week, with cost, share of the week's session cost, tokens,
  span, output tokens and **cost per 1k output tokens**.
- A **⚠** marks a session whose cost per output token is more than **2x that agent's median** for the
  week. Only sessions with at least 50k output tokens count, and an agent needs at least 5 of them to get
  a baseline; otherwise the digest says there were too few sessions to judge.
- For flagged sessions it also shows how much more context they *read* than they *wrote* (cache-read
  tokens per output token) against the other sessions. A high ratio means a long context was re-read on
  every turn for little output: run `/compact` or `/clear` when the task changes, or split the work.

A week older than session archiving shows "No session detail archived" instead of the table.

## Operating it

```bash
agent-usage-snapshot                  # run now (same as the scheduled run)
agent-usage-snapshot --no-notify      # ... without a notification
agent-usage-snapshot --digest         # force-render last full week's digest
agent-usage-snapshot --digest 2026-09-01   # digest for the ISO week containing that date
agent-usage-snapshot --backfill       # re-read everything on disk (one-time / recovery)

launchctl kickstart -k gui/$(id -u)/com.homelab.agent-usage   # run via launchd
launchctl print gui/$(id -u)/com.homelab.agent-usage          # is it loaded? last exit code?
tail -f ~/Library/Logs/agent-usage.log

# Stop it (Ansible re-loads it on the next play):
launchctl bootout gui/$(id -u)/com.homelab.agent-usage
```

Install / update: `ansible-playbook -i inventory.yaml site.yml --limit work-mac` (the `desktop` role).
The play runs one explicit `--backfill` of everything still on disk on first install, so any error shows
up in Ansible's output (the script would also do this by itself on its first run). The Ansible tasks
need the user's GUI session (`launchctl bootstrap gui/<uid>`); they will not load the agent over a bare
SSH login.

The first backfill (2026-09-21) recovered `claude-default` days back to 2026-06-18, earlier than
Claude's 30-day window suggests, because ccusage reads timestamps *inside* transcript files and a
long-lived session file keeps old messages. Those early days are sparse; only the last ~30 days are
complete. In the digest's trend table, `—` means "no recorded usage" (idle **or** pruned).

## Upgrading ccusage

`brew upgrade ccusage` moves to the latest release, and the JSON schema has changed across majors
(v20 folded `@ccusage/codex` into one CLI). The script converts every field through a strict number
check, so **schema drift fails loudly** (non-zero exit, failure notification, archive untouched)
instead of archiving garbage. After a major upgrade, run `agent-usage-snapshot --no-notify` by hand and
re-check `NORMALISE_JQ` (daily rows) and `SESSION_JQ` (session rows) in the script if it fails. The two
are handled differently on purpose: a daily-schema problem fails the run, but a **session-only** problem
only logs a warning and adds a digest note, because the daily archive is the record that must not be
lost.

Pricing: ccusage fetches prices online by default (accurate for new models). Set `CCUSAGE_OFFLINE=1`
in the plist if the network is the flaky part. A model with no price shows up in the digest Notes
(`unpricedModels`) rather than as a silent $0.

## Troubleshooting

| Symptom | Check |
|---|---|
| No notification banner | The job only *calls* `osascript` (which returns 0); whether a banner shows depends on Notification Center permissions. Look under System Settings → Notifications (osascript notifications are typically attributed to *Script Editor*). The digest is always in `reports/latest.md`. |
| `FAIL: ccusage not found` | `brew list ccusage`; the plist `PATH` is `/opt/homebrew/bin:/usr/bin:/bin` (no mise/nvm). |
| `SKIP: … does not exist` | A source dir is missing. Reported in the digest Notes. `ccusage codex` exits 0 on a missing dir, so the script checks itself. |
| `schema drift` | ccusage changed its JSON; see *Upgrading*. |
| Digest note "session detail could not be archived" | `ccusage ... session` failed or its JSON changed. The daily archive is unaffected and the run still succeeds; **Top sessions** may be incomplete. See the `WARN` line in the log, and *Upgrading*. It clears by itself on the next good run. |
| Ansible `Bootstrap failed` (e.g. `5: Input/output error`) | `launchctl bootstrap gui/<uid>` needs the user's GUI login session and typically fails over a bare SSH login. Run the play from Terminal on the Mac. |
| Gap warning | The Mac was off or the job failing for >20 days; check the log. |
| Archive deleted | Nothing to do: the next run re-reads everything on disk for any profile with no rows. Claude data already pruned at the source is gone. |
| Archive truncated (old days missing, recent rows present) | Not auto-detected. Run `agent-usage-snapshot --backfill`. The Ansible `creates:` guard will **not** do it, because the file exists. |

## Design notes

- **Why `launchctl` commands instead of `community.general.launchd`:** the module treats "loaded, no PID,
  exit 0" as *stopped*, so `state: started` would `launchctl start` an idle calendar job (plus a 5 s
  sleep) on every Ansible run and never be idempotent. `launchctl print` is the state check instead;
  a changed plist triggers `bootout` + `bootstrap`. There is no handler.
- **Why Ansible rather than chezmoi:** it is the repo's existing scheduled-job precedent
  (`rclone_sync.yml`), and it keeps install + script + schedule in one run so the agent never points at
  a script that has not been deployed yet.
- **Shared directories are never re-moded.** The role creates `~/.local/bin` and
  `~/Library/LaunchAgents` if missing but does not touch their modes; only the archive dir is forced to
  `0700`. (`~/Library/Logs` is 0700 by default and left alone.)
- **Timezone is pinned to `Asia/Tokyo`** in the script so archived day boundaries never shift. Session
  timestamps arrive in UTC and are converted with the zone's offset at run time (fine for a zone without
  DST).
- **Session ids are hashed with Perl's `Digest::SHA`** (ships with macOS), in one process; a `shasum` loop is
  the fallback but is ~400x slower.

## Not covered

- Linux desktops (`dt-dev-01/02`): would need a systemd user timer like `rclone_sync.yml`.
- Remote destinations (Slack / Notion): deliberately omitted. If added later, send **aggregates only**,
  and note that a launchd job has no interactive 1Password unlock (see [SECRETS.md](SECRETS.md)).
