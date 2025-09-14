#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 Tianling Shen <cnsztl@immortalwrt.org>
# Modified for HomeProxy with Clash UI Integration

export PKG_SOURCE_DATE_EPOCH="$(date "+%s")"

BASE_DIR="$(cd "$(dirname $0)"; pwd)"
PKG_DIR="$BASE_DIR/.."

function get_mk_value() {
	awk -F "$1:=" '{print $2}' "$PKG_DIR/Makefile" | xargs
}

PKG_NAME="$(get_mk_value "PKG_NAME")"
if [ "$RELEASE_TYPE" == "release" ]; then
	PKG_VERSION="release-$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo 'v1.0.0')"
else
	PKG_VERSION="clash-ui-$PKG_SOURCE_DATE_EPOCH-$(git rev-parse --short HEAD)"
fi

TEMP_DIR="$(mktemp -d -p $BASE_DIR)"
TEMP_PKG_DIR="$TEMP_DIR/$PKG_NAME"
mkdir -p "$TEMP_PKG_DIR/CONTROL/"
mkdir -p "$TEMP_PKG_DIR/lib/upgrade/keep.d/"
mkdir -p "$TEMP_PKG_DIR/usr/lib/lua/luci/i18n/"
mkdir -p "$TEMP_PKG_DIR/www/"

cp -fpR "$PKG_DIR/htdocs"/* "$TEMP_PKG_DIR/www/"
cp -fpR "$PKG_DIR/root"/* "$TEMP_PKG_DIR/"

echo -e "/etc/config/homeproxy" > "$TEMP_PKG_DIR/CONTROL/conffiles"
cat > "$TEMP_PKG_DIR/lib/upgrade/keep.d/$PKG_NAME" <<-EOF
/etc/homeproxy/certs/
/etc/homeproxy/ruleset/
/etc/homeproxy/resources/china_ip4.txt
/etc/homeproxy/resources/china_ip4.ver
/etc/homeproxy/resources/china_ip6.txt
/etc/homeproxy/resources/china_ip6.ver
/etc/homeproxy/resources/china_list.txt
/etc/homeproxy/resources/china_list.ver
/etc/homeproxy/resources/gfw_list.txt
/etc/homeproxy/resources/gfw_list.ver
/etc/homeproxy/resources/direct_list.txt
/etc/homeproxy/resources/proxy_list.txt
/etc/homeproxy/cache.db
EOF

cat > "$TEMP_PKG_DIR/CONTROL/control" <<-EOF
	Package: $PKG_NAME
	Version: $PKG_VERSION
	Depends: libc, sing-box, firewall4, kmod-nft-tproxy
	Source: https://github.com/Nothinghhhhh/homeproxy_build
	SourceName: $PKG_NAME
	Section: luci
	SourceDateEpoch: $PKG_SOURCE_DATE_EPOCH
	Maintainer: HomeProxy with Clash UI <nothinghhhhh@example.com>
	Architecture: all
	Installed-Size: TO-BE-FILLED-BY-IPKG-BUILD
	Description:  HomeProxy with integrated Clash UI - The modern ImmortalWrt proxy platform for ARM64/AMD64 with complete Clash API support and Web Dashboard
EOF

# Clone luci source for po2lmo tool
git clone "https://github.com/openwrt/luci.git" --depth=1 "luci-src"
pushd "luci-src/modules/luci-base/src"
make po2lmo
./po2lmo "$PKG_DIR/po/zh_Hans/homeproxy.po" "$TEMP_PKG_DIR/usr/lib/lua/luci/i18n/homeproxy.zh-cn.lmo"
popd
rm -rf "luci-src"

# Create postinst script
echo -e '#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_postinst $0 $@' > "$TEMP_PKG_DIR/CONTROL/postinst"
chmod 0755 "$TEMP_PKG_DIR/CONTROL/postinst"

# Create postinst-pkg script
echo -e "[ -n "\${IPKG_INSTROOT}" ] || {
	(. /etc/uci-defaults/$PKG_NAME) && rm -f /etc/uci-defaults/$PKG_NAME
	rm -f /tmp/luci-indexcache
	rm -rf /tmp/luci-modulecache/
	exit 0
}" > "$TEMP_PKG_DIR/CONTROL/postinst-pkg"
chmod 0755 "$TEMP_PKG_DIR/CONTROL/postinst-pkg"

# Create prerm script
echo -e '#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh
default_prerm $0 $@' > "$TEMP_PKG_DIR/CONTROL/prerm"
chmod 0755 "$TEMP_PKG_DIR/CONTROL/prerm"

# Download ipkg-build tool and build package
curl -fsSL "https://raw.githubusercontent.com/openwrt/openwrt/master/scripts/ipkg-build" -o "$TEMP_DIR/ipkg-build"
chmod 0755 "$TEMP_DIR/ipkg-build"
"$TEMP_DIR/ipkg-build" -m "" "$TEMP_PKG_DIR" "$TEMP_DIR"

# Move the built package to final location
mv "$TEMP_DIR/${PKG_NAME}_${PKG_VERSION}_all.ipk" "$BASE_DIR/${PKG_NAME}_${PKG_VERSION}_all.ipk"

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Package built successfully: ${PKG_NAME}_${PKG_VERSION}_all.ipk"
echo "📦 Package size: $(du -h "$BASE_DIR/${PKG_NAME}_${PKG_VERSION}_all.ipk" | cut -f1)"