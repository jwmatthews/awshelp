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
        MATCH=$(echo "$NOTIFICATIONS_JSON" | jq --argjson t "$THRESHOLD" \
            '.Notifications[] | select(.NotificationType == "ACTUAL" and .ComparisonOperator == "GREATER_THAN" and .Threshold == $t)')
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
