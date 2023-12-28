FROM lincanyitse/tomcat:8-jdk8-debian as tomcat
FROM lincanyitse/openjdk:8-jre-debian

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

COPY *.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/*.sh

EXPOSE 8080
CMD ["catalina.sh", "run"]