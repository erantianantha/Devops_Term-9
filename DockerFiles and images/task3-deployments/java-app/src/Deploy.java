import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/** Task 3, Java deployment. Same two routes as the Node and Python ones. */
public class Deploy {

    private static final int PORT =
            Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));

    private static final Map<String, String> FACTS = new LinkedHashMap<>();
    static {
        FACTS.put("stack", "Java 21, JDK HttpServer");
        FACTS.put("base", "eclipse-temurin:21-jre");
        FACTS.put("builder", "eclipse-temurin:21-jdk, discarded");
        FACTS.put("artefact", "compiled classes copied out of stage 1");
    }

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", PORT), 0);
        server.createContext("/", Deploy::card);
        server.createContext("/health", ex -> send(ex, 200,
                "{\"ok\":true,\"stack\":\"java\",\"host\":\"" + host() + "\"}",
                "application/json"));
        server.start();
        System.out.println("[java] listening on 0.0.0.0:" + PORT);
    }

    private static void card(HttpExchange ex) throws IOException {
        if (!ex.getRequestURI().getPath().equals("/")) {
            send(ex, 404, "not found\n", "text/plain");
            return;
        }
        StringBuilder rows = new StringBuilder();
        FACTS.forEach((k, v) -> rows.append("  <dt>").append(k).append("</dt><dd>")
                                    .append(v).append("</dd>\n"));

        // Built with concatenation rather than String.formatted, because the
        // CSS below contains a literal % and Formatter would read it as the
        // start of a conversion.
        String html = "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
            + "<title>deploy :: java</title>\n<style>\n"
            + " body{margin:0;min-height:100vh;display:grid;place-items:center;background:#f4f1ea;"
            + "color:#1f2124;font-family:\"Segoe UI\",system-ui,sans-serif}\n"
            + " .card{background:#fff;border:1px solid #d9d3c7;border-radius:10px;"
            + "padding:2rem 2.4rem;box-shadow:0 10px 30px rgba(0,0,0,.07);min-width:24rem}\n"
            + " h1{margin:0 0 .2rem;font-size:1.9rem}\n"
            + " .tag{font-size:.75rem;letter-spacing:.12em;text-transform:uppercase;"
            + "color:#b07219;font-weight:700}\n"
            + " dl{display:grid;grid-template-columns:auto 1fr;gap:.35rem 1rem;font-size:.88rem;"
            + "margin-top:1.3rem}\n dt{color:#6b6b6b} dd{margin:0;font-family:Consolas,monospace}\n"
            + "</style></head><body><main class=\"card\">\n"
            + "<span class=\"tag\">deployment 3 of 3</span>\n<h1>Java</h1>\n<dl>\n"
            + rows
            + "  <dt>container</dt><dd>" + host() + "</dd>\n"
            + "  <dt>port</dt><dd>" + PORT + "</dd>\n"
            + "  <dt>heap ceiling</dt><dd>"
            + (Runtime.getRuntime().maxMemory() / (1024 * 1024)) + " MB</dd>\n"
            + "</dl></main></body></html>";

        send(ex, 200, html, "text/html; charset=utf-8");
    }

    private static String host() {
        return System.getenv().getOrDefault("HOSTNAME", "unknown");
    }

    private static void send(HttpExchange ex, int code, String body, String type)
            throws IOException {
        byte[] out = body.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type", type);
        ex.sendResponseHeaders(code, out.length);
        try (OutputStream os = ex.getResponseBody()) { os.write(out); }
    }
}
