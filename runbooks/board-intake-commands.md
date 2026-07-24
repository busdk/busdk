# Board Intake Commands

Before each new or resumed BusDK feature turn, read the owning module
portfolio and latest shared baseline from the live Bus Thread board. Thread
ids are environment-local and are never hardcoded in guidance: resolve them at
run time from `bus thread list --roots` (or `bus thread search <title>`) by
role — the module-owned work portfolio, the shared development co-work
coordination thread, and the active-bug board. Then use
`bus thread list <portfolio-id> --depth 2` and
`bus thread show <co-work-id> --latest 6`. Place every future canonical BusDK
feature root under exactly one module portfolio. The co-work coordination
thread and active-bug cards remain explicit cross-module navigation surfaces;
product work belongs beneath its semantic product/module hierarchy.
