
/*
   == TODO LIST ==
   - Verschiedene Widgetgroessen
   - Revealer in Widget
   - add rows at runtime
   - remove rows at runtime
   - set model at runtime
   - ModelListBox nicht in ScrolledWindow
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);
delegate void WidgetDestroyFunc (Gtk.Widget? widget);


Gtk.Label n_widget_label;
Gtk.Label height_label;

class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gdk.Window bin_window;
  private GLib.ListModel model;
  public WidgetFillFunc fill_func;
  public WidgetDestroyFunc destroy_func;
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

  public ModelListBox () {
    this.get_style_context ().add_class ("list");
  }


  private Gtk.Widget? get_old_widget ()
  {
    if (this.old_widgets.size == 0)
      return null;

    var w = this.old_widgets.get (0);
    this.old_widgets.remove (w);
    return w;
  }

  public void set_model (GLib.ListModel model)
  {
    this.model = model;
    model.items_changed.connect ((position, removed, added) => {
      assert (false);
    });
  }

  public override void map ()
  {
    base.map ();
    ensure_visible_widgets ();
  }


  private void update_height () {
    int h = estimated_list_height ();
    //height_label.label = "Estimated height: %d".printf (h);
  }

  private void insert_child_internal (Gtk.Widget widget, int index)
  {
    widget.set_parent_window (this.bin_window);
    widget.set_parent (this);
    this.widgets.insert (index, widget);
    //n_widget_label.label = "Widgets: %d (%d)"
      //.printf (this.widgets.size, this.old_widgets.size);
    update_height ();
  }

  private void remove_child_internal (Gtk.Widget widget)
  {
    assert (widget.parent == this);
    assert (widget.get_parent_window () == this.bin_window);
    assert (this.widgets.contains (widget));

    this.destroy_func (widget);
    this.widgets.remove (widget);
    widget.unparent ();
    this.old_widgets.add (widget);
    //n_widget_label.label = "Widgets: %d (%d)"
      //.printf (this.widgets.size, this.old_widgets.size);
    update_height ();
  }

  private void remove_all_widgets ()
  {
    for (int i = this.widgets.size - 1; i >= 0; i --) {
      this.remove_child_internal (this.widgets.get (i));
    }
    //n_widget_label.label = "Widgets: %d (%d)"
      //.printf (this.widgets.size, this.old_widgets.size);
    update_height ();
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


    //Gtk.Allocation alloc;
    //this.get_allocation (out alloc);
    //this.get_style_context ().render_background (ct, alloc.x, alloc.y, alloc.width, alloc.height);

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
      child.get_preferred_height_for_width (this.get_allocated_width (),
                                            out child_allocation.height,
                                            out imp);
      child_allocation.y = y;
      child.size_allocate (child_allocation);
      y += child_allocation.height;
    }
  }

  public override void size_allocate (Gtk.Allocation allocation)
  {
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



  private int get_widget_height (Gtk.Widget w) {
    int min, nat;
    w.get_preferred_height_for_width (this.get_allocated_width (),
                                      out min,
                                      out nat);

    assert (min >= 1);

    return min;
  }

  private int estimated_widget_height ()
  {

    int average_widget_height = 0; // XXX This should be 0

    if (this.widgets.size > 0) {
      foreach (var w in this.widgets) {
        //average_widget_height += w.get_allocated_height ();
        average_widget_height += get_widget_height (w);
      }
      average_widget_height /= this.widgets.size;
    }

    return average_widget_height;
  }

  /* We use the exact height of the shown widgets PLUS the estimated widget height (which we get from the
   * shown widgets) for all the invisible rows */
  private int estimated_list_height (out int top_part = null)
  {
    int widget_height = estimated_widget_height ();

    assert (widget_height >= 0);

    assert (model_from >= 0);

    int top_widgets    = model_from;
    int bottom_widgets = (int)this.model.get_n_items () - model_to - 1;

    assert (top_widgets >= 0);
    assert (bottom_widgets >= 0);

    int exact_height = 0;
    foreach (var w in this.widgets) {
      int h = get_widget_height (w);
      exact_height += h;
    }

    assert (exact_height >= 0);

    top_part = top_widgets * widget_height;

    return exact_height +
           top_widgets * widget_height +
           bottom_widgets * widget_height;
  }

  private void configure_adjustment ()
  {
    //message ("-- configure_adjustment");
    int top_widgets_height;
    int list_height = estimated_list_height (out top_widgets_height);

    double new_value = this._vadjustment.value;
    if (this._vadjustment.upper != list_height) {
      int c = bin_y ();
      assert (c <= 0);
      new_value = top_widgets_height - c; // XXX int?
      message ("new_value = %d - %d -> %f", top_widgets_height, c, new_value);
      message ("bin_y_diff = %d", top_widgets_height);
      this.bin_y_diff = top_widgets_height;
      assert (-new_value + bin_y_diff <= 0);
    }


    //if (list_height != (int)this._vadjustment.upper) {
      //message ("New upper: %d", list_height);
    //}


    message ("Value before: %f", this._vadjustment.value);
    message ("new value: %f, max: %f", new_value, list_height - this.get_allocated_height ());
    this._vadjustment.configure (new_value,                     // value,
                                 0,                             // lower
                                 list_height,                   // Upper
                                 1,                             // step increment
                                 2,                             // page increment
                                 this.get_allocated_height ()); // page_size
    message ("Value after: %f", this._vadjustment.value);
    //assert (this._vadjustment.value == new_value);


    //if (top_widgets_height > bin_y_diff) {
      //message ("%d -- %d", top_widgets_height, bin_y_diff);
    //}
    //assert (top_widgets_height <= bin_y_diff);


    //if (bin_y () >= 0)
      //message ("bin_y: %d", bin_y ());
    //assert (bin_y () <= 0);
  }

  private int get_bin_height ()
  {
    int h = 0;
    int min;
    foreach (var w in this.widgets) {
      min = get_widget_height (w);
      assert (min >= 0);
      h += min;
    }

    assert (h >= 0);
    return h;
  }

  /**
   * @return The bin_window's y coordinate in widget coordinates.
   */
  private int bin_y ()
  {
    int p = -(int)this._vadjustment.value + this.bin_y_diff;
    return p;
  }

  private void ensure_visible_widgets ()
  {
    if (!this.get_mapped ()) return;


    int bin_height;
    Gtk.Allocation widget_alloc;
    /* We need child_y_diff to keep track of the allocation.y change
       of all children, since they won'y be updated until the next
       size_allocate */
    int child_y_diff = 0;
    this.get_allocation (out widget_alloc);
    this.bin_window.get_geometry (null, null, null, out bin_height);


    // OUT OF SIGHT {{{
    // If the bin_window, with the new vadjustment.value and the old
    // bin_y_diff is not in the viewport anymore at all...
    if (bin_y () + bin_height < 0 ||
        bin_y () > widget_alloc.height) {
      int estimated_widget_height = estimated_widget_height ();
      assert (estimated_widget_height > 0);
      int top_widget_index = (int)this._vadjustment.value / estimated_widget_height;
      assert (top_widget_index >= 0);

      int new_y_diff = (top_widget_index * estimated_widget_height);// - top_widget_y_diff;

      this.bin_y_diff = new_y_diff;

      remove_all_widgets ();

      message ("top_widget_index: %d", top_widget_index);
      this.model_from = top_widget_index;// - 1;
      //this.model_to  = model_from - 1; XXX
      this.model_to = model_from;
      message ("model_to: %d, model_from: %d", model_to, model_from);
      assert (model_from <= model_to);
      assert (model_from >= 0);
      assert (model_from < model.get_n_items ());
      assert (model_to < model.get_n_items ());


      // Fill the list again
      int cur_height = 0;
      while (cur_height < this.get_allocated_height () &&
             model_to < this.model.get_n_items ()) {
        model_to ++;
        Gtk.Widget new_widget = fill_func (model.get_object (model_to),
                                           get_old_widget ());
        int min;
        min = get_widget_height (new_widget);
        cur_height += min;
        this.insert_child_internal (new_widget, model_to - model_from);
      }
      configure_adjustment ();
      return;
    }
    // }}}

    // TOP {{{
    // Insert widgets at top
    while (bin_y () > 0 && model_from > 0) {
      var new_widget = fill_func (model.get_object (model_from - 1),
                                  get_old_widget ());
      assert (new_widget != null);
      model_from --;
      this.insert_child_internal (new_widget, 0);
      int min = get_widget_height (new_widget);
      this.bin_y_diff -= min;
      message ("bin_y_diff -= %d -> %d", min, bin_y_diff);
      child_y_diff += min;
    }

    if (bin_y () > 0) {
      this.bin_y_diff = (int)this._vadjustment.value;
    }
    assert (bin_y () <= 0);


    for (int i = 0; i < this.widgets.size; i ++) {
      Gtk.Allocation alloc;
      Gtk.Widget w = this.widgets.get (i);
      w.get_allocation (out alloc);
      if (bin_y () + alloc.y + child_y_diff + alloc.height < 0) {
        // Remove widget, resize and move bin_window
        bin_height -= alloc.height;
        this.bin_y_diff += alloc.height;
        message ("Removing widget with index %d: bin_y_diff += %d -> %d", i, alloc.height, bin_y_diff);
        child_y_diff -= alloc.height;
        this.remove_child_internal (w);
        model_from ++;
      }
      else break;
    }

    // }}}

    // BOTTOM {{{
    // Bottom of bin_window hangs into the widget
    while (bin_y () + bin_height <= widget_alloc.height &&
           model_to < (int)model.get_n_items () - 1) {
      var new_widget = fill_func (model.get_object (model_to + 1),
                                  get_old_widget ());
      assert (new_widget != null);
      this.insert_child_internal (new_widget, this.widgets.size);
      model_to ++;
      int min;
      min = get_widget_height (new_widget);
      bin_height += min;
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
        model_to --;
      } else
        break;
    }

    // }}}

    configure_adjustment ();


    // Maybe optimize this out if nothing changed?
    this.update_bin_window ();
    this.position_children ();

    //assert (bin_y () <= 0);
    assert (this.widgets.size == (model_to - model_from + 1));
    assert (model_to <= model.get_n_items () -1);
    assert (model_to >= 0);
    assert (model_from >= 0);
    assert (model_from <= model.get_n_items () - 1);
    assert (this.bin_y_diff >= 0);
    if (this._vadjustment.value == 0) {
      assert (this.bin_y_diff == 0);
      assert (this.model_from == 0);
      assert (bin_y () == 0);
    }
  }

  private void update_bin_window ()
  {
    Gtk.Allocation allocation;
    this.get_allocation (out allocation);

    int h = get_bin_height ();
    this.bin_window.move_resize (allocation.x,
                                 bin_y (),
                                 allocation.width,
                                 h);
  }

}

// Model stuff {{{
class ModelItem : GLib.Object {
  public string name;
  public int i;
  public ModelItem (string s, int i) { name = s; this.i = i;}
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
  public void set_num (int i) {
    this.set_size_request (-1, 4);
  }
}

// }}}


void clicked_cb () {
  message ("foobar");
}


/*

void main (string[] args) {
  Gtk.init (ref args);
  var w = new Gtk.Window ();
  w.delete_event.connect (() => {Gtk.main_quit (); return false;});
  var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
  var l = new ModelListBox ();
  l.vexpand = true;


  var store = new GLib.ListStore (typeof (ModelItem));
  n_widget_label = new Gtk.Label ("Foobar");
  height_label = new Gtk.Label ("zomg model");


  l.fill_func = (item, old) => {
    assert (item != null);

    ModelWidget b = (ModelWidget)old;
    if (old == null)
      b = new ModelWidget ();

    b.set_name (((ModelItem)item).name);
    b.set_num (((ModelItem)item).i);
    b.remove_button.clicked.connect (clicked_cb);
    if (((ModelItem)item).i == store.get_n_items () -1) {
      b.set_size_request (-1, 500);
    }
    b.show_all ();
    return b;
  };

  l.destroy_func = (_w) => {
    var b = (ModelWidget) _w;

    b.remove_button.clicked.disconnect (clicked_cb);
  };

  for (int i = 0; i < 20; i ++)
  //for (int i = 0; i < 200; i ++)
    store.append (new ModelItem ("NUMBER " + i.to_string (), i));


  l.set_model (store);

  var scroller = new Gtk.ScrolledWindow (null, null);

  // Add widget button {{{

  var hw = new Gtk.HeaderBar ();
  hw.show_close_button = true;
  w.set_titlebar (hw);

  var awb = new Gtk.Button.with_label ("Add widget");
  awb.clicked.connect (() => {
    //store.append (new ModelItem ("one more"));
                       assert (false);
  });

  box.add (awb);
  box.add (n_widget_label);
  box.add (height_label);

  var scb = new Gtk.Button.with_label ("Scroll up");
  scb.clicked.connect (() => {
    //scroller.get_vadjustment ().value += 100;
    scroller.get_vadjustment ().value = 0;
  });

  box.pack_end (scb, false, false);

  var sub = new Gtk.Button.with_label ("Scroll down");
  sub.clicked.connect (() => {
    scroller.get_vadjustment ().value = scroller.get_vadjustment ().upper -
                                        scroller.get_vadjustment ().page_size;
  });
  box.pack_end (sub, false, false);


  var bbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
  bbox.halign = Gtk.Align.CENTER;
  bbox.get_style_context ().add_class ("linked");
  var up = new Gtk.Button.from_icon_name ("pan-up-symbolic");
  up.clicked.connect (() => {
    scroller.get_vadjustment ().value --;
  });
  bbox.pack_start (up, false, true);

  var down= new Gtk.Button.from_icon_name ("pan-down-symbolic");
  down.clicked.connect (() => {
    scroller.get_vadjustment ().value ++;
  });
  bbox.pack_start (down, false, true);

  box.pack_end (bbox, false, false);



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

*/
