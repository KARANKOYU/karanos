/* kavis-selftest — scenario files (madde 72, kararlar.md 9b).
 *
 * The format is a deliberately small YAML subset so no YAML library is
 * needed at runtime: top-level "key: value" lines, one "steps:" list
 * whose items start with "- do:" and continue with indented
 * "key: value" lines. Quotes around values are stripped, "#" starts a
 * comment, "allowed: [a, b]" is an inline list. A value of ">" folds
 * the more-indented lines under it into one line, which is how a note
 * long enough to matter can be written without a 200-column file.
 * Anything else is an error — a scenario that does not parse is
 * reported, never skipped, and `kavis-selftest --check` parses them all
 * before a push so a typo never costs a VM round.
 */
namespace Kavis.Selftest {

    public class Step : Object {
        public string action = "none";
        public string expect = "ok";
        public int timeout_ms = 3000;
        public string note = "";
        public bool shot = false;      /* keep the full frame at this step too */
    }

    public class Scenario : Object {
        public string name = "";
        public string title = "";
        public string item = "";
        public string path = "";
        public string[] allowed = {};  /* known window classes */
        private Step[] _steps = {};
        public unowned Step[] get_steps () { return _steps; }
        public string parse_error = "";

        public static Scenario load (string path) {
            var sc = new Scenario ();
            sc.path = path;
            sc.name = Path.get_basename (path).replace (".yaml", "");
            string text;
            try {
                FileUtils.get_contents (path, out text);
            } catch (Error e) {
                sc.parse_error = e.message;
                return sc;
            }
            Step? cur = null;
            bool in_steps = false;
            int lineno = 0;
            /* State for a folded ">" value: which key is collecting,
             * how deeply the line that opened it was indented, and what
             * has been gathered so far. */
            string folding_key = "";
            int folding_indent = 0;
            var folded = new StringBuilder ();
            foreach (string raw in text.split ("\n")) {
                lineno++;
                string line = strip_comment (raw);
                int indent = 0;
                while (indent < line.length && line[indent] == ' ') {
                    indent++;
                }
                if (folding_key != "") {
                    /* A blank line inside a folded block is a paragraph
                     * break in YAML; here the whole thing becomes one
                     * line anyway, so it is simply skipped. */
                    if (line.strip () == "") {
                        continue;
                    }
                    if (indent > folding_indent) {
                        if (folded.len > 0) {
                            folded.append_c (' ');
                        }
                        folded.append (line.strip ());
                        continue;
                    }
                    /* Less indented: the block ended. */
                    apply_step_key (cur, folding_key, folded.str);
                    folding_key = "";
                    folded = new StringBuilder ();
                }
                if (line.strip () == "") {
                    continue;
                }
                string body = line.strip ();
                if (indent == 0) {
                    in_steps = false;
                    cur = null;
                    if (body == "steps:") {
                        in_steps = true;
                        continue;
                    }
                    string k, v;
                    if (!split_kv (body, out k, out v)) {
                        sc.parse_error = "line %d: expected a key: %s".printf (lineno, body);
                        return sc;
                    }
                    switch (k) {
                    case "name":  sc.name = v; break;
                    case "title": sc.title = v; break;
                    case "item":  sc.item = v; break;
                    case "allowed": sc.allowed = parse_list (v); break;
                    default:
                        sc.parse_error = "line %d: unknown key %s".printf (lineno, k);
                        return sc;
                    }
                    continue;
                }
                if (!in_steps) {
                    sc.parse_error = "line %d: indented line outside steps".printf (lineno);
                    return sc;
                }
                if (body.has_prefix ("- ")) {
                    cur = new Step ();
                    sc._steps += cur;
                    body = body.substring (2).strip ();
                }
                if (cur == null) {
                    sc.parse_error = "line %d: a step must start with '- do:'".printf (lineno);
                    return sc;
                }
                string key, val;
                if (!split_kv (body, out key, out val)) {
                    sc.parse_error = "line %d: expected 'key: value'".printf (lineno);
                    return sc;
                }
                if (val == ">" || val == "|") {
                    folding_key = key;
                    folding_indent = indent;
                    continue;
                }
                if (!apply_step_key (cur, key, val)) {
                    sc.parse_error = "line %d: unknown key %s in step".printf (lineno, key);
                    return sc;
                }
            }
            if (folding_key != "" && cur != null) {
                apply_step_key (cur, folding_key, folded.str);
            }
            if (sc._steps.length == 0 && sc.parse_error == "") {
                sc.parse_error = "no steps";
            }
            return sc;
        }

        /* One "key: value" inside a step; false when the key is not one
         * we know. Separate from the loop so a folded block can be
         * applied when it ends, with the same rules. */
        private static bool apply_step_key (Step? step, string key,
                                            string val) {
            if (step == null) {
                return false;
            }
            switch (key) {
            case "do":      step.action = val; return true;
            case "expect":  step.expect = val; return true;
            case "timeout": step.timeout_ms = int.parse (val); return true;
            case "note":    step.note = val; return true;
            case "shot":
                step.shot = (val == "true" || val == "yes");
                return true;
            }
            return false;
        }

        /* "#" outside quotes starts a comment. */
        private static string strip_comment (string line) {
            bool in_q = false;
            var sb = new StringBuilder ();
            for (int i = 0; i < line.length; i++) {
                char c = line[i];
                if (c == '"') {
                    in_q = !in_q;
                }
                if (c == '#' && !in_q) {
                    break;
                }
                sb.append_c (c);
            }
            return sb.str;
        }

        private static bool split_kv (string body, out string key, out string val) {
            key = ""; val = "";
            int i = body.index_of (":");
            if (i <= 0) {
                return false;
            }
            key = body.substring (0, i).strip ();
            val = body.substring (i + 1).strip ();
            if (val.length >= 2 && val[0] == '"' && val[val.length - 1] == '"') {
                val = val.substring (1, val.length - 2);
            }
            return true;
        }

        private static string[] parse_list (string v) {
            string s = v.strip ();
            if (s.has_prefix ("[")) {
                s = s.substring (1);
            }
            if (s.has_suffix ("]")) {
                s = s.substring (0, s.length - 1);
            }
            string[] res = {};
            foreach (string item in s.split (",")) {
                string t = item.strip ();
                if (t != "") {
                    res += t;
                }
            }
            return res;
        }
    }
}
