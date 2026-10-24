FROM eclipse-temurin:17.0.20.1_1-jdk-noble@sha256:fdae60b4aee31b7228cd10fa883141fe8da67b59ba4d6292af47ccf8e5fd59d2 AS build

WORKDIR /workspace
ENV MAVEN_OPTS="-Xmx384m -Dfile.encoding=UTF-8"
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN sed -i 's/\r$//' mvnw && chmod 0755 mvnw
COPY src/ src/
COPY config/ config/
RUN --mount=type=cache,target=/root/.m2,sharing=locked \
    ./mvnw -B -ntp clean verify -DargLine=-Xmx384m

FROM eclipse-temurin:17.0.20.1_1-jre-noble@sha256:07fa0356cf354c5252947575f42ed42aa6fd921f36438b7bc77ad81c31c537dd

WORKDIR /app
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app
COPY --from=build /workspace/target/demo-0.0.1.jar /app/app.jar

ENV PORT=8000
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=60.0 -XX:InitialRAMPercentage=20.0"
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl --noproxy '*' --fail --silent --show-error --max-time 3 \
    "http://127.0.0.1:${SERVER_PORT:-${PORT:-8000}}/api/actuator/health/readiness" || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
