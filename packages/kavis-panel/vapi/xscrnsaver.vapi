/* Minimal binding for the X screen saver extension (item 51).
 *
 * Only the idle counter is needed — milliseconds since the last key or
 * pointer event, the same number every screen locker uses. Debian has
 * no vapi for libXss, and a full binding for two functions would be
 * more code than the feature. It lives in a vapi rather than in a .vala
 * file so valac treats the struct as one C already defines instead of
 * emitting a second, conflicting definition of it.
 *
 * Link with -lXss (packages/kavis-panel/debian/rules).
 */

[CCode (cheader_filename = "X11/extensions/scrnsaver.h")]
namespace XScreenSaver {

	[CCode (cname = "XScreenSaverInfo", free_function = "XFree",
	        has_type_id = false)]
	[Compact]
	public class Info {
		public X.Window window;
		public int state;
		public int kind;
		public ulong til_or_since;
		/* Milliseconds since the last input event. */
		public ulong idle;
		public ulong eventMask;
	}

	[CCode (cname = "XScreenSaverAllocInfo")]
	public Info? alloc_info ();

	[CCode (cname = "XScreenSaverQueryInfo")]
	public int query_info (X.Display display, X.Drawable drawable, Info info);
}
