#!/bin/bash
# Run a computationally intensive hash on random data for 5 seconds
timeout 5 sha256sum /dev/urandom > /dev/null 2>&1 || true