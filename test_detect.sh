#!/usr/bin/env bash
echo "BASH_SOURCE[0]: ${BASH_SOURCE[0]}"
echo "0: $0"
echo "stdin: $([ -t 0 ] && echo "tty" || echo "pipe/redirect")"
