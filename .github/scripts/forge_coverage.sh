#!/bin/bash

echo "Generating coverage report..."
COVERAGE_OUTPUT=$(forge coverage --no-match-coverage "(^test/|_testContracts/|utils/)" --ir-minimum 2>&1)
          
# Display the coverage report
echo "=== Coverage Report ==="
echo "$COVERAGE_OUTPUT"
echo "======================="

TOTAL_LINE=$(echo "$COVERAGE_OUTPUT" | grep "| Total.*|")
if [ -z "$TOTAL_LINE" ]; then
    echo "❌ Could not find Total coverage line"
    exit 1
fi

# Extract and display coverage metrics
# Format: | Total | 85.41% (1153/1350) | 84.95% (1095/1289) | 29.48% (125/424) | 87.74% (272/310) |
LINE_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $3}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')
STMT_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $4}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')
BRANCH_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $5}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')
FUNC_COV=$(echo "$TOTAL_LINE" | awk -F'|' '{print $6}' | grep -o '[0-9]*\.[0-9]*%' | sed 's/%//')

echo ""
echo "📊 Coverage Summary:"
echo "  Line coverage:     ${LINE_COV}%"
echo "  Statement coverage: ${STMT_COV}%"
echo "  Branch coverage:   ${BRANCH_COV}%"
echo "  Function coverage: ${FUNC_COV}%"
echo ""
echo "✅ Coverage report generated successfully!"
