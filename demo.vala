

Soup.Session SESSION;

class SampleModelItem : GLib.Object {
  public int num;
  public int size;
  public SampleModelItem (int num, int size) {
    this.num = num;
    this.size = size;
  }
}

class SampleWidget : Gtk.Grid {
  public Gtk.Image image = new Gtk.Image ();
  public Gtk.Label label = new Gtk.Label ("");
  public int num;
  public int size;

  public SampleWidget () {
    this.attach (image, 0, 0, 1, 1);
    this.attach (label, 1, 0, 1, 1);
    var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
    sep.hexpand = true;
    sep.vexpand = true;
    sep.valign = Gtk.Align.END;
    this.attach (sep, 0, 1, 2, 1);
  }

  public override bool draw (Cairo.Context ct) {

    float f = (float) num  /  (float) size;

    ct.set_source_rgba (1 - f, 0.5 + f, f, 1.0);
    ct.rectangle (0, 0,
                  get_allocated_width (),
                  get_allocated_height ());
    ct.fill ();


    ct.set_source_rgba (0, 0, 0, 1);
    ct.move_to (0, get_allocated_height ());
    ct.line_to (get_allocated_width (), get_allocated_height ());
    ct.stroke ();


    return false;
  }

}


void main (string[] args) {
  Gtk.init (ref args);
  var window = new Gtk.Window ();
  var list_box = new ModelListBox ();
  var scroller = new Gtk.ScrolledWindow (null, null);
  var n_widgets_label = new Gtk.Label ("");
  var model_size_label = new Gtk.Label ("");


  SESSION = new Soup.Session ();

  var model = new GLib.ListStore (typeof (SampleModelItem));

  //model.append (new SampleModelItem (0, 2));

  //for (int i = 0; i < 1000000; i ++)
  for (int i = 0; i < 100; i ++)
    model.append (new SampleModelItem (i, 20 + (i * 10)));


  //model.append (new SampleModelItem (59, 2));


  //int i = 0;
  // Listbox setup
  list_box.fill_func = (item, widget) => {
    SampleWidget sample_widget = (SampleWidget) widget;
    assert (item != null);

    if (widget == null)
      sample_widget = new SampleWidget ();


    var sample = (SampleModelItem) item;
    //message ("fill func");

    sample_widget.label.label = "ZOMG %d".printf (sample.num);
    if (sample.num > 25)
      sample_widget.set_size_request (-1, 100);
    else
      sample_widget.set_size_request (-1, 20);


    sample_widget.num = sample.num;
    sample_widget.size = (int)model.get_n_items ();

    sample_widget.show_all ();
    return sample_widget;
  };

  list_box.destroy_func = (widget) => {
  };


  GLib.Timeout.add (2000, () => {
    list_box.set_model (model);
    return false;
  });
  scroller.add (list_box);

  var items_label = new Gtk.Label ("");
  var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
  var box2 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
  n_widgets_label.xalign = 0.0f;
  box2.add (n_widgets_label);
  model_size_label.xalign = 1.0f;
  box2.add (model_size_label);
  box2.add (items_label);
  box.add (box2);
  box.add (scroller);


  model_size_label.label = "Items: %u".printf (model.get_n_items ());

  list_box.notify["cur-widgets"].connect (() => {
    n_widgets_label.label = "Widgets used: %u".printf (list_box.cur_widgets);
  });

  list_box.notify["model-from"].connect (() => {
    items_label.label = "Visible: %d - %d".printf (list_box.model_from, list_box.model_to);
  });
  list_box.notify["model-to"].connect (() => {
    items_label.label = "Visible: %d - %d".printf (list_box.model_from, list_box.model_to);
  });




  scroller.overlay_scrolling = false;
  window.add (box);
  window.resize (400, 500);
  window.show_all ();
  Gtk.main ();
}
