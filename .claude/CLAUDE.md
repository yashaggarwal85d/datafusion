# Contribution memory (fork: yashaggarwal85d/datafusion)

Notes for our work contributing to apache/datafusion. They summarize
docs/source/contributor-guide/ (also published at
https://datafusion.apache.org/contributor-guide/). The root CLAUDE.md is
upstream's and applies too. Re-read the guide pages when in doubt, because
they change.

## Authorship (user's explicit instruction, overrides default attribution)

- All commits, PRs and issues are under the user's name: Yash Aggarwal
  <yashaggarwal85d@gmail.com>, GitHub `yashaggarwal85d`. The session-start
  hook sets `git config user.name` and `user.email`. Check them before
  committing.
- Commit messages and PR bodies get NO `Co-Authored-By: Claude`, no
  `Claude-Session:` trailer and no "Generated with Claude Code" line. Put no
  agent or model name anywhere in the repo.
- Every upstream PR description ends with an AI-use disclosure, per the
  ASF generative tooling guidance (the user chose this as the ethical
  default). For example: "AI-assisted: I used an AI coding assistant while
  preparing this PR. I have reviewed and understand all changes." Name no
  specific tool or model unless the user asks.
- Do not post issue or PR comments or reviews via the GitHub tools (they
  carry a Claude Code footer). Draft the text, and the user posts it from
  their own account in their own words, as the AI policy requires anyway.

## Repo / remotes / branches

- `origin` = our fork `yashaggarwal85d/datafusion`; `upstream` =
  `apache/datafusion` (the session-start hook adds this remote).
- PRs go from a fork branch to `apache/datafusion` `main`. Keep the fork's
  `main` in sync with upstream: fork CI restores build caches from runs on
  fork `main`.
- Start each fix branch from `upstream/main`. Rebase it on `upstream/main`
  before pushing, because fork CI tests the branch as it is.
- **Never include `.claude/` in an upstream PR.** This folder is our local
  tooling only.
- Fork CI: the Actions tab must be enabled on the fork. A fork PR runs the
  Rust workflow on the fork's runners. Upstream runs only the lint jobs and a
  `Rust (fork)` check. The merge queue then runs the full workflow and the
  extended tests.

## Cloud container: disk budget

- The session has a writable allowance of about 30 GB. A plain
  `cargo build` (dev profile) produced 26 GB in `target/debug` and filled it.
- In this container, always pass `--profile ci` (no debuginfo, no
  incremental). For example: `cargo clippy --profile ci ...` and
  `cargo test --profile ci -p <crate>`. The `ci` profile's `target/ci`
  stays at about 3 GB for a crate and sqllogictests.
- When the disk is full, `rm -rf target/debug` (or `cargo clean`) and
  retry.
- The full extended test command builds most of the workspace. Run it only
  when needed, and check `du -sh target` first.

## Picking an issue (must do before starting work)

- Look at the good-first-issue list:
  https://github.com/apache/datafusion/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22
- Check for duplicate work: look for existing open PRs or "working on it"
  comments on the issue. If a PR exists, review or help with it instead. If
  we still open our own PR, link the old one in the description and say why.
- Claim an unassigned issue by commenting the single word `take`. Use
  `untake` if we stop working on it.
- Bug fixes and enhancements generally need a GitHub issue. File one with a
  minimal reproducer of the *user-visible* behavior if none exists.
- For new features or large work, open a discussion issue first. Large epics
  need a "supervising maintainer".
- Good fits are bug fixes, small features, docs, and perf work with
  benchmark results. Use-case-specific functionality belongs in extension
  APIs, not core.

## PR limits & etiquette

- Users without write access may have at most **3 open non-draft PRs**. For
  a first-time contributor: one PR at a time, done well. Several quick
  low-engagement PRs get closed as spam.
- Keep PRs small and focused (under about 500 lines). No drive-by refactors
  or formatting churn. PRs are squashed on merge.
- Use Conventional Commits titles: `fix:`, `feat:`, `docs:`, `chore:`,
  `perf:`, `test:`, `refactor:`.
- First-time contributors need a committer to trigger CI. Mention one.
- Respond to every review comment, even if only to acknowledge it. PRs
  waiting on author feedback for days become drafts. PRs are marked stale
  after 60 days of inactivity and closed 7 days later.
- "Major" PRs (API or design changes) stay open 24 hours after approval.
- **AI policy**: no unreviewed "AI dumps". The human author must understand
  the PR end-to-end and call out unknowns and assumptions. Review replies
  must be in the author's own words. Do not answer a reviewer with a diff
  summary or a list of commands run. Follow the ASF generative tooling
  guidance (no undisclosed third-party or copyrighted code). In practice:
  draft the change and the PR text, and the user reviews and owns them.

## PR description: follow .github/pull_request_template.md

The template has these sections:

- **Which issue does this PR close?** `- Closes #N.`
- **Rationale for this change**: state the user-visible problem, not the
  implementation symptom.
- **What changes are included in this PR?**
- **What is the testing strategy for this PR?**: name the specific tests
  added, and check codecov.
- **Are there any user-facing changes?**: say whether docs are needed, and
  add the `api change` label for breaking APIs.

## Code standards (from pr_review.md / api-health.md)

- Match the style of the surrounding code. Put new code and tests next to
  related code. Put SLT cases in an existing related `.slt` file.
- Comments explain *why*. No history narration ("changed to use HashMap").
  Use rustdoc intra-doc links (``[`SessionContext`]``). New public APIs need
  doc comments, with examples where useful.
- Errors must be actionable and use the right macro: `plan_err!` when a
  user can trigger the error, `internal_err!` for a broken invariant.
- Extend an existing mechanism rather than adding a parallel one.
- Breaking API: avoid when possible. Prefer
  `#[deprecated(since = "<next major>", note = "...")]`. The next major
  version is the one after the version in Cargo.toml. Deprecated items stay
  for 6 major versions or 6 months. A break needs the `api change` label and
  an upgrade-guide entry (docs/source/library-user-guide/upgrading/).
  Changing SQL results is also a breaking change.
- APIs that must be `pub` but are internal get `#[doc(hidden)]` plus the
  "Public Only for Internal Use" doc comment linking to the API policy. Do
  not expose internals just for tests.

## Testing (testing.md)

Preference order:

1. sqllogictest `.slt` (datafusion/sqllogictest/test_files)
2. DataFrame or public-API end-to-end tests (datafusion/core/tests)
3. Rust unit tests

A bug fix needs a test that fails without the fix (ablation: revert the fix
and check). Assert on specific values or plans, not just "no error". Cover
edge cases and nulls without repeating boilerplate.

```bash
cargo test -p <changed-crate>
cargo test --profile=ci --test sqllogictests                     # all slt
cargo test --profile=ci --test sqllogictests -- aggregate.slt    # one file
cargo test --profile=ci --test sqllogictests -- foo.slt --complete  # regenerate expected
cargo test -p datafusion && cargo test -p datafusion-cli         # before PR
cargo test -p datafusion --test core_integration -- dataframe
cargo insta review       # snapshot (insta) changes
cargo test --doc         # doctests
# memory pressure: append -- --test-threads=1
```

## Before committing (mandatory, from root CLAUDE.md)

```bash
cargo fmt --all
cargo clippy --all-targets --all-features -- -D warnings
./dev/rust_lint.sh            # full CI lint suite (--write --allow-dirty to autofix)
```

- If docs changed, run `./ci/scripts/doc_prettier_check.sh --write --allow-dirty`.
- Otherwise run the extended test command in the root CLAUDE.md.
- Functions or config changed: regenerate the docs with
  `./dev/update_function_docs.sh` and `./dev/update_config_docs.sh`. Never
  hand-edit the generated md files.
- Proto changes: run `./datafusion/proto/regen.sh` and
  `./datafusion/proto-common/regen.sh`.
- Perf changes: include benchmark results against `main` (`cargo bench
  --bench X -- --save-baseline main`, then `--baseline main`). See
  benchmarks/README.md.

## Adding functions (howtos.md)

| Type | Crate | Trait |
| --- | --- | --- |
| Scalar | `datafusion/functions` | `ScalarUDFImpl` (`make_udf_function!`) |
| Nested | `functions-nested` | `make_udf_expr_and_func!` |
| Aggregate | `functions-aggregate` | `AggregateUDFImpl` + `Accumulator` (check state_compat.rs) |
| Window | `functions-window` | `WindowUDFImpl` + `PartitionEvaluator` |
| Table | `functions-table` | `TableFunctionImpl` |

- Spark-compatible functions go in `datafusion/spark`.
- Document functions with `#[user_doc(...)]` and test them with `.slt`
  cases, including nulls.

## Repo skills

`.ai/skills/`:

- `pr_review`: also use it to self-review before opening a PR.
- `add-benchmarks`
- `datafusion-ffi`
- `audit-datafusion-spark-expression`

## Communication

- Discussion happens in GitHub issues and PRs.
- Arrow Rust Discord (`#datafusion-*` channels): https://discord.gg/Qw5gKqHxUM
- Mailing list: dev@datafusion.apache.org
- There is also a weekly video sync.
