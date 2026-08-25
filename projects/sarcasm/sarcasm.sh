#!/bin/sh
# sarcasm — SAfe Runtime Capability-enforced Assembler. `as`-like CLI for Yolo-C
# ARM64/X86_64 assembly annotated with ;! Fil-C directives. Run `./sarcasm.sh --help`
# for usage.
exec lute "$(dirname "$0")/sarcasm-cli.luau" "$@"
