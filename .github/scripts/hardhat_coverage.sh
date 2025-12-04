#!/bin/bash

FAIL=0

echo "Generating coverage report..."
COVERAGE_OUTPUT=$(npm run coverage:hardhat 2>&1)

# Display the coverage report
echo "=== Coverage Report ==="
echo "$COVERAGE_OUTPUT"
echo "======================="

TOTAL_LINE=$(echo "$COVERAGE_OUTPUT" | grep "All files.*|" | tr -d '\n\r')
if [ -z "$TOTAL_LINE" ]; then
    echo "❌ Could not find All files line"
    exit 1
fi

STMT_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $2}' | tr -d ' ' | sed 's/%//')
BRANCH_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $3}' | tr -d ' ' | sed 's/%//')
FUNC_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $4}' | tr -d ' ' | sed 's/%//')
LINE_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $5}' | tr -d ' ' | sed 's/%//')

# Check if coverage is 100%
if [ "$(echo "$STMT_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Statement coverage ($STMT_COV%) is below 100%"
    FAIL=1
fi

if [ "$(echo "$BRANCH_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Branch coverage ($BRANCH_COV%) is below 100%"
    FAIL=1
fi

if [ "$(echo "$FUNC_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Function coverage ($FUNC_COV%) is below 100%"
    FAIL=1
fi

if [ "$(echo "$LINE_COV < 100" | bc -l)" = "1" ]; then
    echo "❌ Line coverage ($LINE_COV%) is below 100%"
    FAIL=1
fi

if [ $FAIL = 1 ]; then
    echo ""
    echo "Coverage check failed! All coverage metrics must be 100%"
    exit 1
else
    echo "✅ Coverage requirements met!"
fi

