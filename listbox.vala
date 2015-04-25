
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

class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<GLib.Object> model  = new Gee.ArrayList<GLib.Object> ();
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();

  /* GtkScrollable properties  {{{ */
  private Gtk.Adjustment _vadjustment;
  public Gtk.Adjustment vadjustment {
    set {
      this._vadjustment = value;
      this._vadjustment.upper = 100;
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
    this.set_has_window (false);
  }


  public void add_item (GLib.Object item) {
    model.add (item);
    Gtk.Widget new_widget = this.fill_func (item);
    this.add_child_internal (new_widget);
    this.queue_resize ();
  }

  private void add_child_internal (Gtk.Widget widget) {
    widget.set_parent (this);
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

  /* GtkWidget API */
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
  }

  public override bool draw (Cairo.Context ct) {
    Gtk.Allocation alloc;
    this.get_allocation (out alloc);

    ct.set_source_rgba (0.1, 0.1, 0.1, 0.4);
    ct.rectangle (0, 0, alloc.width, alloc.height);
    ct.fill ();

    base.draw (ct);

    return false;
  }

  private void vadjustment_changed_cb () {
    double new_value = this._vadjustment.value;
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
