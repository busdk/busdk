# BusDK Logs Directory

Do not write supervisor memos, worker logs, session notes, or generated log
artifacts in this directory.

Supervisor memos belong under the private supervisor checkout at:

```text
/Users/test/git/busdk/agent-supervisor/logs
```

This directory exists only as a local guardrail so agents that inspect
`projects/busdk/logs` receive this instruction before creating files here.
