
/*
	 == TODO LIST ==
	 - remove last row(s) -> checkbox doesn't work anymore
	 - Make model_from and model_to uints.
	 - Remove all, add 2 items -> will display the same item twice.
	 - Very thin window -> widgets invisible
	 - Fix all XXX
	 - Revealer in Widget (Should work already?)
	 - test invisible widgets (this will probably fail)
	 - value animation is broken if upper changes during it.
		 Might need changes in gtkadjustment.c (_scroll_to_value)
		 -> loading new content when scrolling to bottom breaks it :/
	 - Port to C
 */


delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);

delegate bool ItemFilterFunc (GLib.Object item);


class ModelListBox : Gtk.Container, Gtk.Scrollable {
	private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
	private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
	private Gdk.Window bin_window;
	private GLib.ListModel model;
	public WidgetFillFunc fill_func;
	public ItemFilterFunc? filter_func = null;
	private int _bin_y_diff = 0;// distance between -vadjustment.value and bin_y
	public int bin_y_diff {
		get {
			return this._bin_y_diff;
		}
		set {
			message ("Setting bin_y_diff to %d", value);
			this._bin_y_diff = value;
		}
	}

	private int _model_from = 0;
	private int _model_to	 = -1;
	// We need this in case this.widgets is empty
	// but we still need to estimated their height
	private int last_valid_widget_height = 1;

	/* GtkScrollable properties	{{{ */
	private Gtk.Adjustment? _vadjustment;
	public Gtk.Adjustment? vadjustment {
		set {
			this._vadjustment = value;
			if (this._vadjustment != null) {
				this._vadjustment.value_changed.connect (ensure_visible_widgets);
			}
			configure_adjustment ();
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

	private int _estimated_height = 0;
	public int estimated_height {
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


	public void refilter ()
	{
		this.remove_all_widgets ();
		this.update_bin_window ();
		this.model_from = 0;
		this.model_to = -1;
		this.bin_y_diff = 0;
		this._vadjustment.value = 0;
		this.ensure_visible_widgets ();
	}

	private Gtk.Widget? get_next_widget (uint start_index,
	                                     out uint selected_index)
	{
		uint unfiltered_index = start_index;

		if (this.filter_func != null) {
			while (unfiltered_index < this.model.get_n_items () &&
			       !this.filter_func (this.model.get_object (unfiltered_index)))
				unfiltered_index ++;
		}

		assert (unfiltered_index >= start_index);

		selected_index = unfiltered_index;

		if (unfiltered_index >= this.model.get_n_items ())
			return null;

		return fill_func (model.get_object (unfiltered_index),
		                  get_old_widget ());
	}

	private Gtk.Widget? get_prev_widget (uint start_index,
	                                     out uint selected_index)
	{
		uint unfiltered_index = start_index;

		if (this.filter_func != null) {
			while (unfiltered_index >= 0 &&
			       !this.filter_func (this.model.get_object (unfiltered_index)))
				unfiltered_index --;
		}

		assert (unfiltered_index <= start_index);

		selected_index = unfiltered_index;

		if (unfiltered_index < 0)
			return null;

		return fill_func (model.get_object (unfiltered_index),
		                  get_old_widget ());
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
			//this.model.items_changed.disconnect (items_changed_cb);
		}

		this.model = model;
		//this.model.items_changed.connect (items_changed_cb);
		this.queue_resize ();
	}


	//private void remove_visible_widgets (int pos, int count)
	//{
		// Remove the specified amount of widgets,
		// moving all of the below widgets down and
		// adjusting model_to/model_from accordingly
		//model_to -= count;
		//int removed_height = 0;
		//for (int i = count - 1; i >= 0; i --) {
			//int index = pos + i;
			//var w = this.widgets.get (index);
			//removed_height += get_widget_height (w);
			//this.remove_child_internal (w);
		//}

		// Move the tail up
		//this.position_children ();
	//}

	//public void insert_visible_widgets (int pos, int count)
	//{
		// We need to kill all of the widgets below the inserted ones,
		// since their index gets invalidated by the insertion.

		//this.model_to -= this.widgets.size - pos;

		// delete all after the insertion point
		//for (int i = pos; i < this.widgets.size; i ++) {
			//this.remove_child_internal (this.widgets.get (pos));
			//i --;
		//}
		//this.position_children ();
	//}


	//private inline uint max (uint a, uint b)
	//{
		//return (a > b) ? a : b;
	//}

	//private inline bool bin_window_full () {
		//int bin_height;
		//Gtk.Allocation widget_alloc;
		//this.bin_window.get_geometry (null, null, null, out bin_height);
		//this.get_allocation (out widget_alloc);

		//return !(bin_y () + bin_height <= widget_alloc.height);
	//}

	//private void items_changed_cb (uint position, uint removed, uint added)
	//{
		//message ("ITEMS CHANGED. position: %u, removed: %u, added: %u",
				 //position, removed, added);

		//if (position > model_to &&
				//bin_window_full ()) {
			//if (this._vadjustment == null)
				//this.queue_resize ();
			//else
				//this.configure_adjustment ();

			//return;
		//}

		//uint impact = position + max (added, removed);

		//if (impact > model_from) {
			// XXX We could optimize this by actually inserting new widgets
			//		 When they can be inserted instead of always removing/re-adding
			//		 the entire tail/.
			//int widgets_to_remove = (int)position + (int)removed - model_from;
			//if (widgets_to_remove > this.widgets.size)
				//widgets_to_remove = this.widgets.size - 1;

			//int widgets_to_add	= (int)position + (int)added - model_from;
			//int widget_pos = (int)position - model_from;

			//if (widget_pos < 0) widget_pos = 0;

			//if (widgets_to_remove > 0) {
				//widgets_to_remove = this.widgets.size - widget_pos;
				//this.remove_visible_widgets (widget_pos, widgets_to_remove);
			//}

			//if (widgets_to_add > 0 && widgets_to_add < this.widgets.size)
				//this.insert_visible_widgets (widget_pos, widgets_to_add);

			// XXX Just decrease the bin_window size by the widget's height when removing it.
			//this.update_bin_window ();
			//this.ensure_visible_widgets ();
		//}




		//if (this._vadjustment == null)
			//this.queue_resize ();
		//else
			//configure_adjustment ();

	//}

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

		// DBG
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

		// DBG
		this.cur_widgets = this.widgets.size;
	}

	private void remove_all_widgets ()
	{
		for (int i = this.widgets.size - 1; i >= 0; i --)
			this.remove_child_internal (this.widgets.get (i));
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
		//return typeof (Gtk.ListBoxRow);
	}
	/* }}} */

	/* GtkWidget API	{{{ */

	public override bool draw (Cairo.Context ct)
	{
		//var sc = this.get_style_context ();
		Gtk.Allocation alloc;
		this.get_allocation (out alloc);

		ct.set_source_rgba (1, 0, 0, 1);
		ct.rectangle (0, 0, alloc.width, alloc.height);
		ct.fill ();


		//sc.render_background (ct, 0, 0, alloc.width, alloc.height);
		//sc.render_frame (ct, 0, 0, alloc.width, alloc.height);


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

		//ensure_visible_widgets ();
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



	private inline int get_widget_height (Gtk.Widget w)
	{
		int min, nat;
		w.get_preferred_height_for_width (this.get_allocated_width (),
		                                  out min,
		                                  out nat);

		assert (min >= 1);

		return min;
	}

	private inline int estimated_widget_height ()
	{

		int average_widget_height = 0;

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

	private int estimated_list_height (out int top_part     = null,
	                                   out int bottom_part  = null,
	                                   out int widgets_part = null)
	{
		int widget_height = estimated_widget_height ();

		assert (widget_height >= 0);
		assert (model_from >= 0);

		if (this.model == null) {
			top_part = 0;
			bottom_part = 0;
			widgets_part = 0;
			return 0;
		}

		float filter_factor;
		if (this.filter_func == null)
			filter_factor = 1.0f;
		else {
			if (this.widgets.size > 0)
				filter_factor = (float)this.widgets.size / (float)(model_to - model_from);
			else
				filter_factor = 1.0f;
		}


		int top_widgets		= model_from;
		//message ("%u, %d", model.get_n_items (), model_to);
		int bottom_widgets = (int)this.model.get_n_items () - model_to - 1;

		assert (top_widgets >= 0);
		assert (bottom_widgets >= 0);

		// XXX all the get_preferred_width_for height calls might be very expensive?
		int exact_height = 0;
		foreach (var w in this.widgets) {
			int h = get_widget_height (w);
			exact_height += h;
		}

		assert (exact_height >= 0);

		top_part     = (int)(top_widgets    * widget_height * filter_factor);
		bottom_part  = (int)(bottom_widgets * widget_height * filter_factor);
		widgets_part = exact_height;

		assert (top_part >= 0);

		int h =	exact_height +
		        (int)(top_widgets    * widget_height * filter_factor) +
		        (int)(bottom_widgets * widget_height * filter_factor);


		// DBG
		this.estimated_height = h;

		return h;
	}

	private void update_bin_window ()
	{
		Gtk.Allocation allocation;
		this.get_allocation (out allocation);

		int h = 0;
		int min;
		foreach (var w in this.widgets) {
			min = get_widget_height (w);
			assert (min >= 0);
			h += min;
			//message ("h + %d = %d", min, h);
		}

		if (h == 0)
			h = 1;


		this.bin_window.move_resize (0,
		                             bin_y (),
		                             allocation.width,
		                             h);
	}


	public void print_debug_info ()
	{
		message ("-----------------------------");
		message ("bin_y: %d", bin_y ());

		message ("-----------------------------");
	}

	private void configure_adjustment ()
	{
		if (this._vadjustment == null)
			return;

		int top_widgets_height;
		int bottom_widgets_height;
		int exact_list_height;
		int list_height = estimated_list_height (out top_widgets_height,
		                                         out bottom_widgets_height,
		                                         out exact_list_height);
		if ((int)this._vadjustment.upper != list_height) {
			//message ("Updating upper from %d to %d", (int)this._vadjustment.upper, list_height);
			//int diff = (int)this._vadjustment.upper - list_height;
			//this.bin_y_diff -= diff;
		}

		this._vadjustment.configure (this._vadjustment.value,// value,
		                             0, // lower
		                             list_height, // Upper
		                             1, // step increment
		                             2, // page increment
		                             this.get_allocated_height ()); // page_size
	}

	/**
	 * @return The bin_window's y coordinate in widget coordinates.
	 */
	private int bin_y ()
	{
		int v = 0;
		if (this._vadjustment != null)
			v = - (int)this._vadjustment.value;
		int p = v + this.bin_y_diff;
		return p;
	}


	private void insert_needed_top_widgets (ref int bin_height, bool end = false)
	{
		// Insert widgets at top
		while (bin_y () > 0 && model_from > 0) {
			uint new_model_from;
			var new_widget = get_prev_widget (model_from - 1, out new_model_from);
			assert (new_widget != null);
			this.model_from = (int)new_model_from;
			this.insert_child_internal (new_widget, 0);
			int min = get_widget_height (new_widget);
			message ("INSERT AT TOP");
			this.bin_y_diff -= min;
			bin_height += min;
			if (end) {
				message ("bin_y now: %d", bin_y ());
			}
		}
	}


	private void ensure_visible_widgets ()
	{
		if (!this.get_mapped () ||
		    this.model == null)
			return;

		// !vadjustment case {{{
		if (this._vadjustment == null) {
			if (this.widgets.size < (int)this.model.get_n_items ()) {
				while (model_to < (int)this.model.get_n_items () - 1) {
					//model_to ++;
					//uint new_model_to;
					//var new_widget = get_next_widget (model_to + 1, out new_model_to);
					error ("FIXME: Wrong insertion position");
					//this.insert_child_internal (new_widget, model_to); // XXX Insertion position will be wrong.
					//this.model_to = (int)new_model_to;
				}
			}

			assert (model_from == 0);
			assert (model_to == this.model.get_n_items () - 1);
			return;
		}

		//}}}


		message ("==================================== %f", this._vadjustment.value);


		int bin_height;
		Gtk.Allocation widget_alloc;
		this.get_allocation (out widget_alloc);
		this.bin_window.get_geometry (null, null, null, out bin_height);
		if (bin_height == 1) bin_height = 0;


		// OUT OF SIGHT {{{
		// If the bin_window, with the new vadjustment.value and the old
		// bin_y_diff is not in the viewport anymore at all...
		if (bin_y () + bin_height < 0 ||
		    bin_y () > widget_alloc.height) {
			int estimated_widget_height = estimated_widget_height ();
			assert (estimated_widget_height >= 0);

			message ("OUT OF SIGHT");
			/*
				 XXX We can overestimate the complete real size of the list,
						 so top_widget_index might be too big.
						 In that case, just set model_to = items.size - 1
						 and build the visible widgets backwards.
			 */
			int top_widget_index = (int)this._vadjustment.value / estimated_widget_height;
			assert (top_widget_index >= 0);

			if (top_widget_index > (int)this.model.get_n_items ()) {
				message ("OVERESTIMATE");
				remove_all_widgets ();
				this.model_to = (int)this.model.get_n_items () - 1;
				this.model_from = this.model_to + 1;

				// Empty bin window at the bottom of the list/widget
				bin_height = 0;
				this.bin_y_diff = (int)this._vadjustment.value + this.get_allocated_height ();
				while (model_from > 0 &&
				       bin_height < this.get_allocated_height ()) {
					//this.model_from --;
					//var widget = get_next_widget (model_from - 1);
					uint new_model_from;
					var widget = get_prev_widget (model_from -1, out new_model_from);
					int widget_height = this.get_widget_height (widget);

					bin_height += widget_height;
					this.bin_y_diff -= widget_height;
					this.insert_child_internal (widget, 0);
					this.model_from = (int)new_model_from;
				}

				if (!(model_from == 0 && model_to == -1)) {
					assert (model_from <= model_to);
				}
				assert (model_to == (int)this.model.get_n_items () - 1);

				// if bin_y () is still > 0, we just don't have enough widgets to fill the entire
				// viewport, so just move the bin_window up again
				if (bin_y () > 0)
					this.bin_y_diff = 0;

				this.update_bin_window ();
				this.configure_adjustment ();

				return;
			}

			this.bin_y_diff = (top_widget_index * estimated_widget_height);// - top_widget_y_diff;
			bin_height = 0; // Because we removed all  widgets.

			remove_all_widgets ();

			this.model_from = top_widget_index;// - 1;
			this.model_to	= model_from - 1;

			assert (model_from >= 0);
			assert (model_from < model.get_n_items ());
			assert (model_to < (int)model.get_n_items ());

			// Let the rest of the code handle refilling our bin_window
		}
		// }}}



		/* XXX This case can happen when we overestimate the size
			 of the widgets at the top of the visible range.
		*/
		if (bin_y () > 0 && model_from == 0) {
			// Can't help it, need to move the bin_window :(
			int top;
			this.estimated_list_height (out top);
			message ("top: %d", top);
			message ("VALUE: %f", this._vadjustment.value);
			assert (top == 0);
			this.bin_y_diff = 0;
			//assert (bin_y () == 0);
		}


		// TOP {{{

		// Removing children at top
		for (int i = 0; i < this.widgets.size; i ++) {
			Gtk.Allocation alloc;
			Gtk.Widget w = this.widgets.get (i);
			w.get_allocation (out alloc);
			int w_height = get_widget_height (w);
			if (bin_y () + alloc.y +  w_height < 0) {
				// Remove widget, resize and move bin_window
				message ("REMOVE AT TOP");
				this.bin_y_diff += w_height;
				bin_height -= w_height;

				this.remove_child_internal (w);

				uint new_model_from;
				this.get_next_widget (model_from + 1, out new_model_from);
				this.model_from = (int)new_model_from;
			}
			else break;
		}

		insert_needed_top_widgets (ref bin_height);


		// }}}

		// BOTTOM {{{
		// Bottom of bin_window hangs into the widget


		// remove widgets
		for (int i = this.widgets.size - 1; i >= 0; i --) {
			Gtk.Allocation alloc;
			var w = this.widgets.get (i);
			w.get_allocation (out alloc);

			// The widget's y in the lists' coordinates
			int widget_y = bin_y () + alloc.y;
			message ("%d: %d + %d = %d", i, bin_y (), alloc.y, widget_y);
			message ("%d: Allocated height: %d", i, this.get_allocated_height ());
			if (widget_y > this.get_allocated_height ()) {
				message ("REMOVE AT BOTTOM %d", i);
				if (model_to == 28) {
					var row = (TweetRow) w;
					row.set_label ("END");
					break;
				} else {
				this.remove_child_internal (w);
				// XXX Just calling this to get the previous visible item index
				uint new_model_to;
				this.get_prev_widget (this.model_to - 1,
															out new_model_to);
				int w_height = get_widget_height (w);
				bin_height -= w_height;

				//message ("Changing model_to from %d to %d", model_to, (int)new_model_to);

				this.model_to = (int)new_model_to;
				}
				//model_to --;
			} else
				break;
		}


		// Insert widgets at bottom
		while (bin_y () + bin_height <= widget_alloc.height &&
		       model_to < (int)model.get_n_items () - 1) {
			uint new_model_to;
			var new_widget = get_next_widget (model_to + 1, out new_model_to);
			if (new_widget == null) {
				//assert (new_model_to == this.model.get_n_items ());
				this.model_to = (int)this.model.get_n_items () - 1;

				// XXX At this point, the widgets could hang into the window
						 //because we just didn't have enough widgets to fill it.
				message ("END OF LIST : %d", this.bin_y_diff);
				this.bin_y_diff = (int)this._vadjustment.upper - bin_height;
				insert_needed_top_widgets (ref bin_height, true);
				break;
			}
			this.insert_child_internal (new_widget, this.widgets.size);

			message ("INSERT AT BOTTOM");
			this.model_to = (int)new_model_to;
			int min;
			min = get_widget_height (new_widget);
			bin_height += min;
		}
		// }}}





		// XXX Maybe optimize this out if nothing changed?
		// XXX update_bin_window will do slow stuff and we just computed bin_height ourselves...
		configure_adjustment ();
		this.update_bin_window ();
		int h;
		this.bin_window.get_geometry (null, null, null, out h);
		if (h == 1) h = 0;
		message ("h: %d, bin_height: %d", h, bin_height);
		assert (h == bin_height);
		this.position_children ();


		assert (this.bin_y_diff >= 0);
		if (bin_y () > 0)
		  message ("bin_y: %d", bin_y ());
		assert (bin_y () <= 0);

		// is the lower bound of bin_window in our viewport? It shouldn't.
		assert (bin_y () + bin_height > -(int)vadjustment.value + this.get_allocated_height ());

		// This should also alwways be true
		assert (bin_height > this.get_allocated_height ());


		if (this.filter_func == null)
			assert (this.widgets.size == (model_to - model_from + 1));

		assert (model_to <= model.get_n_items () -1);
		//message ("model_to: %d", model_to);
		//assert (model_to >= 0);
		assert (model_from >= 0);
		assert (model_from <= model.get_n_items () - 1);
		if (this._vadjustment != null && this._vadjustment.value == 0) {
			assert (this.bin_y_diff == 0);
			assert (this.model_from == 0);
			assert (bin_y () == 0);
		}
	}

}
