// vim: set noexpandtab tabstop=4 shiftwidth=4 softtabstop=4:



class Data : GLib.Object
{
	public int index;

	public Data (int i) { index = i; }
}

class Row : Gtk.ListBoxRow
{
	private Gtk.Label label;
	public Row ()
	{
		var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);

		label = new Gtk.Label ("Foobar \\o/");
		label.ellipsize = Pango.EllipsizeMode.END;
		label.hexpand = true;
		label.halign = Gtk.Align.START;
		box.add (label);

		var button = new Gtk.Button.with_label ("Click Me");
		box.add (button);

		box.margin = 6;
		this.add (box);
	}

	public void assign (Data d)
	{
		this.label.label = "\\o/ %d".printf (d.index);
	}
}

class Model : GLib.ListModel, GLib.Object
{
	private Data[] data;

	public Model (int count)
	{
		this.data = new Data[count];
	}

	public GLib.Type get_item_type ()
	{
		return typeof (Data);
	}

	public uint get_n_items ()
	{
		return data.length;
	}

	public GLib.Object? get_item (uint index)
	{
		return this.data[index];
	}

	public new void set (int index, Data data)
	{
		this.data[index] = data;
	}
}

void main (string[] args)
{
	int N = 30;
	Gtk.init (ref args);
	var window = new Gtk.Window ();
	var list = new ModelListBox ();
	var model = new Model (N);
	var scroller = new Gtk.ScrolledWindow (null, null);


	try {
		var provider = new Gtk.CssProvider ();
		provider.load_from_data (".list-row { border-bottom: 1px solid alpha(grey, 0.3);}",-1);
		Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
		                                          provider,
		                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
	} catch (GLib.Error e) {
		error (e.message);
	}

	for (int i = 0; i < N; i ++) {
		// dummy
		model.set (i, new Data (i));
	}



	list.set_model (model);
	list.fill_func = (item, old_widget) => {
		Row? row = null;
		if (old_widget != null) row = old_widget as Row;
		else                    row = new Row ();

		row.assign ((Data)item);
		row.show_all ();
		return row;
	};

	scroller.add (list);
	scroller.margin_bottom = 40;
	window.add (scroller);

	window.resize (400, 400);
	window.show_all ();
	Gtk.main ();
}
