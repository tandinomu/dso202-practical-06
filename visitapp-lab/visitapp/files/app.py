"""visitapp backend - a tiny JSON API that counts visits in Redis.

Uses only the Python standard library, so it runs on the stock python image
without building a custom container. Configuration comes from environment
variables that the Helm chart sets.

Endpoints
  GET  /api/health  liveness: the process is running
  GET  /api/ready   readiness: Redis answers PING
  GET  /api/stats   current visit count, without changing it
  POST /api/visit   add one visit and return the new count
"""
import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", "")
APP_ENV = os.environ.get("APP_ENV", "unknown")
APP_MESSAGE = os.environ.get("APP_MESSAGE", "")
APP_VERSION = os.environ.get("APP_VERSION", "unknown")
PORT = int(os.environ.get("APP_PORT", "8080"))
POD_NAME = socket.gethostname()


class RedisError(Exception):
    pass


def _encode(*args):
    """Encode a command in the Redis protocol (RESP)."""
    parts = [b"*%d\r\n" % len(args)]
    for arg in args:
        data = str(arg).encode()
        parts.append(b"$%d\r\n%s\r\n" % (len(data), data))
    return b"".join(parts)


def _read_reply(stream):
    line = stream.readline()
    if not line:
        raise RedisError("connection closed by Redis")
    kind, body = line[:1], line[1:-2]
    if kind == b"+":
        return body.decode()
    if kind == b"-":
        raise RedisError(body.decode())
    if kind == b":":
        return int(body)
    if kind == b"$":
        length = int(body)
        if length == -1:
            return None
        return stream.read(length + 2)[:-2].decode()
    raise RedisError("unexpected reply from Redis: %r" % line)


def redis(*command):
    """Run one Redis command and return its reply."""
    with socket.create_connection((REDIS_HOST, REDIS_PORT), timeout=2) as sock:
        stream = sock.makefile("rb")
        if REDIS_PASSWORD:
            sock.sendall(_encode("AUTH", REDIS_PASSWORD))
            _read_reply(stream)
        sock.sendall(_encode(*command))
        return _read_reply(stream)


def _visits():
    value = redis("GET", "visits")
    return int(value) if value is not None else 0


class Handler(BaseHTTPRequestHandler):
    server_version = "visitapp/" + APP_VERSION

    def _send(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _info(self, **extra):
        info = {
            "environment": APP_ENV,
            "message": APP_MESSAGE,
            "version": APP_VERSION,
            "servedBy": POD_NAME,
        }
        info.update(extra)
        return info

    def do_GET(self):
        try:
            if self.path == "/api/health":
                self._send(200, {"status": "ok"})
            elif self.path == "/api/ready":
                redis("PING")
                self._send(200, {"status": "ready"})
            elif self.path == "/api/stats":
                self._send(200, self._info(visits=_visits()))
            else:
                self._send(404, {"error": "not found"})
        except (OSError, RedisError) as err:
            self._send(503, {"error": "redis unavailable: %s" % err})

    def do_POST(self):
        try:
            if self.path == "/api/visit":
                self._send(200, self._info(visits=redis("INCR", "visits")))
            else:
                self._send(404, {"error": "not found"})
        except (OSError, RedisError) as err:
            self._send(503, {"error": "redis unavailable: %s" % err})

    def log_message(self, fmt, *args):
        # Probes call /api/health and /api/ready every few seconds; keep them
        # out of the logs so real requests are easy to read.
        if "/api/health" in self.requestline or "/api/ready" in self.requestline:
            return
        print("%s %s" % (self.address_string(), fmt % args), flush=True)


if __name__ == "__main__":
    print("visitapp %s (%s) listening on :%d, redis at %s:%d"
          % (APP_VERSION, APP_ENV, PORT, REDIS_HOST, REDIS_PORT), flush=True)
    ThreadingHTTPServer(("", PORT), Handler).serve_forever()
