#!/bin/bash
echo "🔍 Generating coverage reports..."

# Ensure coverage directory exists
mkdir -p coverage

# Generate coverage with LCOV report (exclude test files and test contracts)
forge coverage --report summary --report lcov --no-match-coverage "(^test/|_testContracts/|utils/)"

# Move lcov.info to coverage folder if it exists in root
if [ -f lcov.info ]; then
    mv lcov.info coverage/lcov.info
    echo "✅ Moved lcov.info to coverage folder"
elif [ -f coverage/lcov.info ]; then
    echo "ℹ️  lcov.info already in coverage folder"
else
    echo "⚠️  lcov.info not found - coverage may have failed"
    exit 1
fi

# Generate HTML report from LCOV if genhtml is available
if command -v genhtml &> /dev/null; then
    echo "📄 Generating HTML report..."
    # Generate HTML report with branch coverage and function coverage
    genhtml coverage/lcov.info -o coverage/lcov-report --branch-coverage --ignore-errors inconsistent > /dev/null 2>&1
    if [ -f coverage/lcov-report/index.html ]; then
        # Extract statements coverage from forge summary and inject into HTML report headers
        echo "📊 Adding statements coverage to report headers..."
        
        # Get statements coverage data for Token.sol (format: "100.00% (234/234)")
        STATEMENTS_LINE=$(forge coverage --report summary --no-match-coverage "(^test/|_testContracts/|utils/)" 2>&1 | grep "Token.sol")
        if [ ! -z "$STATEMENTS_LINE" ]; then
            # Extract: percentage, total, hit from the statements column (4th column)
            STATEMENTS_PCT=$(echo "$STATEMENTS_LINE" | awk -F'|' '{print $4}' | awk '{print $1}' | tr -d ' ')
            STATEMENTS_TOTAL=$(echo "$STATEMENTS_LINE" | awk -F'|' '{print $4}' | grep -o '[0-9]*/' | tr -d '/')
            STATEMENTS_HIT=$(echo "$STATEMENTS_LINE" | awk -F'|' '{print $4}' | grep -o '/[0-9]*' | tr -d '/')
            
            # Add statements row to header in all HTML files
            find coverage/lcov-report -name "*.html" -type f | while read htmlfile; do
                # Insert statements row after Functions row in header section (using BSD sed syntax for macOS)
                STATEMENTS_ROW="          <tr>\\
            <td></td>\\
            <td></td>\\
            <td></td>\\
            <td class=\"headerItem\">Statements:</td>\\
            <td class=\"headerCovTableEntryHi\">${STATEMENTS_PCT}</td>\\
            <td class=\"headerCovTableEntry\">${STATEMENTS_TOTAL}</td>\\
            <td class=\"headerCovTableEntry\">${STATEMENTS_HIT}</td>\\
          </tr>"
                # Use awk to insert after Functions row
                awk -v stmt_row="$STATEMENTS_ROW" '
                    /<td class="headerItem">Functions:<\/td>/ {found=1}
                    found && /<\/tr>/ && !inserted {
                        print
                        print stmt_row
                        inserted=1
                        found=0
                        next
                    }
                    {print}
                ' "$htmlfile" > "$htmlfile.tmp" && mv "$htmlfile.tmp" "$htmlfile" 2>/dev/null || true
            done
            echo "   ✅ Statements coverage added: ${STATEMENTS_PCT} (${STATEMENTS_HIT}/${STATEMENTS_TOTAL})"
        fi
        
        echo "✅ HTML report generated successfully!"
        echo "📊 View HTML report: open coverage/lcov-report/index.html"
    else
        echo "⚠️  HTML report generation failed (but LCOV file is available)"
    fi
else
    echo "⚠️  genhtml not found - install with: brew install lcov"
    echo "   LCOV file available at: coverage/lcov.info"
fi

echo ""
echo "✅ Coverage reports generated!"
