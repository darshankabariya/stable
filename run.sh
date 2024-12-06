#!/bin/bash

case "$1" in
    "monitor")
        python3 price_monitoring/price_monitoring.py monitor
        ;;
    "stable")
        python3 price_monitoring/price_monitoring.py stable
        ;;
    "help" | *)
        python3 price_monitoring/price_monitoring.py help
        ;;
esac
