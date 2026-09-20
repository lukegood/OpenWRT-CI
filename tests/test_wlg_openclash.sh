#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WLG_WF="$ROOT_DIR/.github/workflows/WLG-RE-CS-07-BUILD.yml"
CORE_WF="$ROOT_DIR/.github/workflows/WRT-CORE.yml"
PACKAGES="$ROOT_DIR/Scripts/Packages.sh"
SETTINGS="$ROOT_DIR/Scripts/Settings.sh"
GENERAL="$ROOT_DIR/Config/GENERAL.txt"
RE_CS_07="$ROOT_DIR/Config/IPQ60XX-RE-CS-07-NOWIFI.txt"

[ -f "$WLG_WF" ] || { echo "missing WLG RE-CS-07 workflow"; exit 1; }
[ -f "$CORE_WF" ] || { echo "missing WRT-CORE workflow"; exit 1; }
[ -f "$PACKAGES" ] || { echo "missing Packages.sh"; exit 1; }
[ -f "$SETTINGS" ] || { echo "missing Settings.sh"; exit 1; }

# The last WLG image had no OpenClash LuCI menu because Packages.sh cloned the
# feed but no .config symbol selected luci-app-openclash. Keep the enablement
# on the WLG caller only so production Nikki images stay unchanged.
grep -q '^      WRT_PACKAGE:' "$WLG_WF" || {
	echo "WLG workflow does not pass WRT_PACKAGE into WRT-CORE"
	exit 1
}
grep -A4 '^      WRT_PACKAGE:' "$WLG_WF" | grep -q 'CONFIG_PACKAGE_luci-app-openclash=y' || {
	echo "WLG workflow does not enable luci-app-openclash via WRT_PACKAGE"
	exit 1
}

if grep -q '^CONFIG_PACKAGE_luci-app-openclash=y$' "$GENERAL"; then
	echo "GENERAL.txt must not enable OpenClash; it would land on every device"
	exit 1
fi
if grep -q '^CONFIG_PACKAGE_luci-app-openclash=y$' "$RE_CS_07"; then
	echo "IPQ60XX-RE-CS-07-NOWIFI.txt must not enable OpenClash; production RE-CS-07 stays Nikki"
	exit 1
fi

grep -Fq "UPDATE_PACKAGE \"openclash\" \"vernesong/OpenClash\" \"dev\" \"pkg\"" "$PACKAGES" || {
	echo "Packages.sh no longer clones vernesong/OpenClash"
	exit 1
}
grep -Fq "CONFIG_PACKAGE_luci-app-openclash=y" "$PACKAGES" || {
	echo "Packages.sh must gate the OpenClash feed on WRT_PACKAGE"
	exit 1
}

grep -Fq 'echo -e "$WRT_PACKAGE" >> ./.config' "$SETTINGS" || {
	echo "Settings.sh no longer appends WRT_PACKAGE to .config"
	exit 1
}

grep -Fq 'extra package from WRT_PACKAGE was dropped by defconfig' "$CORE_WF" || {
	echo "WRT-CORE does not retain WRT_PACKAGE symbols after defconfig"
	exit 1
}

echo "WLG OpenClash enablement test passed"
