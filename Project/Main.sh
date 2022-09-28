#!/bin/bash
. ./Read-Validate-Save.sh $1
. ./Generate-Listener-Scripts.sh
. ./Generate-Tester-Scripts.sh
. ./remote-execution.sh
. ./Report-Gathering.sh