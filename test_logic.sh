#!/bin/bash

# Test APK sed logic
echo "Testing APK sed..."
input="bash-5.1.16-r0 - The GNU Project Bourne Again Shell"
# Current regex (simplified)
echo "$input" | sed -E 's/(.*)-([0-9].*)/\1\t\2\t\1/'
# Output: bash	5.1.16-r0 - The GNU Project Bourne Again Shell	bash

# Proposed regex
# We want: Name \t Version \t Description
# Logic: Split on first hyphen followed by digit? No, package names can have digits?
# APK format: name-ver-rel.
# Usually last hyphen separates version? No.
# `apk search -v` says:
# "package-version description" (no hyphen?) or " - description"?
# Let's assume input has " - " separator for description if present.
# And name-version is separated by hyphen.
# Version starts with digit.

echo "Proposed:"
echo "$input" | sed -E 's/^([^ ]+)-([0-9][^ ]*) - (.*)$/\1\t\2\t\3/'

# Test complex package name
input2="libxx-2.0.0 - Description"
echo "$input2" | sed -E 's/^([^ ]+)-([0-9][^ ]*) - (.*)$/\1\t\2\t\3/'

# Test AWK truncation logic
echo "Testing AWK..."
cat << 'EOF' > test.awk
{
    pkg = $1
    ver = $2
    
    # Name Truncation (Max 30)
    limit_name = 30
    display_pkg = pkg
    if (length(pkg) > limit_name) {
        display_pkg = substr(pkg, 1, limit_name)
    }
    
    # Calculate padding based on LIMIT, not full length
    # If we allow 30 chars for name, we want padding to reach column 32 (padding 2)
    # len = length(display_pkg) + 4 ??
    # Existing code: len = length(pkg) + 4; pad = 36 - len
    
    # New logic:
    # Fixed width column for name. e.g. 35 chars.
    # Printf %-35s ?
    # But we need color codes.
    
    col = "[+]"
    reset = "[R]"
    sym = "[S]"
    
    # Construct "Field 2"
    # We want: col sym display_pkg reset padding
    
    # If display_pkg is 30 chars.
    # Total visual length = 3 (sym) + 1 (space) + 30 (name) = 34.
    # If we want constant width, e.g. 40.
    # Pad = 40 - visual_length.
    
    vis_len = 4 + length(display_pkg)
    pad_len = 40 - vis_len
    if (pad_len < 1) pad_len = 1
    padding = ""
    for(i=0; i<pad_len; i++) padding = padding " "
    
    print display_pkg "|" padding "|" ver
}
EOF

echo "short-pkg 1.0" | awk -f test.awk
echo "very-long-package-name-that-should-be-truncated-somewhere 2.0" | awk -f test.awk

