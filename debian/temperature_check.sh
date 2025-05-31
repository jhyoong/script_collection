#!/bin/bash

# System Temperature Monitor
# Monitors all available temperature sensors every 5 seconds

# Colors for better readability
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get CPU temperature from different sources
get_cpu_temp() {
    local temp=""

    # Try thermal zones first (most common on Linux)
    if [ -d "/sys/class/thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$zone" ]; then
                local zone_name=$(basename $(dirname $zone))
                local temp_raw=$(cat "$zone")
                local temp_celsius=$((temp_raw / 1000))
                local temp_fahrenheit=$(((temp_celsius * 9 / 5) + 32))

                # Try to get zone type for better labeling
                local zone_type="Unknown"
                local type_file=$(dirname $zone)/type
                if [ -r "$type_file" ]; then
                    zone_type=$(cat "$type_file")
                fi

                echo -e "${BLUE}$zone_name ($zone_type):${NC} ${temp_celsius}°C / ${temp_fahrenheit}°F"
            fi
        done
    fi

    # Try sensors command if available
    if command_exists sensors; then
        echo -e "${GREEN}Hardware Sensors:${NC}"
        sensors | grep -E "(°C|°F)" | while read line; do
            echo -e "  $line"
        done
    fi

    # Try vcgencmd for Raspberry Pi
    if command_exists vcgencmd; then
        local pi_temp=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 | cut -d\' -f1)
        if [ ! -z "$pi_temp" ]; then
            local pi_temp_f=$(echo "$pi_temp * 9 / 5 + 32" | bc -l 2>/dev/null || echo "N/A")
            echo -e "${YELLOW}Raspberry Pi CPU:${NC} ${pi_temp}°C / ${pi_temp_f}°F"
        fi
    fi

    # Try reading from /proc/acpi/thermal_zone (older systems)
    if [ -d "/proc/acpi/thermal_zone" ]; then
        for zone in /proc/acpi/thermal_zone/*/temperature; do
            if [ -r "$zone" ]; then
                local zone_name=$(basename $(dirname $zone))
                local temp_line=$(cat "$zone")
                local temp_celsius=$(echo "$temp_line" | awk '{print $2}')
                if [ ! -z "$temp_celsius" ]; then
                    local temp_fahrenheit=$(((temp_celsius * 9 / 5) + 32))
                    echo -e "${BLUE}ACPI $zone_name:${NC} ${temp_celsius}°C / ${temp_fahrenheit}°F"
                fi
            fi
        done
    fi

    # Try coretemp for Intel CPUs
    if [ -d "/sys/devices/platform" ]; then
        for core in /sys/devices/platform/coretemp.*/hwmon/hwmon*/temp*_input; do
            if [ -r "$core" ]; then
                local core_name=$(basename "$core" _input)
                local temp_raw=$(cat "$core")
                local temp_celsius=$((temp_raw / 1000))
                local temp_fahrenheit=$(((temp_celsius * 9 / 5) + 32))
                echo -e "${GREEN}Intel Core ($core_name):${NC} ${temp_celsius}°C / ${temp_fahrenheit}°F"
            fi
        done
    fi
}

# Function to get GPU temperature
get_gpu_temp() {
    # NVIDIA GPU
    if command_exists nvidia-smi; then
        local nvidia_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
        if [ ! -z "$nvidia_temp" ] && [ "$nvidia_temp" != "N/A" ]; then
            local nvidia_temp_f=$(((nvidia_temp * 9 / 5) + 32))
            echo -e "${RED}NVIDIA GPU:${NC} ${nvidia_temp}°C / ${nvidia_temp_f}°F"
        fi
    fi

    # AMD GPU (try different methods)
    if [ -d "/sys/class/drm" ]; then
        for gpu_temp in /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input; do
            if [ -r "$gpu_temp" ]; then
                local temp_raw=$(cat "$gpu_temp")
                local temp_celsius=$((temp_raw / 1000))
                local temp_fahrenheit=$(((temp_celsius * 9 / 5) + 32))
                local gpu_name=$(basename $(dirname $(dirname "$gpu_temp")))
                echo -e "${RED}GPU ($gpu_name):${NC} ${temp_celsius}°C / ${temp_fahrenheit}°F"
            fi
        done
    fi
}

# Function to get hard drive temperatures
get_hdd_temp() {
    if command_exists hddtemp; then
        echo -e "${YELLOW}Hard Drive Temperatures:${NC}"
        # Try to get temperatures for all drives
        for drive in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
            if [ -b "$drive" ]; then
                local temp_info=$(hddtemp "$drive" 2>/dev/null | grep -o '[0-9]*°C')
                if [ ! -z "$temp_info" ]; then
                    local temp_celsius=$(echo "$temp_info" | grep -o '[0-9]*')
                    local temp_fahrenheit=$(((temp_celsius * 9 / 5) + 32))
                    echo -e "  $(basename $drive): ${temp_celsius}°C / ${temp_fahrenheit}°F"
                fi
            fi
        done
    fi

    # Try smartctl as alternative
    if command_exists smartctl; then
        for drive in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
            if [ -b "$drive" ]; then
                local temp_celsius=$(smartctl -A "$drive" 2>/dev/null | awk '/Temperature_Celsius/ {print $10}' | head -1)
                if [ ! -z "$temp_celsius" ] && [ "$temp_celsius" -gt 0 ]; then
                    local temp_fahrenheit=$(((temp_celsius * 9 / 5) + 32))
                    echo -e "${YELLOW}$(basename $drive) (SMART):${NC} ${temp_celsius}°C / ${temp_fahrenheit}°F"
                fi
            fi
        done
    fi
}

# Function to display temperature warnings
check_temp_warnings() {
    echo -e "\n${YELLOW}Temperature Status:${NC}"

    # Check if any temperature is critically high (adjust thresholds as needed)
    local high_temp_found=false

    # This is a simple check - you might want to make it more sophisticated
    if [ -d "/sys/class/thermal" ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -r "$zone" ]; then
                local temp_raw=$(cat "$zone")
                local temp_celsius=$((temp_raw / 1000))

                if [ "$temp_celsius" -gt 80 ]; then
                    echo -e "${RED}WARNING: High temperature detected: ${temp_celsius}°C${NC}"
                    high_temp_found=true
                elif [ "$temp_celsius" -gt 70 ]; then
                    echo -e "${YELLOW}CAUTION: Elevated temperature: ${temp_celsius}°C${NC}"
                fi
            fi
        done
    fi

    if [ "$high_temp_found" = false ]; then
        echo -e "${GREEN}All temperatures appear normal${NC}"
    fi
}

# Main monitoring loop
main() {
    echo -e "${BLUE}=== System Temperature Monitor ===${NC}"
    echo -e "Monitoring system temperatures every 5 seconds..."
    echo -e "Press Ctrl+C to stop\n"

    while true; do
        clear
        echo -e "${BLUE}=== System Temperature Monitor - $(date) ===${NC}\n"

        echo -e "${GREEN}CPU Temperatures:${NC}"
        get_cpu_temp

        echo -e "\n${RED}GPU Temperatures:${NC}"
        get_gpu_temp

        echo -e "\n${YELLOW}Storage Temperatures:${NC}"
        get_hdd_temp

        check_temp_warnings

        echo -e "\n${BLUE}Next update in 5 seconds...${NC}"
        sleep 5
    done
}

# Check if running as root for some sensors
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Note: Some temperature sensors may require root privileges${NC}"
    echo -e "${YELLOW}Consider running with sudo for complete information${NC}\n"
fi

# Start monitoring
main