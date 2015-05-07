



class SampleModelItem : GLib.Object {
  public string path;
}

class SampleWidget : Gtk.Grid {
  private Gtk.Image image = new Gtk.Image ();
  private GLib.Cancellable cancel;

  public SampleWidget () {
    this.attach (image, 0, 0, 1, 1);
  }

  public async void start_load_image (string path) {
    try {
      this.cancel = new GLib.Cancellable ();
      var file = GLib.File.new_for_path (path);
      var stream = file.read ();
      var pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream, this.cancel);

      this.image.pixbuf = pixbuf;
    } catch (GLib.Error e) {

    }
  }

  public void abort_load_image () {
    this.cancel.cancel ();
    this.cancel.reset ();
  }
}

int current_image = 0;

Gee.ArrayList<string> paths;




void main (string[] args) {
  Gtk.init (ref args);
  var window = new Gtk.Window ();
  var list_box = new ModelListBox ();
  var scroller = new Gtk.ScrolledWindow (null, null);


  var model = new GLib.ListStore (typeof (SampleModelItem));

  // Init sample data
  paths = new Gee.ArrayList<string> ();
  var folder = File.new_for_path ("/usr/share/icons/hicolor/48x48/apps/");
  var enumerator = folder.enumerate_children (FileAttribute.STANDARD_NAME, 0);

  GLib.FileInfo file_info;
  while ((file_info  = enumerator.next_file ()) != null) {
    var it = new SampleModelItem ();
    it.path = folder.get_child (file_info.get_name ()).get_path ();
    model.append (it);
    //paths.add (folder.get_child (file_info.get_name ()).get_path ());
  }


  // Listbox setup
  list_box.fill_func = (item, widget) => {
    SampleWidget sample_widget = (SampleWidget) widget;

    if (widget == null)
      sample_widget = new SampleWidget ();


    var sample = (SampleModelItem) item;
    message ("fill func");

    sample_widget.start_load_image.begin (sample.path);
    //sample_widget.start_load_image.begin (paths.get (current_image));

    //current_image = current_image +1 % paths.size;

    sample_widget.show_all ();
    return sample_widget;
  };

  list_box.destroy_func = (widget) => {
    var sample_widget = (SampleWidget) widget;

    sample_widget.abort_load_image ();
  };



  list_box.set_model (model);
  scroller.add (list_box);

  window.add (scroller);
  window.show_all ();
  Gtk.main ();
}
