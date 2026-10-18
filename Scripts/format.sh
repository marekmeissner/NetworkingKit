#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift format format --in-place --recursive \
  "$PROJECT_ROOT/Sources" \
  "$PROJECT_ROOT/Tests"
