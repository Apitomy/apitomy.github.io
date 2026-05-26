#!/bin/bash
set -euo pipefail

echo "Starting Jekyll dev server at http://localhost:4000"
docker run --rm -p 4000:4000 -v "$(pwd):/srv/jekyll" jekyll/jekyll jekyll serve --host 0.0.0.0
