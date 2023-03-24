#!/bin/bash

# Update main and production in preparation for prod PR

git checkout main && git pull && git checkout production && git pull && git checkout main

# TODO: prod PR template
