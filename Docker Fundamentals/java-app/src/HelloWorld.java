import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.Executors;

/**
 * Hello World over HTTP with nothing but the JDK.
 *
 * com.sun.net.httpserver has shipped with every JDK since 6, so there is no
 * Maven or Gradle step and no dependency download inside the image. A real
 * service would be Spring Boot, but then the Dockerfile would mostly be a
 * lesson about build tools rather than about layers and stages.
 */
public final class HelloWorld {

    private static final int PORT =
            Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));

    private static final Instant BOOTED = Instant.now();

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", PORT), 0);

        server.createContext("/", HelloWorld::page);
        server.createContext("/health", HelloWorld::health);

        // A small fixed pool rather than the default null executor, which
        // serves every request on the accept thread and therefore serialises
        // them. Two threads is plenty here and makes the behaviour explicit.
        server.setExecutor(Executors.newFixedThreadPool(2));
        server.start();

        System.out.printf("ana-java up on http://0.0.0.0:%d%n", PORT);
    }

    private static void page(HttpExchange exchange) throws IOException {
        // createContext("/") is a PREFIX match, so without this check every
        // unknown path returns the landing page and a typo looks like success.
        if (!"/".equals(exchange.getRequestURI().getPath())) {
            send(exchange, 404, "not found\n", "text/plain; charset=utf-8");
            return;
        }

        Map<String, String> env = System.getenv();
        String body = """
                <!doctype html>
                <html lang="en">
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Hello World :: Java</title>
                <style>
                  :root { color-scheme: light; }
                  body { margin: 0; min-height: 100vh; display: grid; place-items: center;
                         background: #f4f1ea; color: #1f2124;
                         font-family: "Segoe UI", system-ui, sans-serif; }
                  .card { background: #fff; border: 1px solid #d9d3c7; border-radius: 10px;
                          padding: 2rem 2.5rem; box-shadow: 0 10px 30px rgba(0,0,0,.07);
                          max-width: 30rem; }
                  h1 { margin: 0 0 .25rem; font-size: 2.4rem; letter-spacing: -.02em; }
                  .stack { font-size: .8rem; text-transform: uppercase; letter-spacing: .12em;
                           color: #b07219; font-weight: 700; }
                  dl { display: grid; grid-template-columns: auto 1fr; gap: .35rem 1rem;
                       margin: 1.5rem 0 0; font-size: .9rem; }
                  dt { color: #6b6b6b; }
                  dd { margin: 0; font-family: Consolas, "Courier New", monospace; }
                </style>
                </head>
                <body>
                  <main class="card">
                    <span class="stack">Java :: JDK HttpServer</span>
                    <h1>Hello World</h1>
                    <p>Compiled by a JDK stage, served by a JRE-only image.</p>
                    <dl>
                      <dt>listening on</dt><dd>0.0.0.0:%d</dd>
                      <dt>container id</dt><dd>%s</dd>
                      <dt>java version</dt><dd>%s</dd>
                      <dt>vm</dt><dd>%s</dd>
                      <dt>uptime</dt><dd>%ds</dd>
                    </dl>
                  </main>
                </body>
                </html>
                """.formatted(
                        PORT,
                        env.getOrDefault("HOSTNAME", "unknown"),
                        System.getProperty("java.version"),
                        System.getProperty("java.vm.name"),
                        Duration.between(BOOTED, Instant.now()).toSeconds());

        send(exchange, 200, body, "text/html; charset=utf-8");
    }

    private static void health(HttpExchange exchange) throws IOException {
        String json = "{\"ok\":true,\"service\":\"java\",\"host\":\"%s\"}"
                .formatted(env("HOSTNAME"));
        send(exchange, 200, json, "application/json");
    }

    private static String env(String key) {
        return System.getenv().getOrDefault(key, "unknown");
    }

    private static void send(HttpExchange exchange, int status, String body, String type)
            throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", type);
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream out = exchange.getResponseBody()) {
            out.write(bytes);
        }
    }
}
