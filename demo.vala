


class SampleModelItem : GLib.Object {
  public int num;
  public int size;
  public bool checked = false;
  public SampleModelItem (int num, int size) {
    this.num = num;
    this.size = size;
  }
}

class SampleWidget : Gtk.Grid {
  public Gtk.CheckButton checkbox = new Gtk.CheckButton ();
  public Gtk.Label label = new Gtk.Label ("");
  public int num;
  public int size;
  private unowned SampleModelItem? item;

  public SampleWidget () {
    checkbox.halign = Gtk.Align.START;
    checkbox.hexpand = false;
    this.attach (checkbox, 0, 0, 1, 1);
    label.hexpand = true;
    label.margin_left = 12;
    label.halign = Gtk.Align.START;
    this.attach (label, 1, 0, 1, 1);
    var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
    sep.hexpand = true;
    sep.vexpand = true;
    sep.valign = Gtk.Align.END;
    this.attach (sep, 0, 1, 2, 1);
  }

  private void toggled_callback () {
    this.item.checked = this.checkbox.active;
  }

  public void assign (SampleModelItem item) {
    checkbox.active = item.checked;
    checkbox.toggled.connect (toggled_callback);
    this.item = item;
  }

  public void unassign () {
    checkbox.toggled.disconnect (toggled_callback);
    this.item = null;
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


    return base.draw (ct);
  }

}


void main (string[] args) {
  Gtk.init (ref args);
  var window = new Gtk.Window ();
  var list_box = new ModelListBox ();
  var scroller = new Gtk.ScrolledWindow (null, null);
  var n_widgets_label = new Gtk.Label ("");
  var model_size_label = new Gtk.Label ("");
  var height_label = new Gtk.Label ("Estimated height: 1337");

  var model = new GLib.ListStore (typeof (SampleModelItem));

  //for (int i = 0; i < 1000000; i ++)
  for (int i = 0; i < 100; i ++)
    model.append (new SampleModelItem (i, 20 + (i * 10)));



  //int i = 0;
  // Listbox setup
  list_box.fill_func = (item, widget) => {
    SampleWidget sample_widget = (SampleWidget) widget;
    assert (item != null);

    if (widget == null)
      sample_widget = new SampleWidget ();
    else
      sample_widget.unassign ();

    var sample = (SampleModelItem) item;

    sample_widget.assign (sample);


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

  list_box.set_model (model);
  scroller.add (list_box);

  var items_label = new Gtk.Label ("");
  var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
  var box2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
  box2.add (n_widgets_label);
  box2.add (model_size_label);
  box2.add (items_label);
  box2.add (height_label);
  box.add (box2);
  box.add (scroller);


  scroller.get_vadjustment ().value_changed.connect (() => {
    height_label.label = "Estimated height: %d".printf (list_box.estimated_height);
  });



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


  var bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
  var asb = new Gtk.Button.with_label ("Start");
  asb.clicked.connect (() => {
    model.insert (0, new SampleModelItem (100, 100));
  });
  var amb = new Gtk.Button.with_label ("Middle");
  var aeb = new Gtk.Button.with_label ("End");
  aeb.clicked.connect (() => {
    model.insert (model.get_n_items (), new SampleModelItem (50, 50));
  });

  var rsb = new Gtk.Button.with_label ("Remove selected");
  rsb.clicked.connect (() => {
    for (int i = 0; i < model.get_n_items (); i ++) {
      var item = (SampleModelItem)model.get_object (i);
      if (item.checked) {
        model.remove (i);
        i --;
      }
    }
  });

  bbox.add (asb);
  bbox.add (amb);
  bbox.add (aeb);
  bbox.add (rsb);
  box.add (bbox);


  scroller.overlay_scrolling = false;
  window.add (box);
  window.resize (400, 500);
  window.show_all ();
  Gtk.main ();
}
