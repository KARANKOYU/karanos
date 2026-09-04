/* Low battery warning (item 51).
 *
 * A laptop that dies without saying anything is the worst failure a
 * desktop can have, and up to now nothing watched the charge. The
 * threshold is in kavis.conf [power] low_battery (percent, 0 = off),
 * set in Settings > Power.
 *
 * Warned once per discharge, not once per tick: the flag clears when
 * the charger goes back in or the charge rises above the threshold
 * again. A notification every minute at 14% would train people to
 * ignore the one at 5%.
 */

namespace Kavis {

    namespace BatteryWarning {

        private uint timer = 0;
        private bool warned = false;
        private bool warned_critical = false;

        /* Below this we say it plainly regardless of the setting: at 5%
         * the machine is minutes from stopping. */
        private const int CRITICAL = 5;

        private int threshold () {
            try {
                return Config.load ().get_integer ("power", "low_battery");
            } catch (Error e) {
                return 15;
            }
        }

        private void check () {
            if (!Battery.present ()) {
                return;
            }
            int percent = Battery.percent ();
            if (percent < 0) {
                return;
            }
            if (Battery.charging () || Battery.on_ac ()) {
                warned = false;
                warned_critical = false;
                return;
            }
            int limit = threshold ();
            if (percent > limit && percent > CRITICAL) {
                warned = false;
                warned_critical = false;
                return;
            }
            bool critical = percent <= CRITICAL;
            if (critical ? warned_critical : warned) {
                return;
            }
            if (critical) {
                warned_critical = true;
            }
            warned = true;
            if (limit <= 0 && !critical) {
                return;   /* warnings switched off, and not critical yet */
            }
            show (percent, critical);
        }

        private void show (int percent, bool critical) {
            unowned NotificationServer? server = Notifications.server;
            if (server == null) {
                return;
            }
            var hints = new HashTable<string, Variant> (str_hash, str_equal);
            if (critical) {
                hints.insert ("urgency", new Variant.byte (2));
            }
            int minutes = Battery.minutes_remaining ();
            string body = (minutes > 0)
                ? ngettext ("About %d minute left.",
                            "About %d minutes left.", minutes).printf (minutes)
                : _("Plug in the charger.");
            try {
                /* replaces_id 0 with a fixed app name: the notification
                 * centre groups them, and there is at most one live at
                 * a time anyway. */
                server.notify ("kavis-power", 0,
                    critical ? "battery-caution-symbolic"
                             : "battery-low-symbolic",
                    critical
                        ? _("Battery critically low (%d%%)").printf (percent)
                        : _("Battery low (%d%%)").printf (percent),
                    body, {}, hints, critical ? 0 : 12000);
            } catch (Error e) {
                warning ("kavis-panel: battery warning failed: %s",
                         e.message);
            }
        }

        /* One check a minute: the charge cannot fall through a
         * threshold and reach zero inside that. */
        public void start () {
            if (timer != 0 || !Battery.present ()) {
                return;
            }
            check ();
            timer = Timeout.add_seconds (60, () => {
                check ();
                return Source.CONTINUE;
            });
        }
    }
}
