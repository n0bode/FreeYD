pub fn BoundedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        len: usize = 0,

        pub fn init() BoundedArray(T, capacity) {
            return BoundedArray(T, capacity){
                .items = undefined,
                .len = 0,
            };
        }

        pub fn push(self: *BoundedArray(T, capacity), item: T) !void {
            if (self.len >= capacity) {
                return error.Overflow;
            }
            self.items[self.len] = item;
            self.len += 1;
        }

        pub fn pop(self: *BoundedArray(T, capacity)) ?T {
            if (self.len == 0) {
                return null;
            }
            self.len -= 1;
            return self.items[self.len];
        }

        pub fn remove(self: *@This(), value: T) !void {
            for (0..self.len) |i| {
                if (self.items[i] == value) {
                    try self.removeAt(i);
                    return;
                }
            }
        }

        pub fn removeAt(self: *@This(), index: usize) !void {
            if (index >= self.len) {
                return error.OutOfBounds;
            }

            defer _ = self.pop();
            if (index == self.len - 1) {
                return;
            }

            for (index..(self.len - 1)) |i| {
                self.items[index] = self.items[index + i];
            }
        }

        pub fn get(self: *BoundedArray(T, capacity), index: usize) !*T {
            if (index >= self.len) {
                return error.OutOfBounds;
            }
            return &self.items[index];
        }
    };
}
