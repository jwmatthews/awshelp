# AWS Budget Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two scripts that verify and set up AWS Budgets billing alerts on a personal account, with account safety guards to prevent accidental runs on the wrong account.

**Architecture:** A shared `config.env` file holds all configurable values (account ID, email, budget amount, thresholds). Both scripts share an identical startup sequence: prerequisite checks → config load → AWS credential check → account safety guard with interactive confirmation. `check-budget.sh` is read-only audit; `setup-budget.sh` creates missing resources.

**Tech Stack:** Bash, AWS CLI v2, jq

---

## File Structure

| File | Responsibility |
|------|---------------|
| `content/projects/aws/config.env.example` | Template config with placeholder values — checked into git |
| `content/projects/aws/config.env` | User's actual config with real account ID/email — gitignored |
| `content/projects/aws/common.sh` | Shared functions: prerequisite checks, config loading, account guard |
| `content/projects/aws/check-budget.sh` | Read-only audit of SNS topic, subscription, and budget thresholds |
| `content/projects/aws/setup-budget.sh` | Creates missing SNS topic, subscription, and budget |
| `content/projects/aws/.gitignore` | Ignores `config.env` to prevent committing real credentials |

**Why `common.sh`?** Both scripts have an identical startup sequence (~60 lines). Duplicating it means bugs get fixed in one script but not the other. A shared source file keeps them in sync.

---

### Task 1: Create config files and .gitignore

**Files:**
- Create: `content/projects/aws/config.env.example`
- Create: `content/projects/aws/.gitignore`

- [ ] **Step 1: Create `config.env.example`**

```bash
# AWS Budget Guard configuration
# Copy this file to config.env and fill in your values:
#   cp config.env.example config.env

# Your personal AWS account ID (12-digit number from aws sts get-caller-identity)
AWS_ALLOWED_ACCOUNT_ID=""

# Email address for billing alert notifications
AWS_ALLOWED_ACCOUNT_EMAIL=""

# Budget settings
BUDGET_NAME="monthly-cost-budget"
BUDGET_AMOUNT="100"
SNS_TOPIC_NAME="billing-alerts"
AWS_REGION="us-east-1"
```

- [ ] **Step 2: Create `.gitignore`**

```
config.env
```

- [ ] **Step 3: Verify config.env.example is sourceable**

Run:
```bash
cd content/projects/aws
bash -c 'source config.env.example && echo "BUDGET_NAME=$BUDGET_NAME BUDGET_AMOUNT=$BUDGET_AMOUNT"'
```

Expected output:
```
BUDGET_NAME=monthly-cost-budget BUDGET_AMOUNT=100
```

- [ ] **Step 4: Create the user's actual `config.env`**

Copy the example and fill in the personal account ID. Get the account ID from the user or leave it for them to fill in:

```bash
cp config.env.example config.env
```

Edit `config.env` to set `AWS_ALLOWED_ACCOUNT_ID` and `AWS_ALLOWED_ACCOUNT_EMAIL` to the user's personal account values.

- [ ] **Step 5: Verify `.gitignore` works**

Run:
```bash
cd content/projects/aws
git status --short config.env config.env.example
```

Expected: `config.env.example` shows as untracked (will be committed), `config.env` does NOT appear (gitignored).

- [ ] **Step 6: Commit**

```bash
git add content/projects/aws/config.env.example content/projects/aws/.gitignore
git commit -m "feat(aws): add budget guard config template and gitignore"
```

---

### Task 2: Create shared startup functions (`common.sh`)

**Files:**
- Create: `content/projects/aws/common.sh`

This file is sourced by both scripts. It provides three functions and one variable:

- `SCRIPT_DIR` — resolved directory of the calling script (used to locate `config.env`)
- `check_prerequisites` — verifies aws, jq are installed; checks all before exiting
- `load_config` — sources `config.env`, validates required vars are non-empty
- `verify_account` — calls `sts get-caller-identity`, compares account, prompts for confirmation

- [ ] **Step 1: Create `common.sh`**

```bash
#!/bin/bash
# common.sh — Shared startup functions for AWS Budget Guard scripts
# Source this file, do not execute it directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

check_prerequisites() {
    local missing=0

    if ! command -v aws &>/dev/null; then
        echo "ERROR: AWS CLI not found."
        echo "  Install via: brew install awscli"
        missing=1
    fi

    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq not found."
        echo "  Install via: brew install jq"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        echo ""
        echo "Install the missing dependencies above and try again."
        exit 1
    fi
}

load_config() {
    local config_file="$SCRIPT_DIR/config.env"

    if [[ ! -f "$config_file" ]]; then
        echo "ERROR: config.env not found at $config_file"
        echo "  Copy the example and fill in your values:"
        echo "  cp config.env.example config.env"
        exit 1
    fi

    source "$config_file"

    local missing=0

    if [[ -z "$AWS_ALLOWED_ACCOUNT_ID" ]]; then
        echo "ERROR: AWS_ALLOWED_ACCOUNT_ID is not set in config.env"
        missing=1
    fi

    if [[ -z "$AWS_ALLOWED_ACCOUNT_EMAIL" ]]; then
        echo "ERROR: AWS_ALLOWED_ACCOUNT_EMAIL is not set in config.env"
        missing=1
    fi

    if [[ -z "$BUDGET_NAME" ]]; then
        echo "ERROR: BUDGET_NAME is not set in config.env"
        missing=1
    fi

    if [[ -z "$BUDGET_AMOUNT" ]]; then
        echo "ERROR: BUDGET_AMOUNT is not set in config.env"
        missing=1
    fi

    if [[ -z "$SNS_TOPIC_NAME" ]]; then
        echo "ERROR: SNS_TOPIC_NAME is not set in config.env"
        missing=1
    fi

    if [[ -z "$AWS_REGION" ]]; then
        echo "ERROR: AWS_REGION is not set in config.env"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        echo ""
        echo "Fill in the missing values in config.env and try again."
        exit 1
    fi
}

verify_account() {
    local identity
    identity=$(aws sts get-caller-identity --output json 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to get AWS identity. Are your credentials configured?"
        echo "  Source your personal account credentials before running."
        echo ""
        echo "  AWS error: $identity"
        exit 1
    fi

    local account_id
    local arn
    account_id=$(echo "$identity" | jq -r '.Account')
    arn=$(echo "$identity" | jq -r '.Arn')

    if [[ "$account_id" != "$AWS_ALLOWED_ACCOUNT_ID" ]]; then
        echo "ERROR: Wrong AWS account!"
        echo ""
        echo "  Current account: $account_id"
        echo "  Current ARN:     $arn"
        echo "  Expected account: $AWS_ALLOWED_ACCOUNT_ID"
        echo ""
        echo "  This is NOT your personal account. Exiting."
        exit 1
    fi

    echo "AWS Account: $account_id"
    echo "ARN:         $arn"
    echo ""
    read -r -p "You are running as the above identity on personal account $account_id. Continue? (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
}
```

- [ ] **Step 2: Verify `common.sh` is syntactically valid**

Run:
```bash
bash -n content/projects/aws/common.sh
```

Expected: no output (exit 0 = valid syntax).

- [ ] **Step 3: Test the prerequisite check works**

Run:
```bash
bash -c '
  BASH_SOURCE[1]="content/projects/aws/test"
  source content/projects/aws/common.sh
  check_prerequisites
  echo "Prerequisites OK"
'
```

Expected output (assuming aws and jq are installed):
```
Prerequisites OK
```

- [ ] **Step 4: Commit**

```bash
git add content/projects/aws/common.sh
git commit -m "feat(aws): add shared startup functions for budget guard scripts"
```

---

### Task 3: Create check script (`check-budget.sh`)

**Files:**
- Create: `content/projects/aws/check-budget.sh`

- [ ] **Step 1: Create `check-budget.sh`**

```bash
#!/bin/bash
# check-budget.sh — Read-only audit of AWS billing safeguards
set -euo pipefail

source "$(dirname "$0")/common.sh"

check_prerequisites
load_config
verify_account

FAILURES=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }

echo "Checking AWS billing safeguards..."
echo ""

# --- Check 1: SNS topic exists ---
echo "SNS Topic ($SNS_TOPIC_NAME):"
TOPIC_ARN=$(aws sns list-topics --region "$AWS_REGION" --output json \
    | jq -r --arg name "$SNS_TOPIC_NAME" '.Topics[].TopicArn | select(endswith(":" + $name))')

if [[ -n "$TOPIC_ARN" ]]; then
    pass "Topic exists: $TOPIC_ARN"
else
    fail "Topic '$SNS_TOPIC_NAME' not found in $AWS_REGION"
fi

# --- Check 2: Confirmed email subscription ---
echo ""
echo "SNS Email Subscription:"
if [[ -n "$TOPIC_ARN" ]]; then
    CONFIRMED_SUBS=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$AWS_REGION" --output json \
        | jq -r '.Subscriptions[] | select(.Protocol == "email" and .SubscriptionArn != "PendingConfirmation") | .Endpoint')

    if [[ -n "$CONFIRMED_SUBS" ]]; then
        pass "Confirmed email subscription(s): $CONFIRMED_SUBS"
    else
        PENDING=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$AWS_REGION" --output json \
            | jq -r '.Subscriptions[] | select(.Protocol == "email" and .SubscriptionArn == "PendingConfirmation") | .Endpoint')
        if [[ -n "$PENDING" ]]; then
            fail "Email subscription exists but is PENDING confirmation: $PENDING (check your inbox)"
        else
            fail "No email subscription found on topic"
        fi
    fi
else
    fail "Cannot check subscriptions — topic does not exist"
fi

# --- Check 3: Budget exists ---
echo ""
echo "AWS Budget ($BUDGET_NAME):"
BUDGET_JSON=$(aws budgets describe-budget \
    --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
    --budget-name "$BUDGET_NAME" \
    --output json 2>/dev/null || echo "")

if [[ -n "$BUDGET_JSON" ]]; then
    BUDGET_LIMIT=$(echo "$BUDGET_JSON" | jq -r '.Budget.BudgetLimit.Amount')
    pass "Budget exists with limit: \$$BUDGET_LIMIT/month"
else
    fail "Budget '$BUDGET_NAME' not found"
fi

# --- Check 4-6: Threshold notifications ---
echo ""
echo "Budget Notifications:"
if [[ -n "$BUDGET_JSON" ]]; then
    NOTIFICATIONS_JSON=$(aws budgets describe-notifications-for-budget \
        --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
        --budget-name "$BUDGET_NAME" \
        --output json 2>/dev/null || echo '{"Notifications":[]}')

    for THRESHOLD in 50.0 80.0 100.0; do
        DISPLAY_PCT=$(echo "$THRESHOLD" | sed 's/\.0$//')
        MATCH=$(echo "$NOTIFICATIONS_JSON" | jq --arg t "$THRESHOLD" \
            '.Notifications[] | select(.NotificationType == "ACTUAL" and .ComparisonOperator == "GREATER_THAN" and (.Threshold | tostring) == $t)')

        if [[ -n "$MATCH" ]]; then
            # Check if this notification has the SNS topic as a subscriber
            SUBSCRIBERS_JSON=$(aws budgets describe-subscribers-for-notification \
                --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
                --budget-name "$BUDGET_NAME" \
                --notification "$(echo "$NOTIFICATIONS_JSON" | jq -c --arg t "$THRESHOLD" \
                    '.Notifications[] | select(.NotificationType == "ACTUAL" and .ComparisonOperator == "GREATER_THAN" and (.Threshold | tostring) == $t)')" \
                --output json 2>/dev/null || echo '{"Subscribers":[]}')

            HAS_SNS=$(echo "$SUBSCRIBERS_JSON" | jq --arg arn "$TOPIC_ARN" \
                '.Subscribers[] | select(.SubscriptionType == "SNS" and .Address == $arn)')

            if [[ -n "$HAS_SNS" ]]; then
                pass "${DISPLAY_PCT}% threshold notification wired to SNS topic"
            else
                fail "${DISPLAY_PCT}% threshold exists but is NOT wired to SNS topic"
            fi
        else
            fail "${DISPLAY_PCT}% threshold notification not configured"
        fi
    done
else
    fail "Cannot check notifications — budget does not exist"
    fail "Cannot check notifications — budget does not exist"
    fail "Cannot check notifications — budget does not exist"
fi

# --- Summary ---
echo ""
echo "---"
if [[ $FAILURES -eq 0 ]]; then
    echo "All checks passed."
    exit 0
else
    echo "$FAILURES issue(s) found — run setup-budget.sh to fix."
    exit 1
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x content/projects/aws/check-budget.sh
```

- [ ] **Step 3: Verify syntax is valid**

Run:
```bash
bash -n content/projects/aws/check-budget.sh
```

Expected: no output (exit 0).

- [ ] **Step 4: Dry-run the script to verify startup sequence**

Run the script with personal credentials sourced. It should prompt for account confirmation. Type `y` and let it run the audit. If no budget is set up yet, expect all checks to fail — that's correct and confirms the check script works.

```bash
content/projects/aws/check-budget.sh
```

Expected output pattern:
```
AWS Account: <account-id>
ARN:         <arn>

You are running as the above identity on personal account <id>. Continue? (y/N) y

Checking AWS billing safeguards...

SNS Topic (billing-alerts):
  ✗ Topic 'billing-alerts' not found in us-east-1
...
6 issue(s) found — run setup-budget.sh to fix.
```

- [ ] **Step 5: Commit**

```bash
git add content/projects/aws/check-budget.sh
git commit -m "feat(aws): add check-budget.sh for billing safeguard audit"
```

---

### Task 4: Create setup script (`setup-budget.sh`)

**Files:**
- Create: `content/projects/aws/setup-budget.sh`

- [ ] **Step 1: Create `setup-budget.sh`**

```bash
#!/bin/bash
# setup-budget.sh — Create missing AWS billing safeguards
set -euo pipefail

source "$(dirname "$0")/common.sh"

check_prerequisites
load_config
verify_account

echo "Setting up AWS billing safeguards..."
echo ""

# --- Step 1: SNS Topic ---
echo "SNS Topic ($SNS_TOPIC_NAME):"
TOPIC_ARN=$(aws sns list-topics --region "$AWS_REGION" --output json \
    | jq -r --arg name "$SNS_TOPIC_NAME" '.Topics[].TopicArn | select(endswith(":" + $name))')

if [[ -n "$TOPIC_ARN" ]]; then
    echo "  Already exists: $TOPIC_ARN"
else
    TOPIC_ARN=$(aws sns create-topic --name "$SNS_TOPIC_NAME" --region "$AWS_REGION" --output json \
        | jq -r '.TopicArn')
    echo "  Created: $TOPIC_ARN"
fi

# --- Step 2: Email Subscription ---
echo ""
echo "SNS Email Subscription:"
EXISTING_SUB=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$AWS_REGION" --output json \
    | jq -r --arg email "$AWS_ALLOWED_ACCOUNT_EMAIL" \
        '.Subscriptions[] | select(.Protocol == "email" and .Endpoint == $email) | .SubscriptionArn')

if [[ -n "$EXISTING_SUB" ]]; then
    if [[ "$EXISTING_SUB" == "PendingConfirmation" ]]; then
        echo "  Subscription exists but is PENDING confirmation."
        echo "  Check your inbox for a confirmation email from AWS."
    else
        echo "  Already subscribed and confirmed: $AWS_ALLOWED_ACCOUNT_EMAIL"
    fi
else
    aws sns subscribe \
        --topic-arn "$TOPIC_ARN" \
        --protocol email \
        --notification-endpoint "$AWS_ALLOWED_ACCOUNT_EMAIL" \
        --region "$AWS_REGION" \
        --output json > /dev/null
    echo "  Subscribed: $AWS_ALLOWED_ACCOUNT_EMAIL"
    echo "  IMPORTANT: Check your inbox and click the confirmation link from AWS."
fi

# --- Step 3: Budget ---
echo ""
echo "AWS Budget ($BUDGET_NAME):"
BUDGET_EXISTS=$(aws budgets describe-budget \
    --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
    --budget-name "$BUDGET_NAME" \
    --output json 2>/dev/null || echo "")

if [[ -n "$BUDGET_EXISTS" ]]; then
    BUDGET_LIMIT=$(echo "$BUDGET_EXISTS" | jq -r '.Budget.BudgetLimit.Amount')
    echo "  Budget already exists with limit: \$$BUDGET_LIMIT/month"
    echo ""

    # Check if thresholds match expected configuration
    NOTIFICATIONS_JSON=$(aws budgets describe-notifications-for-budget \
        --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
        --budget-name "$BUDGET_NAME" \
        --output json 2>/dev/null || echo '{"Notifications":[]}')

    NOTIF_COUNT=$(echo "$NOTIFICATIONS_JSON" | jq '.Notifications | length')

    EXPECTED_OK=true
    for THRESHOLD in 50.0 80.0 100.0; do
        MATCH=$(echo "$NOTIFICATIONS_JSON" | jq --arg t "$THRESHOLD" \
            '.Notifications[] | select(.NotificationType == "ACTUAL" and .ComparisonOperator == "GREATER_THAN" and (.Threshold | tostring) == $t)')
        if [[ -z "$MATCH" ]]; then
            EXPECTED_OK=false
            break
        fi
    done

    if [[ "$EXPECTED_OK" == "true" ]]; then
        echo "  Budget has all expected notification thresholds (50%, 80%, 100%)."
    else
        echo "  WARNING: Budget exists but has unexpected notification configuration."
        echo "  Current notification count: $NOTIF_COUNT"
        echo "  To reset, delete the budget manually and re-run this script:"
        echo "    aws budgets delete-budget --account-id $AWS_ALLOWED_ACCOUNT_ID --budget-name $BUDGET_NAME"
    fi
else
    aws budgets create-budget \
        --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
        --budget "{
            \"BudgetName\": \"$BUDGET_NAME\",
            \"BudgetLimit\": {
                \"Amount\": \"$BUDGET_AMOUNT\",
                \"Unit\": \"USD\"
            },
            \"BudgetType\": \"COST\",
            \"TimeUnit\": \"MONTHLY\"
        }" \
        --notifications-with-subscribers "[
            {
                \"Notification\": {
                    \"NotificationType\": \"ACTUAL\",
                    \"ComparisonOperator\": \"GREATER_THAN\",
                    \"Threshold\": 50.0,
                    \"ThresholdType\": \"PERCENTAGE\"
                },
                \"Subscribers\": [{
                    \"SubscriptionType\": \"SNS\",
                    \"Address\": \"$TOPIC_ARN\"
                }]
            },
            {
                \"Notification\": {
                    \"NotificationType\": \"ACTUAL\",
                    \"ComparisonOperator\": \"GREATER_THAN\",
                    \"Threshold\": 80.0,
                    \"ThresholdType\": \"PERCENTAGE\"
                },
                \"Subscribers\": [{
                    \"SubscriptionType\": \"SNS\",
                    \"Address\": \"$TOPIC_ARN\"
                }]
            },
            {
                \"Notification\": {
                    \"NotificationType\": \"ACTUAL\",
                    \"ComparisonOperator\": \"GREATER_THAN\",
                    \"Threshold\": 100.0,
                    \"ThresholdType\": \"PERCENTAGE\"
                },
                \"Subscribers\": [{
                    \"SubscriptionType\": \"SNS\",
                    \"Address\": \"$TOPIC_ARN\"
                }]
            }
        ]"

    echo "  Created budget: $BUDGET_NAME (\$$BUDGET_AMOUNT/month)"
    echo "  Notifications configured at 50%, 80%, 100% thresholds"
    echo "  All wired to SNS topic: $TOPIC_ARN"
fi

# --- Summary ---
echo ""
echo "---"
echo "Setup complete. Run check-budget.sh to verify everything is configured correctly."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x content/projects/aws/setup-budget.sh
```

- [ ] **Step 3: Verify syntax is valid**

Run:
```bash
bash -n content/projects/aws/setup-budget.sh
```

Expected: no output (exit 0).

- [ ] **Step 4: Commit**

```bash
git add content/projects/aws/setup-budget.sh
git commit -m "feat(aws): add setup-budget.sh to create billing safeguards"
```

---

### Task 5: End-to-end verification

**Files:** No new files — this task validates the complete flow.

- [ ] **Step 1: Run check-budget.sh on personal account (expect failures)**

Source personal account credentials, then run:

```bash
content/projects/aws/check-budget.sh
```

Expected: Account confirmation prompt, then audit showing all checks failing (nothing set up yet). Exit code 1.

- [ ] **Step 2: Run setup-budget.sh on personal account**

```bash
content/projects/aws/setup-budget.sh
```

Expected: Account confirmation prompt, then creates SNS topic, subscribes email, creates budget with 3 thresholds. Prints reminder to confirm email subscription.

- [ ] **Step 3: Run check-budget.sh again (expect passes)**

```bash
content/projects/aws/check-budget.sh
```

Expected: All 6 checks pass (email subscription may show as pending if not yet confirmed — that's the one expected manual step). Exit code 0 (or 1 if email is still pending).

- [ ] **Step 4: Verify wrong-account guard works**

Without sourcing personal credentials (using default work account):

```bash
content/projects/aws/check-budget.sh
```

Expected: Immediately prints "Wrong AWS account!" error with account details and exits. No audit runs. No confirmation prompt.

- [ ] **Step 5: Confirm email subscription**

Check inbox for the AWS SNS confirmation email and click the link. Then re-run check-budget.sh to verify the subscription shows as confirmed.

- [ ] **Step 6: Final commit**

```bash
git add -A content/projects/aws/
git commit -m "feat(aws): complete budget guard setup — verified end-to-end"
```
