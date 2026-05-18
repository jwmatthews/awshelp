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
        MATCH=$(echo "$NOTIFICATIONS_JSON" | jq --argjson t "$THRESHOLD" \
            '.Notifications[] | select(.NotificationType == "ACTUAL" and .ComparisonOperator == "GREATER_THAN" and .Threshold == $t)')

        if [[ -n "$MATCH" ]]; then
            # Check if this notification has the SNS topic as a subscriber
            SUBSCRIBERS_JSON=$(aws budgets describe-subscribers-for-notification \
                --account-id "$AWS_ALLOWED_ACCOUNT_ID" \
                --budget-name "$BUDGET_NAME" \
                --notification "$(echo "$NOTIFICATIONS_JSON" | jq -c --argjson t "$THRESHOLD" \
                    '.Notifications[] | select(.NotificationType == "ACTUAL" and .ComparisonOperator == "GREATER_THAN" and .Threshold == $t)')" \
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
    fail "50% threshold — cannot check, budget does not exist"
    fail "80% threshold — cannot check, budget does not exist"
    fail "100% threshold — cannot check, budget does not exist"
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
