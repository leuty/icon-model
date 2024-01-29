#!/bin/bash

device=$(($SLURM_LOCALID%8))

export ROCR_VISIBLE_DEVICES=$device
exec "$@"
