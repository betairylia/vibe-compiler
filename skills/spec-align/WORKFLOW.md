# Spec workflow (shared by /spec-align and /spec-impl)

- `Specs/` (project root): the owner's intent, in the owner's own git repository. Read-only: never write, stage or commit there. Propose spec wording in chat only.
- `Specs-vbc/` (project root): Claude's notes, tracked in the code repository.
- The user's instructions and the project `CLAUDE.md` keep applying.

## How to read Specs

- Specs is self-contained and describes a working system. The owner chooses the granularity per part. Below it, the code is the source of truth: do not change it, do not report it.
- Specs is intent, written as pseudo code. The code satisfies a construct when it has the behaviour, the order and the boundaries that the spec gives, inside the complexity of the spec form. Names, split and structure can differ.
- A DIFFERENCE is a difference in behaviour, order, boundary or complexity, or in the fields of a `strict` construct.
- A pointer out of Specs (`>> file`, "follow X") must be bounded: it names its target, and Specs gives what the rest of the system needs from the target.
- A construct with the keyword `concept` is a term for communication: it names a model, a role or a category. The code needs no construct with its name or its form, and the notes get no `Mapping` entry for it. What Specs says through the concept (behaviour, bounds) still applies to the code that does that work, and to the constructs that derive from the concept.
- Out of scope: `TODO`, `TBD`, and a construct that is commented out. A comment about the construct beside it is spec text.

## Fuzzy and strict

Apply this rule while you read and write. It gets no test, no check step and no note entry.

- A construct is fuzzy unless it has the keyword `strict`. The written form of a fuzzy construct is the minimum: the code can add fields, steps and helper constructs.
- An addition stays inside the complexity class of the spec form. The class is the written bound, else the implied one: scalar fields O(1), a collection O(its count), a loop O(its range). Logic that Specs gives only in words has no time bound.

  ```
  struct data { float a, b; }                // implied O(1)
  struct data : space O(n) { float a, b; }   // written O(n)
  strict struct data { float a; }            // exactly this field
  ```
- `strict`: exactly the written fields. A type alias is permitted. The order is free unless the spec gives it.
- An invented construct counts as a part of the spec construct that it serves: data per instance against the space of that struct, a called procedure against the time of its caller, the state of a system against the data that the system processes. If it serves no spec construct, ask the owner.
- An addition does not change behaviour that the spec gives, and it crosses no boundary of the spec.
- If the implementation needs more than this rule permits, do not write it: ask the owner.
- If you see code that breaks this rule and is not in the work of the run (old code included), say so in one line of the report.

## Optimize

Apply this rule while you implement. It gets no test, no check step and no note entry.

- Write the best form that satisfies the spec, not the form nearest to the spec text.
- Better is: less time, less space, or simpler code (fewer abstractions, fewer lines to read).
- When these conflict and no spec bound decides: time and space win in code that runs per tick, per frame or per element of a large collection. Simpler code wins in all other code.
- Scope: the code that the run writes, and the existing code of a construct that the run changes. For other code, change nothing and write one line in the report.
- An optimization keeps the behaviour, the order, the boundaries and the bounds that the spec gives, and the fields of a `strict` construct. In existing code, it also keeps the behaviour that Specs does not give.

## Step 0: Specs alone

Do this before you read the notes or the code.

1. Delta: `git -C Specs diff <synced_to>..HEAD`. `synced_to` is in `Specs-vbc/STATE.md`; without that file, the delta is the whole tree. Use committed content only (`git -C Specs show HEAD:<path>`): ignore uncommitted edits and do not ask about them.
2. Read the changed files, the files that they point to and the files that point to them. Read the whole tree when it is small.
3. Check that the delta is clear, self-contained, consistent with the rest of Specs (also with the parts that it makes obsolete), buildable from Specs alone, and sound.
4. Coarse is not a failure. A missing detail is a failure only when another part of Specs needs it, or when two reasonable implementations would differ in a way that the owner would see. For an obvious slip, use its one reading and report it in one line.
5. A failure that touches the delta: stop. Another problem: one line in the report, and one line in `Open questions` when the run updates the notes. Do not report a listed problem again.

## Stop

At a stop, change nothing: no code, no notes, no commit. Ask with one AskUserQuestion call, and put the facts and the proposed spec wording inside the question. The owner answers with a Specs commit and runs the command again.

Stop points:

1. After Step 0.
2. After the code read, before the first change: the delta cannot be built as written, or the code shows a choice that Specs leaves to the owner.

## The notes

The notes hold exceptions only, for the current state of the branch. A construct without an entry satisfies the spec, and a search for its spec name finds it in the code.

- `STATE.md`: the line `synced_to: <Specs commit>` (the code satisfies Specs at this commit, except the `Open` entries) and the section `## Open questions` (`- <spec file>: <one sentence>`; problems in Specs that wait for the owner).
- `<spec path>.md` (`Specs/a/b.x` -> `Specs-vbc/a/b.x.md`), only when it has entries. It starts with `# <spec path>` and can have one `Short path:` line that defines path prefixes.
  - `## Mapping`: `<spec construct>` -> `<code symbol>` (`<file path>`): what differs, in one clause. Only for a construct that a search for its spec name does not find.
  - `## Open`: a construct that the code does not satisfy: what the spec says, what the code does, why it is open.
- No history, no dates, no line numbers, no status, no owner intent, no proposals.
- Check an entry against the code before you write it. Delete an entry that is no longer true, and a file that has no entry.

## Commits

- Never push.
- HEAD is the checkpoint. Commit only the files that the run changed, by path. The owner's uncommitted work stays untouched and uncommitted. If the run must change a file that has uncommitted changes of the owner, ask first.
- `/spec-impl`: code and notes in one commit, `<what changed> (Specs <short hash>)`.
- `/spec-align`: the notes, `spec-align: <spec files> @ Specs <short hash>`.
