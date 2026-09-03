/* kavis-selftest — process / memory / journal / coredump probes. */
namespace Kavis.Selftest {

    namespace SysMon {

        public int uss_mb (int pid) {
            string s;
            try {
                FileUtils.get_contents ("/proc/%d/smaps_rollup".printf (pid), out s);
            } catch (Error e) {
                return -1;
            }
            long kb = 0;
            foreach (string line in s.split ("\n")) {
                if (line.has_prefix ("Private_Clean:") || line.has_prefix ("Private_Dirty:")) {
                    kb += long.parse (line.replace ("Private_Clean:", "").replace ("Private_Dirty:", "").strip ().split (" ")[0]);
                }
            }
            return (int) (kb / 1024);
        }

        /* MemTotal - MemAvailable in MB (the CI's MEM-USED). */
        public int mem_used_mb () {
            string s;
            try {
                FileUtils.get_contents ("/proc/meminfo", out s);
            } catch (Error e) {
                return -1;
            }
            long total = 0, avail = 0;
            foreach (string line in s.split ("\n")) {
                if (line.has_prefix ("MemTotal:")) {
                    total = long.parse (line.substring (9).strip ().split (" ")[0]);
                } else if (line.has_prefix ("MemAvailable:")) {
                    avail = long.parse (line.substring (13).strip ().split (" ")[0]);
                }
            }
            return (int) ((total - avail) / 1024);
        }

        /* pid list by comm (exact) — pgrep -x without spawning. */
        public int[] pids_of (string comm) {
            int[] res = {};
            try {
                var dir = Dir.open ("/proc");
                string? name;
                while ((name = dir.read_name ()) != null) {
                    if (name[0] < '0' || name[0] > '9') {
                        continue;
                    }
                    string c;
                    try {
                        FileUtils.get_contents ("/proc/" + name + "/comm", out c);
                    } catch (Error e) {
                        continue;
                    }
                    if (c.strip () == comm) {
                        res += int.parse (name);
                    }
                }
            } catch (Error e) { }
            return res;
        }

        public bool running (string comm) {
            return pids_of (comm).length > 0;
        }

        /* processes-NNN.txt: every kavis-* plus the session pillars. */
        public string process_table () {
            var sb = new StringBuilder ();
            string[] watch = { "kavis-panel", "kavis-snap", "kavis-osd", "kavis-tools",
                               "kavis-settings", "openbox", "picom", "nemo-desktop",
                               "lxpolkit", "xcape" };
            foreach (string comm in watch) {
                foreach (int pid in pids_of (comm)) {
                    string st = "";
                    try {
                        FileUtils.get_contents ("/proc/%d/status".printf (pid), out st);
                    } catch (Error e) { }
                    int rss = 0;
                    foreach (string line in st.split ("\n")) {
                        if (line.has_prefix ("VmRSS:")) {
                            rss = int.parse (line.substring (6).strip ().split (" ")[0]) / 1024;
                        }
                    }
                    sb.append_printf ("%-16s pid %-6d rss %4d MB  uss %4d MB\n", comm, pid, rss, uss_mb (pid));
                }
            }
            return sb.str;
        }

        public int coredump_count () {
            int n = 0;
            try {
                var dir = Dir.open ("/var/lib/systemd/coredump");
                while (dir.read_name () != null) {
                    n++;
                }
            } catch (Error e) { }
            return n;
        }

        /* Journal lines since an epoch timestamp; empty when journald
         * refuses (the live user is not always in adm). */
        public string journal_since (int64 epoch) {
            string res = "";
            try {
                string se, so;
                int rc;
                Process.spawn_sync (null,
                    { "journalctl", "-b", "-q", "-o", "short", "--no-pager",
                      "--since=@%lld".printf (epoch) },
                    null, SpawnFlags.SEARCH_PATH, null, out so, out se, out rc);
                if (rc == 0) {
                    res = so;
                }
            } catch (Error e) { }
            return res;
        }

        public string run_shell (string cmd, out int rc) {
            rc = -1;
            try {
                string so, se;
                Process.spawn_sync (null, { "sh", "-c", cmd }, null,
                    SpawnFlags.SEARCH_PATH, null, out so, out se, out rc);
                if (Process.if_exited (rc)) {
                    rc = Process.exit_status (rc);
                }
                return so + se;
            } catch (Error e) {
                return e.message;
            }
        }
    }
}
