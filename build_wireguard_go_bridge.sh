#!/bin/sh
set -eo pipefail

# Skip this script when running SwiftUI previews
if [ "${XCODE_RUNNING_FOR_PREVIEWS:-}" = "1" ]; then
  echo "Skipping WireGuard bridge for SwiftUI Previews"
  exit 0
fi

if [ -z "${1:-}" ]; then
  echo "Error: Go version not specified."
  echo "Usage: $0 <go_version>"
  exit 1
fi

GO_VERSION="$1"

install_go() {
  TEMP_DIR="$(mktemp -d)"
  GO_TAR_URL="https://go.dev/dl/go${GO_VERSION}.darwin-arm64.tar.gz"

  echo "Downloading Go ${GO_VERSION} for macOS arm64..."
  curl -fsSL -o "${TEMP_DIR}/go.tar.gz" "$GO_TAR_URL"
  tar -C "$TEMP_DIR" -xzf "${TEMP_DIR}/go.tar.gz"
  rm -f "${TEMP_DIR}/go.tar.gz"

  export PATH="${TEMP_DIR}/go/bin:${PATH}"
  export GOROOT="${TEMP_DIR}/go"

  go version
}

ensure_go() {
  current_go_version="$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//' || true)"
  if [ "$current_go_version" = "$GO_VERSION" ]; then
    echo "Using installed Go ${GO_VERSION}"
    return
  fi

  echo "Installing Go ${GO_VERSION} (found: ${current_go_version:-none})..."
  install_go
}

find_derived_data_root() {
  local dir="${BUILD_DIR:-}"

  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/SourcePackages/checkouts" ]; then
      printf '%s\n' "$dir"
      return 0
    fi

    if [ "$(basename "$dir")" = "Build" ] && [ -d "$(dirname "$dir")/SourcePackages/checkouts" ]; then
      printf '%s\n' "$(dirname "$dir")"
      return 0
    fi

    dir="$(dirname "$dir")"
  done

  return 1
}

find_wireguard_go_dir() {
  local derived_root="$1"
  local checkouts_dir="$derived_root/SourcePackages/checkouts"

  if [ -d "$checkouts_dir/amneziawg-apple/Sources/WireGuardKitGo" ]; then
    printf '%s\n' "$checkouts_dir/amneziawg-apple/Sources/WireGuardKitGo"
    return 0
  fi

  if [ -d "$checkouts_dir/wireguard-apple/Sources/WireGuardKitGo" ]; then
    printf '%s\n' "$checkouts_dir/wireguard-apple/Sources/WireGuardKitGo"
    return 0
  fi

  return 1
}

if [ -z "${BUILD_DIR:-}" ]; then
  echo "Error: BUILD_DIR is not set."
  exit 1
fi

ensure_go

derived_root="$(find_derived_data_root || true)"
if [ -z "$derived_root" ]; then
  echo "Error: Could not locate DerivedData SourcePackages from BUILD_DIR=${BUILD_DIR}"
  exit 1
fi

wireguard_go_dir="$(find_wireguard_go_dir "$derived_root" || true)"
if [ -z "$wireguard_go_dir" ]; then
  echo "Error: WireGuardKitGo sources not found under ${derived_root}/SourcePackages/checkouts"
  ls -la "$derived_root/SourcePackages/checkouts" || true
  exit 1
fi

export PATH="${PATH}:/usr/local/bin:/opt/homebrew/bin"
export PLATFORM_NAME="${PLATFORM_NAME:-iphoneos}"
export ARCHS="${ARCHS:-arm64}"

build_dir="${CONFIGURATION_BUILD_DIR:-$BUILD_DIR}"
temp_dir="${CONFIGURATION_TEMP_DIR:-$build_dir/tmp}"
output_lib="${build_dir}/libwg-go.a"

mkdir -p "$build_dir" "$temp_dir"

echo "Building WireGuard bridge in ${wireguard_go_dir}"
echo "SDKROOT=${SDKROOT:-unset} PLATFORM_NAME=${PLATFORM_NAME} ARCHS=${ARCHS}"
echo "CONFIGURATION_BUILD_DIR=${build_dir}"

cd "$wireguard_go_dir"
# Never short-circuit: Xcode's PBXLegacyTarget breaks if this script exits early.
/usr/bin/make build

if [ ! -f "$output_lib" ]; then
  echo "Error: Expected bridge artifact at ${output_lib}"
  exit 1
fi

echo "WireGuardGoBridge successfully built at ${output_lib}"
