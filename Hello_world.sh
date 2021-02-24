#!/bin/bash

echo "Updating apt-get and installing JQ..."
apt-get -qq update
apt-get -qq -y install jq >/dev/null 2>&1

echo "Running Python script $script_path/$script_name..."
python3 Hello_world.py
