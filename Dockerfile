FROM lincanyitse/openjdk:8-jdk-debian

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

COPY docker-entrypoint.sh /
COPY /docker-entrypoint.d/*.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.sh /docker-entrypoint.d/*.sh

EXPOSE 8080
CMD ["catalina.sh", "run"]