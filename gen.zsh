#! /bin/zsh

## Get version number to download and patch
if [ -z "$1" ]; then
	echo "No version specified"
	exit 1
else
	discordver="$1"
fi

## Make clean tmp dir
rm -rf /tmp/aliucord
mkdir /tmp/aliucord

mkdir /tmp/aliucord/downloads
cp manifest.patch /tmp/aliucord/downloads/manifest.patch

## Download tools
mkdir /tmp/aliucord/tools
wget "https://github.com/patrickfav/uber-apk-signer/releases/download/v1.2.1/uber-apk-signer-1.2.1.jar" -O /tmp/aliucord/tools/uber-apk-signer.jar
wget "https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.6.1.jar" -O /tmp/aliucord/tools/apktool.jar
cp hbcdump /tmp/aliucord/tools/hbcdump
chmod +x /tmp/aliucord/tools/hbcdump

## Download hermes native libraries
cd /tmp/aliucord
mkdir downloads
cd /tmp/aliucord/downloads
wget "https://nightly.link/TymanWasTaken/AliuHermes/actions/artifacts/241134965.zip" -O /tmp/aliucord/downloads/android.zip
unzip android.zip

## Iterate over all discord architectures to download apks and replace native libs
mkdir /tmp/aliucord/apks/unsigned -p
architectures_url=(x86 x86_64 arm64_v8a armeabi_v7a)
architectures_zip=(x86 x86_64 arm64-v8a armeabi-v7a)

unzip -o /tmp/aliucord/downloads/hermes-cppruntime-release.aar
unzip -o /tmp/aliucord/downloads/hermes-release.aar
for i in {1..$#architectures_url}; do
	# Download config apk
	wget "https://aliucord.com/download/discord?v=$discordver&split=config.${architectures_url[i]}" -O "/tmp/aliucord/apks/unsigned/config.${architectures_url[i]}.apk"

	# configs need libs/ folder
	mkdir -p "lib/${architectures_zip[i]}"
	cp "jni/${architectures_zip[i]}/libhermes.so" "lib/${architectures_zip[i]}/libhermes.so"
	cp "jni/${architectures_zip[i]}/libc++_shared.so" "lib/${architectures_zip[i]}/libc++_shared.so"

	# Replace libs in config split
	zip -0u "/tmp/aliucord/apks/unsigned/config.${architectures_url[i]}.apk" "lib/${architectures_zip[i]}/libhermes.so"
	zip -0u "/tmp/aliucord/apks/unsigned/config.${architectures_url[i]}.apk" "lib/${architectures_zip[i]}/libc++_shared.so"
done

## Download AliucordNative
wget "https://nightly.link/Aliucord/AliucordNative/workflows/android/main/AliucordNative.zip" -O /tmp/aliucord/downloads/AliucordNative.zip
unzip /tmp/aliucord/downloads/AliucordNative.zip

## Download and patch base apk
wget "https://aliucord.com/download/discord?v=$discordver" -O /tmp/aliucord/downloads/base.apk
java -jar /tmp/aliucord/tools/apktool.jar d --no-src base.apk
cd base
patch AndroidManifest.xml ../manifest.patch
for f in ./classes?.dex(On); do
	OLD_NUM="${f//\.(\/classes|dex)/}"
	NEW_NUM=$((OLD_NUM+1))
	mv $f "${f/$OLD_NUM/$NEW_NUM}"
done
mv classes.dex classes2.dex
cp /tmp/aliucord/downloads/classes.dex classes.dex
cd ..
java -jar /tmp/aliucord/tools/apktool.jar b base
cd base/build/apk

## Replace all necessary files in base.apk
zip -u /tmp/aliucord/downloads/base.apk AndroidManifest.xml
for dex in ./classes*.dex; do
	zip -u /tmp/aliucord/downloads/base.apk $dex
done
cp /tmp/aliucord/downloads/base.apk /tmp/aliucord/apks/unsigned/base.apk

## Download rest of the splits
# Lanuage splits
wget "https://aliucord.com/download/discord?v=$discordver&split=config.en" -O /tmp/aliucord/apks/unsigned/config.en.apk
wget "https://aliucord.com/download/discord?v=$discordver&split=config.de" -O /tmp/aliucord/apks/unsigned/config.de.apk
# DPI Splits
wget "https://aliucord.com/download/discord?v=$discordver&split=config.hdpi" -O /tmp/aliucord/apks/unsigned/config.hdpi.apk
wget "https://aliucord.com/download/discord?v=$discordver&split=config.xxhdpi" -O /tmp/aliucord/apks/unsigned/config.xxhdpi.apk

## Sign all apks
java -jar /tmp/aliucord/tools/uber-apk-signer.jar --apks /tmp/aliucord/apks/unsigned/ --allowResign --out /tmp/aliucord/apks/

## Disassemble .bundle file
cd /tmp/aliucord/downloads
unzip -p base.apk assets/index.android.bundle > index.android.bundle
/tmp/aliucord/tools/hbcdump index.android.bundle -human -pretty-disassemble -out=bytecode.hbc -c="disassemble;quit"
cp bytecode.hbc ../apks/
