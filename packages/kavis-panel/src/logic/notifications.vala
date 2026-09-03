/* System-wide notification service (business logic — no widget code).
 *
 * Madde 37: the panel itself owns org.freedesktop.Notifications on the
 * session bus — no external daemon (dunst etc.) to configure, style
 * and keep from fighting over the bus name. Design rules distilled
 * from dunst's most-reported issues (docs/referans/grup-d-taramasi.md):
 *   - single ownership: if the name cannot be acquired, log LOUDLY —
 *     silent loss of notifications is the worst failure mode;
 *   - the history is CAPPED so weeks of uptime cannot balloon memory;
 *   - critical urgency is delivered even in do-not-disturb mode (the
 *     spec requires it);
 *   - each toast is its own window (drawn by ui/toast.vala), never
 *     rows painted into a shared surface.
 */

namespace Kavis {

    public class NotificationEntry {
        public uint32 id;
        public string app_name;
        public string app_icon;
        public string summary;
        public string body;
        public bool critical;
        public DateTime timestamp;
        /* Optional attachments (Grup D fix): a preview image shown in
         * the notification center ("image-path" hint, file path form)
         * and a file the click opens ("x-kavis-path" hint — Kavis'
         * own tools set it, e.g. a screenshot revealing itself in the
         * file manager). Empty when absent. */
        public string image_path = "";
        public string target_path = "";
        /* Action buttons (section 5c): [key, label, ...] pairs. The toast
         * draws a button per pair; a click goes back to the owner via
         * the ActionInvoked signal (like the color picker's 'copy rgb'). */
        public string[] actions = {};
    }

    [DBus (name = "org.freedesktop.Notifications")]
    public class NotificationServer : Object {

        public signal void notification_closed (uint32 id, uint32 reason);
        public signal void action_invoked (uint32 id, string action_key);

        /* Server-internal (not exported): the UI listens to these. */
        [DBus (visible = false)]
        public signal void toast_requested (NotificationEntry entry,
                                            int timeout_ms);
        [DBus (visible = false)]
        public signal void history_changed ();

        /* Kept modest on purpose (dunst lesson: unbounded history =
         * slow leak). Oldest entries fall off the end. */
        private const int HISTORY_LIMIT = 50;
        private const int DEFAULT_TIMEOUT_MS = 5000;

        public GenericArray<NotificationEntry> history =
            new GenericArray<NotificationEntry> ();
        public bool dnd = false;
        /* Suppressed while in DND — a batched summary is shown when DND
         * is turned off (madde 55: "show them in a batch later"). */
        private int suppressed = 0;

        private uint32 next_id = 1;

        public new uint32 notify (string app_name, uint32 replaces_id,
                              string app_icon, string summary, string body,
                              string[] actions,
                              HashTable<string, Variant> hints,
                              int32 expire_timeout) throws Error {
            var entry = new NotificationEntry ();
            entry.id = (replaces_id != 0) ? replaces_id : next_id++;
            entry.app_name = app_name;
            entry.app_icon = app_icon;
            entry.summary = summary;
            entry.body = body;
            entry.timestamp = new DateTime.now_local ();
            unowned Variant? urgency = hints.lookup ("urgency");
            entry.critical = (urgency != null
                              && urgency.get_byte () == 2);
            /* "image-path" is spec 1.2; "image_path" the 1.1 spelling —
             * accept both, file paths only (no raw image data). */
            unowned Variant? image = hints.lookup ("image-path")
                ?? hints.lookup ("image_path");
            if (image != null
                && image.is_of_type (VariantType.STRING)) {
                entry.image_path = image.get_string ();
            }
            unowned Variant? target = hints.lookup ("x-kavis-path");
            if (target != null
                && target.is_of_type (VariantType.STRING)) {
                entry.target_path = target.get_string ();
            }
            entry.actions = actions;

            /* If a notification was refreshed (replaces_id), drop the old entry. */
            for (int i = 0; i < history.length; i++) {
                if (history[i].id == entry.id) {
                    history.remove_index (i);
                    break;
                }
            }
            history.insert (0, entry);
            while (history.length > HISTORY_LIMIT) {
                history.remove_index (history.length - 1);
            }
            history_changed ();

            /* DND: non-critical ones silently go to the history only. */
            if (dnd && !entry.critical) {
                suppressed++;
            }
            if (!dnd || entry.critical) {
                int timeout = (expire_timeout > 0)
                    ? expire_timeout : DEFAULT_TIMEOUT_MS;
                if (entry.critical) {
                    timeout = 0;   /* stays until closed by hand */
                }
                toast_requested (entry, timeout);
                /* Notification sound (6b): NEVER plays in do-not-disturb
                 * (even if a critical toast is shown — the rule is explicit). */
                if (!dnd) {
                    Sounds.play (entry.critical
                        ? "dialog-warning" : "message-new-instant");
                }
            }
            return entry.id;
        }

        public void close_notification (uint32 id) throws Error {
            notification_closed (id, 3 /* closed by CloseNotification */);
        }

        public string[] get_capabilities () throws Error {
            return { "body", "persistence" };
        }

        public void get_server_information (out string name,
                                            out string vendor,
                                            out string version,
                                            out string spec_version)
                                            throws Error {
            /* The product name is not embedded in code; the daemon name is the component name. */
            name = "kavis-panel";
            vendor = "kavis";
            version = "1.0";
            spec_version = "1.2";
        }

        /* --- history management (used by the notification center) --- */

        [DBus (visible = false)]
        public void clear_all () {
            history.remove_range (0, history.length);
            history_changed ();
        }

        [DBus (visible = false)]
        public void clear_app (string app_name) {
            for (int i = (int) history.length - 1; i >= 0; i--) {
                if (history[i].app_name == app_name) {
                    history.remove_index (i);
                }
            }
            history_changed ();
        }

        [DBus (visible = false)]
        public void set_dnd (bool enabled) {
            bool was = dnd;
            dnd = enabled;
            /* DND turned off → one toast summarizing what was missed (madde 55). */
            if (was && !enabled && suppressed > 0) {
                var summary_entry = new NotificationEntry ();
                summary_entry.id = 0;
                summary_entry.app_name = "";
                summary_entry.app_icon = "notification-symbolic";
                summary_entry.summary =
                    _("%d new notifications").printf (suppressed);
                summary_entry.body = "";
                summary_entry.critical = false;
                summary_entry.timestamp = new DateTime.now_local ();
                toast_requested (summary_entry, 5000);
            }
            if (!enabled) {
                suppressed = 0;
            }
        }
    }

    namespace Notifications {

        public NotificationServer? server = null;

        /* Own the bus name and export the server object. Failure is
         * loud (dunst lesson: a lost name loses every notification
         * silently). */
        public void start () {
            server = new NotificationServer ();
            Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications",
                BusNameOwnerFlags.NONE,
                (connection) => {
                    try {
                        connection.register_object (
                            "/org/freedesktop/Notifications", server);
                    } catch (IOError e) {
                        warning ("kavis-panel: could not export the notification object: %s",
                                 e.message);
                    }
                },
                null,
                () => {
                    warning ("kavis-panel: could not acquire org.freedesktop.Notifications — is another notification daemon running? Notifications will NOT be shown.");
                });
        }
    }
}
