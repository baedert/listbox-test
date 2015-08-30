


class RowData : GLib.Object {
	string name;
	bool revealed; /* XXX UI State in the data... */
}


class RevealerModel : GLib.Object, GLib.ListModel
{
	private Gee.ArrayList<RowData> rows = new Gee.ArrayList<RowData> ();

	public uint get_n_items ()
	{
		return this.rows.size;
	}

	public GLib.Object? get_item (uint index)
	{
		return this.rows.get ((int)index);
	}

	public GLib.Type get_item_type ()
	{
		return typeof (RowData);
	}

	public void add (RowData row)
	{
		this.rows.add (row);
	}

}



class Row : Gtk.ListBoxRow {
	public Row () {
		var box  = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
		var box2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		var revealer = new Gtk.Revealer ();
		var btn = new Gtk.Button.with_label ("Show");


		var img = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU);
		revealer.add (img);

		var l = new Gtk.Label ("SOME TEXT OMG");
		l.hexpand = true;

		box.add (l);



		/* XXX

			- Revealing lots of children does not add rows at the end.



		   */


		revealer.reveal_child = true;

		btn.clicked.connect (() => {
			revealer.reveal_child = !revealer.reveal_child;
		});

		box.add (btn);

		box2.add (box);
		box2.add (revealer);


		box2.margin = 6;
		this.add (box2);
	}
}


void main (string[] args)
{
	Gtk.init (ref args);
	var window = new Gtk.Window ();
	var list = new ModelListBox ();
	var model = new RevealerModel ();
	var scroller = new Gtk.ScrolledWindow (null, null);


	list.set_model (model);
	list.fill_func = (item, old_widget) => {
		Row row;
		if (old_widget != null)
		  row = (Row) old_widget;
		else
		  row = new Row ();

		row.show_all ();

		return row;
	};

	for (int i = 0; i < 5000; i ++) {
		model.add (new RowData  ());
	}


	scroller.add (list);
	window.add (scroller);
	window.resize (500, 400);
	window.show_all ();
	Gtk.main ();
}
