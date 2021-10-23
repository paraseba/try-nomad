FROM adoptopenjdk/openjdk16:alpine-slim AS base
ENV USER=docker
ENV UID=12345
ENV GID=23456
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home /home/docker \
    --uid "$UID" \
    "$USER"
USER docker


FROM base AS deps
COPY --chown=docker:docker app/build.gradle.kts settings.gradle.kts ./gradlew /app/
COPY --chown=docker:docker ./gradle/ /app/gradle/
RUN cd /app && ./gradlew --no-daemon --info resolveDependencies


FROM deps AS build
COPY --chown=docker:docker app/ /app/
RUN cd /app && ./gradlew --no-daemon --info clean installDist


FROM adoptopenjdk/openjdk16:alpine-slim
WORKDIR /app
COPY --from=build /app/build/install/svc0 ./
EXPOSE 8081
CMD ./bin/svc0