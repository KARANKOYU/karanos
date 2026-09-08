/* Asking the person (item 76).
 *
 * One dialog, and it says the two things somebody needs to decide with:
 * WHO is sending and WHAT. A prompt that says "Accept incoming file?"
 * has told them nothing they did not already know from the fact that a
 * prompt appeared.
 *
 * "Always allow this device" is on the dialog rather than buried in
 * Settings, because the moment a person has just decided they trust a
 * device is the only moment they are thinking about whether they do.
 */

namespace Kavis.Share.Prompt {

    private static Trust? trust_list = null;

    /* Set at startup. Without a display there is nobody to ask, and a
     * transfer nobody agreed to is exactly what the prompt exists to
     * prevent — so the answer is no, not yes. */
    public static bool display_available = false;

    public void use (Trust trust) {
        trust_list = trust;
    }

    public bool accept (Device sender, string what) {
        if (!display_available) {
            warning ("kavis-share: %s asked to send with no display to ask"
                     + " on — declined", sender.display ());
            return false;
        }
        var dialog = new Gtk.Dialog ();
        dialog.set_title (_("Incoming file"));
        dialog.set_modal (false);
        dialog.set_keep_above (true);
        dialog.add_button (_("Decline"), Gtk.ResponseType.CANCEL);
        var ok = dialog.add_button (_("Accept"), Gtk.ResponseType.ACCEPT);
        ok.get_style_context ().add_class ("suggested-action");

        var box = dialog.get_content_area ();
        box.set_border_width (16);
        box.set_spacing (8);
        var heading = new Gtk.Label (null);
        heading.set_markup ("<b>%s</b>".printf (
            Markup.escape_text (
                _("%s wants to send you something").printf (
                    sender.display ()))));
        heading.set_xalign (0);
        box.pack_start (heading, false, false, 0);
        if (what != "") {
            var detail = new Gtk.Label (what);
            detail.set_xalign (0);
            detail.set_line_wrap (true);
            box.pack_start (detail, false, false, 0);
        }
        var always = new Gtk.CheckButton.with_label (
            _("Always allow this device"));
        box.pack_start (always, false, false, 0);
        box.show_all ();

        int answer = dialog.run ();
        bool accepted = (answer == Gtk.ResponseType.ACCEPT);
        if (accepted && always.active && trust_list != null) {
            trust_list.add (sender.fingerprint, sender.alias);
        }
        dialog.destroy ();
        return accepted;
    }
}
