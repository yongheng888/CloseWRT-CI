#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
#修改默认密码 tk12345678
sed -i "s/root:.*/root:\$5\$sqX6egp88nLYx.iR\$E3joP3ZjFuvkvfSyhaPT2S97MqCkzHeeuU96YD96Mk6:20358:0:99999:7:::/g" $(find ./package/base-files/files/etc/ -type f -name "shadow")

# TTYD 免登录
#sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

WIFI_FILE="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
#修改WIFI名称
sed -i "s/ImmortalWrt/$WRT_SSID/g" $WIFI_FILE
#修改WIFI加密
sed -i "s/encryption=.*/encryption='psk2+ccmp'/g" $WIFI_FILE
#修改WIFI密码
sed -i "/set wireless.default_\${dev}.encryption='psk2+ccmp'/a \\\t\t\t\t\t\set wireless.default_\${dev}.key='$WRT_WORD'" $WIFI_FILE

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#修复web更新
WEB_UPDATE_FILE="./target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh"
sed -i '/qihoo,360t7)/i\	cudy,tr3000-v1-ubootmod|\\' $WEB_UPDATE_FILE

# 自定义脚本同步（Others/uci-defaults → package/base-files/files/etc/uci-defaults）
UCI_DEFAULTS_DIR="./package/base-files/files/etc/uci-defaults"
CUSTOM_UCI_DEFAULTS="${GITHUB_WORKSPACE:+$GITHUB_WORKSPACE/Others/uci-defaults}"
CUSTOM_UCI_DEFAULTS="${CUSTOM_UCI_DEFAULTS:-../Others/uci-defaults}"

mkdir -p "$UCI_DEFAULTS_DIR"

if [ -d "$CUSTOM_UCI_DEFAULTS" ] && find "$CUSTOM_UCI_DEFAULTS" -maxdepth 1 -type f | grep -q .; then
	while IFS= read -r FILE; do
		BASENAME=$(basename "$FILE")
		cp -f "$FILE" "$UCI_DEFAULTS_DIR/$BASENAME"
		chmod +x "$UCI_DEFAULTS_DIR/$BASENAME"
	done < <(find "$CUSTOM_UCI_DEFAULTS" -maxdepth 1 -type f)

	echo "已同步自定义 uci-defaults 脚本到: $UCI_DEFAULTS_DIR"
else
	echo "未找到自定义 uci-defaults 脚本，跳过同步"
fi

# 自定义 root 脚本同步（Others/root-scripts → package/base-files/files/root）
ROOT_SCRIPTS_DIR="./package/base-files/files/root"
CUSTOM_ROOT_SCRIPTS="${GITHUB_WORKSPACE:+$GITHUB_WORKSPACE/Others/root-scripts}"
CUSTOM_ROOT_SCRIPTS="${CUSTOM_ROOT_SCRIPTS:-../Others/root-scripts}"

mkdir -p "$ROOT_SCRIPTS_DIR"

if [ -d "$CUSTOM_ROOT_SCRIPTS" ] && find "$CUSTOM_ROOT_SCRIPTS" -maxdepth 1 -type f | grep -q .; then
	while IFS= read -r FILE; do
		BASENAME=$(basename "$FILE")
		cp -f "$FILE" "$ROOT_SCRIPTS_DIR/$BASENAME"
		chmod +x "$ROOT_SCRIPTS_DIR/$BASENAME"
	done < <(find "$CUSTOM_ROOT_SCRIPTS" -maxdepth 1 -type f)

	echo "已同步自定义 root 脚本到: $ROOT_SCRIPTS_DIR"
else
	echo "未找到自定义 root 脚本，跳过同步"
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
# echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi
