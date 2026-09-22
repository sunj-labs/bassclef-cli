#!/usr/bin/env bash
# Mock claude — reproduces the Cooper C1 pre-mortem risk.
# LLM interprets prompt as needing input; asks a clarifying question;
# no marker; no artifact. Positive-artifact check MUST catch this.
set -eu

echo "Which specific scope would you like /temperance applied to? Waiting for your input..."
exit 0
