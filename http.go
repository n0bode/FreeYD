package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"time"
)

func main() {
	ctx, _ := signal.NotifyContext(context.Background(), os.Interrupt)
	var lc net.ListenConfig
	listen, err := lc.Listen(ctx, "tcp", "0.0.0.0:8080")
	if err != nil {
		slog.Error("failed to listen http", "err", err)
		return
	}

	go func() {
		<-ctx.Done()
		slog.Info("programa foi interrompido")
		listen.Close()
	}()

	for {
		slog.Info("esperando conexao")
		conn, err := listen.Accept()
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return
			}
			slog.Warn("erro ao conectar ao nova conexao", "err", err)
			continue
		}

		go func() {
			<-ctx.Done()
			conn.Close()
		}()

		content := `100\r\n-1\r\n-1\r\n-1\r\n-1\r\n`
		now := time.Now().Format("%a, %d %b %Y %H:%M:%S %Z")
		fmt.Fprintf(conn, "HTTP/1.1 200 OK\r\n")
		fmt.Fprintf(conn, "Date: %s\r\n", now)
		fmt.Fprintf(conn, "Content-Length: %d\r\n", len(content))
		fmt.Fprint(conn, "Connection: close\r\n")
		fmt.Fprintf(conn, "\r\n")
		fmt.Fprint(conn, content)

		conn.Close()
	}
}
