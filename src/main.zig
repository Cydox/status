const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const sqe_t = std.os.linux.io_uring_sqe;
const cqe_t = std.os.linux.io_uring_cqe;

const c = @cImport({
    @cInclude("time.h");
});

pub fn main() !void {
    const stdout = std.io.getStdOut();

    const ring_buf_size = @as(u64, 1) <<| 2;

    var io_uring = try linux.IoUring.init(
        @intCast(ring_buf_size),
        0 |
            linux.IORING_SETUP_DEFER_TASKRUN |
            linux.IORING_SETUP_SINGLE_ISSUER,
    );
    defer io_uring.deinit();

    const timer_fd = try posix.timerfd_create(linux.CLOCK.REALTIME, linux.TFD{ ._0 = 0 });
    defer posix.close(timer_fd);

    clock_reset: while (true) {
        var now: posix.timespec = undefined;
        try posix.clock_gettime(linux.CLOCK.REALTIME, &now);
        now.tv_nsec = 0;

        var tspec: linux.itimerspec = .{
            .it_value = .{ .tv_sec = now.tv_sec + 1, .tv_nsec = 0 },
            .it_interval = .{ .tv_sec = 1, .tv_nsec = 0 },
        };
        try posix.timerfd_settime(timer_fd, .{ .ABSTIME = true, .CANCEL_ON_SET = true }, &tspec, null);

        while (true) {
            var sqe: *sqe_t = undefined;
            var buf: [8]u8 = undefined;
            var buf2: [256]u8 = undefined;

            const n = write_time_fmt(@ptrCast(&now), &buf2);

            sqe = try io_uring.write(0, stdout.handle, buf2[0..n], 0);
            sqe.flags |= linux.IOSQE_CQE_SKIP_SUCCESS;
            sqe = try io_uring.read(1, timer_fd, .{ .buffer = &buf }, 0);

            _ = try io_uring.submit_and_wait(1);

            const cqe = try io_uring.copy_cqe();
            if (cqe.res != 8) {
                continue :clock_reset;
            }

            const dt: u64 = @as(u64, @bitCast(buf)) * 1;
            now.tv_sec += @intCast(dt);
        }
    }
}

fn write_time_fmt(now: *posix.timespec, buf: []u8) usize {
    const gm = c.localtime(@ptrCast(now));
    const n = c.strftime(buf.ptr, buf.len, "%a %b %d %I:%M:%S %p %Z %Y", gm);
    buf[n] = '\n';

    return n + 1;
}
