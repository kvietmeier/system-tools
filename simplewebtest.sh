#!/bin/bash
# ------------------------------------------------------------------------------
# test_web.sh - Simple test of web page load balancing behavior
#
# Description:
#   Sends repeated requests to a web server (e.g., behind a load balancer)
#   and counts how many responses come from server 1 vs server 2.
#
# Source:
#   Hands-on Kubernetes on Azure (Chapter 7)
#
# Created by: Karl Vietmeier
# License: Apache License 2.0
# SPDX-License-Identifier: Apache-2.0
# Copyright 2025 Karl Vietmeier
# ------------------------------------------------------------------------------

# Check for required argument
if [ -z "$1" ]; then
  echo "Usage: $0 <IP-ADDRESS>"
  exit 1
fi

IP="$1"
TMP_OUTPUT=$(mktemp)

# Perform 50 HTTP requests and extract identifying line
for i in {1..50}; do
  curl --silent "$IP" | sed -n '7p' >> "$TMP_OUTPUT"
done

# Count and display how many responses came from each server
echo 'Server 1 responses:'
grep '1' "$TMP_OUTPUT" | wc -l
echo 'Server 2 responses:'
grep '2' "$TMP_OUTPUT" | wc -l

# Clean up
rm -f "$TMP_OUTPUT"
