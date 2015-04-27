
/*
  - Make the container itself work
    - --- Adding and removing widgets at runtime shouold work just fine.
    - --- Adding them before showing the container too.
  - Use a model
    - Model changes -> widget changes
    - First, show widgets for ALL the items in the model, like GtkListBox
    - Port to GLib.ListModel
  Remove out-of-sight widgets
    - implement Gtk.Scrollable
    - On Scroll
    - On Resize
  - Reuse widgets
  - Fix destruction (see XXX in forall)
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item);// XXX Pass old widget (?)

class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gdk.Window bin_window;
  private GLib.ListModel model;
  public WidgetFillFunc? fill_func;

  /* GtkScrollable properties  {{{ */
  private Gtk.Adjustment _vadjustment;
  public Gtk.Adjustment vadjustment {
    set {
      this._vadjustment = value;
      configure_adjustment ();
      this._vadjustment.value_changed.connect (vadjustment_changed_cb);
    }
    get {
      return this._vadjustment;
    }
  }
  private Gtk.Adjustment _hadjustment;
  public Gtk.Adjustment hadjustment {
    set {
      this._hadjustment = value;
    }
    get {
      return this._hadjustment;
    }
  }
  public Gtk.ScrollablePolicy hscroll_policy { get; set; }
  public Gtk.ScrollablePolicy vscroll_policy { get; set; }
  /* }}} */

  private void debug_print_model () {
    assert (model != null);
    message ("MODEL:");
    for (int i = 0; i < this.model.get_n_items (); i ++) {
      message ("%d: %p", i, this.model.get_item (i));
    }
    message ("----------");
  }

  private void debug_print_widgets () {
    message ("WIDGETS:");
    for (int i = 0; i < this.widgets.size; i ++) {
      message ("%d: %p", i, this.widgets.get (i));
    }
    message ("----------");
  }


  public void set_model (GLib.ListModel model) {
    this.model = model;
    // Add already existing widgets
    for (int i = 0; i < model.get_n_items (); i ++) {
      var w = fill_func (model.get_object (i));
      insert_child_internal (w, i);
    }

    this.debug_print_widgets ();
    this.debug_print_model ();

    model.items_changed.connect ((position, removed, added) => {
      int index = (int)position - 1;
      //message ("items changed! index: %d, removed: %u, added: %u", index, removed, added);

      var item = model.get_object (position);
      for (int i = 0; i < removed; i ++) {
        widgets.remove_at ((int)position);
      }

      for (int i = 0; i < added; i ++) {
        var widget = fill_func (item);
        insert_child_internal (widget, index + 1);
      }

      this.debug_print_widgets ();

      this.debug_print_model ();
      this.queue_resize ();
    });

  }

  private void insert_child_internal (Gtk.Widget widget, int index) {
    widget.set_parent_window (this.bin_window);
    widget.set_parent (this);
    this.widgets.insert (index, widget);
  }

  /* GtkContainer API {{{ */
  public override void add (Gtk.Widget child) { assert (false); }

  public override void forall_internal (bool         include_internals,
                                        Gtk.Callback callback) {
    // XXX This breaks removal of all widgets, because remove() changes this.widgets
    foreach (var child in widgets) {
      callback (child);
    }
  }

  public override void remove (Gtk.Widget w) {
    assert (w.get_parent () == this);
    //widgets.remove (w);
    //w.unparent ();
    // XXX unref all widgets manually in the destructor
  }

  public override GLib.Type child_type () {
    return typeof (Gtk.Widget);
  }
  /* }}} */

  /* GtkWidget API  {{{ */
  public override bool draw (Cairo.Context ct) {
    Gtk.Allocation alloc;
    this.get_allocation (out alloc);

    // Draw the bin_window on the widget window
    ct.set_source_rgba (0.1, 0.1, 0.1, 0.4);
    ct.rectangle (0, 0, this.bin_window.get_width (), this.bin_window.get_height ());
    ct.fill ();

    if (Gtk.cairo_should_draw_window (ct, this.bin_window)) {
      ct.set_source_rgba (1.0, 0.0, 0.0, 1.0);
      ct.rectangle (-100, -100, 10000, 10000);
      ct.fill ();
      //message ("    drawing window");
      foreach (var child in widgets) {
        this.propagate_draw (child, ct);
      }
    }// else message ("not drawing window");

    base.draw (ct);

    return false;
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    Gtk.Allocation child_allocation = {0};
    int imp;

    this.set_allocation (allocation);
    int y = allocation.y;
    child_allocation.x = 0;
    child_allocation.width = allocation.width;
    foreach (Gtk.Widget child in this.widgets) {
      child.get_preferred_height (out imp, out child_allocation.height);
      child_allocation.y = y;
      child.size_allocate (child_allocation);
      y += child_allocation.height;
    }

    configure_adjustment ();

    if (this.get_realized ()) {
      this.get_window ().move_resize (allocation.x,
                                      allocation.y,
                                      allocation.width,
                                      allocation.height);

      int new_y = allocation.y - (int) this._vadjustment.value;
      int h = 0;
      foreach (var w in widgets) {
        h += w.get_allocated_height ();
      }

      this.bin_window.move_resize (allocation.x,
                                   new_y,
                                   allocation.width,
                                   h);
                                   //new_height);
    }
  }

  public override void realize () {
    Gtk.Allocation allocation;
    Gdk.Window window;
    Gdk.WindowAttr attr = Gdk.WindowAttr ();
    Gdk.WindowAttributesType attr_types;

    this.set_realized (true);
    this.get_allocation (out allocation);

    attr.x = allocation.x;
    attr.y = allocation.y;
    attr.width = allocation.width;
    attr.height = allocation.height;
    attr.window_type = Gdk.WindowType.CHILD;
    attr.event_mask = this.get_events () |
                      Gdk.EventMask.ALL_EVENTS_MASK;
    attr.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
    attr.visual = this.get_visual ();

    attr_types = Gdk.WindowAttributesType.X |
                 Gdk.WindowAttributesType.Y |
                 Gdk.WindowAttributesType.VISUAL;

    window = new Gdk.Window (this.get_parent_window (),
                             attr,
                             attr_types);


    this.set_window (window);
    this.register_window (window);

    //attr.y = -(int)vadjustment.value + bin_window_displacement;
    //attr.height = exact_children_height (); XXX


    this.bin_window = new Gdk.Window (this.get_window (),
                                      attr,
                                      attr_types);
    this.register_window (this.bin_window);

    //this.set_window (this.bin_window);
    this.bin_window.show ();

    foreach (var w in widgets)
      w.set_parent_window (this.bin_window);
  }
  /* }}} */

  private void configure_adjustment () {
    int h = 0;
    foreach (var w in widgets) {
      h += w.get_allocated_height ();
    }

    // XXX ???
    if (h == 0) h = 1;

    this._vadjustment.configure (this._vadjustment.value, // value,
                                 0, // lower
                                 h, // Upper
                                 0, //step increment
                                 0, // page increment
                                 this.get_allocated_height ()); // page_size
  }


  private void vadjustment_changed_cb () {
    double new_value = this._vadjustment.value;
    int bin_x;
    int bin_y;
    this.bin_window.get_geometry (out bin_x, out bin_y, null, null);

    for (int widget_index = 0; widget_index < /*this.widgets.size*/1; widget_index ++) {
      Gtk.Allocation alloc;
      Gtk.Widget w = this.widgets.get (widget_index);
      w.get_allocation (out alloc);
      message ("y: %d, bin_y: %d", alloc.y, bin_y);
    }

    this.queue_resize (); // XXX needed?!
  }

}

// Model stuff {{{
class ModelItem : GLib.Object {
  public string name;
  public ModelItem (string s) { name = s; }
}

class ModelWidget : Gtk.Box {
  private Gtk.Label name_label = new Gtk.Label ("");
  public  Gtk.Button remove_button = new Gtk.Button.from_icon_name ("list-remove-symbolic");
  public ModelWidget () {
    name_label.hexpand = true;
    this.add (name_label);
    this.add (remove_button);
  }

  public void set_name (string name) {
    this.name_label.label = name;
  }
}

// }}}

void main (string[] args) {
  Gtk.init (ref args);
  var w = new Gtk.Window ();
  var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
  var l = new ModelListBox ();
  l.vexpand = true;


  var store = new GLib.ListStore (typeof (ModelItem));


  l.fill_func = (item) => {
    var b = new ModelWidget ();
    b.set_name (((ModelItem)item).name);
    b.remove_button.clicked.connect (() => {
      //store.remove (index);
      message ("TODO: Remove");
    });
    b.show_all ();
    return b;
  };

  for (int i = 0; i < 20; i ++)
    store.append (new ModelItem ("a"));

  l.set_model (store);


  // Add widget button {{{
  var awb = new Gtk.Button.with_label ("Add widget");
  awb.clicked.connect (() => {
    store.append (new ModelItem ("one more"));
  });
  box.add (awb);

  // }}}


  var scroller = new Gtk.ScrolledWindow (null, null);
  scroller.vscrollbar_policy = (Gtk.PolicyType.ALWAYS);
  scroller.overlay_scrolling = false;
  scroller.add (l);
  box.add (scroller);
  w.add (box);
  w.show_all ();
  w.resize (400, 400);
  Gtk.main ();
}
