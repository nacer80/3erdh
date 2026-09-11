#!/bin/bash
set -e

echo "==================================================="
echo "  Building 3erdh (عِرضْ) Web Application (Release) "
echo "==================================================="

flutter build web --release

echo "==================================================="
echo "  Build Successful! Output ready in: build/web     "
echo "==================================================="
