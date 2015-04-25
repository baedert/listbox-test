
/*
  - Make the container itself work XXX
    - --- Adding and removing widgets at runtime shouold work just fine.
    - --- Adding them before showing the container too.
  - Use a model
    - Model changes -> widget changes
    - First, show widgets for ALL the items in the model, like GtkListBox
  Remove out-of-sight widgets
    - implement Gtk.Scrollable
    - On Scroll
    - On Resize
  - Reuse widgets
  - Use GLib.ListModel
  - Fix destruction (see XXX in forall)
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item);// XXX Pass old widget (?)

// Util crap {{{
inline int max (int a, int b) {
  return a > b ? a : b;
}
// }}}

class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<GLib.Object> model  = new Gee.ArrayList<GLib.Object> ();
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gdk.Window bin_window;

  /* GtkScrollable properties  {{{ */
  private Gtk.Adjustment _vadjustment;
  public Gtk.Adjustment vadjustment {
    set {
      this._vadjustment = value;
      this._vadjustment.upper = 500;
      this._vadjustment.lower = 0;
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


  public WidgetFillFunc? fill_func;

  public ModelListBox () {
    this.set_has_window (true);
  }


  public void add_item (GLib.Object item) {
    model.add (item);
    Gtk.Widget new_widget = this.fill_func (item);
    this.add_child_internal (new_widget);
    this.queue_resize ();
  }

  private void add_child_internal (Gtk.Widget widget) {
    widget.set_parent_window (this.bin_window);
    widget.set_parent (this);
    //widget.set_parent_window (this.get_window ());
    this.widgets.add (widget);
  }

  /* GtkContainer API */
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
    widgets.remove (w);
    w.unparent ();
  }
  public override GLib.Type child_type () {
    return typeof (Gtk.Widget);
  }

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
      assert (child.visible);
      child.get_preferred_height (out imp, out child_allocation.height);
      child_allocation.y = y;
      child.size_allocate (child_allocation);
      y += child_allocation.height;
    }

    if (this.get_realized ()) {
      this.get_window ().move_resize (allocation.x,
                                      allocation.y,
                                      allocation.width,
                                      allocation.height);

      int new_y = allocation.y + (int) this._vadjustment.value;
      //int new_height = max (allocation.height + (int)(this._vadjustment.value * 2),
                            //allocation.height);
      //message ("New height: %d (allocated; %d)", new_height, allocation.height);
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

  private void vadjustment_changed_cb () {
    double new_value = this._vadjustment.value;
    this.queue_resize ();
  }
}


class ModelItem : GLib.Object {
  string name;
}

void main (string[] args) {
  Gtk.init (ref args);
  var w = new Gtk.Window ();
  var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
  var l = new ModelListBox ();
  l.vexpand = true;
  l.fill_func = (item) => {
    var b = new Gtk.Button.with_label ("From fill_func");
    b.clicked.connect (() => { message ("Clicked on filll_func button"); });
    b.show_all ();
    return b;
  };


  // Add widget button {{{
  var awb = new Gtk.Button.with_label ("Add widget");
  awb.clicked.connect (() => {
    message ("Button clicked");
    l.add_item (new ModelItem ());
    //var b = new Gtk.Button.with_label ("HEY HEY");
    //b.show_all ();
    //l.add (b);
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
