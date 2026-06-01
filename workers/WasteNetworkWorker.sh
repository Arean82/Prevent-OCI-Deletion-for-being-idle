#!/bin/bash
# Downloads a test file for up to 5 seconds and discards it to generate network traffic
timeout 5 wget -O /dev/null http://speedtest.tele2.net/100MB.zip -q || true
