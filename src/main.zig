const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const c = @cImport({
    @cInclude("time.h");
});

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout);
    var w = bw.writer();

    const timer_fd = try posix.timerfd_create(linux.CLOCK.REALTIME, linux.TFD{ ._0 = 0 });

    var now: posix.timespec = undefined;
    try posix.clock_gettime(linux.CLOCK.REALTIME, &now);

    now.tv_nsec = 0;
    try write_time_fmt(&now, w);
    try bw.flush();

    var tspec: linux.itimerspec = .{
        .it_value = .{ .tv_sec = now.tv_sec + 1, .tv_nsec = 0 },
        .it_interval = .{ .tv_sec = 1, .tv_nsec = 0 },
    };
    try posix.timerfd_settime(timer_fd, .{ .ABSTIME = true }, &tspec, null);

    while (true) {
        var buf: [8]u8 = undefined;
        _ = try posix.read(timer_fd, &buf);

        const dt: u64 = @as(u64, @bitCast(buf)) * 1;
        now.tv_sec += @intCast(dt);

        try write_time_fmt(@ptrCast(&now), &w);

        try bw.flush();
    }
}

fn write_time_fmt(now: *posix.timespec, w: anytype) !void {
    var buf: [64]u8 = undefined;
    const gm = c.localtime(@ptrCast(now));
    const n = c.strftime(&buf, buf.len, "%a %b %d %I:%M:%S %p %Z %Y", gm);
    try w.print("{s}\n", .{buf[0..n]});
}
