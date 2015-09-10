// vim: set noexpandtab tabstop=4 shiftwidth=4 softtabstop=4:

class Message : GLib.Object
{
	public int64 id;
	public string text;
	public string screen_name;
	public string name;
}

class MessageModel : GLib.ListModel, GLib.Object
{
	private const uint N = 388;
	private uint n;
	private Message[] messages;

	public MessageModel (uint n)
	{
		this.n = n;
	}

	public void load_messages () throws GLib.Error
	{
		this.messages = new Message[this.n];
		GLib.Bytes msgs_data = GLib.resources_lookup_data ("/org/baedert/listbox/messages.txt",
		                                                   GLib.ResourceLookupFlags.NONE);
		string msgs_str = (string)msgs_data.get_data ();
		string[] lines = msgs_str.split ("\n");
		for (int i = 0; i < lines.length - 1; i ++) {
			string[] parts = lines[i].split ("|");

			var msg = new Message ();
			msg.id = int64.parse (parts[0]);
			msg.name = parts[1];
			msg.screen_name = parts[2];
			msg.text = parts[3];

			this.messages[i] = msg;
		}

		this.items_changed (0, this.n, 0);
	}

	public GLib.Type get_item_type ()
	{
		return typeof (Message);
	}

	public uint get_n_items ()
	{
		return this.n;
	}

	public GLib.Object? get_item (uint index)
	{
		return this.messages[index % N];
	}
}

[GtkTemplate (ui = "/org/baedert/listbox/gtk-demo.ui")]
class GtkMessageRow : Gtk.ListBoxRow
{
	[GtkChild]
	Gtk.Image avatar_image;
	[GtkChild]
	Gtk.Label source_nick;
	[GtkChild]
	Gtk.Label source_name;
	[GtkChild]
	Gtk.Label content_label;

  private const int64 TRANSITION_DURATION = 300;

	public void assign (Message msg)
	{
		source_nick.label = "@" + msg.screen_name;
		source_name.label = msg.name;
		content_label.label = msg.text;

		if (msg.screen_name == "GTKtoolkit")
			avatar_image.set_from_icon_name ("gtk3-demo", Gtk.IconSize.DND);
		else
			avatar_image.set_from_icon_name ("corebird", Gtk.IconSize.DND);
	}

	[GtkCallback]
	private void favorite_clicked ()
	{

	}

	[GtkCallback]
	private void reshare_clicked ()
	{

	}

	[GtkCallback]
	private void expand_clicked ()
	{

	}



  private int64 start_time;
  private int64 end_time;

  private double ease_out_cubic (double t) {
    double p = t - 1;
    return p * p * p +1;
  }

  private bool anim_tick (Gtk.Widget widget, Gdk.FrameClock frame_clock) {
    int64 now = frame_clock.get_frame_time ();

    if (now > end_time) {
      this.opacity = 1.0;
      return false;
    }

    double t = (now - start_time) / (double)(end_time - start_time);

    t = ease_out_cubic (t);

    this.opacity = t;

    return true;
  }

  public void fade_in () {
    if (this.get_realized ()) {
      this.show ();
      return;
    }

    ulong realize_id = 0;
    realize_id = this.realize.connect (() => {
      this.start_time = this.get_frame_clock ().get_frame_time ();
      this.end_time = start_time + (TRANSITION_DURATION * 1000);
      this.add_tick_callback (anim_tick);
      this.disconnect (realize_id);
    });

    this.show ();
  }

}


void main (string[] args)
{
	Gtk.init (ref args);
	var window = new Gtk.Window ();
	var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
	var scroller = new Gtk.ScrolledWindow (null, null);
	var list = new ModelListBox ();
	//var model = new MessageModel (10000000);
	var model = new MessageModel (400);
	model.items_changed.connect (() => {
		window.set_title ("%'u items".printf (model.get_n_items ()));
    });
	model.load_messages ();

	list.fill_func = (item, old_row) => {
		GtkMessageRow row;
		if (old_row == null)
			row = new GtkMessageRow ();
		else
			row = (GtkMessageRow) old_row;

		Message msg = (Message) item;

		row.assign (msg);

		row.fade_in ();
		return row;
	};

	list.set_model (model);
	list.vexpand = true;
	scroller.add (list);

	box.add (scroller);


	var bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
	bbox.hexpand = true;
	bbox.get_style_context ().add_class ("linked");

	var top_btn = new Gtk.Button.with_label ("Top");
	top_btn.clicked.connect (() => {
		scroller.get_vadjustment ().value = 0.0;
	});
	bbox.add (top_btn);

	var up_btn = new Gtk.Button.with_label ("up");
	up_btn.clicked.connect (() => {
		scroller.get_vadjustment ().value -= 1.0;
	});
	bbox.add (up_btn);

	var down_btn = new Gtk.Button.with_label ("down");
	down_btn.clicked.connect (() => {
		scroller.get_vadjustment ().value += 1.0;
	});
	bbox.add (down_btn);

	var bottom_btn = new Gtk.Button.with_label ("Bottom");
	bottom_btn.clicked.connect (() => {
		var vadj = scroller.get_vadjustment ();
		vadj.value = vadj.upper - vadj.page_size;
	});
	bbox.add (bottom_btn);

	var animate_scroll = new Gtk.Button.with_label ("Animate Scroll");
	int i = 0;
	animate_scroll.clicked.connect (() => {
		var adjustment = scroller.get_vadjustment ();
		GLib.Timeout.add (1000, () => {
			adjustment.value += adjustment.page_size;
			//adjustment.value += 15.0;

			i ++;
			message ("Iteration: %d", i);

			if (adjustment.value >= adjustment.upper - adjustment.page_size)
				return GLib.Source.REMOVE;

			return GLib.Source.CONTINUE;
		});
	});
	bbox.add (animate_scroll);


	box.add (bbox);

	window.add (box);


	window.resize (400, 600);
	window.show_all ();
	Gtk.main ();
}
