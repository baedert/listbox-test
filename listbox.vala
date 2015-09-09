// vim: set noexpandtab tabstop=4 shiftwidth=4 softtabstop=4:

/*
	 == TODO LIST ==
	 - Fix all XXX
	 - Port to C
	 - kinetic scrolling doesn't seem to work
	   in the 'easy' test case
 */


inline uint max (uint a, uint b)
{
	return (a > b) ? a : b;
}

inline int maxi (int a, int b)
{
	return (a > b) ? a : b;
}

inline double maxd (double a, double b)
{
	return (a > b) ? a : b;
}

inline double mind (double a, double b)
{
	return a < b ? a : b;
}


delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);


class ModelListBox : Gtk.Container, Gtk.Scrollable {
	private Gee.ArrayList<Gtk.Widget> widgets     = new Gee.ArrayList<Gtk.Widget> ();
	private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
	private Gdk.Window bin_window;
	private GLib.ListModel model;
	public WidgetFillFunc fill_func;
	private double _bin_y_diff = 0; // distance between -vadjustment.value and bin_y
	public double bin_y_diff {
		get {
			return this._bin_y_diff;
		}
		set {
			message ("Setting bin_y_diff from %f to %f. bin_y now: %f", this._bin_y_diff, value,
			         - this._vadjustment.value + value);
			this._bin_y_diff = value;
		}
	}

	private uint _model_from = 0;
	private uint _model_to   = 0;

	// We need this in case this.widgets is empty
	// but we still need to estimate their height
	private int last_valid_widget_height = 1;

	/* GtkScrollable properties	{{{ */
	private Gtk.Adjustment? _vadjustment;
	public Gtk.Adjustment? vadjustment {
		set {
			/* TODO: Disconnect from the old adjustment */
			this._vadjustment = value;
			if (this._vadjustment != null) {
				this._vadjustment.value_changed.connect (adjustment_value_changed_cb);
				this._vadjustment.notify["page-size"].connect (page_size_changed_cb);
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


	private uint _cur_widgets = 0;
	public uint cur_widgets {
		get {
			return _cur_widgets;
		}
		private set {
			this._cur_widgets = value;
		}
	}

	public uint model_from {
		get {
			return this._model_from;
		}
		private set {
			this._model_from = value;
		}
	}

	public uint model_to {
		get {
			return this._model_to;
		}
		private set {
			this._model_to = value;
		}
	}

	private uint _estimated_height = 0;
	public uint estimated_height {
		get {
			return _estimated_height;
		}
		set {
			this._estimated_height = value;
		}
	}

	public int cached_widgets {
		get {
			return this.old_widgets.size;
		}
	}

	public int total_widgets {
		get {
			return this.old_widgets.size + this.widgets.size;
		}
	}

	/* }}} */


	construct
	{
		this.get_style_context ().add_class ("list");
	}

	private void adjustment_value_changed_cb ()
	{
		this.ensure_visible_widgets (false);
	}

	private void set_value (double v)
	{
		double max = this._vadjustment.upper -
		             this._vadjustment.page_size;

		message ("Setting value to %f from %f (max %f)", v, this._vadjustment.value, max);
		this.block = true;
		this._vadjustment.value = v;
		this.block = false;
	}

	private Gtk.Widget get_widget (uint index)
	{
		var item = model.get_object (index);
		assert (item != null);

		Gtk.Widget? old_widget = null;
		if (this.old_widgets.size > 0) {
			old_widget = this.old_widgets.get (this.old_widgets.size - 1);
			this.old_widgets.remove (old_widget);
		}


		Gtk.Widget new_widget = fill_func (item, old_widget);
		/*
		 * We just enforce visibility here. If a row should be invisible, it just
		 * shouldn't be part of the model at all (i.e. filtered out).
		 */
		new_widget.show ();

		return new_widget;
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


	private inline bool bin_window_full () {
		int bin_height;
		if (this.get_realized ())
			bin_height = this.bin_window.get_height ();
		else
			bin_height = 0;

		int widget_height = this.get_allocated_height ();

		/* The bin window is full if either the bottom of it is not visible OR
		   it already contains all the rows from the model.
		 */
		return (bin_y () + bin_height > widget_height) ||
		       (this.model_to - this.model_from == this.model.get_n_items ());
	}

	private void page_size_changed_cb ()
	{
		if (!this.get_mapped ())
			return;

		double max_value = this._vadjustment.upper - this._vadjustment.page_size;

		if (this._vadjustment.value > max_value) {
			//message ("New Value: %f", max_value);
			this.set_value (max_value);
			//this._vadjustment.value = max_value;
		}

		this.configure_adjustment ();
		/*
		 * We do *not* call ensure_visible_widgets here
		 * and instead do it in size-allocate.
		 */
	}

	private void items_changed_cb (uint position, uint removed, uint added)
	{
		message ("ITEMS CHANGED. position: %u, removed: %u, added: %u, model_size: %u, model_from: %u,
		         model_to: %u",
		         position, removed, added, model.get_n_items (), model_from, model_to);

		if (position >= model_to &&
		    bin_window_full ()) {

			if (this._vadjustment == null)
				this.queue_resize ();
			else
				this.configure_adjustment ();

			return;
		}

		/*
		 * We are just removing all visible widgets and add them again.
		 * Quite some potential for optimization here.
		 */
		this.remove_all_widgets ();
		this.model_to = this.model_from;
		this.update_bin_window ();
		message ("From items-changed");
		this.ensure_visible_widgets (true);

		if (this._vadjustment == null)
			this.queue_resize ();
	}

	public override void map ()
	{
		base.map ();
		/* TODO: Check whether this is really necessary.
		         We already call ensure_visible_widgets in
		         size_allocate.
		*/
		message ("from map");
		ensure_visible_widgets ();
	}

	private void insert_child_internal (Gtk.Widget widget, int index)
	{
		widget.set_parent_window (this.bin_window);
		widget.set_parent (this);
		this.widgets.insert (index, widget);

		// DEBUG
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

		// DEBUG
		this.cur_widgets = this.widgets.size;
	}

	private void remove_all_widgets ()
	{
		/* XXX This will actually remove them, but in most cases we might want
		   to not *actually* remove all the widgets and we will directly
		   add them again to the list (but in a different order?).

		   Could be faster if we had an intermediate list of widgets we want
		   to add again shortly but in a differrent order?
		 */
		message ("Removing all widgets");
		for (int i = this.widgets.size - 1; i >= 0; i --)
			this.remove_child_internal (this.widgets.get (i));
	}

	/* GtkContainer API {{{ */
	public override void add (Gtk.Widget child) { assert (false); }

	public override void forall_internal (bool         include_internals,
	                                      Gtk.Callback callback) {
		foreach (var child in this.widgets) {
			callback (child);
		}
	}

	public override void remove (Gtk.Widget w) {
		assert (w.get_parent () == this);
	}

	public override GLib.Type child_type () {
		return typeof (Gtk.Widget);
		//return typeof (Gtk.ListBoxRow);
	}
	/* }}} */

	/* GtkWidget API {{{ */

	public override bool draw (Cairo.Context ct)
	{
		var sc = this.get_style_context ();
		Gtk.Allocation alloc;
		this.get_allocation (out alloc);

		/* XXX In case of e.g. a background gradient, we technically have
		 *     to use the estimated height... */
		sc.render_background (ct, 0, 0, alloc.width, alloc.height);
		sc.render_frame      (ct, 0, 0, alloc.width, alloc.height);

		if (Gtk.cairo_should_draw_window (ct, this.bin_window)) {
			foreach (var child in widgets) {
				this.propagate_draw (child, ct);
			}
		}

		return Gdk.EVENT_PROPAGATE;
	}

	public override void size_allocate (Gtk.Allocation allocation)
	{
		bool height_changed = allocation.height != this.get_allocated_height ();
		this.set_allocation (allocation);
		position_children ();

		if (this.get_realized ()) {
			assert (this.get_window () != null);
			assert (this.bin_window != null);
			this.get_window ().move_resize (allocation.x,
			                                allocation.y,
			                                allocation.width,
			                                allocation.height);
			this.update_bin_window ();
		}

		if (!bin_window_full () && height_changed) {
			message ("from size-allocate");
			this.ensure_visible_widgets ();
		}

		if (this._vadjustment != null)
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

		attr.height = 1;
		this.bin_window = new Gdk.Window (this.get_window (),
		                                  attr,
		                                  attr_types);
		this.register_window (this.bin_window);

		this.bin_window.show ();

		foreach (var w in widgets)
			w.set_parent_window (this.bin_window);
	}

	public override void get_preferred_width (out int minimal,
	                                          out int natural)
	{
		/* Take the minimal width of all the children
		 * See the no-scroll demo for an example where this
		 * currently breaks. */

		minimal = 0;
		natural = 0;
	}

	public override void get_preferred_height (out int minimal,
	                                           out int natural)
	{
		if (this._vadjustment == null) {
			int h = 0;
			foreach (var w in widgets)
				h += this.get_widget_height (w);

			minimal = h;
			natural = h;

		} else {
			// Doesn't matter, we're in a scrolledwindow anyway.
			minimal = 0;
			natural = 0;
		}
	}
	/* }}} */



	private void position_children ()
	{
		Gtk.Allocation allocation;
		Gtk.Allocation child_allocation = {0};
		int imp;

		this.get_allocation (out allocation);

		int y = 0;
		if (this._vadjustment != null)
			y = allocation.y;

		child_allocation.x = 0;
		if (allocation.width > 0)
			child_allocation.width = allocation.width;
		else
			child_allocation.width = 1;

		foreach (Gtk.Widget child in this.widgets) {
			child.get_preferred_height_for_width (this.get_allocated_width (),
			                                      out child_allocation.height,
			                                      out imp);
			child.get_preferred_width_for_height (child_allocation.height,
			                                      out child_allocation.width,
			                                      out imp);

			child_allocation.width = maxi (child_allocation.width, this.get_allocated_width ());
			assert (child_allocation.width  >= 0);
			assert (child_allocation.height >= 0);
			child_allocation.y = y;
			child.size_allocate (child_allocation);
			y += child_allocation.height;
		}
	}




	private inline int get_widget_height (Gtk.Widget w)
	{
		int min, nat;
		w.get_preferred_height_for_width (this.get_allocated_width (),
		                                  out min,
		                                  out nat);

		if (w.visible)
			assert (min >= 1);
		else
			assert (min == 0);

		return min;
	}

	private inline int estimated_widget_height ()
	{
		int average_widget_height = 0;
		int used_widgets = 0;

		foreach (var w in this.widgets) {
			if (w.visible) {
				average_widget_height += get_widget_height (w);
				used_widgets ++;
			}
		}

		if (used_widgets > 0)
			average_widget_height /= used_widgets;
		else
			average_widget_height = this.last_valid_widget_height;

		this.last_valid_widget_height = average_widget_height;

		return average_widget_height;
	}

	private uint estimated_list_height (out uint top_part     = null,
	                                   out uint bottom_part  = null,
	                                   out uint widgets_part = null)
	{
		if (GLib.unlikely (this.model == null)) {
			top_part = 0;
			bottom_part = 0;
			widgets_part = 0;
			return 0;
		}

		int widget_height = estimated_widget_height ();

		assert (widget_height >= 0);
		assert (model_from >= 0);

		uint top_widgets    = model_from;
		uint bottom_widgets = this.model.get_n_items () - model_to;

		assert (top_widgets >= 0);
		assert (bottom_widgets >= 0);

		assert (top_widgets + bottom_widgets + this.widgets.size == this.model.get_n_items ());

		int exact_height = 0;
		foreach (var w in this.widgets) {
			int h = get_widget_height (w);
			exact_height += h;
		}

		assert (exact_height >= 0);

		top_part     = top_widgets    * widget_height;
		bottom_part  = bottom_widgets * widget_height;
		widgets_part = exact_height;

		assert (top_part >= 0);
		assert (bottom_part >= 0);
		assert (widgets_part >= 0);

		uint h = top_part + bottom_part + widgets_part;

		//int min_list_height = (int)this._vadjustment.value
							  //+ bin_y ()
							  //+ widgets_part;

		//h = (int) max (h, min_list_height);

		// DEBUG
		this.estimated_height = h;

		return h;
	}

	private void update_bin_window (int new_bin_height  = -1)
	{
		Gtk.Allocation allocation;
		this.get_allocation (out allocation);

		int h = (new_bin_height == -1 ? 0 : new_bin_height);

		if (new_bin_height == -1) {
			int min;
			foreach (var w in this.widgets) {
				min = get_widget_height (w);
				assert (min >= 0);
				h += min;
			}
		}

		if (h == 0)
			h = 1;

		if (h != this.bin_window.get_height () ||
		    allocation.width != this.bin_window.get_width ()) {

			this.bin_window.move_resize (0,
			                             bin_y (),
			                             allocation.width,
			                             h);

		} else {
			this.bin_window.move (0, bin_y ());
		}
	}

	bool block = false;

	private void configure_adjustment ()
	{
		int widget_height = this.get_allocated_height ();
		uint list_height = estimated_list_height ();

		if ((int)this._vadjustment.upper != max (list_height, widget_height)) {
			this._vadjustment.upper = max (list_height, widget_height);
		} else if (list_height == 0) {
			this._vadjustment.upper = widget_height;
		}


		if ((int)this._vadjustment.page_size != widget_height)
			this._vadjustment.page_size = widget_height;


		/* We need to ensure this ourselves */
		if (this._vadjustment.value > this._vadjustment.upper - this._vadjustment.page_size) {
			//block = true;
			double v = this._vadjustment.upper - this._vadjustment.page_size;
			//message ("New value: %f", v);
			this.set_value (v);
			//this._vadjustment.value = this._vadjustment.upper - this._vadjustment.page_size;
			//block = false;
		}

	}



	/**
	 * @return The bin_window's y coordinate in widget coordinates.
	 */
	private inline int bin_y ()
	{
		int value = 0;
		if (this._vadjustment != null)
			value = - (int)this._vadjustment.value;
		return value + (int)this.bin_y_diff;
	}



	private inline int widget_y (int index)
	{
		assert (index < this.widgets.size);
		assert (index >= 0);

		int y = 0;
		for (int i = 0; i < index; i ++)
		  y += get_widget_height (this.widgets.get (i));

		assert (y >= 0);
		return y;
	}



	private bool remove_top_widgets (ref int bin_height)
	{
		bool removed = false;
		/*  We don't need any child_y_diff equivalent because we are not
		 *  using the allocation's y.
		 */
		for (int i = 0; i < this.widgets.size; i ++) {
			Gtk.Widget w = this.widgets.get (i);
			int w_height = get_widget_height (w);
			if (bin_y () + widget_y (i) +  w_height < 0) {
				// Remove widget, resize and move bin_window
				message ("Remove widget %d", i);
				message ("REMOVE AT TOP");
				this.bin_y_diff += w_height;
				bin_height -= w_height;
				this.remove_child_internal (w);
				this.model_from ++;
				removed = true;
			} else {
				break;
			}
		}

		return removed;
	}



	private bool insert_top_widgets (ref int bin_height)
	{
		bool added = false;
		// Insert widgets at top
		while (model_from > 0 && bin_y () >= 0) {
			this.model_from --;
			var new_widget = get_widget (this.model_from);
			message ("INSERT AT TOP FOR MODEL_FROM %u", this.model_from);
			assert (new_widget != null);
			this.insert_child_internal (new_widget, 0);
			int min = get_widget_height (new_widget);

			this.bin_y_diff -= min;
			bin_height += min;
			added = true;
		}

		if (bin_y () > 0) {
			message ("This one!");
			// We just didn't have enough widgets...
			this.bin_y_diff = 0;
			block = true;
			//message ("New value: %f", 0.0);
			this.set_value (0.0);
			//this._vadjustment.value = 0.0;
			block = false;
		}

		return added;
	}



	private bool remove_bottom_widgets (ref int bin_height)
	{
		for (int i = this.widgets.size - 1; i >= 0; i --) {
			var w = this.widgets.get (i);

			// The widget's y in the lists' coordinates
			int widget_y = bin_y () + widget_y (i);
			if (widget_y > this.get_allocated_height ()) {
				message ("REMOVE AT BOTTOM with pos %u", model_to);
				int w_height = get_widget_height (w);
				this.remove_child_internal (w);
				bin_height -= w_height;
				this.model_to --;
			} else
				break;
		}
		return false;
	}



	private bool insert_bottom_widgets (ref int bin_height)
	{
		bool added = false;
		while (bin_y () + bin_height <= this.get_allocated_height () &&
		       model_to < (int)model.get_n_items ()) {
			var new_widget = get_widget (this.model_to);
			this.insert_child_internal (new_widget, this.widgets.size);

			message ("INSERT AT BOTTOM FOR model_to %u", this.model_to);
			int min = get_widget_height (new_widget);
			message ("new bin_height: %d -> %d", bin_height, bin_height + min);
			bin_height += min;
			added = true;
			this.model_to ++;
		}

		return added;
	}



	int counter = 0;
	private void ensure_visible_widgets (bool model_changed = false)
	{
		if (!this.get_mapped () ||
		    this.model == null)
			return;

		if (block)
		  return;

		//double value_p = this._vadjustment.value /
						 //(this._vadjustment.upper - this._vadjustment.page_size);

		message ("ensure_visible_widgets(%d): value = %f",
		         counter, this._vadjustment != null ? this._vadjustment.value : -1.0);

		//if (counter > 1) {
			//message ("Counter = %d, Returning.", counter);
			//return;
		//}

		counter ++;



		int bin_height;
		int widget_height = this.get_allocated_height ();
		bin_height = this.bin_window.get_height ();
		if (bin_height == 1) bin_height = 0;


		// OUT OF SIGHT {{{
		// If the bin_window, with the new vadjustment.value and the old
		// bin_y_diff is not in the viewport anymore at all...
		message ("bin_y: %d, bin_height: %d", bin_y (), bin_height);
		if (bin_y () + bin_height < 0 ||
		    bin_y () >= widget_height) {
			int estimated_widget_height = estimated_widget_height ();
			assert (estimated_widget_height >= 0);

			message ("-------------");
			message ("OUT OF SIGHT");
			this.remove_all_widgets ();
			bin_height = 0;


			double percentage = this._vadjustment.value /
			                    (this._vadjustment.upper - this._vadjustment.page_size);
			message ("Used value: %f, from %f (%f%%)",
			         this._vadjustment.value, this._vadjustment.upper - this._vadjustment.page_size,
			         percentage * 100);

			assert (percentage >= 0);
			assert (percentage <= 1.0);
			//uint top_widget_index = (uint)this._vadjustment.value / estimated_widget_height;
			uint top_widget_index = (uint)(this.model.get_n_items () * percentage);
			assert (top_widget_index >= 0);

			message ("estimated top widget index: %u", top_widget_index);
			message ("Model size: %u", this.model.get_n_items ());

			if (top_widget_index > this.model.get_n_items ()) {
				message ("OVERESTIMATE");
				/* Push the bin_window to the very bottom, remove all widgets. */
				this.model_to   = this.model.get_n_items ();
				this.model_from = this.model.get_n_items ();
				this.bin_y_diff = this._vadjustment.value +
				                  this._vadjustment.page_size;
			} else {
				message ("Not overestimated.");
				this.model_from = top_widget_index;
				this.model_to   = top_widget_index;
				this.bin_y_diff = top_widget_index * estimated_widget_height;
			}

			/* Extreme case is 0/0 */
			assert (model_from >= 0);
			assert (model_to   >= 0);
			assert (model_from <= model.get_n_items ());
			assert (model_to   <= model.get_n_items ());
			/* Let the rest of the code handle refilling our bin_window */
			message ("-------------");
		}
		// }}}

		bool top_removed    = remove_top_widgets    (ref bin_height);
		bool top_added      = insert_top_widgets    (ref bin_height);
		bool bottom_removed = remove_bottom_widgets (ref bin_height);
		bool bottom_added   = insert_bottom_widgets (ref bin_height);

		if (top_added)      assert (!top_removed);
		if (top_removed)    assert (!top_added);

		if (bottom_added)   assert (!bottom_removed);
		if (bottom_removed) assert (!bottom_added);

		/* In these cases, we need to reposition our rows */
		bool widgets_pos_changed = top_removed ||
		                           top_added   ||
		                           model_changed;
		bool widgets_changed = top_removed    ||
		                       top_added      ||
		                       bottom_removed ||
		                       bottom_added   ||
		                       model_changed;


		message ("widgets changed: %s, widgets pos changed: %s",
		         widgets_changed ? "true" : "false",
		         widgets_pos_changed ? "true" : "false");

		/* Since we just changed the rows + bin_height,
		   we want to adjust the value/bin_y_diff to the
		   new estimated height of the list.
		 */
		if (this._vadjustment != null && widgets_changed) {
			int bin_y = bin_y ();
			assert (bin_y <= 0);

			uint top_part;
			uint widget_part;
			uint bottom_part;

			uint new_upper = this.estimated_list_height (out top_part,
			                                             out bottom_part,
			                                             out widget_part);

			message ("bin_y_diff before: %f", this.bin_y_diff);
			message ("bin_y_diff: %f (%u or %f)",
			         mind (top_part, this._vadjustment.value),
			         top_part, this._vadjustment.value);
			if (new_upper > this._vadjustment.upper) {
				this.bin_y_diff = maxd (top_part, this._vadjustment.value);
				message ("GREATER");
			} else {
				message ("LESSER");
				this.bin_y_diff = mind (top_part, this._vadjustment.value);
			}

			this.configure_adjustment ();


			message ("setting value to %f - %d", this.bin_y_diff, bin_y);
			this.set_value (this.bin_y_diff - bin_y);
			if (this._vadjustment.value < this.bin_y_diff) {
				message ("Case 1");
				this.set_value (this.bin_y_diff);
			}


			bool top = false;
			bool bottom = false;
			if (this.bin_y () > 0 && this.model_from == 0) {
				top = true;
			}

			if (this.bin_y () + this.bin_window.get_height () < this.get_allocated_height () &&
				this.model_to == this.model.get_n_items () - 1) {

				bottom = true;
			}

			if (top)    assert (!bottom);
			if (bottom) assert (!top);


			/*
			 *
			 */
			if (this.bin_y () > 0) {
				message ("bin_y: %d, setting bin_y_diff to %d",
				         this.bin_y (), (int)this._vadjustment.value);
				this.bin_y_diff = this._vadjustment.value;
				message ("---------------");
				//assert (false);
			}
		}


		//message ("bin_y: %d", bin_y ());
		//if (widgets_changed && this._vadjustment != null)
			//this.configure_adjustment ();

		/* We always need to change this, since the value always changed. */
		this.update_bin_window (bin_height);

		/* XXX Check if we can use the condition here again */
		//if (widgets_pos_changed)
			this.position_children ();


		if (bin_y () > 0)
			message ("bin_y: %d", bin_y ());
		assert (bin_y () <= 0);

		// is the lower bound of bin_window in our viewport? It shouldn't.
		if (model_to - model_from != this.model.get_n_items () &&
		    this._vadjustment != null) {
			assert (bin_y () + bin_height >= -(int)vadjustment.value + this.get_allocated_height ());
		}

		if (this._vadjustment != null) {
			assert (this.get_allocated_height () == (int)this._vadjustment.page_size);

			if (this._vadjustment.value < this.bin_y_diff)
				message ("%f, %f", this._vadjustment.value, this.bin_y_diff);
			assert (this._vadjustment.value >= this.bin_y_diff);
		}

		assert (this.widgets.size == (model_to - model_from));


		assert (model_to <= model.get_n_items ());
		assert (model_from >= 0);
		assert (model_from <= model.get_n_items ());
		assert (bin_y () < this.get_allocated_height ());
		if (bin_y () + bin_height < 0)
			message ("-%f + %d + %d < 0", (int)this._vadjustment.value, (int)this.bin_y_diff, bin_height);
		assert (bin_y () + bin_height >= 0);

		message ("New estimated height: %u", this.estimated_list_height ());
		this.queue_draw ();
		message ("==================");
	}

}
