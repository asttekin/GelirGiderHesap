#!/usr/bin/env bash
# Son kullanıcı için çift tıklayarak çalışan web paketleri üretir:
#   dist/Finans-Windows.zip, dist/Finans-macOS.zip, dist/Finans-Linux.zip
# Gerekenler: Flutter SDK, Go 1.22+ ve zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="$ROOT/tools/launcher"
DIST="$ROOT/dist"
cd "$ROOT"

echo "▶ Web sürümü derleniyor…"
# CanvasKit dosyaları CDN yerine pakete eklenir: uygulama çevrimdışı açılır.
flutter build web --release --no-web-resources-cdn

rm -rf "$LAUNCHER/web" "$DIST"
cp -r build/web "$LAUNCHER/web"
mkdir -p "$DIST"

build() { # GOOS GOARCH çıktı
  echo "▶ Başlatıcı: $1/$2"
  (cd "$LAUNCHER" && CGO_ENABLED=0 GOOS="$1" GOARCH="$2" go build -trimpath -ldflags "-s -w" -o "$3" .)
}

pack() { # .../<platform>/Finans  zip-adı  → ZIP içinde tek "Finans" klasörü
  cp "$ROOT/tools/KULLANIM.txt" "$1/"
  (cd "$(dirname "$1")" && zip -qr -X "$DIST/$2" Finans)
  rm -rf "$(dirname "$1")"
}

W="$DIST/Finans-Windows/Finans"; mkdir -p "$W"
build windows amd64 "$W/Finans.exe"
pack "$W" "Finans-Windows.zip"

M="$DIST/Finans-macOS/Finans"; mkdir -p "$M"
build darwin arm64 "$M/Finans-AppleSilicon.command"
build darwin amd64 "$M/Finans-Intel.command"
chmod +x "$M"/*.command
pack "$M" "Finans-macOS.zip"

L="$DIST/Finans-Linux/Finans"; mkdir -p "$L"
build linux amd64 "$L/Finans"
chmod +x "$L/Finans"
pack "$L" "Finans-Linux.zip"

rm -rf "$LAUNCHER/web"
echo "✔ Hazır:"; ls -lh "$DIST"
