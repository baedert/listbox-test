
/*
   - Fast Scrolling (e.g. click on scrollbar trough)
   - Verschiedene Widgetgroessen
   - Revealer in Widget
   - ModelListBox nicht in ScrolledWindow
   - add rows at runtime
   - remove rows at runtime
   - set model at runtime
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);


Gtk.Label n_widget_label;
Gtk.Label model_label;

class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gdk.Window bin_window;
  private GLib.ListModel model;
  public WidgetFillFunc? fill_func;
  private int bin_y_diff = 0;// distance between -vadjustment.value and bin_y

  private int model_from = 0;
  private int model_to   = -1;

  /* GtkScrollable properties  {{{ */
  private Gtk.Adjustment _vadjustment;
  public Gtk.Adjustment vadjustment {
    set {
      this._vadjustment = value;
      if (this._vadjustment != null) {
        this._vadjustment.value_changed.connect (ensure_visible_widgets);
        configure_adjustment ();
      } else
        warning ("vadjustment == NULL");
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

  private Gtk.Widget? get_old_widget () {
    if (this.old_widgets.size == 0)
      return null;

    var w = this.old_widgets.get (0);
    this.old_widgets.remove (w);
    return w;
  }

  public void set_model (GLib.ListModel model) {
    this.model = model;
    model.items_changed.connect ((position, removed, added) => {
      assert (false);
    });
  }

  public override void map () {
    base.map ();
    ensure_visible_widgets ();
  }

  private void insert_child_internal (Gtk.Widget widget, int index) {
    widget.set_parent_window (this.bin_window);
    widget.set_parent (this);
    this.widgets.insert (index, widget);
  }

  private void remove_child_internal (Gtk.Widget widget) {
    assert (widget.parent == this);
    assert (widget.get_parent_window () == this.bin_window);

    this.widgets.remove (widget);
    widget.unparent ();
    this.old_widgets.add (widget);
  }

  /* GtkContainer API {{{ */
  public override void add (Gtk.Widget child) { assert (false); }

  public override void forall_internal (bool         include_internals,
                                        Gtk.Callback callback) {
    foreach (var child in widgets) {
      callback (child);
    }
  }

  public override void remove (Gtk.Widget w) {
    assert (w.get_parent () == this);
    // XXX unref all widgets manually in the destructor
  }

  public override GLib.Type child_type () {
    return typeof (Gtk.Widget);
  }
  /* }}} */

  /* GtkWidget API  {{{ */
  public override bool draw (Cairo.Context ct)
  {
    // draw bin_window
    int x, y, w, h;
    this.bin_window.get_geometry (out x, out y, out w, out h);
    ct.set_source_rgba (1, 1, 1, 1);
    ct.rectangle (x, y, w, h);
    ct.fill ();

    if (Gtk.cairo_should_draw_window (ct, this.bin_window)) {
      foreach (var child in widgets) {
        this.propagate_draw (child, ct);
      }
    }

    return false;
  }

  private void position_children ()
  {
    Gtk.Allocation allocation;
    Gtk.Allocation child_allocation = {0};
    int imp;

    this.get_allocation (out allocation);

    int y = allocation.y;
    child_allocation.x = 0;
    child_allocation.width = allocation.width;

    foreach (Gtk.Widget child in this.widgets) {
      child.get_preferred_height (out child_allocation.height, out imp);
      child_allocation.y = y;
      child.size_allocate (child_allocation);
      y += child_allocation.height;
    }
  }

  int s_a_c = 0;
  public override void size_allocate (Gtk.Allocation allocation)
  {
    //stdout.printf ("%d: size_allocate\n", s_a_c ++);
    this.set_allocation (allocation);
    position_children ();

    if (this.get_realized ()) {
      this.get_window ().move_resize (allocation.x,
                                      allocation.y,
                                      allocation.width,
                                      allocation.height);
      this.update_bin_window ();
    }

    ensure_visible_widgets ();
    configure_adjustment ();
  }

  public override void realize ()
  {
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

    this.bin_window = new Gdk.Window (this.get_window (),
                                      attr,
                                      attr_types);
    this.register_window (this.bin_window);

    this.bin_window.show ();

    foreach (var w in widgets)
      w.set_parent_window (this.bin_window);
  }
  /* }}} */



  private void configure_adjustment ()
  {
    int average_widget_height = 0;

    if (this.widgets.size > 0) {
      foreach (var w in this.widgets) {
        average_widget_height += w.get_allocated_height ();
      }
      average_widget_height /= this.widgets.size;
    }

    int estimated_list_height = (int)this.model.get_n_items () * average_widget_height;

    this._vadjustment.configure (this._vadjustment.value, // value,
                                 0, // lower
                                 //h, // Upper
                                 estimated_list_height,
                                 1, //step increment
                                 0, // page increment
                                 this.get_allocated_height ()); // page_size
  }

  private int get_bin_height (bool p = false)
  {
    int h = 0;
    int min, nat;
    foreach (var w in this.widgets) {
      w.get_preferred_height_for_width (this.get_allocated_width (),
                                        out min, out nat);
      h += min;
      assert (min == 34);
    }

    assert (h >= 0);
    return h;
  }

  private inline int bin_y ()
  {
    return -(int)this._vadjustment.value + this.bin_y_diff;
  }

  int e_c = 0;
  private void ensure_visible_widgets ()
  {
    // XXX ????
    if (!this.get_mapped ()) return;

    stdout.printf ("%d: ensure_visible_widgets for value %f\n", e_c ++, this._vadjustment.value);
    message ("--------------------------------------");
    message ("bin_y: %d", bin_y ());
    message ("bin_y_diff: %d", this.bin_y_diff);
    //message ("New adjustment value: %f, bin_y: %d", this._vadjustment.value, bin_y ());


    int bin_height;
    Gtk.Allocation widget_alloc;
    /* We need child_y_diff to keep track of the allocation.y change
       of all children, since they won'y be updated until the next
       size_allocate */
    int child_y_diff = 0;
    this.get_allocation (out widget_alloc);
    this.bin_window.get_geometry (null, null, null, out bin_height);


    // TOP {{{
    // Insert widgets at top
    message ("vadjustment.value: %f, bin_y_diff: %d", this._vadjustment.value, bin_y_diff);
    while (bin_y () > 0 && model_to > 0) {
      var new_widget = fill_func (model.get_object (model_from - 1),
                                  get_old_widget ());
      assert (new_widget != null);
      message ("Adding widget at top for index %d", model_from - 1);
      model_from --;
      this.insert_child_internal (new_widget, 0);
      int nat, min;
      new_widget.get_preferred_height_for_width (this.get_allocated_width (),
                                                 out min,
                                                 out nat);
      this.bin_y_diff -= min;
      child_y_diff += min;
    }

    assert (bin_y () <= 0);


    for (int i = 0; i < this.widgets.size; i ++) {
      Gtk.Allocation alloc;
      Gtk.Widget w = this.widgets.get (i);
      w.get_allocation (out alloc);
      if (bin_y () + alloc.y + child_y_diff + alloc.height < 0) {
        // Remove widget, resize and move bin_window
        stdout.printf ("Removing widget %p at top\n", w);
        //stdout.printf ("    bin_height: %d\n", bin_height);
        //stdout.printf ("    bin_y_diff: %d\n", bin_y_diff);
        //stdout.printf ("  child_y_diff: %d\n", child_y_diff);
        //stdout.printf ("       alloc.y: %d\n", alloc.y);
        //stdout.printf ("   alloc.heght: %d\n", alloc.height);
        bin_height -= alloc.height;
        this.bin_y_diff += alloc.height;
        child_y_diff -= alloc.height;
        //stdout.printf ("After:\n");
        //stdout.printf ("    bin_height: %d\n", bin_height);
        //stdout.printf ("    bin_y_diff: %d\n", bin_y_diff);
        //stdout.printf ("  child_y_diff: %d\n", child_y_diff);
        this.remove_child_internal (w);
        model_from ++;
      }
      else break;
    }

    // }}}

    // BOTTOM {{{
    // Bottom of bin_window hangs into the widget
    //message ("bin_height before: %d", bin_height);
    //message ("widget height: %d", widget_alloc.height);
    //message ("bin_y: %d", bin_y ());
    //message ("model_to: %d", model_to);
    //message ("n_items: %u", model.get_n_items ());
    while (bin_y () + bin_height <= widget_alloc.height &&
           model_to < (int)model.get_n_items () - 1) {
      var new_widget = fill_func (model.get_object (model_to + 1),
                                  get_old_widget ());
      assert (new_widget != null);
      this.insert_child_internal (new_widget, this.widgets.size);
      model_to ++;
      int nat, min;
      new_widget.get_preferred_height_for_width (this.get_allocated_width (),
                                                 out min,
                                                 out nat);
      bin_height += min;
      message ("Adding widget at bottom. New bin_height: %d", bin_height);
    }


    // remove widgets
    for (int i = this.widgets.size - 1; i >= 0; i --) {
      Gtk.Allocation alloc;
      var w = this.widgets.get (i);
      w.get_allocation (out alloc);

      // The widget's y in the lists' coordinates
      int widget_y = bin_y () + alloc.y + child_y_diff;
      if (widget_y > this.get_allocated_height ()) {
        this.remove_child_internal (w);
        message ("Removing bottom widget with index %d", i);
        model_to --;
      } else
        break;
    }

    // }}}


    // Maybe optimize this out if nothing changed?
    this.update_bin_window ();
    position_children ();

    assert (bin_y () <= 0);
    assert (this.widgets.size == (model_to - model_from + 1));
    if (this._vadjustment.value == 0)
      assert (this.bin_y_diff == 0);
  }

  private void update_bin_window ()
  {
    Gtk.Allocation allocation;
    this.get_allocation (out allocation);

    int new_y = allocation.y - (int) this._vadjustment.value + this.bin_y_diff;

    int h = get_bin_height ();
    this.bin_window.move_resize (allocation.x,
                                 new_y,
                                 allocation.width,
                                 h);
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
  w.delete_event.connect (() => {Gtk.main_quit (); return false;});
  var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
  var l = new ModelListBox ();
  l.vexpand = true;


  var store = new GLib.ListStore (typeof (ModelItem));
  n_widget_label = new Gtk.Label ("Foobar");
  model_label = new Gtk.Label ("zomg model");


  l.fill_func = (item, old) => {
    assert (item != null);

    //message ("%d: Fill func for '%s'!", ff_c ++, ((ModelItem)item).name);

    ModelWidget b = (ModelWidget)old;
    if (old == null)
      b = new ModelWidget ();

    b.set_name (((ModelItem)item).name);
    b.remove_button.clicked.connect (() => {
      //store.remove (index);
      message ("TODO: Remove");
    });
    b.show_all ();
    return b;
  };

  //for (int i = 0; i < 20; i ++)
  for (int i = 0; i < 200; i ++)
    store.append (new ModelItem ("NUMBER " + i.to_string ()));

  l.set_model (store);

  var scroller = new Gtk.ScrolledWindow (null, null);

  // Add widget button {{{

  var hw = new Gtk.HeaderBar ();
  hw.show_close_button = true;
  w.set_titlebar (hw);

  var awb = new Gtk.Button.with_label ("Add widget");
  awb.clicked.connect (() => {
    store.append (new ModelItem ("one more"));
  });

  box.add (awb);
  box.add (n_widget_label);
  box.add (model_label);

  var scb = new Gtk.Button.with_label ("Scroll up");
  scb.clicked.connect (() => {
    //scroller.get_vadjustment ().value += 100;
    scroller.get_vadjustment ().value = 0;
  });

  box.pack_end (scb, false, false);

  // }}}


  scroller.vscrollbar_policy = (Gtk.PolicyType.ALWAYS);
  scroller.overlay_scrolling = false;
  scroller.add (l);
  box.add (scroller);
  w.add (box);
  w.show_all ();
  w.resize (400, 500);
  Gtk.main ();
}
