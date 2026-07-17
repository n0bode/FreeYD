build:
	pkill -SIGINT -f freeyd 2>/dev/null || true
	zig build

run:
	pkill -SIGINT -f freeyd 2>/dev/null || true
	zig build run

drop-accounts:
	[[ -e ./dbs ]] && rm ./dbs/*
