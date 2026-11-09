#!/usr/bin/env bash
#ddev-generated
set -eu -o pipefail

echo "Installing Pandoc, headless LibreOffice, Poppler utilities, and metric fonts..."
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  pandoc \
  libreoffice-writer-nogui \
  poppler-utils \
  fonts-crosextra-carlito \
  fonts-crosextra-caladea \
  fonts-liberation2
rm -rf /var/lib/apt/lists/*

fc-cache -f 2>/dev/null || true
