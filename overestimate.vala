// vim: set noexpandtab tabstop=4 shiftwidth=4 softtabstop=4:

/*
 *
 * Test case for an overestimate of the list size at the bottom.
 *
 */


class Data : GLib.Object {
	public string str;
	public uint   index;
}

class Row : Gtk.ListBoxRow {
	private Gtk.Label label;

	public Row () {
		this.label = new Gtk.Label ("");
		this.label.margin = 6;
		this.add (label);
	}

	public void assign (Data d) {
		this.label.label = d.str;
	}
}

void main (string[] args)
{
	Gtk.init (ref args);
	var window = new Gtk.Window ();
	var scroller = new Gtk.ScrolledWindow (null, null);
	var list = new ModelListBox ();
	var model = new GLib.ListStore (typeof (Data));



	try {
		var provider = new Gtk.CssProvider ();
		provider.load_from_data (".list-row { border-bottom: 1px solid alpha(grey, 0.3);}",-1);
		Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
		                                          provider,
		                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
	} catch (GLib.Error e) {
		error (e.message);
	}




	for (uint i = 0; i < 400; i ++) {
		var d = new Data ();
		d.str = "Foobar %u".printf (i);
		d.index = i;
		model.append (d);
	}



	list.fill_func = (item, old) => {
		Row row;
		Data data = (Data) item;
		if (old != null) row = old as Row;
		else row = new Row ();

		assert (item != null);
		row.assign (data);

		if (data.index < 3)
		//if (data.index > 0)
		  row.set_size_request (-1, 100);
		else
		  row.set_size_request (-1, -1);



		row.show_all ();

		return row;
	};

	list.set_model (model);



	var bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
	bbox.hexpand = true;
	bbox.get_style_context ().add_class ("linked");

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


	var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
	bbox.margin_bottom = 6;
	bbox.halign = Gtk.Align.CENTER;
	scroller.vexpand = true;
	scroller.add (list);
	box.add (scroller);
	box.add (bbox);


	window.add (box);
	window.resize (400, 300);
	window.delete_event.connect (() => { Gtk.main_quit (); return true;});
	window.show_all ();
	Gtk.main ();
}
