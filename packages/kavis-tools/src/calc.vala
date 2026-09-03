/* Calculator (madde 7): entry + button grid, own expression
 * evaluator (shunting-yard) — no external math library for four
 * operations and parentheses. Keyboard works through the entry.
 */

namespace Kavis.Tools {

    public class CalculatorWindow : Gtk.Window {

        private Gtk.Entry entry;
        private Gtk.Label result_label;

        public CalculatorWindow () {
            set_title (_("Calculator"));
            set_default_size (280, 360);
            set_resizable (false);

            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            root.set_border_width (12);
            add (root);

            entry = new Gtk.Entry ();
            entry.set_alignment (1.0f);
            entry.activate.connect (evaluate);
            root.pack_start (entry, false, false, 0);

            result_label = new Gtk.Label ("");
            result_label.set_xalign (1.0f);
            root.pack_start (result_label, false, false, 0);

            string[] rows = {
                "C ( ) ÷",
                "7 8 9 ×",
                "4 5 6 −",
                "1 2 3 +",
                "0 . % ="
            };
            foreach (unowned string row_spec in rows) {
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                row.set_homogeneous (true);
                foreach (unowned string key in row_spec.split (" ")) {
                    row.pack_start (make_button (key), true, true, 0);
                }
                root.pack_start (row, true, true, 0);
            }
        }

        private Gtk.Button make_button (string key) {
            var button = new Gtk.Button.with_label (key);
            button.clicked.connect (() => {
                switch (key) {
                case "C":
                    entry.set_text ("");
                    result_label.set_text ("");
                    break;
                case "=":
                    evaluate ();
                    break;
                default:
                    entry.set_text (entry.get_text () + key);
                    break;
                }
            });
            return button;
        }

        private void evaluate () {
            double value;
            if (Expression.eval (entry.get_text (), out value)) {
                /* Do not show .0 for whole numbers. */
                if (value == Math.floor (value)
                    && value.abs () < 1e15) {
                    result_label.set_markup ("<big><b>%lld</b></big>"
                        .printf ((int64) value));
                } else {
                    result_label.set_markup ("<big><b>%g</b></big>"
                        .printf (value));
                }
            } else {
                result_label.set_text (_("Invalid expression"));
            }
        }
    }

    /* Shunting-yard over doubles: + − × ÷ %, parentheses, unary minus. */
    namespace Expression {

        private double apply (double a, double b, char op) {
            switch (op) {
            case '+': return a + b;
            case '-': return a - b;
            case '*': return a * b;
            case '/': return a / b;
            case '%': return Math.fmod (a, b);
            default:  return 0;
            }
        }

        private int precedence (char op) {
            return (op == '+' || op == '-') ? 1 : 2;
        }

        public bool eval (string raw, out double result) {
            result = 0;
            /* Display operators to ASCII. */
            string text = raw.replace ("×", "*").replace ("÷", "/")
                .replace ("−", "-").replace (",", ".").strip ();
            if (text == "") {
                return false;
            }

            double[] values = {};
            char[] ops = {};
            bool expect_operand = true;
            int i = 0;
            unowned string s = text;
            int length = s.length;

            while (i < length) {
                char c = s[i];
                if (c == ' ') {
                    i++;
                    continue;
                }
                if (expect_operand && (c.isdigit () || c == '.'
                                       || c == '-')) {
                    int start = i;
                    if (c == '-') {
                        i++;
                    }
                    bool any_digit = false;
                    while (i < length && (s[i].isdigit () || s[i] == '.')) {
                        any_digit = true;
                        i++;
                    }
                    if (!any_digit) {
                        return false;
                    }
                    values += double.parse (s.substring (start, i - start));
                    expect_operand = false;
                    continue;
                }
                if (c == '(') {
                    ops += c;
                    expect_operand = true;
                    i++;
                    continue;
                }
                if (c == ')') {
                    bool matched = false;
                    while (ops.length > 0) {
                        char op = ops[ops.length - 1];
                        ops.resize (ops.length - 1);
                        if (op == '(') {
                            matched = true;
                            break;
                        }
                        if (!reduce (ref values, op)) {
                            return false;
                        }
                    }
                    if (!matched) {
                        return false;
                    }
                    i++;
                    continue;
                }
                if (c == '+' || c == '-' || c == '*' || c == '/'
                    || c == '%') {
                    if (expect_operand) {
                        return false;
                    }
                    while (ops.length > 0
                           && ops[ops.length - 1] != '('
                           && precedence (ops[ops.length - 1])
                              >= precedence (c)) {
                        char op = ops[ops.length - 1];
                        ops.resize (ops.length - 1);
                        if (!reduce (ref values, op)) {
                            return false;
                        }
                    }
                    ops += c;
                    expect_operand = true;
                    i++;
                    continue;
                }
                return false;   /* unrecognized character */
            }
            if (expect_operand) {
                return false;
            }
            while (ops.length > 0) {
                char op = ops[ops.length - 1];
                ops.resize (ops.length - 1);
                if (op == '(' || !reduce (ref values, op)) {
                    return false;
                }
            }
            if (values.length != 1) {
                return false;
            }
            result = values[0];
            return result.is_finite ();
        }

        private bool reduce (ref double[] values, char op) {
            if (values.length < 2) {
                return false;
            }
            double b = values[values.length - 1];
            double a = values[values.length - 2];
            /* `+=` is forbidden on ref/out array parameters (Vala 0.56);
             * we modify the last element in place. */
            values.resize (values.length - 1);
            values[values.length - 1] = apply (a, b, op);
            return true;
        }
    }
}
