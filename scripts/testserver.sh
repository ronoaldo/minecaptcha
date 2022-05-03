#!/usr/bin/bash

minetest --server --config scripts/minetest.conf --verbose --worldname MineCaptchaDev 2>&1 | grep -E 'ACTION|minecaptcha'