#!/bin/bash
# Quality checks for Familiar project
# Usage: ./scripts/check.sh [lint|format|test|all]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAILED=0

check_lint() {
    echo -e "${YELLOW}Running SwiftLint...${NC}"
    if [ -d "Familiar" ]; then
        if swiftlint lint --quiet 2>/dev/null; then
            echo -e "${GREEN}SwiftLint: PASSED${NC}"
        else
            echo -e "${RED}SwiftLint: FAILED${NC}"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}SwiftLint: SKIPPED (no source directory yet)${NC}"
    fi
}

check_format() {
    echo -e "${YELLOW}Running SwiftFormat lint...${NC}"
    if [ -d "Familiar" ]; then
        if swiftformat --lint Familiar/ 2>/dev/null; then
            echo -e "${GREEN}SwiftFormat: PASSED${NC}"
        else
            echo -e "${RED}SwiftFormat: FAILED (run 'swiftformat Familiar/' to fix)${NC}"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}SwiftFormat: SKIPPED (no source directory yet)${NC}"
    fi
}

check_build() {
    echo -e "${YELLOW}Building project...${NC}"
    if [ -f "Package.swift" ]; then
        if swift build 2>&1; then
            echo -e "${GREEN}Build: PASSED${NC}"
        else
            echo -e "${RED}Build: FAILED${NC}"
            FAILED=1
        fi
    elif [ -d "Familiar.xcodeproj" ]; then
        if xcodebuild -scheme Familiar -destination 'platform=macOS' build 2>&1 | tail -5; then
            echo -e "${GREEN}Build: PASSED${NC}"
        else
            echo -e "${RED}Build: FAILED${NC}"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}Build: SKIPPED (no project file yet)${NC}"
    fi
}

check_test() {
    echo -e "${YELLOW}Running tests...${NC}"
    if [ -f "Package.swift" ]; then
        if swift test 2>&1; then
            echo -e "${GREEN}Tests: PASSED${NC}"
        else
            echo -e "${RED}Tests: FAILED${NC}"
            FAILED=1
        fi
    elif [ -d "Familiar.xcodeproj" ]; then
        if xcodebuild -scheme Familiar -destination 'platform=macOS' test 2>&1 | tail -10; then
            echo -e "${GREEN}Tests: PASSED${NC}"
        else
            echo -e "${RED}Tests: FAILED${NC}"
            FAILED=1
        fi
    else
        echo -e "${YELLOW}Tests: SKIPPED (no project file yet)${NC}"
    fi
}

case "${1:-all}" in
    lint)    check_lint ;;
    format)  check_format ;;
    build)   check_build ;;
    test)    check_test ;;
    all)
        check_lint
        check_format
        check_build
        check_test
        ;;
    *)
        echo "Usage: $0 [lint|format|build|test|all]"
        exit 1
        ;;
esac

if [ $FAILED -ne 0 ]; then
    echo -e "\n${RED}CHECKS FAILED${NC}"
    exit 1
else
    echo -e "\n${GREEN}ALL CHECKS PASSED${NC}"
    exit 0
fi
