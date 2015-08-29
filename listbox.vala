/*
	 == TODO LIST ==
	 - Optimize stuff
	 - Make model_from and model_to uints.
	 - Very thin window -> widgets invisible
	 - Fix all XXX
	 - Revealer in Widget (Should work already?)
	 - Port to C
 */



/*




 */

inline uint max (uint a, uint b)
{
	return (a > b) ? a : b;
}

inline int min (int a, int b)
{
	return a < b ? a : b;
}



delegate Gtk.Widget WidgetFillFunc (GLib.Object item,
                                    Gtk.Widget? old_widget);


class ModelListBox : Gtk.Container, Gtk.Scrollable {
	private Gee.ArrayList<Gtk.Widget> widgets = new Gee.ArrayList<Gtk.Widget> ();
	private Gee.ArrayList<Gtk.Widget> old_widgets = new Gee.ArrayList<Gtk.Widget> ();
	private Gdk.Window bin_window;
	private GLib.ListModel model;
	public WidgetFillFunc fill_func;
	private int _bin_y_diff = 0;// distance between -vadjustment.value and bin_y
	public int bin_y_diff {
		get {
			return this._bin_y_diff;
		}
		set {
			message ("Setting bin_y_diff from %d to %d. bin_y now: %d", this._bin_y_diff, value,
			         -((int)this._vadjustment.value) + this._bin_y_diff);
			this._bin_y_diff = value;
			assert (this._bin_y_diff >= 0);
		}
	}

	private int _model_from = 0;
	private int _model_to   = -1;

	// We need this in case this.widgets is empty
	// but we still need to estimate their height
	private int last_valid_widget_height = 1;

	/* GtkScrollable properties	{{{ */
	private Gtk.Adjustment? _vadjustment;
	public Gtk.Adjustment? vadjustment {
		set {
			this._vadjustment = value;
			if (this._vadjustment != null) {
				this._vadjustment.value_changed.connect (ensure_visible_widgets);
				this._vadjustment.notify["page-size"].connect (page_size_changed_cb);
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


	private Gtk.Widget get_widget (int index)
	{
		var item = model.get_object (index);
		assert (item != null);

		return fill_func (item, get_old_widget ());
	}

	private Gtk.Widget? get_old_widget ()
	{
		if (this.old_widgets.size == 0)
			return null;

		var w = this.old_widgets.get (this.old_widgets.size - 1);
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


	private inline int model_range ()
	{
		return this.model_to - this.model_from + 1;
	}

	private inline bool bin_window_full () {
		int bin_height;
		Gtk.Allocation widget_alloc;
		this.bin_window.get_geometry (null, null, null, out bin_height);
		this.get_allocation (out widget_alloc);

		return !(bin_y () + bin_height <= widget_alloc.height);
	}

	private void page_size_changed_cb ()
	{
		if (!this.get_mapped ())
			return;

		double max_value = this._vadjustment.upper - this._vadjustment.page_size;

		if (this._vadjustment.value > max_value) {
			// XXX Will call ensure_visible_widgets
			this._vadjustment.value = max_value;
		}

		this.configure_adjustment ();

		// XXX HERE WE CALL IT AGAIN FUCK
		this.ensure_visible_widgets ();
	}

	private void items_changed_cb (uint position, uint removed, uint added)
	{
		message ("ITEMS CHANGED. position: %u, removed: %u, added: %u, model_size: %u, model_from: %d,
				 model_to: %d",
				 position, removed, added, model.get_n_items (), model_from, model_to);

		if (position > model_to &&
		    bin_window_full ()) {

			if (this._vadjustment == null)
				this.queue_resize ();
			else
				this.configure_adjustment ();

			return;
		}



		/*
		 * XXX
		 * We are just removing all visible widgets and add them again.
		 * Quite some potential for optimization here.
		 */

		this.remove_all_widgets ();
		this.model_to = this.model_from - 1;
		message ("model_from: %d", this.model_from);
		message ("  model_to: %d", this.model_to);
		this.update_bin_window ();
		this.ensure_visible_widgets ();

		if (this._vadjustment == null)
			this.queue_resize ();
		else
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
		var sc = this.get_style_context ();
		Gtk.Allocation alloc;
		this.get_allocation (out alloc);

		sc.render_background (ct, 0, 0, alloc.width, alloc.height);
		sc.render_frame (ct, 0, 0, alloc.width, alloc.height);

		{
			int x, y, w, h;
			this.bin_window.get_geometry (out x, out y, out w, out h);
			ct.set_source_rgba (0, 0, 1, 1);
			ct.rectangle (x, y, w, h);
			ct.stroke ();
		}



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

		// Will call ensure_widgets if needed...
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

		// XXX Do we really not want to care about invisible widgets here?
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

	private int estimated_list_height (out int top_part     = null,
	                                   out int bottom_part  = null,
	                                   out int widgets_part = null)
	{
		int widget_height = estimated_widget_height ();

		assert (widget_height >= 0);
		assert (model_from >= 0);

		int top_widgets    = model_from;
		int bottom_widgets = (int)this.model.get_n_items () - model_to - 1;

		assert (top_widgets >= 0);
		assert (bottom_widgets >= 0);

		assert (top_widgets + bottom_widgets + this.widgets.size == (int)this.model.get_n_items ());

		int exact_height = 0;
		foreach (var w in this.widgets) {
			int h = get_widget_height (w);
			exact_height += h;
		}

		assert (exact_height >= 0);

		top_part     = (int)(top_widgets    * widget_height);
		bottom_part  = (int)(bottom_widgets * widget_height);
		widgets_part = exact_height;

		assert (top_part >= 0);
		assert (bottom_part >= 0);
		assert (widgets_part >= 0);

		int h = top_part + bottom_part + widgets_part;

		//int min_list_height = (int)this._vadjustment.value
							  //+ bin_y ()
							  //+ widgets_part;

		//h = (int) max (h, min_list_height);

		// DEBUG
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
		if (this._vadjustment == null)
			return;


		int widget_height = this.get_allocated_height ();
		int list_height = estimated_list_height ();

		if ((int)this._vadjustment.upper != max (list_height, widget_height)) {
			message ("New upper: %u (Before: %d)", max (list_height, widget_height),
			         (int)this._vadjustment.upper);
			this._vadjustment.upper = max (list_height, widget_height);
		} else if (list_height == 0) {
			this._vadjustment.upper = widget_height;
		}


		if ((int)this._vadjustment.page_size != widget_height)
			this._vadjustment.page_size = widget_height;


		/* We need to ensure this ourselves */
		if (this._vadjustment.value > this._vadjustment.upper - this._vadjustment.page_size) {
			//double new_value = this._vadjustment.upper - this._vadjustment.page_size;
			//message ("Restraining value from %d to %d, upper: %d,page_size: %d",
					 //(int)this._vadjustment.value,
					 //(int)new_value, (int)this._vadjustment.upper,
					 //(int)this._vadjustment.page_size);
			block = true;
			this._vadjustment.value = this._vadjustment.upper - this._vadjustment.page_size;
			block = false;
		}

	}



	/**
	 * @return The bin_window's y coordinate in widget coordinates.
	 */
	private inline int bin_y ()
	{

		// XXX Depends on bin_y_diff and the value!

		int value = 0;
		if (this._vadjustment != null)
			value = - (int)this._vadjustment.value;
		return value + this.bin_y_diff;
	}

	private bool remove_top_widgets (ref int bin_height)
	{
		bool removed = false;
		// XXX We don't need any child_y_diff equivalent because we are not
		//     using the allocation's y.
		for (int i = 0; i < this.widgets.size; i ++) {
			Gtk.Widget w = this.widgets.get (i);
			int w_height = get_widget_height (w);
			if (bin_y () + widget_y (i) +  w_height < 0) {
				// Remove widget, resize and move bin_window
				message ("Remove widget %d", i);
				message ("REMOVE AT TOP");
				message ("Height: %d", w_height);
				if (w.visible) message ("Visible!");
				this.bin_y_diff += w_height;
				bin_height -= w_height;
				this.remove_child_internal (w);
				this.model_from ++;
				removed = true;
			}
			else {
				message ("Break at %d", i);
				break;
			}
		}

		return removed;
	}


	private bool insert_top_widgets (ref int bin_height,
                                     bool end = false)
	{
		bool added = false;
		// Insert widgets at top
		while (bin_y () >= 0 && model_from > 0) {
			this.model_from --;
			var new_widget = get_widget (this.model_from);
			message ("INSERT AT TOP FOR MODEL_FROM %d", this.model_from);
			assert (new_widget != null);
			this.insert_child_internal (new_widget, 0);
			int min = get_widget_height (new_widget);
			this.bin_y_diff -= min;
			bin_height += min;
			added = true;
		}

		if (bin_y () > 0) {
			// We just didn't have enough widgets...
			this.bin_y_diff = 0;
			block = true;
			this._vadjustment.value = 0;
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
				message ("REMOVE AT BOTTOM with pos %d", model_to);
				int w_height = get_widget_height (w);
				this.remove_child_internal (w);
				bin_height -= w_height;
				this.model_to --;
			} else
				break;
		}
		return false;
	}

	private bool insert_bottom_widgets (ref int bin_height,
                                        bool    start = false)
	{
		bool added = false;
		while (bin_y () + bin_height <= this.get_allocated_height () &&
		       model_to < (int)model.get_n_items () - 1) {
			this.model_to ++;
			var new_widget = get_widget (this.model_to);
			this.insert_child_internal (new_widget, this.widgets.size);

			message ("INSERT AT BOTTOM FOR model_to %u", this.model_to);
			int min = get_widget_height (new_widget);
			message ("new bin_height: %d -> %d", bin_height, bin_height + min);
			bin_height += min;
			added = true;
		}

		return added;
	}



	private inline int widget_y (int index)
	{
		// XXX Sould we really iterate all the time like that?
		assert (index < this.widgets.size);
		assert (index >= 0);

		int y = 0;
		for (int i = 0; i < index; i ++)
		  y += get_widget_height (this.widgets.get (i));

		assert (y >= 0);
		return y;
	}


	private void ensure_visible_widgets ()
	{
		if (!this.get_mapped () ||
		    this.model == null)
			return;

		if (block)
		  return;





		int bin_height;
		Gtk.Allocation widget_alloc;
		this.get_allocation (out widget_alloc);
		bin_height = this.bin_window.get_height ();
		if (bin_height == 1) bin_height = 0;

		// OUT OF SIGHT {{{
		// If the bin_window, with the new vadjustment.value and the old
		// bin_y_diff is not in the viewport anymore at all...
		if (bin_y () + bin_height < 0 ||
		    bin_y () >= widget_alloc.height) {
			int estimated_widget_height = estimated_widget_height ();
			assert (estimated_widget_height >= 0);

			message ("OUT OF SIGHT");
			/*
				 XXX We can overestimate the complete real size of the list,
				     so top_widget_index might be too big.
				     In that case, just set model_to = items.size - 1
				     and build the visible widgets backwards.
			 */

			/*
				XXX
				If lots of widgets e.g. at the end are invisible, we'd have to go back
				int the list and find enough visible ones...
			 */


			int top_widget_index = (int)this._vadjustment.value / estimated_widget_height;
			assert (top_widget_index >= 0);

			if (top_widget_index > (int)this.model.get_n_items ()) {
				message ("OVERESTIMATE");
				remove_all_widgets ();
				this.model_to = (int)this.model.get_n_items () - 1;
				this.model_from = this.model_to + 1;

				 //Empty bin window at the bottom of the list/widget
				bin_height = 0;
				this.bin_y_diff = (int)this._vadjustment.value + this.get_allocated_height ();
				while (model_from > 0 &&
					   bin_height < this.get_allocated_height ()) {
					this.model_from --;

					//var widget = get_next_widget (model_from - 1);
					this.model_from --;
					var widget = get_widget (model_from);
					//this.model_from --;
					//var widget = get_widget (this._model_from);
					int widget_height = this.get_widget_height (widget);

					bin_height += widget_height;
					this.bin_y_diff -= widget_height;
					this.insert_child_internal (widget, 0);
				}

				if (!(model_from == 0 && model_to == -1)) {
					assert (model_from <= model_to);
				}
				assert (model_to == (int)this.model.get_n_items () - 1);

				 //if bin_y () is still > 0, we just don't have enough widgets to fill the entire
				 //viewport, so just move the bin_window up again
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
			this.model_to    = model_from - 1;

			message ("New range: %d - %d", model_from, model_to);

			/* Extreme case is 0/-1 */
			assert (model_from >= 0);
			assert (model_from <= model.get_n_items ());
			assert (model_to < (int)model.get_n_items ());

			 //Let the rest of the code handle refilling our bin_window
		}
		// }}}

		bool top_removed = remove_top_widgets (ref bin_height);
		bool top_added   = insert_top_widgets (ref bin_height);

		if (top_added) assert (!top_removed);
		if (top_removed) assert (!top_added);

		bool bottom_removed = remove_bottom_widgets (ref bin_height);
		bool bottom_added   = insert_bottom_widgets (ref bin_height);

		if (bottom_added)   assert (!bottom_removed);
		if (bottom_removed) assert (!bottom_added);



		{
			message ("------------");
			int bin_y = bin_y ();
			assert (bin_y <= 0);

			int top_part;
			int widget_part;
			int bottom_part;

			message ("bin_y before: %d", this.bin_y ());
			message ("value before: %f", this._vadjustment.value);
			this.estimated_list_height (out top_part,
			                            out bottom_part,
			                            out widget_part);

			this.bin_y_diff = min (top_part, (int)this._vadjustment.value);

			message ("bin_y now: %d", this.bin_y ());

			this.configure_adjustment ();
			message ("Value now: %f", this._vadjustment.value);

			//message ("bin_y: %d", this.bin_y ());
			block = true;
			message ("Max: %f", this._vadjustment.upper - this._vadjustment.page_size);
			this._vadjustment.value = this.bin_y_diff + (-bin_y);
			message ("New value: %f (%f - %d)", this._vadjustment.value, this.bin_y_diff, bin_y);
			message ("bin_y now: %d", this.bin_y ());
			block = false;

			bool top = false;
			bool bottom = false;
			if (this.bin_y () > 0 && this.model_from == 0) {
				top = true;
			}

			if (this.bin_y () + this.bin_window.get_height () < this.get_allocated_height () &&
			    this.model_to == (int)this.model.get_n_items () - 1) {

				bottom = true;
			}

			if (top)    assert (!bottom);
			if (bottom) assert (!top);


			if (this.bin_y () > 0) {
				message ("bin_y: %d, setting bin_y_diff to %d",
				         this.bin_y (), (int)this._vadjustment.value);
				this.bin_y_diff = (int)this._vadjustment.value;
				assert (false);
			}

			message ("---------------");

		}






		// XXX Maybe optimize this out if nothing changed?
		// XXX update_bin_window will do slow stuff and we just computed bin_height ourselves...
		message ("bin_y: %d", bin_y ());
		this.configure_adjustment ();
		message ("bin_y: %d", bin_y ());
		this.update_bin_window ();
		int h;
		// XXX Remove this assertion, pass the new bin_size to update_bin_window
		h = this.bin_window.get_height ();
		if (h == 1) h = 0;
		if (h != bin_height)
		  message ("h: %d, bin_height: %d", h, bin_height);
		assert (h == bin_height);

		// XXX Is this really necessary EVERY TIME?
		this.position_children ();


		if (bin_y () > 0)
		  message ("bin_y: %d", bin_y ());
		assert (bin_y () <= 0);

		// is the lower bound of bin_window in our viewport? It shouldn't.
		if (model_range () != this.model.get_n_items ()) {
			assert (bin_y () + bin_height >= -(int)vadjustment.value + this.get_allocated_height ());
		}

		assert (this.get_allocated_height () == (int)this._vadjustment.page_size);

		assert (this.widgets.size == (model_to - model_from + 1));

		assert (model_to <= model.get_n_items () - 1);
		assert (model_from >= 0);
		assert (model_from <= model.get_n_items () - 1);
	}

}
