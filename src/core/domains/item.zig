pub const Item = extern struct {
    itemID: i16,
    effect: [3]IValue,
};

pub const IValue = extern struct {
    index: u8,
    value: u8,
};
