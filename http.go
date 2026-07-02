package main

import (
	"log"
	"log/slog"
	"net/http"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /serv00", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("100\r\n1\r\n1\r\n"))
	})

	mux.HandleFunc("GET /serv01", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("100\r\n-1\r\n-1\r\n-1\r\n-1\r\n-1\r\n-1\r\n-1\r\n-1\r\n"))
	})

	middleware := func(next http.Handler) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			log.Printf("[%s] %s", r.Method, r.URL.Path)
			next.ServeHTTP(w, r)
		}
	}
	if err := http.ListenAndServe(":8080", middleware(mux)); err != nil {
		slog.Error("failed", err)
	}
}
