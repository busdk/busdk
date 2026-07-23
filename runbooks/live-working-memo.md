# Live Working Memo Runbook

Read this before substantial work sessions, memo closeout, or Bus Notes use.
It is the full memo style contract; it expands the binding Live Working Memo
core in the root `AGENTS.md` without replacing it.

1. Maintain a live working memo during every substantial work session. The memo
   is hourly based.
2. At the start of work, create or update
   `./logs/{YYYYMMDD}-{HH}-agent-memo.md`, where `YYYYMMDD` is the current
   local/project date and `HH` is the zero-padded 24-hour hour when that memo
   period starts. Create `./logs` if it does not exist.
3. Use the current local/project time when naming memo files. Continue writing
   to the same memo only while the current hour remains the same.
4. When the hour changes, finish the current memo with a short handoff note
   explaining the current state of the work, what is complete, what is still in
   progress, what was verified, what remains uncertain, and what should happen
   next. Then create or continue the next hourly memo for the new hour.
5. Write each memo as an editorial engineering diary in story form. It should
   read like a clear narrative of the work session, not like a checklist,
   changelog, or raw activity dump.
6. The memo should let a future maintainer, human reviewer, or AI agent
   understand the flow of work: what the agent was trying to accomplish, what
   it found, why it made certain choices, where it hesitated, what changed,
   what went wrong, what worked well, and what could be improved next time.
7. Use Markdown. Prefer narrative paragraphs over lists. Headings may be used
   when helpful, such as `## Session Context`, `## Work Narrative`,
   `## Observations`, `## Decisions`, `## Tests and Checks`,
   `## Problems and Friction`, `## Improvement Ideas`, `## Hourly Handoff`,
   and `## Final State`.
8. Lists are allowed only when they genuinely improve readability, for example
   for compact test results or final next steps.
9. Update the current hourly memo throughout the hour after meaningful phases
   of work. Add a short narrative note explaining what just happened and what
   it means.
10. Do not merely write "ran tests" or "updated parser." Explain why tests were
    run, what the result suggested, why a change was needed, whether the change
    felt clean, and whether any concern remains.
11. If work changes direction, describe the reason. If an assumption turns out
    to be wrong, record how that changed the approach. If a command fails,
    explain the failure, likely cause, and next action.
12. Before making a risky, broad, or hard-to-reverse change, write a short note
    explaining the intended change, why it seems necessary, and what risk it
    carries. After making the change, update the memo with what actually
    happened.
13. If no code changes were made during an hour, still write the story of that
    hour: what was examined, what was learned, what remains uncertain, and what
    the next useful action would be.
14. Keep the memo truthful, concise, and useful for later learning. Do not
    claim planned work as completed. Do not invent successful results. Clearly
    separate facts from interpretation. Mark uncertainty, failed attempts,
    skipped checks, and assumptions honestly.
15. Avoid blame-oriented language. Focus on what the project, tooling,
    architecture, process, tests, or prompts can learn from the session.
16. Summarize long command outputs instead of pasting them in full, and mention
    how the result can be reproduced when useful.
17. Treat committed logs and memos as public repository content. Never write
    secrets, API keys, passwords, tokens, private customer data, proprietary
    customer details, raw `.env` contents, or other sensitive values into memos
    or committed logs. Summarize or redact sensitive evidence instead.
18. When investigating environment variables or config files, query only the
    exact non-secret key needed, or report whether a key exists without
    displaying unrelated values.
19. Do not edit historical hourly memos after the hour/session has passed
    except to remove sensitive information or undo an accidental inappropriate
    edit. Later lessons from old memos should be captured in the current memo
    or in durable project guidance.
20. Before finishing a session, review the current hourly memo. Make sure it
    explains not only what changed, but how the work unfolded and what can be
    learned from it.
21. End the final memo for the session with a concise final state: what is
    complete, what remains incomplete, what was verified, what was not
    verified, and what the next agent or maintainer should probably do next.
22. Every hourly memo should contain enough handoff detail that another agent
    can resume without re-reading the whole conversation. For broad work,
    include compact coverage of the current goal, key decisions, modified
    files, commands and tests run with outcomes, blockers, active follow-ups,
    and important context.
23. When Bus Notes is available and configured, delegated workers or
    long-running agents may also publish concise notes through `bus notes` so
    the work becomes searchable and attributable. Local
    `./logs/*-agent-memo.md` files remain the canonical session diary unless
    this repository explicitly chooses Bus Notes as the primary store.
24. If Bus Notes is unavailable, unconfigured, or inappropriate for the current
    repository, continue with local memo files only and mention that limitation
    in the memo or final handoff when relevant.
