#!/bin/bash
term_cols=100
awk -v term_cols="$term_cols" 'BEGIN {
    BOLD="\033[1m"; RESET="\033[0m"; GREY="\033[90m"; col=RESET; sym="[ ]"
    
    # Test Cases
    pkgs[1]="short-pkg"; vers[1]="1.0"; descs[1]="Short description"
    pkgs[2]="very-long-package-name-that-exceeds-limit-surely"; vers[2]="1.2.3-r4"; descs[2]="Description"
    pkgs[3]="pkg"; vers[3]="1.0-very-long-version-string"; descs[3]="Desc"
    pkgs[4]="pkg"; vers[4]="1.0"; descs[4]="Very long description that should be truncated because it exceeds the remaining space in the terminal window which is set to 100 columns for this test."
    
    printf "_\t%s   %-30s %-20s %s%s\n", BOLD, "Name", "Version", "Description", RESET

    for (i=1; i<=4; i++) {
        pkg = pkgs[i]
        ver_info = vers[i]
        display = descs[i]
        
        # Logic from pmget
        w_pkg = 30
        w_ver = 20
        w_desc = term_cols - w_pkg - w_ver - 15
        if (w_desc < 10) w_desc = 10

        d_pkg = pkg
        if (length(d_pkg) > w_pkg) d_pkg = substr(d_pkg, 1, w_pkg-1) "…"
        
        d_desc = display
        if (length(d_desc) > w_desc) d_desc = substr(d_desc, 1, w_desc-1) "…"

        clean_ver = ver_info
        gsub(/\x1b\[[0-9;]*m/, "", clean_ver)
        pad_ver = w_ver - length(clean_ver)
        if (pad_ver < 0) pad_ver = 0
        spaces = "                                                  "
        padding_ver = substr(spaces, 1, pad_ver)

        printf "%s\t%s%s %-*s%s %s%s %s%s %s%s%s\n", pkg, col, sym, w_pkg, d_pkg, RESET, ver_info, padding_ver, GREY, d_desc, RESET, ""
    }
}'
