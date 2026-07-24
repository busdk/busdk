# Experiment And Proof Discipline


For performance, build, boot, sync, or browser-proof goals, size work to the
acceptance path instead of the current session length. Before starting an
experiment, state the expected effect on the gate metric and the mechanism.
Use focused deterministic checks for small questions, reserve expensive
end-to-end proofs for batched changes or gate decisions, and treat a failed
gate as a re-plan point.

Check new work against rejected approaches by mechanism, not by task name.
When one lane is blocked on a long build, browser run, or remote proof, advance
an independent lane from the active plan. When an environment workaround
repeats, promote the first diagnostic and normal handling rule to the nearest
`AGENTS.md`, runbook, or module plan instead of re-explaining it in memos.

