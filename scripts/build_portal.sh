#!/usr/bin/env bash
# Compila el portal web de gimnasios (lib/portal/main_portal.dart) y lo deja
# en hosting/gimnasio, listo para `firebase deploy --only hosting`.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web \
  --release \
  --target lib/portal/main_portal.dart \
  --base-href /gimnasio/ \
  --output "$PWD/build/portal"

rm -rf hosting/gimnasio
cp -r build/portal hosting/gimnasio
echo "✅ Portal listo en hosting/gimnasio. Despliega con: firebase deploy --only hosting --project trainapp-prod"
