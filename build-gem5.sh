#!/bin/bash

scons -sQ -j$(nproc) ./build/GCN3_X86/gem5.opt

tar -czf build.tar build/
