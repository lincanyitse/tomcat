ARG JDK_IMG="lincanyitse/openjdk:8-jdk-debian"
ARG JRE_IMG="lincanyitse/openjdk:8-jre-debian"
# jdk 版本
FROM ${JDK_IMG}

ARG TOMCAT_URL="https://mirrors.aliyun.com/apache/tomcat"

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH ${CATALINA_HOME}/bin:${PATH}
RUN mkdir -p "${CATALINA_HOME}"
WORKDIR ${CATALINA_HOME}

ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.5.100
ENV TOMCAT_DOWNLOAD_URL ${TOMCAT_URL}/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin

RUN set -eux && \
    latest=$(curl -fsSL ${TOMCAT_URL}/tomcat-8/|grep -oE '(v[0-9].[0-9].[0-9]{2,3})'|uniq|sort -nr|head -n 1) \
    && if [ "${TOMCAT_VERSION}" != "${latest#*v}" ]; then \
        export TOMCAT_VERSION="${latest#*v}"  \
        && export TOMCAT_DOWNLOAD_URL="${TOMCAT_URL}/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin"; \
    fi \
    && curl -fsSL ${TOMCAT_DOWNLOAD_URL}/apache-tomcat-${TOMCAT_VERSION}.tar.gz | tar -zx \
    --directory "${CATALINA_HOME}" \
    --strip-components 1 \
    --no-same-owner \
    && rmote_jar_name=$(curl -sL ${TOMCAT_DOWNLOAD_URL}/extras/|grep -oE 'catalina-[A-Za-z0-9-]+.jar'| head -n 1) \
    && curl -sL ${TOMCAT_DOWNLOAD_URL}/extras/${rmote_jar_name} -o ${CATALINA_HOME}/lib/${rmote_jar_name} 

RUN set -eux \
    && nativeBuildDir="$(mktemp -d)" \
    && cd /usr/local/tomcat \
    && tar -xf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1 \
    && savedAptMark="$(apt-mark showmanual)" \
    && apt-get update -qq && apt-get install -qqy \
    dpkg-dev \
	gcc \
	libapr1-dev \
	libssl-dev \
	make  >/dev/null \
    && ( \
    export CATALINA_HOME="$PWD"; \
		cd "$nativeBuildDir/native"; \
		gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
		aprConfig="$(command -v apr-1-config)"; \
		./configure \
			--build="$gnuArch" \
			--libdir="$TOMCAT_NATIVE_LIBDIR" \
			--prefix="$CATALINA_HOME" \
			--with-apr="$aprConfig" \
			--with-java-home="$JAVA_HOME" \
			--with-ssl=yes \
		; \
		nproc="$(nproc)"; \
		make -j "$nproc"; \
		make install; \
	); \
	rm -rf "$nativeBuildDir"; \
	rm bin/tomcat-native.tar.gz; \
    \
    apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	find "$TOMCAT_NATIVE_LIBDIR" -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| xargs -rt readlink -e \
		| sort -u \
		| xargs -rt dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| tee "$TOMCAT_NATIVE_LIBDIR/.dependencies.txt" \
		| xargs -r apt-mark manual \
	; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
    \
     # sh removes env vars it doesn't support (ones with periods)
    # https://github.com/docker-library/tomcat/issues/77
	find ./bin/ -name '*.sh' -exec sed -ri 's|^#!/bin/sh$|#!/usr/bin/env bash|' '{}' +; \
	\
    # fix permissions (especially for running as non-root)
    # https://github.com/docker-library/tomcat/issues/35
	chmod -R +rX .; \
	chmod 777 logs temp work; \
	\
    # smoke test
	catalina.sh version

# verify Tomcat Native is working properly
RUN set -eux; \
	nativeLines="$(catalina.sh configtest 2>&1)"; \
	nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')"; \
	nativeLines="$(echo "$nativeLines" | sort -u)"; \
	if ! echo "$nativeLines" | grep -E 'INFO: Loaded( APR based)? Apache Tomcat Native library' >&2; then \
		echo >&2 "$nativeLines"; \
		exit 1; \
	fi

EXPOSE 8080
CMD ["catalina.sh", "run"]

# jre 版本
FROM ${JRE_IMG}

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

# let "Tomcat Native" live somewhere isolated
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

# see https://www.apache.org/dist/tomcat/tomcat-8/KEYS
# see also "versions.sh" (https://github.com/docker-library/tomcat/blob/master/versions.sh)

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.5.97

COPY --from=tomcat $CATALINA_HOME $CATALINA_HOME
RUN set -eux; \
	apt-get update -qq && \
	xargs -rt apt-get install -y --no-install-recommends < "$TOMCAT_NATIVE_LIBDIR/.dependencies.txt" && \
	rm -rf /var/lib/apt/lists/*

# verify Tomcat Native is working properly
RUN set -eux; \
	nativeLines="$(catalina.sh configtest 2>&1)"; \
	nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')"; \
	nativeLines="$(echo "$nativeLines" | sort -u)"; \
	if ! echo "$nativeLines" | grep -E 'INFO: Loaded( APR based)? Apache Tomcat Native library' >&2; then \
		echo >&2 "$nativeLines"; \
		exit 1; \
	fi

EXPOSE 8080
CMD ["catalina.sh", "run"]