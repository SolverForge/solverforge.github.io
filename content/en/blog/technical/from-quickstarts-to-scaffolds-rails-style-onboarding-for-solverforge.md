---
title: 'From Quickstarts to Scaffolds: Rails-Style Onboarding for SolverForge'
date: 2026-03-27
draft: false
tags: [rust, quickstart, release]
description: >
  SolverForge is moving from clone-and-edit quickstarts to scaffolded project
  generation with solverforge-cli, aligning onboarding with the same
  zero-erasure and explicit-code philosophy described in The Future of
  Constraint Programming in Rust.
---

{{< alert title="Historical transition note" color="info" >}} This article captures
a transition moment in SolverForge onboarding. For the current recommended
first-stop path, start with the Getting Started tutorial pages and the current
`solverforge-cli` documentation. {{< /alert >}}

For the last phase of SolverForge, our default onboarding story was the
quickstart.

You cloned a repository, opened a working example, ran it, and then started
modifying it until it looked like your problem. That model helped us prove the
architecture, teach constraint modeling, and ship complete end-to-end demos
quickly. It was the right move for a project that was changing fast.

Long term, we do not think it is the right default.

We are moving SolverForge from a quickstart-based onboarding model to a
scaffold-based one built around `solverforge-cli`. The inspiration here is
straightforward: Ruby on Rails understood early that there is a big difference
between reading an example application and starting your own application. A
framework needs both.

Quickstarts are excellent examples. A scaffold is a starting point.

That distinction matters more in Rust than in most ecosystems.

## What the Quickstart Model Got Right

The quickstarts were never accidental. They made several good trade-offs for an
early-stage solver:

- They were concrete.
- They showed a complete application, not just a library snippet.
- They taught modeling by example.
- They exposed the full stack: domain types, constraints, API, UI, and sample
  data.

That was especially valuable while SolverForge was proving out the native Rust
architecture. A user could open an employee scheduling app, run it locally,
inspect the constraints, and understand how the solver behaved in a real
service.

That educational value does not go away. We still believe in worked examples. We
still believe in sample applications. We still believe in showing the full path
from domain model to running UI.

What changes is where that material sits in the developer journey.

A quickstart should be something you study. A scaffold should be something you
own.

## Where Quickstarts Stop Scaling as the Default

The problem with clone-and-edit onboarding is that it asks users to begin from
someone else's application structure and then delete their way toward their own.

That works when the example is very close to the target domain. It breaks down
when it is not.

If you start from employee scheduling to build a manufacturing optimizer, or
from a routing demo to build a warehouse sorter, you inherit a lot of decisions
that are not really yours:

- entity names you did not choose,
- constraints that are only relevant as examples,
- sample data that teaches the wrong mental model,
- UI structure optimized for the demo rather than for your domain,
- and repository layout that grew around the example instead of around your
  application.

The result is subtraction-heavy onboarding. New users spend their first hour
deleting artifacts instead of expressing the shape of their own problem.

There is also a maintenance problem. A quickstart-centric ecosystem pushes the
same structural fixes through many example repositories. As the framework
improves, those examples drift. The user is then forced to separate what is
essential to SolverForge from what is just historical residue in a demo.

That is a poor default experience.

## Why a Scaffold Fits SolverForge Better

`solverforge-cli` changes the center of gravity.

Instead of saying, "clone this demo and adapt it," the framework says, "tell us
what kind of planning problem you have, and we will generate the project
skeleton around that choice."

That is a much better fit for how SolverForge itself is designed.

The core idea in
[The Future of Constraint Programming in Rust](/blog/vision-for-rust-constraint-programming/)
was that the solver should preserve concrete types all the way through the
pipeline. No hidden indirection. No erased runtime machinery in hot paths. No
mystery about what code is actually running.

The scaffold story is the same idea one layer out.

In the solver core, we reject late binding in performance-critical paths. In
onboarding, we should also reject late binding in project structure.

A user should not begin with a generic demo and then slowly discover what parts
are incidental. They should begin with a concrete, readable project skeleton
that already names the relevant problem class and exposes the files they are
expected to edit.

The technical vision is consistent:

- move generic machinery into the framework,
- generate explicit user-owned code at the boundary,
- and keep the final application legible.

That is exactly the kind of ergonomics Rust needs. We do not want to hide
complexity behind runtime magic. We want to compress ceremony without hiding
structure.

## The Rails Inspiration, Applied Carefully

When people talk about Rails, they often focus on productivity. That is only
part of it.

The deeper idea is that `rails new` and `rails generate` create a predictable
project shape. The framework knows where models live, where configuration lives,
where migrations live, where routes live. Because that structure is
conventional, tooling can be opinionated without becoming opaque.

That is the model we want for SolverForge.

A SolverForge application should have an expected layout for:

- domain types,
- constraint modules,
- API and server wiring,
- configuration,
- tests,
- and a minimal UI.

Once that structure is predictable, the CLI can do real work:

- `solverforge new` can create the project,
- `solverforge generate` can add entities, facts, variables, and constraints,
- `solverforge check` can validate structure,
- `solverforge routes` can inspect the app surface,
- `solverforge test` can standardize the test loop,
- and `solverforge server` can give a conventional local runtime.

That is not "magic." It is convention-backed automation.

And that distinction matters. We are not trying to turn SolverForge into a
framework where generated code disappears behind macros and hidden runtime
behavior. The generated code is still yours. The point is to make the first
version of that code exist immediately and in the right place.

## What `solverforge-cli` Actually Changes

The standalone `solverforge-cli` repository is the implementation of this shift.

At a high level, the CLI does two things.

First, it scaffolds by problem class, not by an endless menu of domain demos.
The current shape is intentionally simple: standard-variable and list-variable
projects. That tracks the real architectural split inside SolverForge more
closely than "employee scheduling vs. vehicle routing vs. everything else."

Second, it treats project growth as a generator problem, not as copy-paste. The
CLI on `main` already exposes commands in the shape of:

```bash
solverforge new my-scheduler
cd my-scheduler

solverforge generate fact employee --field "skill:String"
solverforge generate entity shift --planning-variable employee_idx
solverforge generate constraint required_skill --join --hard

solverforge server
```

That flow is much closer to how developers actually think:

- create the app,
- name the domain,
- add the missing pieces,
- run the server,
- iterate.

There is also an important front-end consequence. The CLI-generated UI is
intentionally thin and composes shipped `solverforge-ui` primitives instead of
vendoring a one-off front-end stack into every starter project. That keeps
generated applications smaller, reduces drift, and lets the framework own more
of the generic UI surface without forcing users into a heavyweight web
architecture.

## What Happens to Quickstarts Now

This does not mean examples disappear.

It means they stop being the main entry point.

Quickstarts still make sense as:

- worked examples,
- reference implementations,
- documentation companions,
- benchmark and architecture showcases,
- and domain-specific demonstrations.

That is a better role for them anyway.

The quickstarts repository was useful when SolverForge needed a catalog of
concrete applications to teach from. But the moment the framework can generate a
correct project skeleton itself, quickstarts should move to the side of the
experience, not the center.

Read them. Learn from them. Borrow ideas from them.

But do not make every new user begin by forking a demo repo and reverse-
engineering which parts matter.

## The Status of 0.6.0

A status note is important here, because this transition is real but not yet
fully productized.

SolverForge 0.6.0 is technically out. The core project changelog already records
the CLI scaffolding and code generation work in
[SolverForge 0.6.0: Scaffolding and Codegen](/blog/releases/solverforge-0-6-0/).
In other words, this is not hypothetical roadmap copy. The migration is already
reflected in the codebase.

At the time this article was written, the dedicated `solverforge-cli`
repository represented the public transition toward scaffolded onboarding.
The direction was already visible in the codebase even while the product surface
was still evolving.

So the right way to read that moment was:

- the direction was set,
- the implementation was underway in public,
- 0.6.0 contained the transition technically,
- and the polished CLI release is still ahead of us.

That is why we are describing the CLI today as alpha/beta.

## Why This Matters for the Future of Rust Constraint Programming

This migration is not just about convenience. It is about making the whole Rust
story cohere.

In the earlier Rust vision piece, we argued that constraint programming in Rust
should feel like writing code, not configuring a black box. That means strongly
typed domain models, explicit constraints, generated helpers where they help,
and a runtime architecture that stays honest about cost.

Scaffold-based onboarding is the same philosophy expressed at the repository
level.

A framework with a zero-erasure core should not introduce avoidable friction the
moment a new user creates a project. The path from "I have a planning problem"
to "I have a running application skeleton" should be short, conventional, and
structurally clear.

That is the future we want for SolverForge:

- fast solver internals,
- explicit Rust APIs,
- generated project structure where repetition can be automated,
- and examples that teach without pretending to be the only way to start.

The better the scaffolding gets, the less time users spend doing repo
archaeology and the more time they spend modeling constraints.

That is the right optimization target.

## Conclusion

Quickstarts helped SolverForge get here. They proved the architecture, taught
the model, and gave the project a concrete surface while the native Rust solver
matured.

The next phase likely needs a better long-term default, and we think that
future default is scaffold-based onboarding.

That future default looks like:

- create a project,
- declare the problem class,
- generate the missing pieces,
- and start writing domain code immediately.

That is what `solverforge-cli` is for.

For now, though, the right public reading is simpler: quickstarts and tutorials
remain the recommended starting point, while the CLI shows where SolverForge is
heading.

This is the onboarding counterpart to the same idea behind the Rust core: move
repeated machinery into tooling, keep user code explicit, and make the system
feel concrete from the first edit.

We will announce the standalone CLI release properly when it is ready. Until
then, the code on `main` shows the direction, not yet the final default.

## Related

- [The Future of Constraint Programming in Rust](/blog/vision-for-rust-constraint-programming/)
- [How We Build Frontends: jQuery in 2026](/blog/technical/how-we-build-frontends/)
- [SolverForge 0.6.0: Scaffolding and Codegen](/blog/releases/solverforge-0-6-0/)
- [SolverForge 0.5.0: Zero-Erasure Constraint Solving](/blog/releases/solverforge-0-5-0/)

## Source

- [SolverForge](https://github.com/solverforge/solverforge)
- [solverforge-cli](https://github.com/solverforge/solverforge-cli)
- [SolverForge Quickstarts (archived)](https://github.com/solverforge/solverforge-quickstarts)
