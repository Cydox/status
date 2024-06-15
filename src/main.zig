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

    // var t = try std.time.Timer.start();

    const timer_fd = try posix.timerfd_create(linux.CLOCK.REALTIME, linux.TFD{ ._0 = 0 });

    // const epoll_fd: i32 = @bitCast(@as(u32, (@truncate(linux.epoll_create1(0)))));
    // defer posix.close(epoll_fd);
    // if (epoll_fd < 0) {
    //     return error.anyerror;
    // }

    var now: posix.timespec = undefined;
    try posix.clock_gettime(linux.CLOCK.REALTIME, &now);

    // std.debug.print("now: {} s {} ns\n", .{ now.tv_sec, now.tv_nsec });
    now.tv_nsec = 0;
    try write_time_fmt(&now, w);
    try bw.flush();

    // var tspec: linux.itimerspec = .{
    //     .it_value = .{ .tv_sec = (@divTrunc(now.tv_sec, 60) + 1) * 60, .tv_nsec = 0 },
    //     .it_interval = .{ .tv_sec = 60, .tv_nsec = 0 },
    // };
    var tspec: linux.itimerspec = .{
        .it_value = .{ .tv_sec = now.tv_sec + 1, .tv_nsec = 0 },
        .it_interval = .{ .tv_sec = 1, .tv_nsec = 0 },
    };
    try posix.timerfd_settime(timer_fd, .{ .ABSTIME = true }, &tspec, null);

    // var timer_event: linux.epoll_event = .{
    //     .events = linux.EPOLL.IN,
    //     .data = linux.epoll_data{ .u32 = 0 },
    // };

    // if (@as(i32, @bitCast(@as(u32, @truncate(linux.epoll_ctl(
    //     epoll_fd,
    //     linux.EPOLL.CTL_ADD,
    //     timer_fd,
    //     &timer_event,
    // ))))) < 0) {
    //     return error.anyerror;
    // }

    // var event_queue: [1]linux.epoll_event = undefined;

    while (true) {
        // const n_events: i32 = @bitCast(@as(u32, @truncate(linux.epoll_wait(
        //     epoll_fd,
        //     &event_queue,
        //     event_queue.len,
        //     -1,
        // ))));
        // if (n_events < 0) {
        //     continue;
        // }

        // for (event_queue[0..@as(u32, @bitCast(n_events))]) |_| {
        var buf: [8]u8 = undefined;
        // const t0 = t.read();
        _ = try posix.read(timer_fd, &buf);
        // const t1 = t.read();

        // std.debug.print("time to read: {} [ns]\n", .{t1 - t0});

        const dt: u64 = @as(u64, @bitCast(buf)) * 1;
        now.tv_sec += @intCast(dt);

        try write_time_fmt(@ptrCast(&now), &w);

        try bw.flush();
        // }
    }
}

fn write_time_fmt(now: *posix.timespec, w: anytype) !void {
    var buf: [64]u8 = undefined;
    const gm = c.localtime(@ptrCast(now));
    // const n = c.strftime(&buf, buf.len, "%a %b %d %H:%M:%S UTC %Y", gm);
    const n = c.strftime(&buf, buf.len, "%a %b %d %I:%M:%S %p %Z %Y", gm);
    // const n = c.strftime(&buf, buf.len, "%a %b %d %I:%M %p %Z %Y", gm);
    try w.print("{s}\n", .{buf[0..n]});
}
