#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <bits/time.h>
#include <sys/time.h>
#include <time.h>
#include <sys/timerfd.h>

#define BUF_SIZE 1024
static char buf[BUF_SIZE];

ssize_t write_time_fmt(const struct timespec *t, char *p, size_t p_len) {
	struct tm *gm = localtime((const time_t *)t);
	assert(gm);

	ssize_t n = strftime(p, p_len, "%a %b %d %I:%M:%S %p %Z %Y\n", gm);
	assert(n > 0);

	return n;
}

int main (void) {
	int r;

	while (1) {
		struct timespec now;
		r = clock_gettime(CLOCK_REALTIME, &now);
		assert(!r);

		now.tv_nsec = 0;

		struct itimerspec tspec = {
			.it_value = {.tv_sec = now.tv_sec + 1, .tv_nsec = 0},
			.it_interval = {.tv_sec = 1, .tv_nsec = 0}
		};

		int timer_fd = timerfd_create(CLOCK_REALTIME, 0);
		assert(timer_fd >= 0);

		r = timerfd_settime(
			timer_fd,
			TFD_TIMER_ABSTIME | TFD_TIMER_CANCEL_ON_SET,
			&tspec,
			0
		);
		assert(!r);

		while (1) {
			char read_buf[8];

			ssize_t n = write_time_fmt(&now, buf, BUF_SIZE);
			r = write(1, buf, n);
			assert(r == n);

			n = read(timer_fd, read_buf, 8);
			if (n != 8) {
				assert(errno == ECANCELED);
				break;
			}

			uint64_t dt = *((uint64_t *)read_buf);
			now.tv_sec += dt;
		}

		r = close(timer_fd);
		assert(!r);
	}

	return EXIT_SUCCESS;
}
