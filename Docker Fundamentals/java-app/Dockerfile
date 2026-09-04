# Java :: multi-stage ---------------------------------------------------------
# Demonstrates: compiling in one image and shipping in another.
#
# Stage "build" has javac. Stage "run" has only a JRE. The compiler, the source
# file and every intermediate stay behind in a stage that is never tagged, so
# they cost nothing in the final image and give an attacker who gets a shell
# nothing to compile with.

FROM eclipse-temurin:21-jdk AS build
WORKDIR /work
COPY src/HelloWorld.java .
# -Xlint:all so a warning in my own code shows up at build time rather than
# turning into a surprise at runtime.
RUN javac -Xlint:all -d /work/classes HelloWorld.java

FROM eclipse-temurin:21-jre
WORKDIR /opt/app

# The one instruction the whole pattern turns on: reach into the previous
# stage and take only the artefact.
COPY --from=build /work/classes ./classes

# The temurin images run as root by default, so create an account to drop to.
RUN useradd --system --create-home --shell /usr/sbin/nologin javauser
USER javauser

EXPOSE 8080

# -XX:MaxRAMPercentage is a container habit worth keeping: it sizes the heap
# from the cgroup limit rather than from the machine total, which is what got
# pre-10 JVMs OOM-killed in containers. Modern JVMs are container-aware, but
# writing it down states the intent.
CMD ["java", "-XX:MaxRAMPercentage=75", "-cp", "classes", "HelloWorld"]
