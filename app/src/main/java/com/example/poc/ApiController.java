package com.example.poc;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.*;

import java.net.InetAddress;
import java.time.Instant;
import java.util.*;

@RestController
public class ApiController {

    @GetMapping({"/", "/api/public"})
    public Map<String, Object> publicEndpoint() throws Exception {
        return Map.of(
                "message", "public endpoint reached",
                "time", Instant.now().toString(),
                "pod", InetAddress.getLocalHost().getHostName()
        );
    }

    @GetMapping("/api/user")
    public Map<String, Object> user() {
        return Map.of("message", "authenticated user endpoint reached");
    }

    @GetMapping("/api/admin")
    public Map<String, Object> admin() {
        return Map.of("message", "admin-only endpoint reached");
    }

    @GetMapping("/api/whoami")
    public Map<String, Object> whoami(HttpServletRequest request) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("authorizationPresent", request.getHeader(HttpHeaders.AUTHORIZATION) != null);
        out.put("xAuthRequestUser", request.getHeader("X-Auth-Request-User"));
        out.put("xAuthRequestEmail", request.getHeader("X-Auth-Request-Email"));
        out.put("xForwardedUser", request.getHeader("X-Forwarded-User"));
        out.put("xForwardedEmail", request.getHeader("X-Forwarded-Email"));
        out.put("xForwardedAccessTokenPresent", request.getHeader("X-Forwarded-Access-Token") != null);
        return out;
    }

    @GetMapping("/api/headers")
    public Map<String, String> headers(HttpServletRequest request) {
        Map<String, String> headers = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        Enumeration<String> names = request.getHeaderNames();
        while (names.hasMoreElements()) {
            String name = names.nextElement();
            String value = request.getHeader(name);
            if (name.equalsIgnoreCase("authorization") && value != null) {
                value = value.length() > 20 ? value.substring(0, 20) + "...[redacted]" : "[redacted]";
            }
            if (name.toLowerCase().contains("token") && value != null) {
                value = "[present; redacted]";
            }
            headers.put(name, value);
        }
        return headers;
    }
}
