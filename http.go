package main

import (
	"log"
	"net/http"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /serv00", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("0\r\n0\r\n0\r\n0\r\n"))
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
	http.ListenAndServe(":8080", middleware(mux))
}
