#!/bin/bash

# Lynis git installer
if [[ ! -d /usr/local/lynis ]]; then
    cd /usr/local || exit 1
    git clone https://github.com/CISOfy/lynis
    cd lynis || exit 1
    chmod +x lynis
    ln -s /usr/local/lynis/lynis /usr/local/bin/lynis
fi

# Run Lynis
lynis audit system
