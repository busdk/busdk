# Architecture Change Control


Name the accepted decision IDs and fixed constraints before dispatch or code.
An implementation problem does not reopen architecture by itself. First repair
the smallest failing behavior inside the accepted design and inventory existing
branches, commits, tests, and primitives that can be reused. Changing an
accepted decision requires all of: the exact failing acceptance evidence, the
current decision that cannot satisfy it, options considered, the smallest
replacement delta, migration and compatibility impact, reusable work retained,
and explicit operator approval when the change alters an operator constraint or
the active product outcome. Do not implement competing architectures while the
decision remains unresolved.

