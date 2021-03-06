#!/bin/sh

# A dwm_bar function to display information regarding system memory, CPU temperature, and storage
# Joe Standring <git@joestandring.com>
# GNU GPLv3

dwm_resources () {
    # Used and total memory
     MEMUSED=$(free -h | awk '(NR == 2) {print $3}')
     MEMTOT=$(free -h |awk '(NR == 2) {print $2}')
    # CPU temperature
    # CPU=$(sysctl -n hw.sensors.cpu0.temp0 | cut -d. -f1)
    # Used and total storage in /home (rounded to 1024B)
    STOUSED=$(df -h | grep '/home$' | awk '{print $3}')
    STOTOT=$(df -h | grep '/home$' | awk '{print $2}')
    STOPER=$(df -h | grep '/home$' | awk '{print $5}')
    STAVAIL=$(df -h | grep '/home$' | awk '{print $4}')
    TEMP=$(sensors | awk '/Core 0/ {print $3}')


    printf "%s" "$SEP1"
    if [ "$IDENTIFIER" = "unicode" ]; then
        printf "%s/%s%s%s%s" "$STAVAIL" "$STOTOT" "$SEP2" "$SEP1" "$TEMP"
    else
        printf "STA | MEM %s/%s CPU %s STO %s/%s: %s" "$MEMUSED" "$MEMTOT" "$CPU" "$STOUSED" "$STOTOT" "$STOPER" "$TEMP"
    fi
    printf "%s\n" "$SEP2"
}

dwm_resources
