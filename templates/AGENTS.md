# Global model routing

## Objective

Keep the main Codex App task on the configured global model. Use specialized
subagents whenever bounded, independent work can materially improve latency,
evidence quality, or context isolation. Preserve completion quality with
explicit evidence, validation, and escalation instead of using the most
expensive model for every step.

## Delegation authorization

You are explicitly authorized to create bounded subagents without asking the
user again when the delegation gate below is satisfied.

## Delegation gate

Before beginning a non-trivial research, diagnosis, multi-file exploration,
design analysis, or feature task, identify independent work lanes.

- If exactly one substantial independent read-only lane exists, you MAY spawn
  one focused subagent.
- If two or more independent read-only lanes can proceed in parallel without
  blocking the next critical-path decision, you MUST spawn one focused subagent
  per selected lane: normally two, and up to four only when the additional
  lanes materially improve coverage or latency.
- For research that needs current or external evidence, separate official
  sources, community or practitioner feedback, and counterexamples or risks
  into independent lanes when doing so improves coverage.
- For repository work, parallelize independent code-path mapping, log or test
  evidence gathering, documentation comparison, and focused review. Keep final
  edits, integration, and validation in the main task unless write ownership is
  cleanly disjoint.
- Do not delegate short questions, a one-command lookup, a single-file tiny
  change, or work whose next critical-path step depends on the same result.

## Routing rules

- Complete short, direct, or tightly scoped work in the main task. Do not spawn
  a subagent merely to run one command, read a few files, or make a tiny edit.
- Use `fast_reader` for substantial but deterministic read-only extraction,
  classification, transformation, comparison, or summarization work.
- Use `explorer` for read-heavy repository exploration, execution-path tracing,
  focused log analysis, and evidence gathering before a change.
- Use `worker` for a bounded multi-step implementation with clear acceptance
  criteria when delegating it keeps routine execution out of the main context.
- Use `deep_reviewer` for architecture decisions and for work involving
  authentication, security, permissions, money, destructive operations, data
  loss, migrations, concurrency, public APIs, cross-system behavior, or subtle
  regressions. It may review a plan before implementation or a focused diff
  afterward.
- If tests fail twice for reasons that remain unclear, evidence conflicts, or a
  worker reports low confidence, escalate once to `deep_reviewer` with the
  smallest relevant context. Do not create open-ended retry or review loops.

## Cost and concurrency guardrails

- Do not delegate when setup and context would be as large as the task itself.
- Use at most two subagents by default. Use up to four only for genuinely
  independent, read-heavy work whose results can be summarized separately.
- Keep delegation depth at one. Subagents must not spawn additional subagents.
- Allow only one write-capable agent to edit a given working tree at a time.
  Exploration and review agents remain read-only.
- Do not send the same broad context to multiple agents. Give each agent the
  smallest file set, logs, constraints, and acceptance criteria it needs.

## Return contract

Every subagent should return a concise result containing:

- conclusion or work completed;
- decisive evidence with file paths, symbols, or commands;
- validation performed and its result;
- uncertainties, risks, or blockers;
- a recommended next action when one is still needed.

Return summaries rather than raw logs or long file contents. The main task owns
final integration, conflict resolution, user communication, and confirmation
that the requested outcome is actually complete.
