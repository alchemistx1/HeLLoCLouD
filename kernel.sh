#!/bin/bash

set -e

msg() {
	curl -X POST https://api.telegram.org/bot$bot_api/sendMessage?chat_id=$chat_id \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"
}

file() {
	MD5=$(md5sum "$1" | cut -d' ' -f1)
	curl -F document=@"$1" https://api.telegram.org/bot$bot_api/sendDocument?chat_id=$chat_id \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=Markdown" \
	-F caption="$2 | *MD5 Checksum : *\`$MD5\`"
}

git clone --depth=1 https://$DEVICE_REPO:$DEVICE_TOKEN@github.com/$DEVICE_REPO/kernel_xiaomi_raphael -b topaz-staging $CIRRUS_WORKING_DIR/msm-4.14
git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 --depth=1 -b master $CIRRUS_WORKING_DIR/linux-x86
mv $CIRRUS_WORKING_DIR/linux-x86/clang-r450784d $CIRRUS_WORKING_DIR/clang && rm -rf $CIRRUS_WORKING_DIR/linux-x86
git clone --depth=1 https://github.com/back-up-git/AnyKernel3 -b main $CIRRUS_WORKING_DIR/AnyKernel

cd $CIRRUS_WORKING_DIR/msm-4.14

export BUILD_START=$(date +"%s")
export KBUILD_BUILD_USER="AB"
export KBUILD_BUILD_HOST="Server"
export ARCH=arm64
export PATH="$CIRRUS_WORKING_DIR/clang/bin/:$PATH"
make O=out raphael_defconfig
make -j$(nproc --all) O=out \
      LLVM=1 \
      LLVM_IAS=1 \
      CROSS_COMPILE="aarch64-linux-gnu-" \
      CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
      2>&1 | tee out/error.txt
export BUILD_END=$(date +"%s")
export DIFF=$((BUILD_END - BUILD_START))

export ZIP_NAME=Raphael-T-$(TZ=Asia/Kolkata date +%Y%m%d-%H%M).zip

if [ -e out/arch/arm64/boot/Image.gz-dtb ] && [ -e out/arch/arm64/boot/dtbo.img ]; then
cp out/arch/arm64/boot/Image.gz-dtb $CIRRUS_WORKING_DIR/AnyKernel
cp out/arch/arm64/boot/dtbo.img $CIRRUS_WORKING_DIR/AnyKernel

zip -r9 $ZIP_NAME * -x .git README.md *placeholder
file "$ZIP_NAME" "*Build Completed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
else
file "$CIRRUS_WORKING_DIR/msm-4.14/out/error.txt" "*Build Failed :* $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
fi
