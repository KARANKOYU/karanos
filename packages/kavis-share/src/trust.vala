/* The devices this machine has agreed to (item 76).
 *
 * A trusted device is one somebody said yes to once. The list is a
 * plain file of fingerprints and the names they had when they were
 * added — the name is only ever a label, and it is stored so Settings
 * can show "phone" rather than sixty-four hex characters; the
 * fingerprint is what is actually compared.
 *
 * WHY THE NAME IS NOT TRUSTED: a device announces whatever alias it
 * likes and can change it between one announcement and the next. If
 * the name were what we matched on, calling yourself the same thing as
 * somebody's laptop would be the whole attack.
 */

namespace Kavis.Share {

    public class Trust : Object {

        public signal void changed ();

        private HashTable<string, string> names =
            new HashTable<string, string> (str_hash, str_equal);

        public Trust () {
            load ();
        }

        private string path () {
            return Path.build_filename (Environment.get_user_data_dir (),
                                        "kavis", "trusted-devices");
        }

        private void load () {
            string contents;
            try {
                FileUtils.get_contents (path (), out contents);
            } catch (Error e) {
                return;
            }
            foreach (unowned string line in contents.split ("\n")) {
                string trimmed = line.strip ();
                if (trimmed == "" || trimmed.has_prefix ("#")) {
                    continue;
                }
                int space = trimmed.index_of (" ");
                if (space > 0) {
                    names.insert (trimmed.substring (0, space),
                                  trimmed.substring (space + 1).strip ());
                } else {
                    names.insert (trimmed, trimmed);
                }
            }
        }

        private void save () {
            var text = new StringBuilder ();
            text.append ("# Devices this machine has been paired with.\n");
            text.append ("# <fingerprint> <name when it was added>\n");
            foreach (unowned string fingerprint in names.get_keys ()) {
                text.append_printf ("%s %s\n", fingerprint,
                                    names.lookup (fingerprint));
            }
            DirUtils.create_with_parents (Path.get_dirname (path ()), 0700);
            try {
                FileUtils.set_contents (path (), text.str);
                FileUtils.chmod (path (), 0600);
            } catch (Error e) {
                warning ("kavis-share: could not write the trusted list: %s",
                         e.message);
            }
            changed ();
        }

        public bool is_trusted (string fingerprint) {
            return names.lookup (fingerprint) != null;
        }

        public void add (string fingerprint, string name) {
            names.insert (fingerprint, name);
            save ();
        }

        public void remove (string fingerprint) {
            if (names.remove (fingerprint)) {
                save ();
            }
        }

        public string[] fingerprints () {
            string[] all = {};
            foreach (unowned string fingerprint in names.get_keys ()) {
                all += fingerprint;
            }
            return all;
        }

        public string name_of (string fingerprint) {
            return names.lookup (fingerprint) ?? fingerprint;
        }
    }
}
