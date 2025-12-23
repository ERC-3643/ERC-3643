#!/bin/bash
echo "🔍 Generating coverage reports..."

# Ensure coverage directory exists
mkdir -p coverage

# Generate coverage with LCOV report
forge coverage --report summary --report lcov

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
    genhtml coverage/lcov.info -o coverage/lcov-report --no-function-coverage > /dev/null 2>&1
    if [ -f coverage/lcov-report/index.html ]; then
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
