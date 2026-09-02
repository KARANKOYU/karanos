/* Power actions (business logic — no widget code here).
 * KANONİK KOPYA BURASI (kavis-common) — appinit düzeni: derlemede
 * kavis-panel ve kavis-tools src ağaçlarına kopyalanır (6d: Ctrl+
 * Alt+Del ekranı da aynı eylemleri kullanır).
 *
 * Via systemd/logind. No sudo: logind already grants the local seated
 * user poweroff/reboot/suspend through polkit, so no password prompt
 * and no root privileges in the panel.
 */

namespace Kavis.Power {

    /* Spawn a command in the background. A missing binary or a spawn
     * failure is logged (never swallowed) but does not crash the panel:
     * a power button that does nothing but explains itself in the log
     * beats a dead taskbar. */
    private void run (string[] argv) {
        if (Environment.find_program_in_path (argv[0]) == null) {
            warning ("kavis: %s yok, eylem atlandi", argv[0]);
            return;
        }
        try {
            Process.spawn_async (null, argv, null,
                                 SpawnFlags.SEARCH_PATH, null, null);
        } catch (SpawnError e) {
            warning ("kavis: %s basarisiz: %s", argv[0], e.message);
        }
    }

    public void shutdown () {
        run ({ "systemctl", "poweroff" });
    }

    public void reboot () {
        run ({ "systemctl", "reboot" });
    }

    public void suspend () {
        run ({ "systemctl", "suspend" });
    }

    /* Openbox ends its own session; going through logind is neither
     * needed nor the clean way to unwind the session. */
    public void log_out () {
        if (Environment.find_program_in_path ("openbox") != null) {
            run ({ "openbox", "--exit" });
        } else {
            run ({ "loginctl", "terminate-session", "self" });
        }
    }

    /* Own lock screen arrives with kavis-greeter (item 18); until then
     * logind's lock signal is the placeholder. */
    public void lock () {
        run ({ "loginctl", "lock-session" });
    }
}
