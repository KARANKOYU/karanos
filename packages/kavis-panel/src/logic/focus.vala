/* Focus mode (business logic) — madde 55.
 *
 * A timed do-not-disturb: notifications are muted for the session
 * length, and a notification announces the end. App blocking is
 * DELIBERATELY not here yet — the block list needs a settings surface
 * (Grup F, Ayarlar); the timer core lands now so the quick tile works.
 */

namespace Kavis.Focus {

    public const int DEFAULT_MINUTES = 30;

    private uint timer = 0;

    public bool active () {
        return timer != 0;
    }

    public void start (int minutes = DEFAULT_MINUTES) {
        cancel ();
        if (Notifications.server == null) {
            return;
        }
        Notifications.server.set_dnd (true);
        timer = Timeout.add_seconds ((uint) minutes * 60, () => {
            timer = 0;
            finish (true);
            return Source.REMOVE;
        });
    }

    public void cancel () {
        if (timer == 0) {
            return;
        }
        Source.remove (timer);
        timer = 0;
        finish (false);
    }

    private void finish (bool announce) {
        unowned NotificationServer? server = Notifications.server;
        if (server == null) {
            return;
        }
        server.set_dnd (false);
        if (announce) {
            try {
                server.notify ("Kavis", 0, "alarm-symbolic",
                               _("Focus session finished"), "",
                               {}, new HashTable<string, Variant> (
                                   str_hash, str_equal), 8000);
            } catch (Error e) {
                warning ("kavis-panel: odaklanma bildirimi verilemedi: %s",
                         e.message);
            }
        }
    }
}
