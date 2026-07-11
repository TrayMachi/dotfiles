---
name: iris-babysit
description: |
  Babysit GitLab CI pipelines until they terminate, especially when the user says
  "babysit CI", "watch the pipeline", "monitor this MR pipeline", "tell me when CI is done",
  or asks to keep an eye on a GitLab pipeline/MR/branch. Use this skill for long-running
  GitLab CI monitoring: poll pipeline state, diagnose failures from job logs, retry only
  likely flaky/flakey failures, avoid retrying deterministic/non-flaky failures, and notify the
  requester in the Lark thread by mentioning them when the pipeline terminates or needs
  manual intervention.
---

# GitLab CI Babysitter

Babysit a GitLab CI pipeline until it reaches a terminal outcome or needs human help. The goal is not just to check status once; keep ownership of the watch loop, classify failures, retry safe flakes, and report the final state back to the requester.

## Inputs

Accept any of these targets:

- Pipeline URL or numeric pipeline ID
- Merge request URL or IID
- Branch name
- No target: infer the MR from the current branch, then use the latest pipeline for that MR/source branch

If the request arrives from Lark and includes chat/thread context, keep the requester's `open_id` and the original/root `message_id` (`om_xxx`) available for the final notification.

## Prerequisites

- Use the `iris-gitlab` skill for GitLab CLI conventions, auth, MR lookup, pipeline jobs, and logs.
- Use `glab` inside the relevant git repository so host/project resolution works.
- Use `lark-im` when sending the final in-thread Lark notification.
- `lark-cli` must be configured with bot access and the bot must be in the chat before it can reply in the thread.

## Operating Rules

- Keep polling until the pipeline reaches `success`, `failed`, `canceled`, or `skipped`, or until a manual-intervention blocker is confirmed.
- Do not stop on `pending`, `running`, `created`, `preparing`, `waiting_for_resource`, or a quiet/unchanged poll.
- Treat a pipeline blocked on a required manual job as manual intervention, not as a retry candidate.
- Retry likely flaky failed jobs automatically, but use a small retry budget: default to 2 retry cycles per pipeline unless the user specified another limit.
- Retry only after inspecting failed job logs and classifying the failure as likely flaky or infrastructure-related.
- Do not retry deterministic failures, code failures, permission failures, missing secrets, required manual jobs, or errors that clearly need a developer/operator.
- Do not change code, commit, push, cancel pipelines, trigger deployments, or approve manual jobs unless the user explicitly asks.
- If classification is ambiguous, perform one deeper diagnosis pass; if still ambiguous, stop and ask for help instead of retrying blindly.

## Resolve The Target

When no explicit pipeline is supplied, infer it from the current branch/MR:

```bash
current_branch=$(git branch --show-current)
glab mr list --source-branch="$current_branch" --per-page=1
```

For structured MR data:

```bash
glab api "projects/<encoded-path>/merge_requests/<mr-iid>"
```

Get the latest pipeline from the MR `head_pipeline` when present; otherwise list recent pipelines for the source branch:

```bash
glab api "projects/<encoded-path>/pipelines?ref=<source-branch>&per_page=5"
```

## Polling Loop

Use this loop for live babysitting:

1. Fetch the pipeline and jobs.
2. If the pipeline is still pending/running, report only meaningful status changes and occasional heartbeat updates.
3. If any job has failed, fetch logs immediately and classify the failure before deciding whether to retry.
4. If the failure is likely flaky and retry budget remains, retry the failed jobs and continue watching the new job/pipeline state.
5. If the failure is non-flaky or needs manual intervention, stop and notify the requester with the failure reason and remedy steps.
6. If the pipeline reaches a terminal success/failure/canceled/skipped state, notify the requester in the Lark thread and provide the final summary.

Useful commands:

```bash
# Pipeline detail
glab api "projects/<encoded-path>/pipelines/<pipeline-id>"

# Jobs for a pipeline
glab api "projects/<encoded-path>/pipelines/<pipeline-id>/jobs?per_page=100"

# Failed job trace
glab api "projects/<encoded-path>/jobs/<job-id>/trace"

# Retry one failed job
glab ci retry <job-id>

# API fallback for retrying one failed job
glab api -X POST "projects/<encoded-path>/jobs/<job-id>/retry"
```

Use a base polling interval of about 60 seconds. Shorten it briefly after a retry or state transition. Avoid noisy updates when nothing changed.

## Failure Classification

Classify from job name, stage, status, and the last relevant log sections. Prefer reading enough logs to understand root cause rather than relying on the final line only.

Likely flaky or safe-to-retry examples:

- Runner lost, runner system failure, stuck job, provisioning failure
- Network timeout, DNS reset, TLS handshake timeout, connection reset
- Package registry, Docker registry, GitLab artifact, cache, or dependency download timeout
- Browser/e2e timeout with no deterministic assertion and a history of passing after rerun
- Explicit known flaky marker from the project docs or job output

Non-flaky or do-not-retry examples:

- Compile/typecheck/lint/test assertion failure tied to changed code
- Missing migration, failing unit snapshot, deterministic spec assertion
- Missing secret/variable, permission denied, protected environment restriction
- Required manual approval/job, deployment gate, blocked environment
- Quota/cost/rate-limit or infra problem that reruns would amplify
- Same flaky-looking job has already exhausted the retry budget

Manual intervention blockers:

- Required manual job or approval is waiting
- Credentials/secrets/scopes are missing
- Runner capacity or infrastructure outage persists after safe retry budget
- Failure cause is ambiguous after one deeper diagnosis pass
- Retrying requires business judgement, deploy approval, or changing code

## Retry Policy

Track retries in the session notes as `(pipeline_id, job_name or job_id, reason, attempt)`.

Before retrying, state the classification briefly in the progress update, for example:

```text
CI failed in e2e-chrome due to a browser startup timeout, which looks flaky. Retrying failed job 12345 (attempt 1/2).
```

After retrying, continue polling. A retry is not a terminal outcome.

If the same failure repeats after the retry budget, stop and report it as requiring manual intervention with evidence from the logs.

## Lark Thread Notification

When the original request came from Lark, send the terminal or manual-intervention report as a reply in the same thread and mention the requester.

Use the Lark mention format:

```text
<at user_id="ou_xxx">Display Name</at>
```

Use `lark-cli im +messages-reply` with `--reply-in-thread`. The `--message-id` must be the original/root Lark message ID (`om_xxx`), not a thread ID. `chat_id` is not needed for this reply command. Prefer `--text` for exact formatting, or `--markdown` if a richer post is useful.

```bash
lark-cli im +messages-reply \
  --as bot \
  --message-id "<root-message-id>" \
  --reply-in-thread \
  --text $'<at user_id="<requester-open-id>">Requester</at> CI pipeline terminated: success\nPipeline: <url>\nSummary: ...'
```

If no Lark context exists, report in the current conversation instead. Do not invent an `open_id`, `chat_id`, or message ID.

## Final Report

On termination, report success or failure. Include:

- Mention of the requester when replying in Lark
- Project, MR/branch, pipeline ID, pipeline URL, and final SHA when available
- Final status: success, failed, canceled, skipped, or manual intervention required
- Jobs retried and retry count
- For failures: failed job names, concise root cause, log evidence, and why it was or was not considered flaky
- Any issues that require manual intervention
- Potential remedy steps

Failure remedy examples:

- Code/test failure: point to the failing assertion or compile error and suggest the relevant file/test area to fix.
- Missing secret/permission: name the missing variable/scope/environment approval if visible and suggest who needs to grant it.
- Required manual job: name the manual job/environment and say it needs an authorized human approval.
- Flaky retries exhausted: include retry count and suggest rerunning later or checking runner/service health.

## Output Tone

Be concise while monitoring. During long waits, only report state changes or occasional heartbeats. The final Lark reply should be self-contained so the requester can understand whether CI passed, failed, or needs them without reading the whole thread.
