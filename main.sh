#!/bin/bash
git pull
(cd tui && go build -o tui-app)
./tui/tui-app "$@"
