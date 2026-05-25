#!/bin/bash

# =========================
# Bootstrap stages
# =========================

CURRENT_STAGE=1
: "${TOTAL_STAGES:=5}"

STAGE_START_TIME=$SECONDS

print_stage() {

    local now elapsed title

    title="${1:-Procesando}"

    now=$SECONDS
    elapsed=$((now - STAGE_START_TIME))

    if [[ "$CURRENT_STAGE" -gt 1 ]]; then
        echo ""
        printf "${BLUE}⏱️ Etapa anterior completada en %ss${NC}\n" "$elapsed"
    fi

    STAGE_START_TIME=$SECONDS

    echo ""

    printf "${BLUE}[%s/%s]${NC} %s\n" \
        "$CURRENT_STAGE" \
        "$TOTAL_STAGES" \
        "$title"

    CURRENT_STAGE=$((CURRENT_STAGE + 1))
}