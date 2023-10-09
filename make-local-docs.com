#!/bin/sh

julia --project=docs/ make-local-docs.jl
