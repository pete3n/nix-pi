#!/bin/bash

SET_ENV_SCRIPT="./set_env.sh"

if [ -f ".env" ]; then
    ENV_TYPE=$(cat .env)
    
    if [ "$ENV_TYPE" = "NIXOS" ]; then
        exit 1
    elif [ "$ENV_TYPE" = "NIX" ]; then
        exit 2
    else
        echo "Invalid environment type in .env file."
        exit 3
    fi
else
    echo ".env file not found."
    exit 0
fi
