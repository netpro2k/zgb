const Mem = @This();

data: [0xFFFF + 1]u8,

var first_read = false;

pub fn read(self: Mem, addr: u16) u8 {
    switch (addr) {
        0xFF44 => { // LY
            return 0x94; // TODO
        },
        else => {
            return self.data[addr];
        },
    }
}

pub fn read_ff(self: Mem, addr_nib: u8) u8 {
    return self.read(0xff00 + @as(u16, addr_nib));
}

pub fn write(self: *Mem, addr: u16, value: u8) void {
    self.data[addr] = value;
}

pub fn write_ff(self: *Mem, addr_nib: u8, value: u8) void {
    self.write(0xff00 + @as(u16, addr_nib), value);
}
