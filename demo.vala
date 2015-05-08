

Soup.Session SESSION;

class SampleModelItem : GLib.Object {
  public string path;
  public int num;
  public SampleModelItem (int num) {
    this.num = num;
  }
}

class SampleWidget : Gtk.Grid {
  public Gtk.Image image = new Gtk.Image ();
  public Gtk.Label label = new Gtk.Label ("");

  public SampleWidget () {
    this.attach (image, 0, 0, 1, 1);
    this.attach (label, 1, 0, 1, 1);
    var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
    sep.hexpand = true;
    this.attach (sep, 0, 1, 2, 1);
  }

  //public async void start_load_image (string path) {
    //this.cancel = new GLib.Cancellable ();

    //var msg = new Soup.Message ("GET", "http://corebird.baedert.org/corebird.png");
    //this.cancel.cancelled.connect (() => {
      //SESSION.cancel_message (msg, 100);
    //});
    //SESSION.queue_message (msg, () => {
      //if (msg.response_body.data == null)
        //return;

      //var memory_stream = new MemoryInputStream.from_data(msg.response_body.data,
                                                          //null);
      //try {
        //this.image.pixbuf = new Gdk.Pixbuf.from_stream_at_scale (memory_stream,
                                                                 //20 + (int)(GLib.Random.next_int () % 70),
                                                                 //20 + (int)(GLib.Random.next_int () % 80),
                                                                 //false, this.cancel);
      //} catch (GLib.Error e) {
        // Ignore.
      //}

      //memory_stream.close ();
    //});
  //}

  //public void abort_load_image () {
    //this.cancel.cancel ();
    //this.cancel.reset ();
  //}
}

int current_image = 0;

Gee.ArrayList<string> paths;




void main (string[] args) {
  Gtk.init (ref args);
  var window = new Gtk.Window ();
  var list_box = new ModelListBox ();
  var scroller = new Gtk.ScrolledWindow (null, null);

  SESSION = new Soup.Session ();

  var model = new GLib.ListStore (typeof (SampleModelItem));


  //for (int i = 0; i < 100000; i ++)
  for (int i = 0; i < 10; i ++)
    model.append (new SampleModelItem (i));


  //int i = 0;
  // Listbox setup
  list_box.fill_func = (item, widget) => {
    SampleWidget sample_widget = (SampleWidget) widget;

    if (widget == null)
      sample_widget = new SampleWidget ();


    var sample = (SampleModelItem) item;
    //message ("fill func");

    sample_widget.label.label = "ZOMG %d".printf (sample.num);
    sample_widget.set_size_request (-1, 20 + (int)(GLib.Random.next_int () % 200));
    //sample_widget.start_load_image.begin (sample.path);
    //sample_widget.start_load_image.begin (paths.get (current_image));

    //current_image = current_image +1 % paths.size;

    sample_widget.show_all ();
    return sample_widget;
  };

  list_box.destroy_func = (widget) => {
    //var sample_widget = (SampleWidget) widget;
    //sample_widget.image.pixbuf = null;

    //sample_widget.abort_load_image ();
  };



  list_box.set_model (model);
  scroller.add (list_box);

  window.add (scroller);
  window.resize (400, 500);
  window.show_all ();
  Gtk.main ();
}
