# Persistent Codex execution

Announce persistence and its reason. Resume only a supplied thread ID or one unambiguous
ID previously returned in this conversation. Persistent threads belong only to this
passthrough; do not reuse them for pipeline lanes.

For persistent execution, replace the engine command with one of:

```
plx-codex-thread start --mode rw --codex-passthrough-full-access --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort>
plx-codex-thread resume --thread <thread-id> --mode rw --codex-passthrough-full-access --repo <repo> --prompt-file <tmp>/prompt.md --model <model> --effort <effort>
```

Pass the full-access flag on every resume; prior access grants no new authority.
The packaged client prepares its locked environment outside the plugin cache. If the
host sandbox blocks dependency or keychain access, request host approval.
Read `final_response` from the JSON result. Return it verbatim
with `thread_id`, the absolute repo, and `Resume with: /plx:codex resume <thread_id> —
<next request>`. On persistent failure, report the error and stop; do not retry through
the ephemeral path because the failed turn may have changed files.

