
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
    - Don't add too many widgets when setting the model
    - On Resize
  - Reuse widgets
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);


Gtk.Label n_widget_label;

class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gdk.Window bin_window;
  private GLib.ListModel model;
  public WidgetFillFunc? fill_func;
  private int bin_y_diff = 0;// distance between -vadjustment.value and bin_y

  private int model_from = 0;
  private int model_to   = 0;

  /* GtkScrollable properties  {{{ */
  private Gtk.Adjustment _vadjustment;
  public Gtk.Adjustment vadjustment {
    set {
      this._vadjustment = value;
      if (this._vadjustment != null) {
        configure_adjustment ();
        this._vadjustment.value_changed.connect (vadjustment_changed_cb);
      }
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
    //assert (model != null);
    //message ("MODEL:");
    //for (int i = 0; i < this.model.get_n_items (); i ++) {
      //message ("%d: %p", i, this.model.get_item (i));
    //}
    //message ("----------");
  }

  private void debug_print_widgets () {
    //message ("WIDGETS:");
    //for (int i = 0; i < this.widgets.size; i ++) {
      //message ("%d: %p", i, this.widgets.get (i));
    //}
    //message ("----------");
  }

  private Gtk.Widget? get_old_widget () {
    if (this.old_widgets.size == 0)
      return null;

    var w = this.old_widgets.get (0);
    this.old_widgets.remove (w);
    return w;
  }

  public void set_model (GLib.ListModel model) {
    this.model = model;
    // Add already existing widgets
    for (int i = 0; i < model.get_n_items (); i ++) {
      var w = fill_func (model.get_object (i), null);

      insert_child_internal (w, i);
    }

    // XXX Remove this
    this.model_from = 0;
    this.model_to = (int)model.get_n_items () - 1;

    this.debug_print_widgets ();
    this.debug_print_model ();

    model.items_changed.connect ((position, removed, added) => {
      int index = (int)position - 1;
      //message ("items changed! index: %d, removed: %u, added: %u", index, removed, added);

      var item = model.get_object (position);
      for (int i = 0; i < removed; i ++) {
        // XXX cache these
        widgets.remove_at ((int)position);
      }

      for (int i = 0; i < added; i ++) {
        var widget = fill_func (item, get_old_widget ());
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
    n_widget_label.label = "Widgets: " + this.widgets.size.to_string ()
                           + " (" + this.old_widgets.size.to_string () + ")";
  }

  private void remove_child_internal (Gtk.Widget widget) {
    assert (widget.parent == this);
    assert (widget.get_parent_window () == this.bin_window);

    this.widgets.remove (widget);
    widget.unparent ();
    this.old_widgets.add (widget);
    n_widget_label.label = "Widgets: " + this.widgets.size.to_string ()
                           + " (" + this.old_widgets.size.to_string () + ")";
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
  public override bool draw (Cairo.Context ct) {
    Gtk.Allocation alloc;
    this.get_allocation (out alloc);

    // Draw the bin_window on the widget window
    ct.set_source_rgba (0.1, 0.1, 0.1, 0.4);
    ct.rectangle (0, 0, this.bin_window.get_width (), this.bin_window.get_height ());
    ct.fill ();

    if (Gtk.cairo_should_draw_window (ct, this.bin_window)) {
      ct.set_source_rgba (1.0, 0.0, 0.0, 0.2);
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

    if (this.get_realized ()) {
      this.get_window ().move_resize (allocation.x,
                                      allocation.y,
                                      allocation.width,
                                      allocation.height);

      int new_y = allocation.y - (int) this._vadjustment.value + this.bin_y_diff;
      int h = 0;
      foreach (var w in widgets) {
        h += w.get_allocated_height ();
      }


      // XXX Resizing the window/widget
      //if (this._vadjustment.value >=
          //this._vadjustment.upper - this._vadjustment.page_size) {
        //new_y = allocation.y - (h - allocation.height);
        //this.bin_y_diff = new_y - (int)this._vadjustment.value;
        //this.bin_y_diff = allocation.height - h;
      //}

      this.bin_window.move_resize (allocation.x,
                                   new_y,
                                   allocation.width,
                                   h);
                                   //new_height);
    }

    configure_adjustment ();
    vadjustment_changed_cb ();

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
    int average_widget_height = 0;
    foreach (var w in this.widgets) {
      average_widget_height += w.get_allocated_height ();
    }
    average_widget_height /= this.widgets.size;

    int estimated_list_height = (int)this.model.get_n_items () * average_widget_height;

    this._vadjustment.configure (this._vadjustment.value, // value,
                                 0, // lower
                                 //h, // Upper
                                 estimated_list_height,
                                 0, //step increment
                                 0, // page increment
                                 this.get_allocated_height ()); // page_size
  }

  private void vadjustment_changed_cb () {
    message ("Checking with %d", this.get_allocated_height ());
    int bin_y;
    int bin_height;
    Gtk.Allocation widget_alloc;
    this.get_allocation (out widget_alloc);
    this.bin_window.get_geometry (null, out bin_y, null, out bin_height);

    if (-this._vadjustment.value + this.bin_y_diff > 0) {
      //message ("Adding new widget with index %d", model_from - 1);
      while (-this._vadjustment.value + this.bin_y_diff > 0) {
        var new_widget = fill_func (model.get_object (model_from - 1),
                                    get_old_widget ());
        model_from --;
        //message ("%d: Adding widget, new model_from: %d", n_call, model_from);
        this.insert_child_internal (new_widget, 0);
        Gtk.Allocation a;
        new_widget.get_allocation (out a);
        int nat, min;
        new_widget.get_preferred_height_for_width (this.get_allocated_width (),
                                                   out min,
                                                   out nat);
        this.bin_y_diff -= min;
      }

      assert (this.widgets.size == (model_to - model_from + 1));
    } else {
      for (int widget_index = 0; widget_index < this.widgets.size; widget_index ++) {
        Gtk.Allocation alloc;
        Gtk.Widget w = this.widgets.get (widget_index);
        w.get_allocation (out alloc);
        if (bin_y + alloc.y + alloc.height < 0) {
          // Remove widget, resize and move bin_window
          this.remove_child_internal (w);
          this.bin_y_diff += alloc.height;
          //widget_index --;
          model_from ++;
          //message ("%d: Removing widget, new model_from: %d", n_call, model_from);
        }
        else break;
      }
    }


    // Same at the bottom
    if (-this._vadjustment.value + this.bin_y_diff + bin_height < widget_alloc.height) {
      // Add Widgets
    } else if (this.get_allocated_height () > 300) {
      // XXX This gets called before the container has its final size, i.e. the allocated
      //     height is pretty small and we remove a lot of widgets unnecessarily. What to do?
      // remove widgets
      for (int i = this.widgets.size - 1; i >= 0; i --) {
        Gtk.Allocation alloc;
        var w = this.widgets.get (i);
        w.get_allocation (out alloc);


        // XXX WRONG
        if (-this._vadjustment.value + this.bin_y_diff + alloc.y > this.get_allocated_height ()) {
          message ("Remove bottom widget, alloc.y: %d", alloc.y);
          this.remove_child_internal (w);
          model_to --;
        } else
          break;
      }
    }



    this.queue_resize (); // XXX needed?!


    //assert (bin_height >= this.get_allocated_height ());
    assert (this.widgets.size + this.old_widgets.size == model.get_n_items ());
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
    this.opacity = 0.3;
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


  l.fill_func = (item, old) => {
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

  for (int i = 0; i < 20; i ++)
    store.append (new ModelItem ("NUMBER " + i.to_string ()));

  l.set_model (store);


  // Add widget button {{{
  var awb = new Gtk.Button.with_label ("Add widget");
  awb.clicked.connect (() => {
    store.append (new ModelItem ("one more"));
  });
  box.add (awb);

  box.add (n_widget_label);

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
