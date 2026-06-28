build:
	killall -SIGKILL zyd 2>/dev/null || true
	zig build
