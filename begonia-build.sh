#!/bin/bash

MainPath=$(pwd)
Clang=$(pwd)/../clang
Gcc64=$(pwd)/../gcc64
Gcc=$(pwd)/../gcc
AnyKernel=$(pwd)/../AnyKernel3

# Telegram message
# echo 'your bot token' > .bot_token
# echo 'your group or channel chat id' > .chat_id
if [[ -e .bot_token && -e .chat_id ]]; then
    BOT_TOKEN=$(cat .bot_token)
    CHAT_ID=$(cat .chat_id)
    UT=1
else
    UT=0
fi

alias msg='curl -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
            -d chat_id=$CHAT_ID \
            -d disable_web_page_preview=true \
            -d parse_mode=html'

alias upload='curl -F chat_id=$CHAT_ID \
            -F document=@$FILE \
            -F parse_mode=markdown https://api.telegram.org/bot$BOT_TOKEN/sendDocument'

if [ $UT = 1 ]; then
    msg -d text="Start to building Kernel"
fi

# Make zip
MakeZip(){
    if [ ! -d $AnyKernel ]; then
        git clone https://github.com/TeraaBytee/AnyKernel3 -b begonia-ross $AnyKernel
        cd $AnyKernel
    else
        cd $AnyKernel
        git fetch origin begonia-ross
        git checkout begonia-ross
        git reset --hard origin/begonia-ross
    fi
    cp -af $MainPath/out/arch/arm64/boot/Image.gz-dtb $AnyKernel
    sed -i "s/kernel.string=.*/kernel.string=$KERNEL_NAME-$HeadCommit test by $KBUILD_BUILD_USER/g" anykernel.sh
    zip -r9 $MainPath/"[$TIME][$Compiler][R-OSS]-$KERNEL_VERSION-$KERNEL_NAME-$HeadCommit.zip" * -x .git README.md *placeholder
    cd $MainPath
}

# Clone Compiler
if [ $UT = 1 ]; then
    msg -d text="Clone Compiler . . ."
fi
if [ ! -d $Clang ]; then
    git clone --depth=1 https://github.com/TeraaBytee/google-clang -b 11.0.2 $Clang
else
    cd $Clang
    git fetch origin 11.0.2
    git checkout 11.0.2
    git reset --hard origin/11.0.2
    cd $MainPath
fi
if [ ! -d $Gcc64 ]; then
    git clone --depth=1 https://github.com/TeraaBytee/aarch64-linux-android-4.9 -b master $Gcc64
else
    cd $Gcc64
    git fetch origin master
    git checkout master
    git reset --hard origin/master
    cd $MainPath
fi
if [ ! -d $Gcc ]; then
    git clone --depth=1 https://github.com/TeraaBytee/arm-linux-androideabi-4.9 -b master $Gcc
else
    cd $Gcc
    git fetch origin master
    git checkout master
    git reset --hard origin/master
    cd $MainPath
fi
ClangVersion=$($Clang/bin/clang --version | grep version)

# Kernel config
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="$(hostname)"
export KBUILD_BUILD_USER="TeraaBytee"
Defconfig="begonia_user_defconfig"
Branch=$(git branch | grep '*' | awk '{ print $2 }')
Changelogs=$(git log --oneline -5 --no-decorate)
HeadCommit=$(git log --pretty=format:'%h' -1)
KERNEL_NAME=$(cat "$MainPath/arch/arm64/configs/$Defconfig" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g')
KERNEL_VERSION="4.14.$(cat "$MainPath/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"

# Cleaning
Compiler=CLANG
rm -rf out

if [ $UT = 1 ]; then
    msg -d text="
<b>Device</b>: <code>Redmi Note 8 Pro [BEGONIA]</code>
<b>Branch</b>: <code>$Branch</code>
<b>User</b>: <code>$KBUILD_BUILD_USER</code>
<b>Host</b>: <code>$KBUILD_BUILD_HOST</code>
<b>Kernel name</b>: <code>$KERNEL_NAME</code>
<b>Kernel version</b>: <code>$KERNEL_VERSION</code>
<b>Compiler</b>:%0A<code>$ClangVersion</code>
<b>Changelogs</b>:%0A<code>$Changelogs</code>"
fi

TIME=$(date +"%d%m")
BUILD_START=$(date +"%s")

# Building
make  -j$(nproc --all)  O=out $Defconfig
exec 2> >(tee -a out/error.log >&2)
make  -j$(nproc --all)  O=out \
                        PATH="$Clang/bin:/$Gcc64/bin:/$Gcc/bin:/usr/bin:$PATH" \
                        LD_LIBRARY_PATH="$Clang/lib64:$LD_LIBRABRY_PATH" \
                        CC=clang \
                        AR=llvm-ar \
                        AS=llvm-as \
                        NM=llvm-nm \
                        OBJCOPY=llvm-objcopy \
                        OBJDUMP=llvm-objdump \
                        STRIP=llvm-strip \
                        LD=ld.lld \
                        CROSS_COMPILE=aarch64-linux-android- \
                        CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                        CLANG_TRIPLE=aarch64-linux-gnu-

BUILD_END=$(date +"%s")
BUILD_DIFF=$((BUILD_END - BUILD_START))
BUILD_TIME="$((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) second(s)"

if [ -e $MainPath/out/arch/arm64/boot/Image.gz-dtb ]; then
    MakeZip
    if [ $UT = 1 ]; then
        FILE=$(echo *$Compiler*$HeadCommit.zip)
        upload -F caption="Build success in: $BUILD_TIME"
    else
        echo "Build success in: $BUILD_TIME"
    fi
else
    if [ $UT = 1 ]; then
        FILE="out/error.log"
        upload -F caption="Build fail in: $BUILD_TIME"
    else
        echo "Build fail in: $BUILD_TIME"
    fi
fi
