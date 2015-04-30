
/*
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
        this._vadjustment.value_changed.connect (vadjustment_changed_cb);
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

    this.pre_fill ();
    update_model_label ();

    model.items_changed.connect ((position, removed, added) => {
      int index = (int)position - 1;
      //message ("items changed! index: %d, removed: %u, added: %u", index, removed, added);

      var item = model.get_object (position);
      for (int i = 0; i < removed; i ++) {
        // XXX cache these
        assert (false);
      }

      for (int i = 0; i < added; i ++) {
        var widget = fill_func (item, get_old_widget ());
        insert_child_internal (widget, index + 1);
      }

      this.queue_resize ();
    });

  }

  private void insert_child_internal (Gtk.Widget widget, int index) {
    widget.set_parent_window (this.bin_window);
    widget.set_parent (this);
    this.widgets.insert (index, widget);
    //n_widget_label.label = "Widgets: " + this.widgets.size.to_string ()
                           //+ " (" + this.old_widgets.size.to_string () + ")";
  }



  private void remove_child_internal2 (Gtk.Widget widget) {
    assert (widget.parent == this);
    assert (widget.get_parent_window () == this.bin_window);

    this.widgets.remove (widget);
    widget.unparent ();
    this.old_widgets.add (widget);
    //n_widget_label.label = "Widgets: " + this.widgets.size.to_string ()
                           //+ " (" + this.old_widgets.size.to_string () + ")";
  }

  private void remove_child_internal (Gtk.Widget widget) {
    assert (widget.parent == this);
    assert (widget.get_parent_window () == this.bin_window);

    this.widgets.remove (widget);
    widget.unparent ();
    this.old_widgets.add (widget);
    //n_widget_label.label = "Widgets: " + this.widgets.size.to_string ()
                           //+ " (" + this.old_widgets.size.to_string () + ")";
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
    //Gtk.Allocation alloc;
    //this.get_allocation (out alloc);

    // XXX Draw background

    if (Gtk.cairo_should_draw_window (ct, this.bin_window)) {
      foreach (var child in widgets) {
        this.propagate_draw (child, ct);
      }
    }


    Gtk.Allocation widget_alloc;
    this.get_allocation (out widget_alloc);


    foreach (var w in widgets) {
      Gtk.Allocation alloc;
      w.get_allocation (out alloc);
      int widget_y = widget_alloc.y - (int)this._vadjustment.value + this.bin_y_diff + alloc.y;
      //message ("widget y: %d", widget_y);
      if (widget_y > this.get_allocated_height ()) {
        ct.set_source_rgba (1, 0, 0, 1);
      } else {
        ct.set_source_rgba (0, 1, 0, 1);
      }

      ct.rectangle (0, widget_y, 1000, 2);
      ct.fill ();
    }


    // XXX This is in widget coordinates, i.e. should always be <= 0
    //int inv_part = alloc.y - (int)this._vadjustment.value + this.bin_y_diff;
    //message
    //assert (inv_part <= 0);

    //int bin_height;
    //this.bin_window.get_geometry (null, null, null, out bin_height);

    //ct.set_source_rgba (0, 0, 1, 1);
    //ct.rectangle (0, 0, 600, inv_part + bin_height);
    //ct.fill ();

    return false;
  }

  public override void size_allocate (Gtk.Allocation allocation)
  {
    message ("size_allocate");
    Gtk.Allocation child_allocation = {0};
    int imp;

    this.set_allocation (allocation);
    int y = allocation.y;
    child_allocation.x = 0;
    child_allocation.width = allocation.width;

    //message ("Using and positioning %d widgets", this.widgets.size);

    foreach (Gtk.Widget child in this.widgets) {
      child.get_preferred_height (out child_allocation.height, out imp);
      child_allocation.y = y;
      child.size_allocate (child_allocation);
      y += child_allocation.height;
    }

    if (this.get_realized ()) {
      this.get_window ().move_resize (allocation.x,
                                      allocation.y,
                                      allocation.width,
                                      allocation.height);
      this.update_bin_window ();
    }

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
      //message ("min: %d", min);
      assert (min == 34);
      //h += w.get_allocated_height ();
      //if (p)
        //message ("   += %d", w.get_allocated_height ());
      //assert (w.get_allocated_height () == 34);
    }

    assert (h >= 0);
    return h;
  }

  private void vadjustment_changed_cb ()
  {
    //message ("adjustment changed: %f", this._vadjustment.value);
    int bin_y;
    int bin_height;
    Gtk.Allocation widget_alloc;
    this.get_allocation (out widget_alloc);
    this.bin_window.get_geometry (null, out bin_y, null, out bin_height);



    // XXX Changes bin_y_diff and possibly bin_window's size
    // {{{
    //if (-this._vadjustment.value + this.bin_y_diff > 0) {
      while (-this._vadjustment.value + this.bin_y_diff > 0 &&
             model_from > 0) {
        var new_widget = fill_func (model.get_object (model_from - 1),
                                    get_old_widget ());
        assert (new_widget != null);
        model_from --;
        update_model_label ();
        this.insert_child_internal (new_widget, 0);
        int nat, min;
        new_widget.get_preferred_height_for_width (this.get_allocated_width (),
                                                   out min,
                                                   out nat);
        this.bin_y_diff -= min;
      }

    //} else {
      for (int widget_index = 0; widget_index < this.widgets.size; widget_index ++) {
        Gtk.Allocation alloc;
        Gtk.Widget w = this.widgets.get (widget_index);
        w.get_allocation (out alloc);
        if (bin_y + alloc.y + alloc.height < 0) {
          // Remove widget, resize and move bin_window
          bin_height -= alloc.height;
          this.bin_y_diff += alloc.height;
          this.remove_child_internal2 (w);
          //widget_index --;
          model_from ++;
          update_model_label ();
        }
        else break;
      }
    //}
    // }}}

    //bin_height = get_bin_height (true);

    // Bottom of bin_window hangs into the widget
    //if (-this._vadjustment.value + this.bin_y_diff + bin_height <= widget_alloc.height) {
      //message ("Adding to the %d widgets", this.widgets.size);
      // Add Widgets
      //int i = 0;
      while (-this._vadjustment.value + this.bin_y_diff + bin_height <= widget_alloc.height &&
             model_to < (int)model.get_n_items () - 1) {
        var new_widget = fill_func (model.get_object (model_to + 1),
                                    get_old_widget ());
        assert (new_widget != null);
        this.insert_child_internal (new_widget, this.widgets.size);
        model_to ++;
        update_model_label ();
        int nat, min;
        new_widget.get_preferred_height_for_width (this.get_allocated_width (),
                                                   out min,
                                                   out nat);
        //message ("Adding widget at bottom for index %d", model_to1);
        //message ("bin_height += %d", min);
        bin_height += min;
        //i ++;
      }
      //message ("Added %d widgets at bottom", i);
    //} else {
      // remove widgets
      for (int i = this.widgets.size - 1; i >= 0; i --) {
        Gtk.Allocation alloc;
        var w = this.widgets.get (i);
        w.get_allocation (out alloc);

        // The widget's y in the lists' coordinates
        int widget_y = widget_alloc.y - (int)this._vadjustment.value + this.bin_y_diff + alloc.y;
        if (widget_y > this.get_allocated_height ()) {
          //assert (false);
          message ("Removin child %p because widget_y is %d and the list's allocated height is %d", w,
                   widget_y, this.get_allocated_height ());
          this.remove_child_internal (w);
          model_to --;
          update_model_label ();
        } else
          break;
      }
    //}


    // Maybe optimize this out if nothing changed?
    this.update_bin_window ();

    //this.queue_resize (); // XXX needed?!
    this.queue_draw ();

    assert (this.widgets.size == (model_to - model_from + 1));
  }

  private void update_bin_window ()
  {
    Gtk.Allocation allocation;
    this.get_allocation (out allocation);

    int new_y = allocation.y - (int) this._vadjustment.value + this.bin_y_diff;

    this.bin_window.move_resize (allocation.x,
                                 new_y,
                                 allocation.width,
                                 get_bin_height ());
  }

  private void update_model_label ()
  {
    model_label.label = "Model: %d -- %d".printf (model_from, model_to);
  }

  private void pre_fill ()
  {
    // XXX Useless?
    int new_list_height = 0;
    int widget_height = this.get_allocated_height ();

    while (new_list_height < widget_height &&
           model_to < (int)model.get_n_items () - 1) {

      var new_widget = fill_func (model.get_object (model_to + 1),
                                  get_old_widget ());
      assert (new_widget != null);
      this.insert_child_internal (new_widget, this.widgets.size);
      this.model_to ++;
      update_model_label ();
      int nat, min;
      new_widget.get_preferred_height_for_width (this.get_allocated_width (),
                                                 out min,
                                                 out nat);
      new_list_height += min;

      assert (this.widgets.size == (model_to - model_from + 1));
    }

    this.queue_resize ();
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

  for (int i = 0; i < 200; i ++)
  //for (int i = 0; i < 200000; i ++)
    store.append (new ModelItem ("NUMBER " + i.to_string ()));

  l.set_model (store);


  // Add widget button {{{
  var awb = new Gtk.Button.with_label ("Add widget");
  awb.clicked.connect (() => {
    store.append (new ModelItem ("one more"));
  });

  //box.add (awb);
  //box.add (n_widget_label);
  //box.add (model_label);

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
