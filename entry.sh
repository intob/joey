#!/bin/bash

set -m # to make job control work
tor &
/go/bin/joeyinnes &
fg %1 # foreground process to prevent killing VM