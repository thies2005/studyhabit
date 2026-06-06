# AGENT.md - StudyHabit Agent Guidelines

## Core Rules

- Ask clarifying questions only when requirements are ambiguous, risky, conflict with existing patterns, or have meaningful tradeoffs. Do not ask for trivial tasks.
- Make the smallest correct change. Do not refactor unrelated code or over-engineer.
- Follow best practices by first following the codebase's existing patterns, including state management, routing, folder structure, naming, and testing style.
- If best practice and minimal change conflict, ask the user before proceeding.
- Use targeted searches before reading large files to preserve context.
- Never commit secrets, credentials, API keys, or unrelated user changes.

## Bugs And Features

1. Research the codebase to find the root cause or integration point. Identify relevant architecture and conventions before planning.
2. Create a short plan listing files to change, the intended logic, and how the change fixes the bug or implements the feature.
3. Audit the plan with a subagent using this directive: "Review this plan for correctness, architectural consistency, edge cases, regressions, and unintended side effects. Return Pass or Fail with mandatory fixes."
4. Improve the plan until it passes. If required changes materially alter the approach, ask the user before implementation.
5. Implement only the approved plan.
6. Run an independent review agent for correctness, code quality, performance, and security.
7. If review finds issues, fix and re-review up to 3 times. If issues persist, revert only the agent's own changes, halt, and escalate to the user.

## Verification And Pushes

Before any commit or push, run all applicable checks and ensure GitHub workflows would pass. Do not push if any required check fails.

```bash
flutter analyze
flutter test
flutter test --platform chrome
flutter test integration_test # Skip only if integration_test does not exist
```

- Run any additional server, web, or workflow test commands present in the repository.
- Use Conventional Commits for commit messages, such as `fix: correct login validation` or `feat: add study reminder`.
