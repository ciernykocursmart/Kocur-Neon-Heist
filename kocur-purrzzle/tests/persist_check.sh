#!/usr/bin/env bash
G="${1:-godot}"
$G --headless --path . -s res://tests/persist_a.gd 2>&1 | grep "A wrote" 
$G --headless --path . -s res://tests/persist_b.gd 2>&1 | grep "B persistence"
