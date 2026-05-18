# AWS Budget Guard — Design Spec

**Date:** 2026-05-16
**Status:** Approved
**Location:** `content/projects/aws/`

## Problem

AWS accounts can accumulate unexpected charges without warning. The user has multiple AWS accounts (personal and work) and needs:

1. A way to verify that billing safeguards are in place on the personal account
2. A way to set up those safeguards if missing
3. Hard protection against accidentally running setup scripts on the wrong account

## Solution

Two bash scripts and a configuration file in `content/projects/aws/`:

| File | Purpose |
|------|---------|
| `config.env` | Allowed account ID and email — sourced by both scripts |
| `check-budget.sh` | Read-only audit: reports what's configured and what's missing |
| `setup-budget.sh` | Creates missing resources (SNS topic, subscription, budget) |

## Configuration File: `config.env`

Shell-sourceable key-value file:

```bash
AWS_ALLOWED_ACCOUNT_ID="<personal-account-id>"
AWS_ALLOWED_ACCOUNT_EMAIL="<personal-email>"
BUDGET_NAME="monthly-cost-budget"
BUDGET_AMOUNT="100"
SNS_TOPIC_NAME="billing-alerts"
AWS_REGION="us-east-1"
```

All configurable values live here. Scripts source this file and refuse to run if it's missing.

## Account Safety Guard

Both scripts implement the same guard on startup:

1. Source `config.env` (exit if missing)
2. Call `aws sts get-caller-identity` to get current account ID and ARN
3. Compare account ID against `AWS_ALLOWED_ACCOUNT_ID`
4. **Wrong account** → print error identifying the account, state it is not the personal account, exit 1 immediately. No confirmation prompt, no chance of proceeding.
5. **Correct account** → display account ID and ARN, prompt: `"You are running as [ARN] on personal account [ID]. Continue? (y/N)"`. Default is No. Wait for explicit `y`.

## AWS Resources

All resources are created in `us-east-1` (required for AWS billing data).

### 1. SNS Topic: `billing-alerts`

Standard SNS topic used as the notification delivery channel for budget alerts.

### 2. SNS Email Subscription

The user's email address (`AWS_ALLOWED_ACCOUNT_EMAIL` from config) subscribed to the `billing-alerts` topic. Requires a one-time manual confirmation click in the user's inbox after creation.

### 3. AWS Budget: `monthly-cost-budget`

A single COST-type budget with:

- **Amount:** $100/month
- **Time unit:** MONTHLY
- **Three notification thresholds:**

| Threshold | Amount | Purpose |
|-----------|--------|---------|
| 50% | $50 | Heads up — halfway through budget |
| 80% | $80 | Warning — approaching limit, investigate |
| 100% | $100 | Limit reached — take action |

- **Notification type:** ACTUAL (based on real spend, not forecasted)
- **Comparison:** GREATER_THAN
- **Subscriber:** The `billing-alerts` SNS topic ARN

## Check Script: `check-budget.sh`

Performs read-only audit and reports pass/fail for each item:

1. ✓/✗ SNS topic `billing-alerts` exists in `us-east-1`
2. ✓/✗ At least one confirmed email subscription on the topic
3. ✓/✗ Budget `monthly-cost-budget` exists
4. ✓/✗ Budget has 50% threshold notification wired to SNS topic
5. ✓/✗ Budget has 80% threshold notification wired to SNS topic
6. ✓/✗ Budget has 100% threshold notification wired to SNS topic

Prints a summary at the end: "All checks passed" or "N issues found — run setup-budget.sh to fix".

Exit code: 0 if all pass, 1 if any fail.

## Setup Script: `setup-budget.sh`

Creates only what doesn't already exist:

1. **SNS topic** — create if `billing-alerts` topic not found
2. **Email subscription** — subscribe email if no confirmed subscription exists. Print reminder to check inbox for confirmation email.
3. **Budget** — create `monthly-cost-budget` with all three thresholds if no budget by that name exists

If the budget exists but is missing thresholds, the script reports this discrepancy but does NOT modify the existing budget. It prints: "Budget exists but has unexpected configuration. Delete it manually and re-run this script if you want a fresh setup."

Each step prints what it's doing and whether it created or skipped the resource.

## What This Does NOT Do

- **No automatic spend-stopping actions.** Alerts are notification-only. The user decides what to shut down.
- **No CloudWatch alarms.** AWS Budgets handles everything needed.
- **No modification of existing budgets.** Setup is create-only to avoid overwriting intentional customizations.
- **No work account interaction.** Both scripts hard-block on any account that isn't the configured personal account.

## Dependencies & Prerequisite Check

Both scripts run a prerequisite check before anything else (before even sourcing `config.env`). If any dependency is missing, the script prints what's missing with install instructions and exits 1 immediately. It checks all dependencies before exiting so the user sees everything needed in one pass, not one at a time.

| Dependency | Check | Install instruction |
|------------|-------|-------------------|
| AWS CLI v2 | `command -v aws` | "Install via: brew install awscli" |
| `jq` | `command -v jq` | "Install via: brew install jq" |
| `config.env` | file exists alongside script | "Copy config.env.example and fill in your account details" |
| AWS credentials | `aws sts get-caller-identity` succeeds | "Source your personal account credentials before running" |

Startup order: check tools → check config.env → check AWS credentials → account safety guard → script logic.
