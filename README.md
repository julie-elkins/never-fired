# never-fired

**A guard that never fired is indistinguishable from a guard that works.**

Three scripts here demonstrate four ways a coding agent's guardrails fail while still looking
armed. Each one runs against a scratch configuration directory it creates and deletes; none of
them reads or writes your real setup. Each exits non-zero and names the arm if it stops
demonstrating what it claims.

There is nothing to install and nothing to configure. Everything below was measured on
**v2.1.304, 20 October 2026** — the dates are here so you can tell when this went stale, which is
the courtesy these claims owe you.

## The four failures

**1. A rule written against the wrong tool is accepted and never consulted.**
File permissions are checked against `Edit(path)` and `Read(path)` only. A path rule for `Write`,
`NotebookEdit`, `Glob` or `MultiEdit` is accepted, stored, never consulted, and warned about once
in a startup banner. `Write(~/secrets/**)` is the rule a careful person writes first, and it is
inert. Changing one word to `Edit` makes it refuse.

**2. Whether a broken guard fails open or closed is decided by its launcher, not by you.**
A hook refuses by exiting 2. So a *missing* script handed to `python3` makes **python** exit 2 and
the call is refused, while `bash <missing>.sh` or a missing executable exits 127 and the call
runs. One missing file, opposite outcomes, decided by the word in front of the path.

And accidentally refusing is not a safe place either: if a moved file and a real refusal produce
the same outcome, you cannot tell them apart, so you lose the ability to notice the guard broke at
the moment it starts mattering.

**3. A guard that crashes permits.**
A hook that raises exits 1, which is not the refuse code, so the call goes through. It is at least
named in the record on this version — three weeks earlier it was not — but detectable-afterwards
is not a control.

**4. An approval leaves no trace at all.**
A hook that approves a call writes nothing anywhere. So a report showing no refusals is equally
consistent with a guard that approved every call, a guard that crashed, and a guard that was never
consulted — and nothing in the record distinguishes them. **This is the one that has no
workaround.** The other three have a fix; this one is a property of what gets recorded.

## Run them

```
bash demos/01-rule-on-the-wrong-tool.sh
bash demos/02-fails-open-is-an-accident.sh
bash demos/03-what-the-record-shows.sh
```

About a minute each. They need `claude` and `python3` on `PATH` and whatever authentication you
already use; the scratch configuration carries no credentials. Each makes three or four short
model calls, so they are not free, and they print what they predicted next to what happened.

**Pass and fail are decided by whether a file exists, never by what the model said.** A model that
narrates being blocked while the write lands anyway is the defect this repository is about, so its
own tests must not be able to make that mistake.

## What these do not show

- **One product, one version, one platform.** Hooks and permission rules as they behaved on
  v2.1.304 on macOS. Not a general claim about guardrails anywhere else.
- **Behaviour, not frequency.** Nothing here measures how often real setups are misconfigured.
  Four demonstrations are not a survey.
- **Configuration, not judgement.** These can tell you a guard fired. They cannot tell you it was
  the right guard, and a guard that fires correctly on the wrong rule is not covered by anything
  here.
- **"Every case" means the four cases tested.** `onFailure: "block"` refused in all of them —
  missing script under two launchers, and a crash. That is not proof it covers every failure a
  hook can have.
- **No transcript reader ships here.** Demo 3 greps for one filename inside the directory its own
  run created, and refuses to search outside it. It cannot tell you *how* something was recorded,
  only that it was, which is all four arms need.

## Corroboration from elsewhere

Two numbers worth knowing, **measured by someone else, on a different target, and not reproduced
here**: [`zernie/vigiles`](https://github.com/zernie/vigiles) pointed a battery of seven textbook
destructive commands at a widely-copied safety hook and found it blocked **2 of 7**. Then they
re-spelled those same seven commands thirty ways the shell runs identically and ran them against a
guard that had just scored 7 of 7 — it blocked **8 of 30**.

That is the lesson this repository does not contain and does not try to: passing a battery tells
you your guard matches the way you typed a command, not that it matches the operation. Their
`docs/compiled-hooks.md` has the detail.

## What to do about it

1. **Set `"onFailure": "block"` on every `PreToolUse` registration.** It is the only thing that
   makes a broken guard's behaviour a decision rather than a side effect of its launcher.
2. **Write path rules as `Edit(...)` and `Read(...)`.** Never `Write(...)`, `Glob(...)`,
   `MultiEdit(...)` or `NotebookEdit(...)` — those are accepted and ignored.
3. **Probe every guard in both directions.** A probe that only checks the refusal cannot
   distinguish a correctly scoped rule from one that has swallowed everything, because both
   refuse.
4. **Never read a quiet report as a clean run.** Failure 4 is why. If you need to know a guard is
   armed, something has to actively check it; nothing passive will tell you.

## License

MIT. See `LICENSE`.
