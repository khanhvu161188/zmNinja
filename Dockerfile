# Build environment
FROM openjdk:8 as base

USER root
ENV SDK_URL="https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip" \
    ANDROID_HOME="/usr/local/android-sdk" \
    ANDROID_VERSION=28 \
    ANDROID_BUILD_TOOLS_VERSION=29.0.2
    
# Download Android SDK
RUN mkdir "$ANDROID_HOME" .android \
    && cd "$ANDROID_HOME" \
    && curl -o sdk.zip $SDK_URL \
    && unzip sdk.zip \
    && rm sdk.zip \
    && yes | $ANDROID_HOME/tools/bin/sdkmanager --licenses

# Install Android Build Tool and Libraries
RUN $ANDROID_HOME/tools/bin/sdkmanager --update
RUN $ANDROID_HOME/tools/bin/sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    "platforms;android-${ANDROID_VERSION}" \
    "platform-tools"

# Install Build Essentials
RUN apt-get update \
    && apt-get upgrade -y \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get install -y nodejs 
RUN npm install -g cordova@8.1.1 @ionic/cli @ionic/v1-toolkit
WORKDIR src
RUN git clone --depth 1 https://github.com/khanhvu161188/zmNinja.git
WORKDIR zmNinja
RUN npm install 
RUN npm install jshint
RUN npm install -g npm
RUN cordova platform add android
RUN cordova prepare 
RUN chmod +x build_android.sh

ENV ANDROID_SDK_ROOT="/usr/local/android-sdk" 
RUN apt-get install -y gradle
RUN ./build_android.sh --debug


# Install app center
RUN mkdir ~/.appcenter-cli && \
    echo false > ~/.appcenter-cli/telemetryEnabled.json && \
    npm install -g appcenter-cli


WORKDIR debug_files
# Upload a build to distribute via appcenter
ENV APPCENTER_ACCESS_TOKEN="TOKEN"
ENV APK_FOLDER="./"
ENV OWNERNAME="OWNER"
ENV STAGING_APPNAME="zm"
ENV RELEASENOTES="from docker"
RUN ls .
RUN echo "Finding staging build" && \
    message=$(git log -1 HEAD --pretty=format:%s) && \
    echo "Messages: $message" && \
    apkPath=$(find ${APK_FOLDER} -name "*.apk" | head -1) && \
    if [ -z ${apkPath} ] ; then echo "No apks were found, skip publishing to App Center" ; \
    else \
        echo "Found staging apk at $apkPath" && \
        echo "Pushing staging app to app center" && \
        appcenter distribute release \
        --group Collaborators \
        --file "${apkPath}" \
        --release-notes "${message}" \
        --app "${OWNERNAME}/${STAGING_APPNAME}" \
        --token "${APPCENTER_ACCESS_TOKEN}" \
        --quiet && \
        echo "Pushed staging app to app center" \
    ; fi
