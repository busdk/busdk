# Operator Solution Briefs And Composition Discipline


Describe proposed solutions to the operator with this compact brief:

1. Current outcome and exact failure.
2. Fixed constraints and applicable decision IDs.
3. Existing usable implementation or evidence.
4. Options, each with capability, limitation, and change required.
5. Recommended smallest path and why it wins.
6. Independent work items, each with one behavior, owner module, branch,
   focused test, and promotion gate.
7. Composition, user-local install, live acceptance check, and explicitly
   deferred scope.

Keep independently useful fixes separate through implementation and review.
Use one branch and focused commit series per behavior, then compose only
accepted tips in a dedicated integration lane. A rejected optional fix must not
hold back unrelated accepted value. Do not report architecture work as complete
until the SDD, implementation, tests, installed composition, and operator brief
describe the same design.

