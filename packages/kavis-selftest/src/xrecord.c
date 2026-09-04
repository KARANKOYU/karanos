/* XRecord plumbing for the selftest recorder (item 72).
 *
 * WHY C. Everything else in this package is Vala, but XRecord has no
 * vapi in Debian and its API is two display connections plus a
 * callback that hands back raw protocol bytes — the kind of thing a
 * hand-written binding gets subtly wrong. Forty lines of C is smaller
 * and more honest than the binding would be. Vala calls the three
 * functions at the bottom; nothing else here is public.
 *
 * XRecord needs TWO connections to the server: the control one sets
 * the context up, the data one blocks reading events. That is a
 * protocol requirement, not a choice — a single connection deadlocks
 * the moment the recorder wants to ask the server anything.
 */
#include <X11/Xlib.h>
#include <X11/Xproto.h>
#include <X11/extensions/record.h>
#include <stdlib.h>
#include <string.h>

/* type, detail (keycode or button), root x, root y. */
typedef void (*kavis_record_cb) (int type, int detail, int x, int y,
                                 void *user);

static Display *control_dpy;
static Display *data_dpy;
static XRecordContext context;
static kavis_record_cb user_cb;
static void *user_data;

static void
intercept (XPointer closure, XRecordInterceptData *data)
{
	(void) closure;
	if (data->category == XRecordFromServer && data->data_len > 0) {
		const unsigned char *e = (const unsigned char *) data->data;
		int type = e[0] & 0x7f;
		if (type == KeyPress || type == KeyRelease
		    || type == ButtonPress || type == ButtonRelease) {
			/* xEvent layout: type, detail, sequence(2), time(4),
			 * root(4), event(4), child(4), rootX(2), rootY(2). */
			short x = (short) ((e[21] << 8) | e[20]);
			short y = (short) ((e[23] << 8) | e[22]);
			user_cb (type, e[1], x, y, user_data);
		}
	}
	XRecordFreeData (data);
}

/* Returns the file descriptor of the data connection, or -1. The
 * caller watches that fd and calls kavis_record_pump when it is
 * readable. */
int
kavis_record_start (kavis_record_cb cb, void *user)
{
	XRecordRange *range;
	XRecordClientSpec clients = XRecordAllClients;
	int major, minor;

	user_cb = cb;
	user_data = user;

	control_dpy = XOpenDisplay (NULL);
	data_dpy = XOpenDisplay (NULL);
	if (!control_dpy || !data_dpy) {
		return -1;
	}
	if (!XRecordQueryVersion (control_dpy, &major, &minor)) {
		return -1;   /* no RECORD extension: the caller says so */
	}
	range = XRecordAllocRange ();
	if (!range) {
		return -1;
	}
	range->device_events.first = KeyPress;
	range->device_events.last = ButtonRelease;
	context = XRecordCreateContext (control_dpy, 0, &clients, 1,
	                                &range, 1);
	XFree (range);
	if (!context) {
		return -1;
	}
	XSync (control_dpy, False);
	if (!XRecordEnableContextAsync (data_dpy, context, intercept, NULL)) {
		return -1;
	}
	return ConnectionNumber (data_dpy);
}

void
kavis_record_pump (void)
{
	if (data_dpy) {
		XRecordProcessReplies (data_dpy);
	}
}

void
kavis_record_stop (void)
{
	if (control_dpy && context) {
		XRecordDisableContext (control_dpy, context);
		XRecordFreeContext (control_dpy, context);
		XSync (control_dpy, False);
		context = 0;
	}
	if (data_dpy) {
		XCloseDisplay (data_dpy);
		data_dpy = NULL;
	}
	if (control_dpy) {
		XCloseDisplay (control_dpy);
		control_dpy = NULL;
	}
}
