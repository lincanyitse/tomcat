#!/bin/sh

nativeBuildDir="$(mktemp -d)" &&
    cd /usr/local/tomcat &&
    tar -xf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1 &&
    savedAptMark="$(apt-mark showmanual)" &&
    apt-get update -qq && apt-get install -qqy \
    dpkg-dev \
    gcc \
    libapr1-dev \
    libssl-dev \
    make >/dev/null &&
    (
        export CATALINA_HOME="$PWD"
        cd "$nativeBuildDir/native"
        gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"
        aprConfig="$(command -v apr-1-config)"
        ./configure \
            --build="$gnuArch" \
            --libdir="$TOMCAT_NATIVE_LIBDIR" \
            --prefix="$CATALINA_HOME" \
            --with-apr="$aprConfig" \
            --with-java-home="$JAVA_HOME" \
            --with-ssl=yes \
            ;
        nproc="$(nproc)"
        make -j "$nproc"
        make install
    )
rm -rf "$nativeBuildDir"
rm bin/tomcat-native.tar.gz

apt-mark auto '.*' >/dev/null
[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null
find "$TOMCAT_NATIVE_LIBDIR" -type f -executable -exec ldd '{}' ';' |
    awk '/=>/ { print $(NF-1) }' |
    xargs -rt readlink -e |
    sort -u |
    xargs -rt dpkg-query --search |
    cut -d: -f1 |
    sort -u |
    tee "$TOMCAT_NATIVE_LIBDIR/.dependencies.txt" |
    xargs -r apt-mark manual \
    ;

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/*

# sh removes env vars it doesn't support (ones with periods)
# https://github.com/docker-library/tomcat/issues/77
find ./bin/ -name '*.sh' -exec sed -ri 's|^#!/bin/sh$|#!/usr/bin/env bash|' '{}' +

# fix permissions (especially for running as non-root)
# https://github.com/docker-library/tomcat/issues/35
chmod -R +rX .
chmod 777 logs temp work

# smoke test
catalina.sh version

# verify Tomcat Native is working properly
nativeLines="$(catalina.sh configtest 2>&1)"
nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')"
nativeLines="$(echo "$nativeLines" | sort -u)"
if ! echo "$nativeLines" | grep -E 'INFO: Loaded( APR based)? Apache Tomcat Native library' >&2; then
    echo >&2 "$nativeLines"
    exit 1
fi
