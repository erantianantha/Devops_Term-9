# Task 3 - Java deployment, multi-stage.
#
# The clearest size demonstration of the three, because the two base images
# are so far apart:
#     eclipse-temurin:21-jdk   726MB   compiler, javadoc, jshell, debugger
#     eclipse-temurin:21-jre   459MB   just enough to run bytecode
FROM eclipse-temurin:21-jdk AS build
WORKDIR /build
COPY src/Deploy.java .
RUN javac -Xlint:all -d classes Deploy.java

FROM eclipse-temurin:21-jre
WORKDIR /srv
COPY --from=build /build/classes ./classes
ENV PORT=8080
EXPOSE 8080
RUN useradd --system --no-create-home --shell /usr/sbin/nologin svc
USER svc
CMD ["java", "-XX:MaxRAMPercentage=75", "-cp", "classes", "Deploy"]
