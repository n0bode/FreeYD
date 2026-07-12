build:
	killall -SIGTERM freeyd 2>/dev/null || true
	zig build

run:
	killall -SIGTERM freeyd 2>/dev/null || true
	zig build run

drop-accounts:
	[[ -e ./dbs ]] && rm ./dbs/*
