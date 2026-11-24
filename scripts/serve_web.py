import functools
import http.server
import os


class COIHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def run(web_dir=None, port=None):
    web_dir = web_dir or os.environ.get("WEB_DIR", "build/web")
    port = port or int(os.environ.get("PORT", "8080"))
    os.chdir(web_dir)

    handler = functools.partial(COIHandler, directory=web_dir)
    http.server.test(HandlerClass=handler, port=port, bind="127.0.0.1")


def main():
    run()


if __name__ == "__main__":
    main()
