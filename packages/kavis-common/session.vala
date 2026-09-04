/* What kind of session this is (item 70).
 *
 * THIS IS THE CANONICAL COPY — build-packages.sh copies it into the
 * packages that need it; the copies are gitignored.
 *
 * One question so far, asked from two places: does this session have a
 * password at all? The lock screen needs it to decide whether to ask
 * for one, and the idle watcher needs it to decide whether locking is
 * worth doing.
 */

namespace Kavis {

    namespace Session {

        /* Membership of `nopasswdlogin` — Debian's own convention for
         * "the system does not ask this user for a password", honoured
         * by lightdm, and what the live image's bootappend puts its
         * user in.
         *
         * NOT /etc/shadow: a normal user cannot read it, so that
         * question always answered "there is a password", which on the
         * live image would have meant a lock screen nothing could
         * satisfy. */
        public bool passwordless () {
            /* The path is overridable so the passwordless path can be
             * exercised at all outside a live image; unset on a real
             * system, like the other test hooks in this tree. */
            string path = Environment.get_variable ("KAVIS_GROUP_FILE")
                ?? "/etc/group";
            string contents;
            try {
                FileUtils.get_contents (path, out contents);
            } catch (Error e) {
                return false;
            }
            string user = Environment.get_user_name ();
            foreach (unowned string line in contents.split ("\n")) {
                if (!line.has_prefix ("nopasswdlogin:")) {
                    continue;
                }
                string[] fields = line.split (":");
                if (fields.length < 4) {
                    return false;
                }
                foreach (unowned string member in fields[3].split (",")) {
                    if (member.strip () == user) {
                        return true;
                    }
                }
            }
            return false;
        }
    }
}
