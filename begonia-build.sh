#!/bin/bash
#
#   Copyright 2022 TeraaBytee
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

MainPath=$(pwd)
Clang=$(pwd)/../clang
Gcc64=$(pwd)/../gcc64
Gcc=$(pwd)/../gcc
AnyKernel=$(pwd)/../AnyKernel3

# Telegram message
# echo 'your bot token' > .bot_token
# echo 'your group or channel chat id' > .chat_id
BOT_TOKEN="$(cat .bot_token)"
CHAT_ID="$(cat .chat_id)"

msg(){
    curl -X POST https://api.telegram.org/bot$BOT_TOKEN/sendMessage \
    -d disable_web_page_preview=true \
    -d chat_id=$CHAT_ID \
    -d parse_mode=html \
    -d text="$text"
}

upload(){
    curl -F parse_mode=markdown https://api.telegram.org/bot$BOT_TOKEN/sendDocument \
    -F chat_id=$CHAT_ID \
    -F document=@$FILE \
    -F caption="$caption"
}

if [[ ! -z $BOT_TOKEN && ! -z $CHAT_ID ]]; then
    text="Time to building kernel" msg
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
if [[ ! -z $BOT_TOKEN && ! -z $CHAT_ID ]]; then
    text="<code>clone compiler . . .</code>" msg
fi
if [ ! -d $Clang ]; then
    git clone --depth=1 https://github.com/TeraaBytee/aosp-clang -b r416183b1 $Clang
else
    cd $Clang
    git fetch origin r416183b1
    git checkout FETCH_HEAD
    git branch -D r416183b1
    git branch r416183b1
    git checkout r416183b1
    git reset --hard origin/r416183b1
    cd $MainPath
fi
if [ ! -d $Gcc64 ]; then
    git clone --depth=1 https://github.com/TeraaBytee/aarch64-linux-android-4.9 -b master $Gcc64
else
    cd $Gcc64
    git fetch origin master
    git checkout FETCH_HEAD
    git branch -D master
    git branch master
    git checkout master
    git reset --hard origin/master
    cd $MainPath
fi
if [ ! -d $Gcc ]; then
    git clone --depth=1 https://github.com/TeraaBytee/arm-linux-androideabi-4.9 -b master $Gcc
else
    cd $Gcc
    git fetch origin master
    git checkout FETCH_HEAD
    git branch -D master
    git branch master
    git checkout master
    git reset --hard origin/master
    cd $MainPath
fi
ClangVersion=$($Clang/bin/clang --version | grep version)

# Kernel config
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="KentangGaming"
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

if [[ ! -z $BOT_TOKEN && ! -z $CHAT_ID ]]; then
    text=$(
    printf "[============ <b>Kernel Update</b> ============]\n\n";
    printf "<b>Device</b>: <code>Redmi Note 8 Pro [BEGONIA]</code>\n";
    printf "<b>Branch</b>: <code>$Branch</code>\n";
    printf "<b>Build User</b>: <code>$KBUILD_BUILD_USER</code>\n"
    printf "<b>Build Host</b>: <code>$KBUILD_BUILD_HOST</code>\n"
    printf "<b>Kernel Name</b>: <code>$KERNEL_NAME</code>\n";
    printf "<b>Kernel Version</b>: <code>$KERNEL_VERSION</code>\n";
    printf "<b>Compiler</b>:\n<code>$ClangVersion</code>\n\n";
    printf "<b>Changelogs</b>:\n<code>$Changelogs</code>\n\n";
    printf "[============ <b>Kernel Update</b> ============]\n";
    ) msg
fi

# Building
if [[ ! -z $BOT_TOKEN && ! -z $CHAT_ID ]]; then
    text="<code>building . . .</code>" msg
fi
TIME=$(date +"%d%m")
BUILD_START=$(date +"%s")
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
    if [[ ! -z $BOT_TOKEN && ! -z $CHAT_ID ]]; then
        FILE=$(echo $MainPath/*$Compiler*$HeadCommit.zip)
        caption="$(date)" upload
        text=$(
        printf "<b>Build success in</b>:\n<code>$BUILD_TIME</code>\n\n";
        printf "[========= <b>Joss Gandos</b> =========]\n";
        ) msg
    else
        echo "Build success in: $BUILD_TIME"
    fi
else
    if [[ ! -z $BOT_TOKEN && ! -z $CHAT_ID ]]; then
        FILE="out/error.log"
        caption="$(date)" upload
        text=$(
        printf "<b>Build fail in</b>:\n<code>$BUILD_TIME</code>\n\n";
        printf "[======= <b>Yahaha Wahyu</b> =======]\n";
        ) msg
    else
        echo "Build fail in: $BUILD_TIME"
    fi
fi
