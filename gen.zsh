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
mkdir -p /tmp/aliucord/downloads


## Iterate over all discord architectures to download apks and replace native libs
mkdir /tmp/aliucord/apks/unsigned -p
architectures_url=(x86 x86_64 arm64_v8a armeabi_v7a)
architectures_zip=(x86 x86_64 arm64-v8a armeabi-v7a)

unzip -o /tmp/aliucord/downloads/hermes-cppruntime-release.aar
unzip -o /tmp/aliucord/downloads/hermes-release.aar
for i in {1..$#architectures_url}; do
	# Download config apk
	wget -nv "https://aliucord.com/download/discord?v=$discordver&split=config.${architectures_url[i]}" -O "/tmp/aliucord/apks/unsigned/config.${architectures_url[i]}.apk"
	
        java -jar /tmp/aliucord/tools/apktool.jar empty-framework-dir --force -p com.alucordrn d /tmp/aliucord/apks/unsigned/config.${architectures_url[i]}.apk -o /tmp/aliucord/apks/unsigned/config.${architectures_url[i]}
done

## Download AliucordNative
wget -nv "https://nightly.link/Aliucord/AliucordNative/workflows/android/main/AliucordNative.zip" -O /tmp/aliucord/downloads/AliucordNative.zip
unzip /tmp/aliucord/downloads/AliucordNative.zip

## Download and patch base apk
wget -nv "https://aliucord.com/download/discord?v=$discordver" -O /tmp/aliucord/downloads/base.apk
java -jar /tmp/aliucord/tools/apktool.jar b base.apk
java -jar /tmp/aliucord/tools/apktool.jar d --no-src base.apk
cd base
echo "Patching manifest"
cat 'AndroidManifest.xml' \
| sed 's/<uses-permission android:maxSdkVersion="23" android:name="android.permission.WRITE_EXTERNAL_STORAGE"\/>/<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"\/>\n    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"\/>/g' \
| sed 's/<application /<application android:usesCleartextTraffic="true" android:debuggable="true" /g' \
| sed 's/<\/application>/<activity android:name="com.facebook.react.devsupport.DevSettingsActivity" android:exported="true" \/>\n<\/application>/g' \
| sed 's/android:enabled="true" android:exported="false" android:name="com.google.android.gms.analytics.Analytics/android:enabled="false" android:exported="false" android:name="com.google.android.gms.analytics.Analytics/g' \
| sed 's/<meta-data android:name="com.google.android.nearby.messages.API_KEY"/<meta-data android:name="firebase_crashlytics_collection_enabled" android:value="false"\/>\n<meta-data android:name="com.google.android.nearby.messages.API_KEY"/g' \
> AndroidManifest.xml
# Replace com.diskord with alucord.com in AndroidManifest.xml for all split APKs

# Path to apktool.jar
APKTOOL="java -jar /tmp/aliucord/tools/apktool.jar"

# Path to APK file
APK_FILE="/tmp/aliucord/downloads/base.apk"

# Output directory for APK tool
OUTPUT_DIR="/tmp/aliucord/apks"

# Extract base APK
$APKTOOL d $APK_FILE -o $OUTPUT_DIR/base

# Extract split APKs
for f in $OUTPUT_DIR/config.*.apk; do
  $APKTOOL d $f -o $OUTPUT_DIR/splits/$(basename "${f%.*}")
done

# Modify package name in AndroidManifest.xml for all APKs
sed -i 's/package="com.diskord"/package="alucord.com"/g' $OUTPUT_DIR/*/AndroidManifest.xml


for f in ./classes?.dex(On); do
	OLD_NUM="${f//\.(\/classes|dex)/}"
	NEW_NUM=$((OLD_NUM+1))
	echo "$f -> ${f/$OLD_NUM/$NEW_NUM}"
	mv $f "${f/$OLD_NUM/$NEW_NUM}"
done
echo "classes.dex -> classes2.dex"
mv classes.dex classes2.dex
cp /tmp/aliucord/downloads/classes.dex classes.dex
cd ..
java -jar /tmp/aliucord/tools/apktool.jar empty-framework-dir --force -p com.alucordrn base

cd base/build/apk

## Replace all necessary files in base.apk
zip -u /tmp/aliucord/downloads/base.apk AndroidManifest.xml
for dex in ./classes*.dex; do
	zip -u /tmp/aliucord/downloads/base.apk $dex
done
cp /tmp/aliucord/downloads/base.apk /tmp/aliucord/apks/unsigned/base.apk

## Download rest of the splits
# Lanuage splits
wget -nv "https://aliucord.com/download/discord?v=$discordver&split=config.en" -O /tmp/aliucord/apks/unsigned/config.en.apk
# wget -nv "https://aliucord.com/download/discord?v=$discordver&split=config.de" -O /tmp/aliucord/apks/unsigned/config.de.apk
# DPI Splits
wget -nv "https://aliucord.com/download/discord?v=$discordver&split=config.hdpi" -O /tmp/aliucord/apks/unsigned/config.hdpi.apk
wget -nv "https://aliucord.com/download/discord?v=$discordver&split=config.xxhdpi" -O /tmp/aliucord/apks/unsigned/config.xxhdpi.apk

## Sign all apks
#java -jar /tmp/aliucord/tools/uber-apk-signer.jar --apks /tmp/aliucord/apks/unsigned/ --allowResign --out /tmp/aliucord/apks/

# Repackage APKs
$APKTOOL b $OUTPUT_DIR/base -o $OUTPUT_DIR/unsigned/base.apk
for f in $OUTPUT_DIR/splits/*; do
  $APKTOOL b $f -o $OUTPUT_DIR/unsigned/$(basename "$f")
done

# Sign all apks
java -jar /tmp/aliucord/tools/uber-apk-signer.jar --apks /tmp/aliucord/apks/unsigned/ --allowResign --out /tmp/aliucord/apks/

# Clean up
rm -rf $OUTPUT_DIR/base
rm -rf $OUTPUT_DIR/splits
rm -rf $OUTPUT_DIR/unsigned

