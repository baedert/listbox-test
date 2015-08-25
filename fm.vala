Gtk.Entry dir_entry;
Gtk.Button show_button;
Gtk.Entry filter_entry;
ModelListBox list_box;


class FileData : GLib.Object
{
	public string filename;
	public string full_path;
	public bool   is_dir;

	public GLib.ThemedIcon icon;
}


// Model {{{

class FileModel : GLib.Object, GLib.ListModel
{
	private Gee.ArrayList<FileData> files = new Gee.ArrayList<FileData> ();
	private Gee.ArrayList<int>      filtered_view = new Gee.ArrayList<int> ();
	private bool dirs_before_files = true;
	private string? filter_text;

	public uint get_n_items ()
	{
		if (this.filter_text != null) {
			return this.filtered_view.size;
		}
		return this.files.size;
	}

	public GLib.Object? get_item (uint index)
	{
		if (this.filter_text != null) {
			return this.files.get (filtered_view.get ((int)index));
		}
		return this.files.get ((int)index);
	}

	public GLib.Type get_item_type ()
	{
		return typeof (FileData);
	}

	private void clear ()
	{
	    int size_before = this.files.size;
		if (size_before > 0) {
		  this.files.clear ();
		  this.items_changed (0, size_before, 0);
		}
	}


	private void append (FileData fd)
	{
		this.files.add (fd);
		this.items_changed (files.size - 1, 0, 1);
	}

	public void apply_filter (string filter)
	{
		if (filter == null || filter.length == 0) {
			this.filter_text = null;
			this.items_changed (0, this.filtered_view.size, this.files.size);
			return;
		}


		this.filter_text = filter;
		this.filtered_view.clear ();
		// Filter all current entries
		for (int i = 0, p = files.size; i < p; i ++) {
			if (files.get (i).filename.down ().contains (filter)) {
				filtered_view.add (i);
			}
		}
		this.items_changed (0, this.files.size, this.filtered_view.size);
	}



	private bool loading = false;

	public async void scan_dir (string path) throws GLib.Error
	{
		message ("scanning %s", path);
		//if (loading)
		  //return;


		loading = true;

		//this.clear ();
		var dir = GLib.File.new_for_path (path);
		var e = yield dir.enumerate_children_async (GLib.FileAttribute.STANDARD_NAME + "," +
		                                            GLib.FileAttribute.STANDARD_ICON + "," +
		                                            GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
		                                            GLib.FileAttribute.STANDARD_TYPE,
		                                            0,
		                                            GLib.Priority.DEFAULT);

		while (true) {
			var files = yield e.next_files_async (20, Priority.DEFAULT);
			if (files == null) {
				loading = false;
				break;
			}

			// XXX We emit items-changed once for every item, but we could also just do
			//     it once for all the files.
			foreach (var info in files) {
				var fd = new FileData ();
				fd.is_dir = false;
				fd.filename = info.get_name ();
				fd.full_path = e.get_child (info).get_path ();
				fd.icon = (GLib.ThemedIcon) info.get_icon ();
				if (info.get_file_type () == GLib.FileType.DIRECTORY) {
					//yield scan_dir (e.get_child (info).get_path ());
				}
				message ("Appending...");
				this.append (fd);
			}

			//break;

		}
	}
}

// }}}

class FileRow : Gtk.ListBoxRow {
	private Gtk.Label name_label;
	private Gtk.Label detail_label;
	private Gtk.Image icon_image;

	private uint load_id = -1;

	public FileRow () {
		var grid = new Gtk.Grid ();
		grid.column_spacing = 12;
		grid.margin = 6;

		icon_image = new Gtk.Image ();
		icon_image.set_size_request (48, 48);
		grid.attach (icon_image, 0, 0, 1, 2);

		name_label = new Gtk.Label ("");
		name_label.halign  = Gtk.Align.START;
		name_label.use_markup = true;
		grid.attach (name_label, 1, 0, 1, 1);

		detail_label = new Gtk.Label ("");
		detail_label.halign = Gtk.Align.START;
		detail_label.get_style_context ().add_class ("dim-label");
		grid.attach (detail_label, 1, 1, 1, 1);



		this.add (grid);
	}


	public void assign (FileData fd, string term) {
		//assert (fd.filename.contains (term));

		if (this.load_id != -1)
			GLib.Source.remove (load_id);

		string new_text = fd.filename.replace (term, "<u>" + term + "</u>");
		this.name_label.label = new_text;
		this.detail_label.label = fd.full_path;

		this.icon_image.pixbuf = null;

		//this.load_id = GLib.Timeout.add (100, () => {
			var icon_theme = Gtk.IconTheme.get_default ();

			try {
				string n = fd.icon.names.length > 1 ? fd.icon.names[1] : fd.icon.names[0];
				this.icon_image.pixbuf = icon_theme.load_icon (n, 48,
																											 Gtk.IconLookupFlags.FORCE_SIZE);
			} catch (GLib.Error e) {}

			//this.load_id = -1;
			//return GLib.Source.REMOVE;
		//});
	}
}

FileModel list_model;

void main (string[] args)
{
	Gtk.init (ref args);
	var window = new Gtk.Window ();
	var grid = new Gtk.Grid ();
	grid.margin = 12;
	grid.column_spacing = 12;
	grid.row_spacing = 6;
	grid.expand = true;


	dir_entry = new Gtk.Entry ();
	dir_entry.hexpand = true;
	dir_entry.placeholder_text = "Directory";
	dir_entry.activates_default = true;
	grid.attach (dir_entry, 0, 0, 1, 1);


	show_button = new Gtk.Button.with_label ("Show");
	show_button.get_style_context ().add_class ("suggested-action");
	show_button.clicked.connect (() => {
		message ("clicked");
		list_model.scan_dir.begin (dir_entry.get_text ());
	 });
	show_button.receives_default = true;
	grid.attach (show_button, 1, 0, 1, 1);

	filter_entry = new Gtk.Entry ();
	filter_entry.hexpand = true;
	filter_entry.placeholder_text = "Filter";
	filter_entry.buffer.notify["text"].connect (() => {
		list_model.apply_filter (filter_entry.get_text ());
	});
	grid.attach (filter_entry, 0, 1, 2, 1);



	list_box = new ModelListBox ();
	list_model = new FileModel ();
	list_model.items_changed.connect (() => {
		int n_items = (int) list_model.get_n_items ();
		window.title = "File manager (%d items)".printf (n_items);
	});
	list_box.set_model (list_model);
	list_box.hexpand = true;
	list_box.vexpand = true;
	list_box.fill_func = (item, old) => {
		FileRow row = (FileRow) old;
		if (row == null)
		  row = new FileRow ();

		row.assign ((FileData)item, filter_entry.text);

		row.show_all ();

		return row;
	};

	var scroller = new Gtk.ScrolledWindow (null, null);
	scroller.add (list_box);
	grid.attach (scroller, 0, 2, 2, 1);



	var items_label = new Gtk.Label ("Items: 0");
	items_label.halign = Gtk.Align.START;

	list_model.items_changed.connect (() => {
		items_label.label = "Items: %u".printf (list_model.get_n_items ());
	});
	grid.attach (items_label, 0, 3, 1, 1);


	window.add (grid);
	window.resize (600, 400);
	window.show_all ();
	Gtk.main ();
}
