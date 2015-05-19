
/*
   == TODO LIST ==
   - Test complex widgets!
   - Revealer in Widget (Should work already?)
   - value animation is broken if upper changes during it.
     Might need changes in gtkadjustment.c (_scroll_to_value)
   - Port to C
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);


class ModelListBox : Gtk.Container, Gtk.Scrollable {
  private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
  private Gdk.Window bin_window;
  private GLib.ListModel model;
  public WidgetFillFunc fill_func;
  private int bin_y_diff = 0;// distance between -vadjustment.value and bin_y

  private int _model_from = 0;
  private int _model_to   = -1;
  // We need this in case this,widgets is empty
  // but we still need to estimated their height
  private int last_valid_widget_height = 1;

  /* GtkScrollable properties  {{{ */
  private Gtk.Adjustment _vadjustment;
  public Gtk.Adjustment vadjustment {
    set {
      this._vadjustment = value;
      if (this._vadjustment != null) {
        this._vadjustment.value_changed.connect (ensure_visible_widgets);
        configure_adjustment ();
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

  /* Debugging Poperties {{{ */
  private uint _max_widgets = 0;
  public uint max_widgets {
    get {
      return _max_widgets;
    }
    set {
      _max_widgets = value;
    }
  }

  private uint _cur_widgets = 0;
  public uint cur_widgets {
    get {
      return _cur_widgets;
    }
    private set {
      //assert (false);
      this._cur_widgets = value;
    }
  }

  public int model_from {
    get {
      return this._model_from;
    }
    private set {
      this._model_from = value;
    }
  }

  public int model_to {
    get {
      return this._model_to;
    }
    private set {
      this._model_to = value;
    }
  }

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
    if (this.model != null) {
      this.model.items_changed.disconnect (items_changed_cb);
    }

    this.model = model;
    this.model.items_changed.connect (items_changed_cb);
    this.queue_resize ();
  }


  private void remove_visible_widgets (int pos, int count)
  {
    // Remove the specified amount of widgets,
    // moving all of the below widgets down and
    // adjusting model_to/model_from accordingly
    model_to -= count;
    int removed_height = 0;
    for (int i = 0; i < count; i ++) {
      int index = pos + i;
      removed_height += get_widget_height (this.widgets.get (index));
      this.widgets.remove_at (index);
      //i --;
    }

    // Move the tail up
    this.position_children ();
  }

  public void insert_visible_widgets (int pos, int count)
  {
    // We need to kill all of the widgets below the inserted ones,
    // since their index gets invalidated by the insertion.

    this.model_to -= this.widgets.size - pos;

    // delete all after the insertion point
    for (int i = pos; i < this.widgets.size; i ++) {
      this.remove_child_internal (this.widgets.get (pos));
      i --;
    }
    this.position_children ();

  }


  private void items_changed_cb (uint position, uint removed, uint added)
  {
    message ("ITEMS CHANGED. position: %u, removed: %u, added: %u",
             position, removed, added);
    // XXX use added/removed for the calculation here!
    /* We need to (try to) keep vadjustment.value the same,
       i.e. if the value was e.g. 0 before and thus displayed
       the first row, it also has to stay 0 after.
     */


    /*

       1) `position` is alreay in the viewport:
           - model_to += net_size
           - remove `net_size` items, beginning from `position`
           - add more items at the bottom until bin_window is big enough
     */

    int net_size = (int)added - (int)removed;
    uint impact = (int)position + (int)added - (int)removed;



    if (position >= model_from &&
        position <= model_to) {
      // we need to do extra work to change some visible widgets

      int widget_pos = (int)position - model_from;

      // XXX These 2 can have special measures for cases,
      //     e.g. the 2nd call might not have to kill all the widgets
      this.remove_visible_widgets (widget_pos, (int)removed);
      this.insert_visible_widgets (widget_pos, (int)added);
      // XXX We need to call update_bin_window just to make
      //     ensure_visible_widgets actually add widgets at the end
      //     of the list (see the condition there). Maybe just change
      //    the condition?
      this.update_bin_window ();
      this.ensure_visible_widgets ();

    } else if (position < model_from) {
      // Can still reach into the viewport
      model_from += net_size;
      model_to   += net_size;
    } else {
      // Everything's fine, basically.
      message ("changed item is invisible");
    }
    configure_adjustment ();
  }

  public override void map ()
  {
    base.map ();
    ensure_visible_widgets ();
  }

  private void insert_child_internal (Gtk.Widget widget, int index)
  {
    widget.set_parent_window (this.bin_window);
    widget.set_parent (this);
    this.widgets.insert (index, widget);


    this.cur_widgets = this.widgets.size;
  }

  private void remove_child_internal (Gtk.Widget widget)
  {
    assert (widget.parent == this);
    assert (widget.get_parent_window () == this.bin_window);
    assert (this.widgets.contains (widget));

    this.widgets.remove (widget);
    widget.unparent ();
    this.old_widgets.add (widget);

    if (old_widgets.size > _max_widgets)
      this.max_widgets = old_widgets.size;

    this.cur_widgets = this.widgets.size;
  }

  private void remove_all_widgets ()
  {
    for (int i = this.widgets.size - 1; i >= 0; i --) {
      this.remove_child_internal (this.widgets.get (i));
    }

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



  private inline int get_widget_height (Gtk.Widget w)
  {
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
        average_widget_height += get_widget_height (w);
      }
      average_widget_height /= this.widgets.size;

      this.last_valid_widget_height = average_widget_height;
    } else
      average_widget_height = this.last_valid_widget_height;

    return average_widget_height;
  }

  /* We use the exact height of the shown widgets PLUS the estimated widget height (which we get from the
   * shown widgets) for all the invisible rows */
  private int estimated_list_height (out int top_part = null)
  {
    int widget_height = estimated_widget_height ();

    assert (widget_height >= 0);
    assert (model_from >= 0);

    if (this.model == null) {
      top_part = 0;
      return 0;
    }

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

    assert (top_part >= 0);

    return exact_height +
           top_widgets * widget_height +
           bottom_widgets * widget_height;
  }

  private void configure_adjustment ()
  {
    int top_widgets_height;
    int list_height = estimated_list_height (out top_widgets_height);

    double new_value = this._vadjustment.value;
    if (this._vadjustment.upper != list_height) {
      int c = bin_y ();
      assert (c <= 0);
      new_value = top_widgets_height - c; // XXX int?
      this.bin_y_diff = top_widgets_height;
      assert (-new_value + bin_y_diff <= 0);
    }

    this._vadjustment.configure (new_value,                     // value,
                                 0,                             // lower
                                 list_height,                   // Upper
                                 1,                             // step increment
                                 2,                             // page increment
                                 this.get_allocated_height ()); // page_size
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
    if (!this.get_mapped () ||
        this.model == null)
      return;


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
      //if (estimated_widget_height <= 0)
        //message ("F: %d", estimated_widget_height);
      assert (estimated_widget_height >= 0);
      int top_widget_index = (int)this._vadjustment.value / estimated_widget_height;
      assert (top_widget_index >= 0);

      int new_y_diff = (top_widget_index * estimated_widget_height);// - top_widget_y_diff;

      this.bin_y_diff = new_y_diff;

      remove_all_widgets ();

      //message ("top_widget_index: %d", top_widget_index);
      this.model_from = top_widget_index;// - 1;
      this.model_to  = model_from - 1;

      //if (model_to >= model.get_n_items ()) {
        //message ("model_from: %d", model_from);
        //message ("model_to: %d", model_to);
      //}
      //message ("model_to: %d, model_from: %d", model_to, model_from);
      assert (model_from >= 0);
      assert (model_from < model.get_n_items ());
      assert (model_to < (int)model.get_n_items ());


      // Fill the list again
      int cur_height = 0;
      int widgets_added = 0;
      while (cur_height < this.get_allocated_height () &&
             model_to < (int)this.model.get_n_items () - 1) {
        model_to ++;
        //message ("model_to:
        assert (model_to < this.model.get_n_items ());
        Gtk.Widget new_widget = fill_func (model.get_object (model_to),
                                           get_old_widget ());
        assert (new_widget != null);
        int min;
        min = get_widget_height (new_widget);
        cur_height += min;
        this.insert_child_internal (new_widget, model_to - model_from);
        widgets_added ++;
      }

      assert (widgets_added > 0);

      // This should definitely be true after that loop
      assert (model_from <= model_to);

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
      //message ("bin_y_diff -= %d -> %d", min, bin_y_diff);
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
      int w_height = get_widget_height (w);
      if (bin_y () + alloc.y + child_y_diff + w_height < 0) {
        // Remove widget, resize and move bin_window
        bin_height -= w_height;
        this.bin_y_diff += w_height;
        //message ("Removing widget with index %d: bin_y_diff += %d -> %d", i, w_height, bin_y_diff);
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
      //if (model_from != 0)
        //message ("model_from: %d", model_from);
      assert (this.model_from == 0);
      assert (bin_y () == 0);
    }


    int h;
    this.bin_window.get_geometry (null, null, null, out h);
    if (h != get_bin_height ()) {
      message ("%d != %d", h, this.get_bin_height ());
    }
    assert (h == this.get_bin_height ());
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
