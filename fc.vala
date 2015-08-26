
public class Bench {
	public string name;
	public GLib.DateTime first;

	public void stop () {
		var ts = new GLib.DateTime.now_local ().difference (first);
		int64 ms = (ts / 1000);

		message (@"$(this.name) took $ms ms");
	}


	public static Bench start (string name) {
		var b = new Bench ();

		b.name = name;
		b.first = new GLib.DateTime.now_local ();
		return b;
	}
}


class FontData : GLib.Object {
	public Pango.FontDescription desc;
	public int index;
}




class FontModel : GLib.Object, GLib.ListModel {
	private Gee.ArrayList<FontData> fonts = new Gee.ArrayList<FontData> ();
	private Gee.ArrayList<int> filtered_view = new Gee.ArrayList<int> ();
	private string? filter = null;



	public GLib.Type get_item_type ()
	{
		return typeof (Pango.FontDescription);
	}

	public uint get_n_items ()
	{
		if (this.filter != null)
		  return this.filtered_view.size;
		else
		  return this.fonts.size;
	}

	public GLib.Object? get_item (uint index)
	{
		if (this.filter != null) {
			return this.fonts.get (this.filtered_view.get ((int)index));
		} else {
			return this.fonts.get ((int)index);
		}
	}

	/* XXX We don't support changing the model while a filter is set here. */
	public void apply_filter (string? filter)
	{
		this.filter = filter;

		if (filter == null || filter.length == 0) {
			this.filtered_view.clear ();
			this.filter = null;
			this.items_changed (0, this.filtered_view.size, this.fonts.size);
			return;
		}

		int filtered_before = this.filtered_view.size;

		this.filtered_view.clear ();

		for (int i = 0, p = this.fonts.size; i < p; i ++) {
			if (fonts.get (i).desc.get_family ().down ().contains (filter.down())) {
				filtered_view.add (i);
			}
		}

		if (filtered_before > 0) {
			this.items_changed (0, filtered_before, this.filtered_view.size);
		} else {
			this.items_changed (0, this.fonts.size, this.filtered_view.size);
		}

	}

	public void load_fonts ()
	{
		  var b = Bench.start ("Loading fonts");

		var font_map = Pango.CairoFontMap.get_default ();
		Pango.FontFamily[] families;
		font_map.list_families (out families);

		int n = 0;
		foreach (var family in families) {
			Pango.FontFace?[] faces;
			family.list_faces (out faces);
			if (faces != null && faces.length == 0)
			  continue;

			for (int i = 0; i < faces.length; i ++) {
				var data = new FontData ();
				data.desc = faces[i].describe ();
				data.index = n;
				this.fonts.add (data);
				n ++;
			}
		}

		b.stop ();

		message ("Got %d fonts", n);


		if (n > 0)
			assert (this.fonts.get (0).desc != null);

		this.items_changed (0, 0, n);
	}
}


/*
	XXX XXX XXX XXX XXX XXX XXX XXX
	Make sure the pango.vapi is fixed!
	XXX XXX XXX XXX XXX XXX XXX XXX
 */


class Row : Gtk.ListBoxRow {
	public Gtk.Label sample_label;
	public Gtk.Label name_label;
	public Row () {
		var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

		this.sample_label = new Gtk.Label ("");
		this.sample_label.halign = Gtk.Align.START;
		this.sample_label.xalign = 0.0f;
		this.sample_label.ellipsize = Pango.EllipsizeMode.END;
		this.name_label = new Gtk.Label ("");
		this.name_label.halign = Gtk.Align.START;
		this.name_label.get_style_context ().add_class ("dim-label");

		box.add (sample_label);
		box.add (name_label);

		box.margin = 6;
		this.add (box);
	}

	public void assign (FontData data) {
		var attrs = new Pango.AttrList ();
		attrs.insert (new Pango.AttrFontDesc (data.desc));
		attrs.insert (new Pango.AttrSize (14 * Pango.SCALE));
		this.sample_label.set_attributes (attrs);
		this.sample_label.set_label ("The quick brown fox jumps over the lazy dog.");

		this.name_label.set_label ("%d: %s".printf (data.index, data.desc.get_family ()));
	}
}


void main (string[] args)
{
	Gtk.init (ref args);
	var window = new Gtk.Window ();
	var list = new ModelListBox ();
	var model = new FontModel ();
	var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
	var scroller = new Gtk.ScrolledWindow (null, null);
	var filter_entry = new Gtk.Entry ();
	filter_entry.placeholder_text = "Filter";
	list.set_model (model);


	try {
		var provider = new Gtk.CssProvider ();
		provider.load_from_data (".list-row { border-bottom: 1px solid alpha(grey, 0.3);}",-1);
		Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
		                                          provider,
		                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
	} catch (GLib.Error e) {
		error (e.message);
	}





	list.fill_func = (item, old_widget) => {
		Row? row = (Row)old_widget;
		if (row == null)
		  row = new Row ();

		FontData data = (FontData) item;

		row.assign (data);
		row.show_all ();

		return row;
	};

	model.items_changed.connect (() => {
		int n_items = (int) model.get_n_items ();
		window.title = "Font Chooser (%d items)".printf (n_items);
	});

	list.size_allocate.connect (() => {
		window.title = "Font Chooser (%d items, %d -- %d)".printf ((int)model.get_n_items (),
																   list.model_from,
																   list.model_to);
	});

	filter_entry.buffer.notify["text"].connect (() => {
		model.apply_filter (filter_entry.get_text ());
	});


	scroller.add (list);
	scroller.vexpand = true;
	box.add (scroller);

	box.add (filter_entry);

	box.margin = 6;
	window.add (box);
	window.resize (600, 800);
	window.show_all ();

	model.load_fonts ();
	message ("after");

	Gtk.main ();
}
