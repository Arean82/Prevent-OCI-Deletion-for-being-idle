#!/bin/bash
# Allocates approx 50MB of memory and holds it for 5 seconds
python3 -c "a = ' ' * 1024 * 1024 * 50; import time; time.sleep(5)" 2>/dev/null || true
