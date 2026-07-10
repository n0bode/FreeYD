build:
	killall -SIGKILL zyd 2>/dev/null || true
	zig build

run:
	killall -SIGKILL zyd 2>/dev/null || true
	zig build run

drop-accounts:
	[[ -e ./dbs ]] && rm ./dbs/*
